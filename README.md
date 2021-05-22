# PL/Nim
Language Handler for executing Nim as a procedural language for postgresql

# Usage

##  Installation
### 1- Install plnim 
```nim
nimble install plnim@#head
```

### 2- Compile plnim source code
```bash

nim c -d:release --app:lib -o:libplnim.so ~/.nimble/pkgs/plnim-#head/plnim
```

### 3- Copy libplnim.so to pkglibdir
```bash
cp libplnim.so $(pg_config --pkglibdir)
```

### 4- Execute extension.sql

This file contains information for building the language_handler for plnim using the libplnim.so file you created before.


```bash
psql [username] [dbname] -f ~/.nimble/pkgs/plnim-#head/plnim/sql/extension.sql

#CREATE FUNCTION
#CREATE LANGUAGE
#COMMENT

```
## Writing PL/Nim code

```sql
create or replace function add_one(integer) returns integer
language plnim 
as
$$
result = $1 + 1
$$
;
```
The first time you execute your function, the language handler will emit the next message
```sql
select add_one(1);

WARNING:  Need Compile to Dynlib
DETAIL:  /var/lib/postgresql/{pg_version}/main/plnim/src/{function_name}.nim was created.
HINT:  nim c -d:release --app:lib [filename]

```
#### Compile the nim file 
```bash
[sudo] nim c -d:release --app:lib [filename]

Copy the produced dynlib file to /usr/lib
[sudo] cp lib{function_name}.so /usr/lib

```
#### Execute your function
```sql
select add_one(1);

 add_one
---------
       2
(1 row)

```
