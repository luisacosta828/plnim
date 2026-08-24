import pgxcrown
import pgxcrown/datatypes/[basic, heaptuples]
import pgxcrown/catalog/[pg_proc, pg_type]
import pgxcrown/syscache
import dynlib
import std/[strutils, sequtils, tables]
import os

type
  CachedPlnimFunction = object
    lib: LibHandle
    fn_call: proc(a: FunctionCallInfo): Datum {.cdecl.}

var gFunctionCache: Table[Oid, CachedPlnimFunction]

PG_MODULE_MAGIC

proc translate_pg_types_to_nim(typ: string): string {.inline.} =
  case typ
  of "int4", "int": "int32"
  of "int8": "int64"
  of "int2": "int16"
  of "float4": "float32"
  of "float8": "float64"
  of "text", "varchar": "string"
  of "bool", "boolean": "bool"
  of "json", "jsonb": "JsonNode"
  of "_int4", "int4[]": "seq[int32]"
  of "_int8", "int8[]": "seq[int64]"
  of "_float8", "float8[]": "seq[float64]"
  of "_text", "text[]": "seq[string]"
  of "_bool", "bool[]": "seq[bool]"
  of "_json", "json[]", "_jsonb", "jsonb[]": "seq[JsonNode]"
  else: typ.capitalizeAscii


proc extract_imports_and_body(prosrc: string): (string, string) =
  var imports: seq[string] = @[]
  var raw_body_lines: seq[string] = @[]

  for line in prosrc.splitLines():
    let trimmed = line.strip()
    if trimmed.startsWith("import ") or trimmed.startsWith("from "):
      imports.add trimmed
    else:
      raw_body_lines.add line

  while raw_body_lines.len > 0 and raw_body_lines[0].strip().len == 0:
    raw_body_lines.delete(0)
  while raw_body_lines.len > 0 and raw_body_lines[^1].strip().len == 0:
    raw_body_lines.delete(raw_body_lines.len - 1)

  var minIndent = int.high
  for line in raw_body_lines:
    if line.strip().len > 0:
      var indent = 0
      for c in line:
        if c == ' ': indent += 1
        elif c == '\t': indent += 2
        else: break
      if indent < minIndent:
        minIndent = indent
  if minIndent == int.high: minIndent = 0

  var formatted_body: seq[string] = @[]
  for line in raw_body_lines:
    if line.strip().len == 0:
      formatted_body.add ""
    else:
      let stripped = if line.len >= minIndent: line[minIndent .. ^1] else: line.strip()
      formatted_body.add "  " & stripped

  return (imports.join("\n"), formatted_body.join("\n"))


proc generate_composite_type_def*(type_oid: Oid, nim_type_name: string): string =
  var tupdesc = lookup_rowtype_tupdesc_noerror(type_oid, -1, true)
  if tupdesc.isNil:
    return ""
  
  var fields: seq[string] = @[]
  var is_null = false
  for i in 0 ..< int(cast[TupleDescStruct](tupdesc).natts):
    var attr = TupleDescAttr(tupdesc, i.cint)
    if not attr.attisdropped:
      var field_name = $NameStr(attr.attname)
      var field_oid = attr.atttypid
      var type_tuple = SearchSysCache1(TYPEOID, ObjectIdGetDatum(field_oid))
      if not type_tuple.isNil:
        var pg_name = get_pg_type_name(type_tuple)
        ReleaseSysCache(type_tuple)
        var field_nim_type = translate_pg_types_to_nim($pg_name)
        fields.add "  " & field_name & "*: " & field_nim_type

  DecrTupleDescRefCount(tupdesc)

  if fields.len > 0:
    return "type " & nim_type_name & "* = object\n" & fields.join("\n") & "\n"
  return ""


