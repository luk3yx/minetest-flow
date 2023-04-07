-- luacheck: ignore

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
minetest.get_player_information = dummy
minetest.show_formspec = dummy

-- Stub minetest player api
local function stub_player(name)
    assert(type(name) == "string")
    local self = {}
    function self:get_player_name()
        return name
    end
    function self:get_inventory_formspec()
        return ""
    end
    function self:set_inventory_formspec(formspec)
        assert(formspec ~= nil)
        function self:get_inventory_formspec()
            return formspec
        end
    end
    return self
end

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

    it("handles visible = false", function()
        test_render(gui.VBox{
            min_w = 10, min_h = 10,

            gui.HBox{
                spacing = 0.5,
                gui.Box{w = 1, h = 1, color = "red"},
                gui.Box{w = 1, h = 1, color = "green", visible = false},
                gui.Box{w = 1, h = 1, color = "blue"},
            },

            gui.HBox{
                gui.Box{w = 1, h = 1, color = "red"},
                gui.Box{w = 1, h = 1, color = "green", visible = false,
                    expand = true},
                gui.Box{w = 1, h = 1, color = "blue"},
            },

            gui.HBox{
                gui.Box{w = 1, h = 1, color = "grey"},
                gui.Spacer{},
                gui.Box{w = 1, h = 1, color = "grey"},
            },

            gui.HBox{
                gui.Box{w = 1, h = 1, color = "red", expand = true},
                gui.Box{w = 1, h = 1, color = "green", visible = false},
                gui.Box{w = 1, h = 1, color = "blue"},
            },

            gui.Box{w = 1, h = 1, expand = true},
        }, [[
            size[10.6,10.6]

            container[0.3,0.3]
            box[0,0;1,1;red]
            box[3,0;1,1;blue]
            container_end[]

            container[0.3,1.5]
            box[0,0;1,1;red]
            box[9,0;1,1;blue]
            container_end[]

            container[0.3,2.7]
            box[0,0;1,1;grey]
            box[9,0;1,1;grey]
            container_end[]

            container[0.3,3.9]
            box[0,0;7.6,1;red]
            box[9,0;1,1;blue]
            container_end[]

            box[0.3,5.1;10,5.2;]
        ]])
    end)

    it("stacks elements", function()
        test_render(gui.Stack{
            gui.Button{w = 3, h = 1, label = "1", align_v = "top"},
            gui.Image{w = 1, h = 1, align_h = "fill", align_v = "fill",
                texture_name = "2"},
            gui.Image{w = 1, h = 3, texture_name = "3", visible = false},
            gui.Field{name = "4", label = "Test", align_v = "fill"},
            gui.Field{name = "5", label = "", align_v = "fill"},

            gui.Label{label = "Test", align_h = "centre"},

            gui.List{inventory_location = "a", list_name = "b", w = 2, h = 2},
            gui.Style{selectors = {"test"}, props = {prop = "value"}},
        }, [[
            size[3.6,3.6]
            field_close_on_enter[4;false]
            field_close_on_enter[5;false]
            button[0.3,0.3;3,1;;1]
            image[0.3,0.3;3,3;2]
            field[0.3,0.7;3,2.6;4;Test;]
            field[0.3,0.3;3,3;5;;]

            image_button[0.3,1.6;3,0.4;blank.png;;Test;;false]
            image_button[0.3,1.6;3,0.4;blank.png;;;;false]

            list[a;b;0.675,0.675;2,2]
            style[test;prop=value]
        ]])
    end)

    it("registers inventory formspecs", function ()
        local stupid_simple_inv_expected =
            "formspec_version[5]" ..
            "size[10.35,5.35]" ..
            "list[current_player;main;0.3,0.3;8,4]"
        local stupid_simple_inv = flow.make_gui(function (p, c)
            return gui.List{
                inventory_location = "current_player",
                list_name = "main",
                w = 8,
                h = 4,
            }
        end)
        local player = stub_player("test_player")
        assert(player:get_inventory_formspec() == "")
        stupid_simple_inv:set_as_inventory_for(player)
        assert(player:get_inventory_formspec() == stupid_simple_inv_expected)
    end)

    it("can still show a form when an inventory formspec is shown", function ()
        local expected_one = "formspec_version[5]size[1.6,1.6]box[0.3,0.3;1,1;]"
        local one = flow.make_gui(function (p, c)
            return gui.Box{ w = 1, h = 1 }
        end)
        local blue = flow.make_gui(function (p, c)
            return gui.Box{ w = 1, h = 4, color = "blue" }
        end)
        local player = stub_player("test_player")
        assert(player:get_inventory_formspec() == "")
        one:set_as_inventory_for(player)
        assert(player:get_inventory_formspec() == expected_one)
        blue:show(player)
        assert(player:get_inventory_formspec() == expected_one)
    end)

    describe("render_to_formspec_string", function ()
        it("renders the same output as manually calling _render", function()
            local build_func = function()
                return gui.VBox{
                    gui.Box{w = 1, h = 1},
                    gui.Label{label = "Test", align_h = "centre"},
                    gui.Field{name = "4", label = "Test", align_v = "fill"}
                }
            end
            local form = flow.make_gui(build_func)
            local player = stub_player("test_player")
            local fs, _ = form:render_to_formspec_string(player)
            test_render(build_func, fs)
        end)
        it("passes events through the callback function", function()
            local manual_spy
            local manual_spy_count = 0
            local buttonargs = {
                label = "Click me!",
                name = "btn",
                on_event = function (...)
                    manual_spy = {...}
                    manual_spy_count = manual_spy_count + 1
                end
            }
            local form = flow.make_gui(function()
                return gui.Button(buttonargs)
            end)
            local player = stub_player("test_player")
            function minetest.get_player_by_name(name)
                assert(name == "test_player")
                return player
            end
            local ctx = {a = 1}
            local _, trigger_event = form:render_to_formspec_string(player, ctx)

            local fields = {btn = 1}
            trigger_event(fields)

            assert.equals(manual_spy_count, 1, "event passed down only once")
            assert.equals(manual_spy[1], player, "player was first arg")
            assert.equals(manual_spy[2], ctx, "context was next")

            minetest.get_player_by_name = nil
        end)
    end)
end)
