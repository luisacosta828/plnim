import pgxcrown
import pgxcrown/reports/reports
import tables
from os import existsFile
import dynlib
import strutils
import plnim/func_utils
import plnim/parser
import plnim/pg_syscache


PG_MODULE_MAGIC

proc plnim_call_handler*(): Datum {.pgv1.} = 

    #Load plnim function oid and plnim oid
    #and inject fn_oid and lang_datum varibles into this scope
    fcinfo_data()

    #Get source code from plnim function 
    var source_info = getPLSourceCode(fn_oid,lang_datum)

    let f  = build_nim_file(source_info)

    if existsFile("plnim/src/lib"&source_info.name&".so"):

        var lib = loadlib("lib"&source_info.name&".so")

        if lib == nil:
            report(warning,"Need Compile to Dynlib","/var/lib/postgresql/{pg_version}/main/plnim/src/{function_name}.nim was created.", "nim c -d:release --app:lib [filename]")
        else:
            type
               pg_func = proc(symbols: seq[string]): int {. nimcall .}

            var fun = cast[pg_func](lib.symAddr(source_info.name))

            if parseInt(source_info.nargs) > 0 :
                var data: seq[string] = @[]
                for n in 0..parseInt(source_info.nargs) - 1: data.add($(cast[cuint](n).getInt32))
                returnInt32(cast[Datum](fun(data)))
            else:
                returnInt32(cast[Datum](fun(@[])))               
    else:
       echo "compile to dynlib"
    returnInt32(-1)

PG_FUNCTION_INFO_V1(plnim_call_handler)
