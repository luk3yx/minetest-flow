--
-- Flow: Unit tests
--
-- Copyright © 2022-2025 by luk3yx
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation, either version 2.1 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.
--

-- luacheck: ignore

-- Load formspec_ast
_G.FORMSPEC_AST_PATH = '../formspec_ast'
dofile(FORMSPEC_AST_PATH .. '/init.lua')

-- Stub Minetest API
_G.core = {}

function core.is_yes(str)
    str = str:lower()
    return str == "true" or str == "yes"
end

local callback
function core.register_on_player_receive_fields(func)
    assert(callback == nil)
    callback = func
end

local function dummy() end
core.register_on_leaveplayer = dummy
core.is_singleplayer = dummy
core.get_player_information = dummy
core.show_formspec = dummy

function core.get_modpath(modname)
    if modname == "flow" then
        return "."
    elseif modname == "formspec_ast" then
        return FORMSPEC_AST_PATH
    end
end

function core.get_translator(modname)
    assert(modname == "flow")
    return function(str) return str end
end

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
    function core.get_player_by_name(passed_in_name)
        assert(name == passed_in_name)
        return self
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

function core.explode_textlist_event(event)
    local event_type, number = event:match("^([A-Z]+):(%d+)$")
    return {type = event_type, index = tonumber(number) or 0}
end

function core.explode_table_event(event)
    local event_type, row, column = event:match("^([A-Z]+):(%d+):(%d+)$")
    return {type = event_type, row = tonumber(row) or 0, column = tonumber(column) or 0}
end

function core.global_exists(var)
    return rawget(_G, var) ~= nil
end

function core.get_player_information(name)
    return name == "fs6" and {formspec_version = 6} or nil
end

-- Load flow
dofile("init.lua")

-- Unfortunately the easiest way of getting naive_str_width without adding
-- runtime checks is to load layout.lua twice. Luckily it is somewhat self
-- contained so this shouldn't be a problem.
local naive_str_width
do
    local f = assert(io.open("layout.lua"))
    local code = f:read("*a"):gsub("\nreturn",
        "\nreturn naive_str_width --[[") .. "]]"
    f:close()
    naive_str_width = assert((loadstring or load)(code))()
end

local gui = flow.widgets

-- "Normalise" the AST by flattening then parsing/unparsing to remove extra
-- values and fix weird floating point offsets
local function normalise_tree(tree)
    tree = formspec_ast.flatten(tree)
    tree.formspec_version = 6
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

local function test_render(build_func, output, description)
    local tree = render(build_func)
    local expected_tree = output
    if type(output) == "string" then
        expected_tree = assert(formspec_ast.parse(output), "expected output must parse")
    end
    if expected_tree.type then
        expected_tree = assert(render(expected_tree), "if expected output is a flow form, it must render")
    end
    tree = normalise_tree(tree)
    expected_tree = normalise_tree(expected_tree)
    assert.same(expected_tree, tree, description)
end

local function render_to_string(tree, pname)
    local player = stub_player(pname or "test_player")
    local form = flow.make_gui(function()
        return table.copy(tree)
    end)
    local ctx = {}
    local fs, event = form:render_to_formspec_string(player, ctx)
    return ctx, event, fs
end

