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

function minetest.get_translator(modname)
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
    function minetest.get_player_by_name(name)
        assert(name == "test_player")
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

function minetest.explode_textlist_event(event)
    local event_type, number = event:match("^([A-Z]+):(%d+)$")
    return {type = event_type, index = tonumber(number) or 0}
end

function minetest.explode_table_event(event)
    local event_type, row, column = event:match("^([A-Z]+):(%d+):(%d+)$")
    return {type = event_type, row = tonumber(row) or 0, column = tonumber(column) or 0}
end

-- Load flow
local f = assert(io.open("init.lua"))
local code = f:read("*a") .. "\nreturn naive_str_width"
f:close()
local naive_str_width = assert((loadstring or load)(code))()

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

local function test_render(build_func, output)
    local tree = render(build_func)
    local expected_tree = assert(formspec_ast.parse(output))

    assert.same(normalise_tree(expected_tree), normalise_tree(tree))
end

local function render_to_string(tree)
    local player = stub_player("test_player")
    local form = flow.make_gui(function() return table.copy(tree) end)
    local ctx = {}
    local _, event = form:render_to_formspec_string(player, ctx)
    return ctx, event
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
        }, ([[
            size[3.6,3.6]
            field_close_on_enter[4;false]
            field_close_on_enter[5;false]
            button[0.3,0.3;3,1;;1]
            image[0.3,0.3;3,3;2]
            field[0.3,0.7;3,2.6;4;Test;]
            field[0.3,0.3;3,3;5;;]

            style[\1;bgimg=;bgimg_pressed=]
            style[\1:hovered,\1:pressed;bgimg=]
            image_button[0.3,1.6;3,0.4;blank.png;\1;Test;;false]
            image_button[0.3,1.6;3,0.4;blank.png;\1;;;false]

            list[a;b;0.675,0.675;2,2]
            style[test;prop=value]
        ]]):gsub("\\1", "\1"))
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

    it("registers inventory formspecs", function ()
        local stupid_simple_inv_expected =
            "formspec_version[6]" ..
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
        local expected_one = "formspec_version[6]size[1.6,1.6]box[0.3,0.3;1,1;]"
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

            minetest.get_player_by_name = nil
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
                    local ctx, event = render_to_string(gui.Dropdown{
                        name = "a", items = {"hello", "world"},
                    })
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
end)
