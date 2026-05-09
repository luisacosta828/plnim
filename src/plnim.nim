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
  of "int4": "int32"
  of "int8": "int64"
  of "float4": "float32"
  of "float8": "float64"
  of "text": "string"
  else: typ.capitalizeAscii


proc extract(content, l1, l2: string): (string, string) =
  if "[type section]" notin content and "[end type section]" notin content:
    return ("", content)
  var
    l1_len = l1.len
    l2_len = l2.len
    l1_pos = content.find(l1)
    l2_pos = content.find(l2)
    type_section = ""
    body_section = ""

  for line in content[l1_pos + l1_len + 1 .. l2_pos - 1]:
    type_section.add line

  for line  in content[l2_pos + l2_len + 1 .. content.len - 1]:
    body_section.add line

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
    for arg in zip(proargnames, plnim_args):
      var nim_type = translate_pg_types_to_nim($arg[1])
      args.add arg[0] & ": " & nim_type

    (type_def, body) = extract($prosrc, "[type section]", "[end type section]")
    result = proc_template.multireplace([("$type_def", type_def), ("$proc_name", $proname), ("$ret_type", translate_pg_types_to_nim($plnim_rettype)), ("$body", body), ("$args", args.join(", "))])
   

template run_command(command: string) =
    discard execShellCmd(load_env.replace("$command", command))


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
      
    #Get source code from plnim function 
    var code = to_pgxcrown(proname, prosrc, pronargs, proargtypes, prorettype, proargnames)

    when defined(linux):
      var
        home = getCurrentDir() / ".." / ".." 
        current_user = home.lastPathPart
        pgxtool_init_dir = home / current_user & "_pgxtool"
        pgxtool_bin = execCmdEx("echo $NIMPATH").output.strip
        load_env = "/bin/bash -c 'export PATH=$PGXTOOL_DIR:$PATH;$command'".replace("$PGXTOOL_DIR", pgxtool_bin)
    
      if not dirExists(pgxtool_init_dir):
        run_command("pgxtool init")
       
      var
        prj_dir   = pgxtool_init_dir & "/$project_name/src" 
      prj_dir   = prj_dir.replace("$project_name", $proname)

      var main_file = prj_dir / "main.nim"
      if not fileExists(main_file):
        run_command("pgxtool create-project $name".replace("$name",$proname))
      
      writeFile(main_file, code)
      
      #build extension
      run_command("pgxtool build-extension $fn".replace("$fn", $proname))

    ReleaseSysCache(heapTuple)
    return cast[Datum](0)



proc plnim_call_handler*(fcinfo: FunctionCallInfo): Datum {.pgv1_plnim.} = 
  
    type pg_proc = proc(a: FunctionCallInfo): Datum {. nimcall .}
    
    var 
      fn_oid = getFnOid(fcinfo)
      heapTuple = SearchSysCache1(PROCOID, ObjectIdGetDatum(fn_oid)) 
      is_null = false
      proname = get_pg_proc_name(heapTuple)

    when defined(linux):
      var 
        libname = "/var/lib/postgresql/postgresql_pgxtool/$prj/src/$lib".replace("$prj", $proname).replace("$lib", $proname) 
        lib = loadLib(libname)

      if lib == nil:
        ReleaseSysCache(heapTuple)
        returnInt32(-404)
      
      let nimfn_name = "pgx" & $proname
      var sym = lib.symAddr(nimfn_name)
        
      if sym == nil:
        ReleaseSysCache(heapTuple)
        returnInt32(-404)
       
      var fn_call = cast[pg_proc](sym)
      ReleaseSysCache(heapTuple)
      return fn_call(fcinfo)

    else:
      ReleaseSysCache(heapTuple)   
      returnInt32(-404)           

PG_FUNCTION_INFO_V1(plnim_call_handler)
PG_FUNCTION_INFO_V1(plnim_validator)