proc to_pgxcrown(proname: cstring, prosrc: cstring, pronargs: int16, heapTuple: spi.HeapTuple, prorettype: Oid, proargnames: seq[string]): string =
  var 
    proretset = get_pg_proc_retset(heapTuple)
    plnim_args: seq[string] = @[]
    is_null = false
    rettype_tuple = SearchSysCache1(TYPEOID, ObjectIdGetDatum(prorettype))
    plnim_rettype = if not rettype_tuple.isNil:
      let n = $get_pg_type_name(rettype_tuple)
      ReleaseSysCache(rettype_tuple)
      n
    else: "void"
    base_ret_nim_type = translate_pg_types_to_nim(plnim_rettype)
    ret_nim_type = if proretset and not base_ret_nim_type.startsWith("seq["):
      "seq[" & base_ret_nim_type & "]"
    else:
      base_ret_nim_type

  var generated_types: seq[string] = @[]
  var type_defs: seq[string] = @[]

  proc collect_composite_type(type_oid: Oid, nim_type: string) =
    if nim_type notin generated_types and not nim_type.startsWith("seq[") and nim_type notin ["int16", "int32", "int64", "float32", "float64", "string", "bool", "JsonNode"]:
      let def = generate_composite_type_def(type_oid, nim_type)
      if def.len > 0:
        generated_types.add nim_type
        type_defs.add def

  # 1. Collect return composite type
  collect_composite_type(prorettype, base_ret_nim_type)

  # 2. Collect arguments and their composite types
  for n in 0 ..< int(pronargs):
    var 
      oid_value    = get_pg_proc_arg_oid(heapTuple, n)
      type_tuple   = SearchSysCache1(TYPEOID, ObjectIdGetDatum(oid_value))
      arg_pg_name  = if not type_tuple.isNil:
        let n = $get_pg_type_name(type_tuple)
        ReleaseSysCache(type_tuple)
        n
      else: "unknown"
      arg_nim_type = translate_pg_types_to_nim(arg_pg_name)
    
    plnim_args.add arg_nim_type
    collect_composite_type(oid_value, arg_nim_type)

  if len(plnim_args) == int(pronargs):
    var proc_template = """
$import_def
$type_def
proc $proc_name($args): $ret_type =
$body
"""
    var args: seq[string]

    # Generate positional parameter names (arg0, arg1, ...) if unnamed
    var effectiveArgNames: seq[string] = @[]
    for i in 0 ..< int(pronargs):
      if i < proargnames.len and proargnames[i].len > 0:
        effectiveArgNames.add proargnames[i]
      else:
        effectiveArgNames.add "arg" & $i

    for arg in zip(effectiveArgNames, plnim_args):
      args.add arg[0] & ": " & arg[1]

    let (import_def, body) = extract_imports_and_body($prosrc)

    var allImports: seq[string] = @[]
    if import_def.len > 0:
      allImports.add import_def

    if not import_def.contains("std/json") and not import_def.contains("json"):
      allImports.add "import std/json"

    if not import_def.contains("pgxcrown/spi") and not import_def.contains("spi"):
      allImports.add "import pgxcrown/[spi, query_builder]"

    result = proc_template.multireplace([
      ("$import_def", allImports.join("\n")),
      ("$type_def", type_defs.join("\n")),
      ("$proc_name", $proname),
      ("$ret_type", ret_nim_type),
      ("$body", body),
      ("$args", args.join(", "))
    ])


proc is_safe_identifier(name: string): bool =
  if name.len == 0 or name.len > 63: return false
  for i, c in name:
    if i == 0 and c notin {'a'..'z', 'A'..'Z', '_'}:
      return false
    elif c notin {'a'..'z', 'A'..'Z', '0'..'9', '_'}:
      return false
  return true

# =============================================================================
# Dynamic Path Resolution Helpers
# =============================================================================

proc getPgxtoolInitDir*(): string =
  let envDir = getEnv("PGXTOOL_INIT_DIR")
  if envDir.len > 0:
    return envDir
  let home = getHomeDir()
  let user = if home.len > 0 and home.lastPathPart.len > 0: home.lastPathPart else: "postgres"
  return home / (user & "_pgxtool")

proc getPgxtoolBin*(): string =
  let envBin = getEnv("PGXTOOL_BIN")
  if envBin.len > 0 and fileExists(envBin):
    return envBin
  let exeInPath = findExe("pgxtool")
  if exeInPath.len > 0:
    return exeInPath
  let nimpath = getEnv("NIMPATH")
  if nimpath.len > 0:
    if fileExists(nimpath / "bin" / "pgxtool"):
      return nimpath / "bin" / "pgxtool"
    if fileExists(nimpath / "pgxtool"):
      return nimpath / "pgxtool"
  let homeNimble = getHomeDir() / ".nimble" / "bin" / "pgxtool"
  if fileExists(homeNimble):
    return homeNimble
  if fileExists("/usr/local/bin/pgxtool"):
    return "/usr/local/bin/pgxtool"
  if fileExists("/usr/bin/pgxtool"):
    return "/usr/bin/pgxtool"
  return "pgxtool"

proc getFunctionLibPath*(proname: string): string =
  let prjDir = getPgxtoolInitDir() / proname / "src"
  const ext = when defined(windows): ".dll" elif defined(macosx): ".dylib" else: ".so"
  let standardLib = prjDir / (proname & ext)
  if fileExists(standardLib):
    return standardLib
  let libPrefix = prjDir / ("lib" & proname & ext)
  if fileExists(libPrefix):
    return libPrefix
  let plain = prjDir / proname
  if fileExists(plain):
    return plain
  return standardLib


