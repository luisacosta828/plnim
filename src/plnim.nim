import pgxcrown
import pgxcrown/reports/reports
import tables
import dynlib
import plnim/pg_syscache
import plnim/toplnim

PG_MODULE_MAGIC
    
proc plnim_call_handler*(): Datum {.pgv1.} = 
  
    type pg_proc = proc(a: FunctionCallInfo): Datum {. nimcall .}

    #Load plnim function oid and plnim oid
    #and inject fn_oid and lang_datum varibles into this scope

    {.emit: """FunctionCallInfo getFcinfoData(){ return fcinfo; }""".}

    proc getFcinfoData():FunctionCallInfo {.importc.}

    var fn_oid {. inject .} = getFcinfoData()[].flinfo[].fn_oid

    var ht = SearchSysCache(ord(SysCacheIdentifier.PROCOID),ObjectIdGetDatum(fn_oid),0,0,0)

    var is_null = false

    var lang_datum {. inject .} = SysCacheGetAttr(ord(SysCacheIdentifier.PROCOID), ht, AttrNumber(4), addr(is_null))
    var prosrc_datum = SysCacheGetAttr(ord(SysCacheIdentifier.PROCOID), ht, AttrNumber(25), addr(is_null))
    var argnames_datum = SysCacheGetAttr(ord(SysCacheIdentifier.PROCOID), ht, AttrNumber(22), addr(is_null))

    #Get source code from plnim function 

    var source_info = getFunctionHeader(fn_oid, lang_datum)
    var lib = loadlib("lib"&source_info.func_name&".so")
    var pfun = lib.symAddr("pgx_" & source_info.func_name)

    if lib.isNil:
        echo "no se pudo cargar la libreria: " & "lib" & source_info.func_name & ".so"
    else:
        var fun = cast[pg_proc](pfun)
        return fun(getFcinfoData())
        
    returnInt32(-404)           

PG_FUNCTION_INFO_V1(plnim_call_handler)

export toplnim