describe("Flow", function()
    describe("bgcolor settings", function ()
        it("renders bgcolor only correctly", function ()
            test_render(gui.VBox{ bgcolor = "green" }, [[
                size[0.6,0.6]
                bgcolor[green]
            ]])
        end)
        it("renders fbgcolor only correctly", function ()
            test_render(gui.VBox{ fbgcolor = "green" }, [[
                size[0.6,0.6]
                bgcolor[;;green]
            ]])
        end)
        it("renders both correctly", function ()
            test_render(gui.VBox{ bgcolor = "orange", fbgcolor = "green" }, [[
                size[0.6,0.6]
                bgcolor[orange;;green]
            ]])
        end)
        it("passes fullscreen setting", function ()
            test_render(gui.VBox{ bg_fullscreen = true }, [[
                size[0.6,0.6]
                bgcolor[;true]
            ]])
        end)
        it("passes fullscreen setting when string", function ()
            test_render(gui.VBox{ bg_fullscreen = "both" }, [[
                size[0.6,0.6]
                bgcolor[;both]
            ]])
        end)
        it("handles it all together", function ()
            test_render(gui.VBox{ bgcolor = "blue", fbgcolor = "red", bg_fullscreen = "neither" }, [[
                size[0.6,0.6]
                bgcolor[blue;neither;red]
            ]])
        end)
    end)

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
        local function func2() return true end

        local tree, state = render(function(player, ctx)
            return gui.VBox{
                gui.Label{label = "Callback demo:"},
                gui.Button{label = "Click me!", name = "btn", on_event = func},
                gui.Field{name = "field", on_event = func2}
            }
        end)

        assert.same(state.callbacks, {field = func2})
        assert.same(state.btn_callbacks, {btn = func})
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
            button[0.3,0.3;3,1;;1]
            image[0.3,0.3;3,3;2]
            field_close_on_enter[4;false]
            field[0.3,0.7;3,2.6;4;Test;]
            field_close_on_enter[5;false]
            field[0.3,0.3;3,3;5;;]

            style[_#;bgimg=;bgimg_pressed=]
            style[_#:hovered,_#:pressed;bgimg=]
            image_button[0.3,1.6;3,0.4;blank.png;_#;Test;;false]
            image_button[0.3,1.6;3,0.4;blank.png;_#;;;false]

            list[a;b;0.675,0.675;2,2]
            style[test;prop=value]
        ]])
    end)

    it("ignores gui.Nil", function()
        test_render(gui.VBox{
            min_h = 5, -- Make sure gui.Nil doesn't expand
            gui.Box{w = 1, h = 1, color = "red"},
            gui.Nil{},
            gui.Box{w = 1, h = 1, color = "green"},
        }, [[
            size[1.6,5.6]
            box[0.3,0.3;1,1;red]
            box[0.3,1.5;1,1;green]
        ]])
    end)

    it("keeps gui.Listcolors invisible", function()
        test_render(gui.VBox{
            min_h = 5,
            gui.Box{w = 1, h = 1, color = "red"},
            gui.Listcolors{slot_bg_normal = "red", slot_bg_hover = "blue"},
            gui.Box{w = 1, h = 1, color = "green"},
        }, [[
            size[1.6,5.6]
            box[0.3,0.3;1,1;red]
            listcolors[red;blue]
            box[0.3,1.5;1,1;green]
        ]])
    end)

    it("registers inventory formspecs", function ()
        local stupid_simple_inv_expected =
            "formspec_version[7]" ..
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
        local expected_one = "formspec_version[7]size[1.6,1.6]box[0.3,0.3;1,1;]"
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
        it("renders the same output as manually calling _render when standalone", function()
            local build_func = function()
                return gui.VBox{
                    gui.Box{w = 1, h = 1},
                    gui.Label{label = "Test", align_h = "centre"},
                    gui.Field{name = "4", label = "Test", align_v = "fill"}
                }
            end
            local form = flow.make_gui(build_func)
            local player = stub_player("test_player")
            local fs = form:render_to_formspec_string(player, nil, true)
            test_render(build_func, fs)
        end)
        it("renders nearly the same output as manually calling _render when not standalone", function()
            local build_func = function()
                return gui.VBox{
                    gui.Box{w = 1, h = 1},
                    gui.Label{label = "Test", align_h = "centre"},
                    gui.Field{name = "4", label = "Test", align_v = "fill"}
                }
            end
            local form = flow.make_gui(build_func)
            local player = stub_player("test_player")
            local fs, _, info = form:render_to_formspec_string(player)
            test_render(
                build_func,
                ("formspec_version[%s]size[%s,%s]"):format(
                    info.formspec_version,
                    info.w,
                    info.h
                ) .. fs
            )
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
            local ctx = {a = 1}
            local _, trigger_event = form:render_to_formspec_string(player, ctx, true)

            local fields = {btn = 1}
            trigger_event(fields)

            assert.equals(manual_spy_count, 1, "event passed down only once")
            assert.equals(manual_spy[1], player, "player was first arg")
            assert.equals(manual_spy[2], ctx, "context was next")

            core.get_player_by_name = nil
        end)
    end)

    describe("naive_str_width", function()
        it("works in a simple string", function()
            local w, h = naive_str_width("Hello world!")
            assert.equals(w, 12)
            assert.equals(h, 1)
        end)

        it("works with multi-line strings", function()
            local w, h = naive_str_width("Hello world!\nLine 2")
            assert.equals(w, 12)
            assert.equals(h, 2)

            w, h = naive_str_width("Hello world!\nThis is a test")
            assert.equals(w, 14)
            assert.equals(h, 2)
        end)

        it("works with Cyrillic script", function()
            local w, h = naive_str_width("Привіт Світ")
            assert.equals(w, 11)
            assert.equals(h, 1)
        end)

        it("works with full width characters", function()
            local w, h = naive_str_width("你好世界\n123456")
            assert.equals(w, 8)
            assert.equals(h, 2)
        end)

        it("strips escape codes", function()
            local w, h = naive_str_width("\27(T@test)Hello \27Fworld\27E!\27E")
            assert.equals(w, 12)
            assert.equals(h, 1)

            w, h = naive_str_width("\27(c@blue)Test\27(c@#ffffff)\n123")
            assert.equals(w, 4)
            assert.equals(h, 2)
        end)
    end)

    describe("field validation for", function()
        describe("Field", function()
            it("passes correct input through", function()
                local ctx, event = render_to_string(gui.Field{
                    name = "a", default = "(default)"
                })
                assert.equals(ctx.form.a, "(default)")
                event({a = "Hello world!"})
                assert.equals(ctx.form.a, "Hello world!")
            end)

            it("strips escape characters", function()
                local ctx, event = render_to_string(gui.Field{name = "a"})
                assert.equals(ctx.form.a, "")
                event({a = "\1\2Hello \3\4world!\n"})
                assert.equals(ctx.form.a, "Hello world!")
            end)

            it("ignores other fields", function()
                local ctx, event = render_to_string(gui.Field{name = "a"})
                assert.equals(ctx.form.a, "")
                event({b = "Hello world!"})
                assert.equals(ctx.form.a, "")
            end)
        end)

        describe("Textarea", function()
            it("strips escape characters", function()
                local ctx, event = render_to_string(gui.Textarea{name = "a"})
                assert.equals(ctx.form.a, "")
                event({a = "\1\2Hello \3\4world!\n"})
                assert.equals(ctx.form.a, "Hello world!\n")
            end)
        end)

        describe("Checkbox", function()
            it("converts the result to a boolean", function()
                local ctx, event = render_to_string(gui.Checkbox{name = "a"})
                assert.equals(ctx.form.a, false)
                event({a = "true"})
                assert.equals(ctx.form.a, true)
            end)
        end)

        describe("Dropdown", function()
            describe("{index_event=false}", function()
                it("passes correct input through", function()
                    local ctx, event, fs = render_to_string(gui.Dropdown{
                        name = "a", items = {"hello", "world"},
                    })
                    assert(fs:find("dropdown%[[^%]]-;true%]") == nil)
                    assert.equals(ctx.form.a, "hello")
                    event({a = "world"})
                    assert.equals(ctx.form.a, "world")
                end)

                it("ignores malicious input", function()
                    local ctx, event = render_to_string(gui.Dropdown{
                        name = "a", items = {"hello", "world"},
                    })
                    assert.equals(ctx.form.a, "hello")
                    event({a = "there"})
                    assert.equals(ctx.form.a, "hello")
                end)

                it("uses index_event internally on new clients", function()
                    local ctx, event, fs = render_to_string(gui.Dropdown{
                        name = "a", items = {"hello", "world"},
                    }, "fs6")
                    assert(fs:find("dropdown%[[^%]]-;true%]") ~= nil)
                    assert.equals(ctx.form.a, "hello")
                    event({a = "2"})
                    assert.equals(ctx.form.a, "world")
                end)

                it("ignores malicious input on new clients", function()
                    local ctx, event = render_to_string(gui.Dropdown{
                        name = "a", items = {"hello", "world"},
                    }, "fs6")
                    assert.equals(ctx.form.a, "hello")
                    event({a = "world"})
                    assert.equals(ctx.form.a, "hello")
                end)
            end)

            describe("{index_event=true}", function()
                it("passes correct input through", function()
                    local ctx, event = render_to_string(gui.Dropdown{
                        name = "a", items = {"hello", "world"},
                        index_event = true,
                    })
                    assert.equals(ctx.form.a, 1)
                    event({a = "2"})
                    assert.equals(ctx.form.a, 2)
                end)

                it("ignores malicious input", function()
                    local ctx, event = render_to_string(gui.Dropdown{
                        name = "a", items = {"hello", "world"},
                        index_event = true,
                    })
                    assert.equals(ctx.form.a, 1)
                    event({a = "nan"})
                    assert.equals(ctx.form.a, 1)
                end)

                it("converts numbers to integers", function()
                    local ctx, event = render_to_string(gui.Dropdown{
                        name = "a", items = {"hello", "world"},
                        index_event = true,
                    })
                    assert.equals(ctx.form.a, 1)
                    event({a = "2.1"})
                    assert.equals(ctx.form.a, 2)
                end)

                it("ignores out of bounds input", function()
                    local ctx, event = render_to_string(gui.Dropdown{
                        name = "a", items = {"hello", "world"},
                        index_event = true,
                    })
                    assert.equals(ctx.form.a, 1)
                    event({a = "3"})
                    assert.equals(ctx.form.a, 1)
                end)
            end)
        end)

        describe("Textlist", function()
            it("converts the result to a number", function()
                local ctx, event = render_to_string(gui.Textlist{
                    name = "a", listelems = {"hello", "world"},
                    selected_idx = 2
                })
                assert.equals(ctx.form.a, 2)
                event({a = "CHG:1"})
                assert.equals(ctx.form.a, 1)
            end)

            it("ignores out of bounds values", function()
                local ctx, event = render_to_string(gui.Textlist{
                    name = "a", listelems = {"hello", "world"},
                    selected_idx = 2
                })
                assert.equals(ctx.form.a, 2)
                event({a = "CHG:3"})
                assert.equals(ctx.form.a, 2)
            end)
        end)

        describe("Table", function()
            it("converts the result to a number", function()
                local ctx, event = render_to_string(gui.Table{
                    name = "a", cells = {"hello", "world"},
                    selected_idx = 2
                })
                assert.equals(ctx.form.a, 2)
                event({a = "CHG:1:0"})
                assert.equals(ctx.form.a, 1)
            end)

            it("ignores out of bounds values", function()
                local ctx, event = render_to_string(gui.Table{
                    name = "a", cells = {"hello", "world"}
                })
                assert.equals(ctx.form.a, 1)
                event({a = "CHG:3:0"})
                assert.equals(ctx.form.a, 1)
            end)

            it("does not replace zero values", function()
                local ctx, event = render_to_string(gui.Table{
                    name = "a", cells = {"hello", "world"}, selected_idx = 0
                })
                assert.equals(ctx.form.a, 0)
                event({a = "INV"})
                assert.equals(ctx.form.a, 0)
            end)

            it("understands tablecolumns", function()
                local ctx, event = render_to_string(gui.VBox{
                    gui.TableColumns{
                        tablecolumns = {
                            {type = "text", opts = {}},
                            {type = "text", opts = {}},
                        }
                    },
                    gui.Table{
                        name = "a", cells = {"1", "2", "3", "4", "5", "6"},
                    }
                })
                assert.equals(ctx.form.a, 1)
                event({a = "CHG:3:0"})
                assert.equals(ctx.form.a, 3)
            end)

            it("ignores out-of-bounds values with tablecolumns", function()
                local ctx, event = render_to_string(gui.VBox{
                    gui.TableColumns{
                        tablecolumns = {
                            {type = "text", opts = {}},
                            {type = "text", opts = {}},
                        }
                    },
                    gui.Table{
                        name = "a", cells = {"1", "2", "3", "4", "5", "6"},
                    }
                })
                assert.equals(ctx.form.a, 1)
                event({a = "CHG:4:0"})
                assert.equals(ctx.form.a, 1)
            end)
        end)

        describe("Button", function()
            it("does not save form input", function()
                local ctx, event = render_to_string(gui.Button{name = "a"})
                assert.equals(ctx.form.a, nil)
                event({a = "test"})
                assert.equals(ctx.form.a, nil)
            end)

            it("only calls a single callback", function()
                local f, b = 0, 0

                local ctx, event = render_to_string(gui.VBox{
                    gui.Field{name = "a", on_event = function() f = f + 1 end},
                    gui.Button{name = "b", on_event = function() b = b + 1 end},
                    gui.Button{name = "c", on_event = function() b = b + 1 end}
                })
                event({})
                assert.equals(f, 0)
                assert.equals(b, 0)

                event({a = "test", b = "test", c = "test"})
                assert.equals(f, 1)
                assert.equals(b, 1)

                event({b = "test", c = "test"})
                assert.equals(f, 1)
                assert.equals(b, 2)

                event({c = "test"})
                assert.equals(f, 1)
                assert.equals(b, 3)
            end)
        end)
    end)

    describe("extra field parameters", function()
        it("default to sensible values", function()
            test_render(gui.Field{
                w = 1, h = 1, name = "test",
            }, [[
                size[1.6,1.6]
                field_close_on_enter[test;false]
                field[0.3,0.3;1,1;test;;]
            ]])
        end)

        it("can enable field_enter_after_edit", function()
            test_render(gui.Field{
                w = 1, h = 1, name = "test", enter_after_edit = true
            }, [[
                size[1.6,1.6]
                field_enter_after_edit[test;true]
                field_close_on_enter[test;false]
                field[0.3,0.3;1,1;test;;]
            ]])
        end)
    end)

    describe("inline style parser", function()
        it("parses inline styles correctly", function()
            test_render(gui.Box{
                w = 1, h = 1, color = "blue",
                style = {hello = "world"}
            }, [[
                size[1.6,1.6]
                style_type[box;hello=world]
                box[0.3,0.3;1,1;blue]
                style_type[box;hello=]
            ]])
        end)

        it("parses inline styles correctly", function()
            test_render(gui.Button{
                w = 1, h = 1, name = "mybtn",
                style = {hello = "world"}
            }, [[
                size[1.6,1.6]
                style[mybtn;hello=world]
                button[0.3,0.3;1,1;mybtn;]
            ]])
        end)

        it("takes advantage of auto-generated names", function()
            test_render(gui.Button{
                w = 1, h = 1, on_event = function() end,
                style = {hello = "world"}
            }, [[
                size[1.6,1.6]
                style[_#0;hello=world]
                button[0.3,0.3;1,1;_#0;]
            ]])
        end)

        it("supports advanced selectors", function()
            test_render(gui.Button{
                w = 1, h = 1, name = "mybtn",
                style = {
                    bgimg = "btn.png",
                    {sel = "$hovered", bgimg = "hover.png"},
                    {sel = "$focused", bgimg = "focus.png"},
                },
            }, [[
                size[1.6,1.6]
                style[mybtn;bgimg=btn.png]
                style[mybtn:hovered;bgimg=hover.png]
                style[mybtn:focused;bgimg=focus.png]
                button[0.3,0.3;1,1;mybtn;]
            ]])
        end)

        it("supports advanced selectors on non-named nodes", function()
            test_render(gui.Box{
                w = 1, h = 1, color = "blue",
                style = {
                    bgimg = "btn.png",
                    {sel = "$hovered", bgimg = "hover.png"},
                    {sel = "$focused", bgimg = "focus.png"},
                },
            }, [[
                size[1.6,1.6]
                style_type[box;bgimg=btn.png]
                style_type[box:hovered;bgimg=hover.png]
                style_type[box:focused;bgimg=focus.png]
                box[0.3,0.3;1,1;blue]
                style_type[box:focused;bgimg=]
                style_type[box:hovered;bgimg=]
                style_type[box;bgimg=]
            ]])
        end)

        it("supports multiple selectors", function()
            test_render(gui.Button{
                w = 1, h = 1, name = "mybtn",
                style = {
                    bgimg = "btn.png",
                    {sel = "$hovered, $focused,$pressed", bgimg = "hover.png"},
                },
            }, [[
                size[1.6,1.6]
                style[mybtn;bgimg=btn.png]
                style[mybtn:hovered,mybtn:focused,mybtn:pressed;bgimg=hover.png]
                button[0.3,0.3;1,1;mybtn;]
            ]])
        end)

        it("allows reuse of the same table", function()
            local style = {
                bgimg = "btn.png",
                {sel = "$hovered", bgimg = "hover.png"},
            }
            test_render(gui.VBox{
                gui.Button{w = 1, h = 1, name = "btn1", style = style},
                gui.Button{w = 1, h = 1, name = "btn2", style = style},
            }, [[
                size[1.6,2.8]
                style[btn1;bgimg=btn.png]
                style[btn1:hovered;bgimg=hover.png]
                button[0.3,0.3;1,1;btn1;]
                style[btn2;bgimg=btn.png]
                style[btn2:hovered;bgimg=hover.png]
                button[0.3,1.5;1,1;btn2;]
            ]])
        end)
    end)

    describe("tooltip insertion", function()
        it("works with named elements", function()
            test_render(gui.Button{
                w = 1, h = 1, name = "mybtn",
                tooltip = "test",
            }, [[
                size[1.6,1.6]
                tooltip[mybtn;test]
                button[0.3,0.3;1,1;mybtn;]
            ]])
        end)

        it("works with unnamed elements", function()
            -- The tooltip[] added here takes the list spacing into account
            test_render(gui.List{
                w = 2, h = 2, padding = 1,
                tooltip = "test"
            }, [[
                size[4.25,4.25]
                tooltip[1,1;2.25,2.25;test]
                list[;;1,1;2,2]
            ]])
        end)
    end)

    describe("Flow.embed", function()
        local embedded_form = flow.make_gui(function(_, x)
            return gui.VBox{
                gui.Label{label = "This is the embedded form!"},
                gui.Field{name = "test2"},
                x.a and gui.Label{label = "A is true!" .. x.a} or gui.Nil{}
            }
        end)
        it("raises an error if called outside of a form context", function()
            assert.has_error(function()
                embedded_form:embed{
                    -- It's fully possible that the API user would have access
                    -- to a player reference
                    player = stub_player"test_player",
                    name = "theprefix"
                }
            end)
        end)
        it("returns a flow widget", function ()
            test_render(function(p, _)
                return gui.HBox{
                    gui.Label{label = "asdft"},
                    embedded_form:embed{player = p, name = "theprefix"},
                    gui.Label{label = "ffaksksdf"}
                }
            end, gui.HBox{
                gui.Label{label = "asdft"},
                gui.VBox{
                    gui.Label{label = "This is the embedded form!"},
                    -- The exact prefix is an implementation detail, you
                    -- shouldn't rely on this in your own code
                    gui.Field{name = "_#theprefix#test2"},
                },
                gui.Label{label = "ffaksksdf"}
            })
        end)
        it("supports nil prefix", function()
            test_render(function(p, _)
                return gui.HBox{
                    gui.Label{label = "asdft"},
                    embedded_form:embed{player = p},
                    gui.Label{label = "ffaksksdf"}
                }
            end, gui.HBox{
                gui.Label{label = "asdft"},
                gui.VBox{
                    gui.Label{label = "This is the embedded form!"},
                    gui.Field{name = "test2"},
                },
                gui.Label{label = "ffaksksdf"}
            })
        end)
        it("child context object lives inside the host", function()
            test_render(function(p, x)
                assert.Nil(
                    x.theprefix,
                    "Prefixes are inserted when :embed is called. "..
                    "The first time this renders, it hasn't been called yet."
                )
                -- Technically, that means both of these will be true the first time
                -- This code only ever runs once, so that's every time.
                -- Regardless, this is how ordinary API users would be using it.
                if not x.theprefix then
                    x.theprefix = {}
                end
                if not x.theprefix.a then
                    x.theprefix.a = " WOW!"
                end
                return gui.HBox{
                    gui.Label{label = "asdft"},
                    embedded_form:embed{player = p, name = "theprefix"},
                    gui.Label{label = "ffaksksdf"}
                }
            end, gui.HBox{
                gui.Label{label = "asdft"},
                gui.VBox{
                    gui.Label{label = "This is the embedded form!"},
                    gui.Field{name = "_#theprefix#test2"},
                    gui.Label{label = "A is true! WOW!"}
                },
                gui.Label{label = "ffaksksdf"}
            })
        end)
        it("flow form context table", function()
            test_render(function(p, x)
                x.form["_#the_name#jkl"] = 3
                local child = flow.make_gui(function(_p, xc)
                    xc.form.thingy = true
                    xc.form.jkl = 9
                    return gui.Label{label = "asdf"}
                end):embed{
                    player = p,
                    name = "the_name"
                }
                assert.True(x.form["_#the_name#thingy"])
                assert.equal(9, x.form["_#the_name#jkl"])
                return child
            end, gui.Label{label = "asdf"})
        end)
        it("host may modify the returned flow form", function()
            test_render(function(p, _x)
                local e = embedded_form:embed{player = p, name = "asdf"}
                e[#e+1] = gui.Box{w = 1, h = 3}
                return e
            end, gui.VBox{
                gui.Label{label = "This is the embedded form!"},
                gui.Field{name = "_#asdf#test2"},
                gui.Box{w = 1, h = 3}
            })
        end)
        it("event handler called correctly", function()
            local function func_btn_event() end
            local function func_field_event() return true end
            local function func_quit() end

            func_btn_event = spy.new(func_btn_event)
            func_field_event = spy.new(func_field_event)
            func_quit = spy.new(func_quit)

            local wrapped_p, wrapped_x
            local event_embedded_form = flow.make_gui(function(p, x)
                wrapped_p, wrapped_x = p, x
                return gui.VBox{
                    on_quit = func_quit,
                    gui.Label{label = "Callback demo:"},
                    gui.Button{label = "Click me!", name = "btn", on_event = func_btn_event},
                    gui.Field{name = "field", on_event = func_field_event}
                }
            end)

            local _tree, state = render(function(player, _ctx)
                return event_embedded_form:embed{
                    player = player,
                    name = "thesubform"
                }
            end)

            local player, ctx = wrapped_p, state.ctx
            state.callbacks.quit(player, ctx)
            state.callbacks["_#thesubform#field"](player, ctx)
            state.btn_callbacks["_#thesubform#btn"](player, ctx)

            assert.same(state.ctx.thesubform, wrapped_x)

            assert.spy(func_quit).was.called(1)
            assert.spy(func_quit).was.called_with(player, wrapped_x)
            assert.spy(func_field_event).was.called(1)
            assert.spy(func_field_event).was.called_with(player, wrapped_x)
            assert.spy(func_btn_event).was.called(1)
            assert.spy(func_btn_event).was.called_with(player, wrapped_x)

            -- Each of these are wrapped with another function to put the actual function in the correct environment
            assert.Not.same(func_quit, state.callbacks.quit)
            assert.Not.same(func_field_event, state.callbacks["_#thesubform#field"])
            assert.Not.same(func_btn_event, state.callbacks["_#thesubform#btn"])
        end)
        describe("metadata", function()
            it("style data is modified", function()
                local style_embedded_form = flow.make_gui(function (p, x)
                    return gui.VBox{
                        gui.Style{selectors = {"test"}, props = {prop = "value"}},
                    }
                end)
                test_render(function(p, _x)
                    return style_embedded_form:embed{player = p, name = "asdf"}
                end, gui.VBox{
                    gui.Style{selectors = {"_#asdf#test"}, props = {prop = "value"}},
                })
            end)
            it("scroll_container data is modified", function()
                local scroll_embedded_form = flow.make_gui(function(p, x)
                    return gui.VBox{
                        gui.ScrollContainer{scrollbar_name = "name"}
                    }
                end)
                test_render(function(p, _x)
                    return scroll_embedded_form:embed{player = p, name = "asdf"}
                end, gui.VBox{
                    gui.ScrollContainer{scrollbar_name = "_#asdf#name"}
                })
            end)
            it("tooltip data is modified", function()
                local tooltip_embedded_form = flow.make_gui(function(p, x)
                    return gui.VBox{
                        gui.Tooltip{gui_element_name = "lololol"}
                    }
                end)
                test_render(function(p, _x)
                    return tooltip_embedded_form:embed{player = p, name = "asdf"}
                end, gui.VBox{
                    gui.Tooltip{gui_element_name = "_#asdf#lololol"}
                })
            end)
        end)
        it("supports missing initial form values", function()
            local tooltip_embedded_form = flow.make_gui(function(_, x)
                assert.same("table", type(x), "embed defines the table and passes it")
                assert.is_nil(x.field, "there was nothing here to begin with")
                x.field = "new value!"
                return gui.VBox{
                    gui.Field{name = "field"}
                }
            end)
            test_render(function(p, x)
                assert.is_nil(x.asdf, "Table isn't defined initially")
                local subform = tooltip_embedded_form:embed{player = p, name = "asdf"}
                assert.same("table", type(x.asdf), "embed defines the table and leaves it in the parent")
                assert.same("new value!", x.asdf.field, "values that it set set are here")
                return subform
            end, gui.VBox{
                gui.Field{name = "_#asdf#field"}
            })
        end)
        it("supports fresh initial form values", function()
            local tooltip_embedded_form = flow.make_gui(function(p, x)
                assert.same("initial value!", x.field)
                return gui.VBox{
                    gui.Field{name = "field"}
                }
            end)
            test_render(function(p, x)
                if not x.asdf then
                    x.asdf = {
                        field = "initial value!"
                    }
                end
                return tooltip_embedded_form:embed{player = p, name = "asdf"}
            end, gui.VBox{
                gui.Field{name = "_#asdf#field"}
            })
        end)
        it("updates flow.get_context", function()
            local form = flow.make_gui(function(player_arg)
                local ctx, player_from_ctx = flow.get_context()
                assert.equals("inner", ctx.value)
                assert.equals(player_arg, player_from_ctx)
                return gui.Label{label = "Hello"}
            end)
            test_render(function(p, ctx)
                ctx.value = "outer"
                ctx.test = {value = "inner"}

                assert.equals("outer", flow.get_context().value)
                local embedded = form:embed{player = p, name = "test"}
                assert.equals("outer", flow.get_context().value)
                return embedded
            end, gui.Label{label = "Hello"})
        end)
    end)
end)
