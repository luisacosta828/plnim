import pgxcrown
import pgxcrown/datatypes/basic
import pgxcrown/catalog/[pg_proc, pg_type]
import pgxcrown/syscache
import pgxcrown/spi
import dynlib
import std/strutils

PG_MODULE_MAGIC

template getFnLanguage:Datum =
  SysCacheGetAttr(PROCOID, heapTuple, Anum_pg_proc_prolang, addr(is_null))

template getFnNArgs:uint16 =
  DatumGetUInt16(SysCacheGetAttr(PROCOID, heapTuple, Anum_pg_proc_pronargs, addr(is_null)))

template getFnSourceCode: cstring =
  DatumGetCString(SysCacheGetAttr(PROCOID, heapTuple, Anum_pg_proc_prosrc, addr(is_null)))

template getFnArgNames: Datum =
  SysCacheGetAttr(PROCOID, heapTuple, Anum_pg_proc_proargnames, addr(is_null))

 
proc plnim_call_handler*(fcinfo: FunctionCallInfo): Datum {.pgv1_plnim.} = 
  
    type pg_proc = proc(a: FunctionCallInfo): Datum {. nimcall .}
    
    #Load plnim function oid and plnim oid
    #and inject fn_oid and lang_datum varibles into this scope

    var 
      fn_oid = getFnOid(fcinfo)
      heapTuple = SearchSysCache1(PROCOID, ObjectIdGetDatum(fn_oid)) 
      is_null = false
      pl_struct = cast[Form_pg_proc](getStruct(heapTuple))
      proname = NameStr(pl_struct.proname) 
      prosrc = getFnSourceCode
    echo "!!"
    echo "pl_struct.pronargs: ", $pl_struct.pronargs 
    echo "pl_struct.prorettype: ", $pl_struct.prorettype
    for n in 0 ..< pl_struct.pronargs:
      var 
        argtype     = pl_struct.proargtypes.values[n]
        type_tuple  = SearchSysCache1(TYPEOID, ObjectIdGetDatum(argtype))
        type_struct = cast[Form_pg_type](getStruct(type_tuple))
      
      echo "argument data type: ", NameStr(type_struct.typname)
      echo "type_tuple is valid: " & $IsValid(type_tuple)

      ReleaseSysCache(type_tuple)



    #Get source code from plnim function 

    #var source_info = getFunctionHeader(fn_oid, lang_datum)
    #var lib = loadlib("lib"&source_info.func_name&".so")
    #var pfun = lib.symAddr("pgx_" & source_info.func_name)

    #if lib.isNil:
    #    echo "no se pudo cargar la libreria: " & "lib" & source_info.func_name & ".so"
    #else:
    #    var fun = cast[pg_proc](pfun)
    #    return fun(getFcinfoData())
    ReleaseSysCache(heapTuple)   
    returnInt32(-404)           

PG_FUNCTION_INFO_V1(plnim_call_handler)

