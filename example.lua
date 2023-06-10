-- You can run /flow-example in singleplayer to open this form
local gui = flow.widgets
local S = minetest.get_translator("flow")

local elements = {"box", "label", "image", "field", "checkbox", "list"}
local alignments = {"auto", "start", "end", "centre", "fill"}

local my_gui = flow.make_gui(function(player, ctx)
    local hbox = {
        min_h = 2,
    }

    local elem_type = elements[ctx.form.element] or "box"

    -- Setting a width/height on labels, fields, or checkboxes can break things
    local w, h
    if elem_type ~= "label" and elem_type ~= "field" and
            elem_type ~= "checkbox" then
        w, h = 1, 1
    end

    hbox[#hbox + 1] = {
        type = elem_type,
        w = w,
        h = h,
        label = "Label",
        color = "#fff",
        texture_name = "air.png",

        expand = ctx.form.expand,
        align_h = alignments[ctx.form.align_h],
        align_v = alignments[ctx.form.align_v],
        name = "testing",

        inventory_location = "current_player",
        list_name = "main",
    }

    if ctx.form.box2 then
        hbox[#hbox + 1] = gui.Box{
            w = 1,
            h = 1,
            color = "#888",
            expand = ctx.form.expand_box2,
        }
    end

    local try_it_yourself_box
    if ctx.form.vbox then
        try_it_yourself_box = gui.VBox(hbox)
    else
        try_it_yourself_box = gui.HBox(hbox)
    end

    return gui.VBox{
        -- Optionally specify a minimum size for the form
        min_w = 8,
        min_h = 9,

        gui.HBox{
            gui.Image{w = 1, h = 1, texture_name = "air.png"},
            gui.Label{label = S"Hello world!"},
        },
        gui.Label{label=S"This is an example form."},
        gui.Checkbox{
            name = "checkbox",

            -- flow will detect that you have accessed ctx.form.checkbox and
            -- will automatically redraw the formspec if the value is changed.
            label = ctx.form.checkbox and S"Uncheck me!" or S"Check me!",
        },
        gui.Button{
            -- Names are optional
            label = S"Toggle checkbox",

            -- Important: Do not use the `player` and `ctx` variables from the
            -- above formspec.
            on_event = function(player, ctx)
                -- Invert the value of the checkbox
                ctx.form.checkbox = not ctx.form.checkbox

                -- Send a chat message
                minetest.chat_send_player(player:get_player_name(), S"Toggled!")

                -- Return true to tell flow to redraw the formspec
                return true
            end,
        },

        gui.Label{label=S"A demonstration of expansion:"},

        -- The finer details of scroll containers are handled automatically.
        -- Clients that don't support scroll_container[] will see a paginator
        -- instead.
        gui.ScrollableVBox{
            -- A name must be provided for ScrollableVBox elements. You don't
            -- have to use this name anywhere else, it just makes sure flow
            -- doesn't mix up scrollbar states if one gets removed or if the
            -- order changes.
            name = "vbox1",

            gui.Label{label=S("By default, objects do not expand\nin the " ..
                              "same direction as the hbox/vbox:")},
            gui.HBox{
                gui.Box{
                    w = 1,
                    h = 1,
                    color = "#fff",
                },
            },

            gui.Label{
                label=S("Items are expanded in the opposite\ndirection,"
                     .. " however:")
            },
            gui.HBox{
                min_h = 2,
                gui.Box{
                    w = 1,
                    h = 1,
                    color = "#fff",
                },
            },

            gui.Label{label=S("To automatically expand an object, add\n" ..
                              "`expand = true` to its definition.")},
            gui.HBox{
                gui.Box{
                    w = 1,
                    h = 1,
                    color = "#fff",
                    expand = true,
                },
            },

            gui.Label{label=S("Multiple expanded items will share the\n" ..
                              "remaining space evenly.")},

            gui.HBox{
                gui.Box{
                    w = 1,
                    h = 1,
                    color = "#fff",
                    expand = true
                },
                gui.Box{
                    w = 1,
                    h = 1,
                    color = "#fff",
                    expand = true
                },
            },

            gui.HBox{
                gui.Box{
                    w = 1,
                    h = 1,
                    color = "#fff",
                    expand = true
                },
                gui.Box{
                    w = 3,
                    h = 1,
                    color = "#fff",
                    expand = true
                },
            },
        },

        gui.Label{label=S"Try it yourself!"},
        gui.HBox{
            gui.VBox{
                gui.Label{label=S"Element:"},
                gui.Dropdown{
                    name = "element",
                    items = elements,
                    index_event = true,
                }
            },
            gui.VBox{
                gui.Label{label="align_h:"},
                gui.Dropdown{
                    name = "align_h",
                    items = {"auto (default)", "start / top / left",
                             "end / bottom / right", "centre / center", "fill"},
                    index_event = true,
                }
            },
            gui.VBox{
                gui.Label{label="align_v:"},
                gui.Dropdown{
                    name = "align_v",
                    items = {"auto (default)", "start / top / left",
                             "end / bottom / right", "centre / center", "fill"},
                    index_event = true,
                }
            },
        },
        gui.HBox{
            gui.VBox{
                gui.Checkbox{name = "expand", label = S"Expand"},
                gui.Checkbox{name = "box2", label = S"Second box"},
            },
            gui.VBox{
                gui.Checkbox{
                    name = "vbox",
                    label = S"Use vbox instead of hbox"
                },
                gui.Checkbox{
                    name = "expand_box2",
                    label = S"Expand second box"
                },
            },
        },
        try_it_yourself_box,
    }
end)

return my_gui
