CREATE FUNCTION plnim_call_handler()
RETURNS language_handler AS '$libdir/plnim' 
LANGUAGE c STRICT;

CREATE FUNCTION plnim_validator(oid) 
RETURNS void AS '$libdir/plnim'
LANGUAGE c STRICT;

CREATE LANGUAGE plnim
HANDLER plnim_call_handler
VALIDATOR plnim_validator;

COMMENT ON LANGUAGE plnim IS 'PL/Nim procedural language';
