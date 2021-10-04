import pgxcrown/pgxmacros

import macros, tables, strutils

macro plnim*(fn: untyped): untyped =

    let pragmas = newNimNode(nnkPragma)
    pragmas.add(ident("pgx"))
    fn.pragma = pragmas

    let NimToPostgres = {"int": "INTEGER", "float": "REAL"}.toTable

    let function_header = "CREATE OR REPLACE FUNCTION " & fn.name.repr 
    let return_type = " RETURNS " & NimToPostgres[fn.params[0].repr]
    
    var params:seq[string]
    var param_len = fn.params.len - 1
    var datatype:string
    var identifier:string

    for index in 1 .. param_len:
        datatype = fn.params[index][1].repr
        identifier = fn.params[index][0].repr
        params.add identifier & " " & NimToPostgres[datatype]

    var return_datatype = fn.params[0].repr

    let plnim_params =  "(" & params.join(",") & ")"   
    var plbody:string
    
    for body in fn.body:
        plbody = plbody & indent(body.repr,4) & "\n"
    
    writeFile(fn.name.repr & ".sql",function_header & plnim_params & return_type & " LANGUAGE PLNIM \nas\n$$\n" & plbody & "\n$$\n;")
       
    result = fn    
   
