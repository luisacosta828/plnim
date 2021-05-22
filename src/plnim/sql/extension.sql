create function plnim_call_handler()
returns language handler as '$libdir/libplnim' 
language c strict;

create language plnim
handler plnim_call_handler;

comment on language plnim
is 'PL/Nim procedural language';
