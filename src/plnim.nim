import pgxcrown
import pgxcrown/datatypes/basic
import pgxcrown/catalog/[pg_proc, pg_type]
import pgxcrown/syscache
import pgxcrown/spi
import dynlib
import std/[strutils, sequtils]
import os, osproc

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
  of "_int4", "int4[]": "seq[int32]"
  of "_int8", "int8[]": "seq[int64]"
  of "_float8", "float8[]": "seq[float64]"
  of "_text", "text[]": "seq[string]"
  of "_bool", "bool[]": "seq[bool]"
  else: typ.capitalizeAscii


proc extract(content, l1, l2: string): (string, string) =
  if l1 notin content or l2 notin content:
    return ("", content)
  let l1_pos = content.find(l1)
  let l2_pos = content.find(l2)
  if l1_pos < 0 or l2_pos < 0 or l2_pos <= l1_pos:
    return ("", content)

  let typeStart = l1_pos + l1.len + 1
  let typeEnd = l2_pos - 1
  let bodyStart = l2_pos + l2.len + 1

  var type_section = ""
  var body_section = ""

  if typeStart <= typeEnd and typeEnd < content.len:
    type_section = content[typeStart .. typeEnd]

  if bodyStart < content.len:
    body_section = content[bodyStart .. ^1]

  return (type_section, body_section)

proc to_pgxcrown(proname: cstring, prosrc: cstring, pronargs: int16, proargtypes: ptr Oid, prorettype: Oid, proargnames: seq[string]): string =
  var 
    plnim_args:seq[cstring]
    is_null = false
    rettype_tuple =  SearchSysCache1(TYPEOID, ObjectIdGetDatum(prorettype))
    plnim_rettype = get_pg_type_name(rettype_tuple)

  ReleaseSysCache(rettype_tuple) 

  for n in 0 ..< pronargs:
    var 
      oid_value    = (proargtypes + n).asOid
      type_tuple   = SearchSysCache1(TYPEOID, ObjectIdGetDatum(oid_value))
    
    plnim_args.add get_pg_type_name(type_tuple)
    ReleaseSysCache(type_tuple)

  if len(plnim_args) == pronargs:
    var proc_template = """
$type_def
proc $proc_name($args): $ret_type =
$body
"""
    var args:seq[string]
    var type_def = ""
    var body = ""

    # Generate positional parameter names (arg0, arg1, ...) if unnamed
    var effectiveArgNames: seq[string] = @[]
    for i in 0 ..< int(pronargs):
      if i < proargnames.len and proargnames[i].len > 0:
        effectiveArgNames.add proargnames[i]
      else:
        effectiveArgNames.add "arg" & $i

    for arg in zip(effectiveArgNames, plnim_args):
      var nim_type = translate_pg_types_to_nim($arg[1])
      args.add arg[0] & ": " & nim_type

    (type_def, body) = extract($prosrc, "[type section]", "[end type section]")
    result = proc_template.multireplace([("$type_def", type_def), ("$proc_name", $proname), ("$ret_type", translate_pg_types_to_nim($plnim_rettype)), ("$body", body), ("$args", args.join(", "))])
   

proc is_safe_identifier(name: string): bool =
  if name.len == 0 or name.len > 63: return false
  for i, c in name:
    if i == 0 and c notin {'a'..'z', 'A'..'Z', '_'}:
      return false
    elif c notin {'a'..'z', 'A'..'Z', '0'..'9', '_'}:
      return false
  return true


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
      var code = to_pgxcrown(proname, prosrc, pronargs, proargtypes, prorettype, proargnames)

      when defined(linux):
        var
          home = getCurrentDir() / ".." / ".." 
          current_user = home.lastPathPart
          pgxtool_init_dir = home / current_user & "_pgxtool"
          pgxtool_bin = execCmdEx("echo $NIMPATH").output.strip
          load_env = "/bin/bash -c 'export PATH=$PGXTOOL_DIR:$PATH;$command'".replace("$PGXTOOL_DIR", pgxtool_bin)
      
        proc run_command(command: string) =
          let cmd = load_env.replace("$command", command)
          let exitCode = execShellCmd(cmd)
          if exitCode != 0:
            reportError("PL/Nim Build Error: Command '" & command & "' for function '" & $proname & "' failed with exit code " & $exitCode & ".")

        if not dirExists(pgxtool_init_dir):
          run_command("pgxtool init")
         
        var
          prj_dir   = pgxtool_init_dir & "/$project_name/src" 
        prj_dir   = prj_dir.replace("$project_name", $proname)

        var main_file = prj_dir / "main.nim"
        if not fileExists(main_file):
          run_command("pgxtool create-project $name".replace("$name",$proname))
        
        writeFile(main_file, code)
        
        # build extension & validate exit code
        run_command("pgxtool build-extension $fn".replace("$fn", $proname))

      return cast[Datum](0)
    finally:
      ReleaseSysCache(heapTuple)



proc plnim_call_handler*(fcinfo: FunctionCallInfo): Datum {.pgv1_plnim.} = 
    type pg_proc = proc(a: FunctionCallInfo): Datum {. nimcall .}
    
    var 
      fn_oid = getFnOid(fcinfo)
      heapTuple = SearchSysCache1(PROCOID, ObjectIdGetDatum(fn_oid)) 
      is_null = false
      proname = get_pg_proc_name(heapTuple)

    try:
      when defined(linux):
        var 
          libname = "/var/lib/postgresql/postgresql_pgxtool/$prj/src/$lib".replace("$prj", $proname).replace("$lib", $proname) 
          lib = loadLib(libname)

        if lib == nil:
          reportError("PL/Nim Execution Error: Dynamic library for function '" & $proname & "' could not be loaded from path '" & libname & "'. Please verify 'pgxtool build-extension " & $proname & "' executed successfully.")
        
        let nimfn_name = cstring("pgx_" & $proname)
        var sym = lib.symAddr(nimfn_name)
          
        if sym == nil:
          reportError("PL/Nim Execution Error: Exported symbol 'pgx_" & $proname & "' was not found inside dynamic library '" & libname & "'.")
         
        var fn_call = cast[pg_proc](sym)
        return fn_call(fcinfo)

      else:
        reportError("PL/Nim Execution Error: PL/Nim dynamic execution is currently only supported on Linux platforms.")
    finally:
      ReleaseSysCache(heapTuple)           

PG_FUNCTION_INFO_V1(plnim_call_handler)
PG_FUNCTION_INFO_V1(plnim_validator)

