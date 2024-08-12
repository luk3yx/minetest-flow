max_line_length = 80

globals = {
    'flow',
}

read_globals = {
    'dump',
    'formspec_ast',
    'fs51',
    'hud_fs',
    'minetest',
    string = {fields = {'split', 'trim'}},
    table = {fields = {'copy', 'indexof'}}
}

-- This error is thrown for methods that don't use the implicit "self"
-- parameter.
ignore = {"212/self", "432/player", "43/ctx", "212/player", "212/ctx", "212/value"}
