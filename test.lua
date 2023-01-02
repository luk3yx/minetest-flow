-- Load formspec_ast
_G.FORMSPEC_AST_PATH = '../formspec_ast'
dofile(FORMSPEC_AST_PATH .. '/init.lua')

-- Stub Minetest API
_G.minetest = {}

function minetest.is_yes(str)
    str = str:lower()
    return str == "true" or str == "yes"
end

local callback
function minetest.register_on_player_receive_fields(func)
    assert(callback == nil)
    callback = func
end

local function dummy() end
minetest.register_on_leaveplayer = dummy
minetest.get_modpath = dummy
minetest.is_singleplayer = dummy

table.indexof = table.indexof or function(list, value)
    for i, item in ipairs(list) do
        if item == value then
            return i
        end
    end
    return -1
end

string.split = string.split or function(str, chr)
    local r, i, s, e = {}, 0, str:find(chr, nil, true)
    while s do
        r[#r + 1] = str:sub(i, s - 1)
        i = e + 1
        s, e  = str:find(chr, i, true)
    end
    r[#r + 1] = str:sub(i)
    return r
end

-- Load flow
dofile('init.lua')
local gui = flow.widgets

-- "Normalise" the AST by flattening then parsing/unparsing to remove extra
-- values and fix weird floating point offsets
local function normalise_tree(tree)
    tree = formspec_ast.flatten(tree)
    tree.formspec_version = 5
    return assert(formspec_ast.parse(formspec_ast.unparse(tree)))
end

local function render(build_func, ctx, fs_ver)
    if type(build_func) ~= "function" then
        local tree = build_func
        function build_func() return tree end
    end

    local form = flow.make_gui(build_func)
    return form:_render({get_player_name = "test"}, ctx or {}, fs_ver)
end

local function test_render(build_func, output)
    local tree = render(build_func)
    local expected_tree = assert(formspec_ast.parse(output))

    assert.same(normalise_tree(expected_tree), normalise_tree(tree))
end

describe("Flow", function()
    it("renders labels correctly", function()
        test_render(gui.Label{label = "Hello world!"}, [[
            size[3.12,1]
            label[0.3,0.5;Hello world!]
        ]])
    end)

    it("spaces elements correctly", function()
        -- Taken from flow-playground tutorial
        test_render(gui.VBox{
            -- Don't rely on label widths
            min_w = 10,

            gui.Label{label = "Spacing = 0.5:"},
            gui.HBox{
                spacing = 0.5,

                gui.Box{w = 1, h = 1, color = "red"},
                gui.Box{w = 1, h = 1, color = "green"},
                gui.Box{w = 1, h = 1, color = "blue"},
            },
            gui.Label{label = "Spacing = 0:"},
            gui.HBox{
                spacing = 0,
                gui.Box{w = 1, h = 1, color = "red"},
                gui.Box{w = 1, h = 1, color = "green"},
                gui.Box{w = 1, h = 1, color = "blue"},
            },
            gui.Label{label = "Spacing = 0.2 (default):"},
            gui.HBox{
                gui.Box{w = 1, h = 1, color = "red"},
                gui.Box{w = 1, h = 1, color = "green"},
                gui.Box{w = 1, h = 1, color = "blue"},
            },
            gui.Label{label = "Padding demo:"},
            gui.Image{
                w = 1, h = 1,
                texture_name = "default_glass.png",
                padding = 0.5,
            },
        }, [[
            size[10.6,8.6]

            container[0.3,0.3]
            label[0,0.2;Spacing = 0.5:]
            box[0,0.6;1,1;red]
            box[1.5,0.6;1,1;green]
            box[3,0.6;1,1;blue]
            container_end[]

            container[0.3,2.1]
            label[0,0.2;Spacing = 0:]
            box[0,0.6;1,1;red]
            box[1,0.6;1,1;green]
            box[2,0.6;1,1;blue]
            container_end[]

            container[0.3,3.9]
            label[0,0.2;Spacing = 0.2 (default):]
            box[0,0.6;1,1;red]
            box[1.2,0.6;1,1;green]
            box[2.4,0.6;1,1;blue]
            container_end[]

            container[0.3,5.7]
            label[0,0.2;Padding demo:]
            image[4.5,1.1;1,1;default_glass.png]
            container_end[]
        ]])
    end)

    it("adds elements to redraw_if_changed", function()
        local tree, state = render(function(player, ctx)
            dummy(ctx.form.test1, ctx.form.test2, ctx.form.test3)

            return gui.VBox{
                gui.Field{name = "test2"},
                gui.Checkbox{name = "test3"},
                gui.Checkbox{name = "test4"},
            }
        end)

        assert.same(state.redraw_if_changed, {test2 = true, test3 = true})
    end)

    it("registers callbacks", function()
        local function func() end

        local tree, state = render(function(player, ctx)
            return gui.VBox{
                gui.Label{label = "Callback demo:"},
                gui.Button{label = "Click me!", name = "btn", on_event = func},
            }
        end)

        assert.same(state.callbacks, {btn = func})
    end)
end)
