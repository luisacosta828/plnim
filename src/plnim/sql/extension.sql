create function plnim_call_handler()
returns language_handler as '$libdir/plnim' 
language c strict;

create function plnim_validator(oid) 
returns void as '$libdir/plnim'
language c strict;

create trusted language plnim
handler plnim_call_handler
validator plnim_validator;

comment on language plnim
is 'PL/Nim procedural language';