proc plnim_validator*(): Datum {. pgv1 .} =
    var 
      fn_oid = getOid(0)
      heapTuple = SearchSysCache1(PROCOID, ObjectIdGetDatum(fn_oid)) 
      is_null = false
      proname = get_pg_proc_name(heapTuple) 
      prosrc = get_pg_proc_src(heapTuple)
      pronargs = get_pg_proc_nargs(heapTuple)
      prodefault_nargs = get_pg_proc_default_nargs(heapTuple)
      proargtypes = get_pg_proc_argtypes(heapTuple)
      prorettype = get_pg_proc_rettype(heapTuple) 
      proargnames = get_pg_proc_argnames(heapTuple)
      
    try:
      # Shell Injection Guard: Validate function name
      if not is_safe_identifier($proname):
        reportError("PL/Nim Security Error: Function name '" & $proname & "' contains invalid characters or exceeds 63 characters. Only letters, numbers, and underscores are permitted.")

      # Get source code from plnim function 
      var code = to_pgxcrown(proname, prosrc, pronargs, heapTuple, prorettype, proargnames)

      when defined(linux) or defined(macosx) or defined(windows):
        let initDir = getPgxtoolInitDir()
        let pgxtoolBin = getPgxtoolBin()
        let pgxtoolParent = if pgxtoolBin.contains(DirSep): pgxtoolBin.parentDir() else: ""
        let nimpath = getEnv("NIMPATH")
        var pathEntries: seq[string] = @[]
        if pgxtoolParent.len > 0: pathEntries.add pgxtoolParent
        if nimpath.len > 0:
          pathEntries.add nimpath
          pathEntries.add nimpath / "bin"
        pathEntries.add getHomeDir() / ".nimble" / "bin"
        pathEntries.add "/usr/local/bin"
        pathEntries.add "/usr/bin"

        let extraPath = pathEntries.join(":")
        let loadEnv = "/bin/bash -c 'export PATH=" & extraPath & ":$PATH; $command'"
      
        proc run_command(command: string) =
          let cmd = loadEnv.replace("$command", command)
          let exitCode = execShellCmd(cmd)
          if exitCode != 0:
            reportError("PL/Nim Build Error: Command '" & command & "' for function '" & $proname & "' failed with exit code " & $exitCode & ".")

        if not fileExists(initDir / "config.json"):
          run_command("pgxtool init")
         
        let prjDir = initDir / $proname / "src"
        let mainFile = prjDir / "main.nim"
        if not fileExists(mainFile):
          run_command("pgxtool create-project " & $proname)
        
        writeFile(mainFile, code)
        
        # build extension & validate exit code
        run_command("pgxtool build-extension " & $proname)

        # Cache Invalidation: Invalidate existing in-memory cache for this OID
        if gFunctionCache.hasKey(fn_oid):
          let oldCached = gFunctionCache[fn_oid]
          if oldCached.lib != nil:
            try:
              unloadLib(oldCached.lib)
            except CatchableError:
              discard
          gFunctionCache.del(fn_oid)

      return cast[Datum](0)
    finally:
      ReleaseSysCache(heapTuple)



proc plnim_call_handler*(fcinfo: FunctionCallInfo): Datum {.pgv1_plnim.} = 
    type pg_proc = proc(a: FunctionCallInfo): Datum {. cdecl .}
    
    let fn_oid = getFnOid(fcinfo)

    # Fast path: In-memory cache hit (direct dispatch, zero I/O, zero syscache)
    if gFunctionCache.hasKey(fn_oid):
      let cached = gFunctionCache[fn_oid]
      return cached.fn_call(fcinfo)

    # Cold start path: First execution only (Cache miss)
    var heapTuple = SearchSysCache1(PROCOID, ObjectIdGetDatum(fn_oid)) 
    if heapTuple == nil:
      reportError("PL/Nim Execution Error: Function OID " & $fn_oid & " not found in syscache.")

    var is_null = false
    var proname = get_pg_proc_name(heapTuple)
    try:
      when defined(linux) or defined(macosx) or defined(windows):
        let libname = getFunctionLibPath($proname)
        let lib = loadLib(libname)

        if lib == nil:
          reportError("PL/Nim Execution Error: Dynamic library for function '" & $proname & "' could not be loaded from path '" & libname & "'. Please verify 'pgxtool build-extension " & $proname & "' executed successfully.")
        
        let nimfn_name = cstring("pgx_" & $proname)
        var sym = lib.symAddr(nimfn_name)
          
        if sym == nil:
          reportError("PL/Nim Execution Error: Exported symbol 'pgx_" & $proname & "' was not found inside dynamic library '" & libname & "'.")
         
        var fn_call = cast[pg_proc](sym)

        # Store in session memory cache for all subsequent calls
        gFunctionCache[fn_oid] = CachedPlnimFunction(lib: lib, fn_call: fn_call)

        return fn_call(fcinfo)

      else:
        reportError("PL/Nim Execution Error: PL/Nim dynamic execution is not supported on this platform.")
    finally:
      ReleaseSysCache(heapTuple)

PG_FUNCTION_INFO_V1(plnim_call_handler)
PG_FUNCTION_INFO_V1(plnim_validator)
