# flow

An experimental layout manager and formspec API replacement for Minetest.
Vaguely inspired by Flutter and GTK.

## Features

 - No manual positioning of elements.
 - Some elements have an automatic size.
 - The size of elements can optionally expand to fit larger spaces
 - No form names. Form names are still used internally, however they are hidden from the API.
 - No having to worry about state.
 - Values of fields, scrollbars, checkboxes, etc are remembered when redrawing
   a formspec and are automatically applied.

## Limitations

 - This mod doesn't support all of the features that regular formspecs do.
 - [FS51](https://content.minetest.net/packages/luk3yx/fs51/) is required if
   you want to have full support for Minetest 5.3 and below.

## Basic example

See `example.lua` for a more comprehensive example which demonstrates how
layouting and alignment works.

```lua
-- GUI elements are accessible with flow.widgets. Using
-- `local gui = flow.widgets` is recommended to reduce typing.
local gui = flow.widgets

-- GUIs are created with flow.make_gui(build_func).
local my_gui = flow.make_gui(function(player, ctx)
    -- The build function should return a GUI element such as gui.VBox.
    -- `ctx` can be used to store context. `ctx.form` is reserved for storing
    -- the state of elements in the form. For example, you can use
    -- `ctx.form.my_checkbox` to check whether `my_checkbox` is checked. Note
    -- that ctx.form.element may be nil instead of its default value.

    -- This function may be called at any time by flow.

    -- gui.VBox is a "container element" added by this mod.
    return gui.VBox {
        gui.Label {label = "Here is a dropdown:"},
        gui.Dropdown {
            -- The value of this dropdown will be accessible from ctx.form.my_dropdown
            name = "my_dropdown",
            items = {'First item', 'Second item', 'Third item'},
            index_event = true,
        },
        gui.Button {
            label = "Get dropdown index",
            on_event = function(player, ctx)
                -- flow should guarantee that `ctx.form.my_dropdown` exists, even if the client doesn't send my_dropdown to the server.
                local selected_idx = ctx.form.my_dropdown
                minetest.chat_send_player(player:get_player_name(), "You have selected item #" .. selected_idx .. "!")
            end,
        }
    }
end)

-- Show the GUI to player as an interactive form
-- Note that `player` is a player object and not a player name.
my_gui:show(player)

-- Close the form
my_gui:close(player)

-- Alternatively, the GUI can be shown as a non-interactive HUD (requires
-- hud_fs to be installed).
my_gui:show_hud(player)
my_gui:close_hud(player)
```

## Other formspec libraries/utilities

These utilities likely aren't compatible with flow.

 - [fs_layout](https://github.com/fluxionary/minetest-fs_layout/) is another mod library that does automatic formspec element positioning.
 - [Just_Visiting's formspec editor](https://content.minetest.net/packages/Just_Visiting/formspec_editor) is a Minetest (sub)game that lets you edit formspecs and preview them as you go
 - [kuto](https://github.com/TerraQuest-Studios/kuto/) is a formspec library that has some extra widgets/components and has a callback API. Some automatic sizing can be done for buttons.
   - It may be possible to use kuto's components with flow somehow as they both use formspec_ast internally.
 - [My web-based formspec editor](https://forum.minetest.net/viewtopic.php?f=14&t=24130) lets you add elements and drag+drop them, however it doesn't support all formspec features.

## Elements

You should do `local gui = flow.widgets` in your code.

### Layouting elements

These elements are used to lay out elements in the formspec. They don't have a
direct equivalent in Minetest formspecs.

#### `gui.VBox`

A vertical box, similar to a VBox in GTK. Elements inside a VBox are stacked
vertically.

```lua
gui.VBox{
    -- These elements are documented later on.
    gui.Label{label="I am a label!"},

    -- The second label will be positioned underneath the first one.
    gui.Label{label="I am a second label!"},
}
```

#### `gui.HBox`

Like `gui.VBox` but stacks elements horizontally instead.

```lua
gui.HBox{
    -- These elements are documented later on.
    gui.Label{label="I am a label!"},

    -- The second label will be positioned to the right of first one.
    gui.Label{label="I am a second label!"},

    -- You can nest HBox and VBox elements
    gui.VBox{
        gui.Image{texture_name="default_dirt.png", align_h = "centre"},
        gui.Label{label="Dirt"},
    }
}
```

#### `gui.ScrollableVBox`

Similar to `gui.VBox` but uses a scroll_container and automatically adds a
scrollbar. You must specify a width and height for the scroll container.

```lua
gui.ScrollableVBox{
    -- A name must be provided for ScrollableVBox elements. You don't
    -- have to use this name anywhere else, it just makes sure flow
    -- doesn't mix up scrollbar states if one gets removed or if the
    -- order changes.
    name = "vbox1",

    -- Specifying a height is optional but is probably a good idea.
    -- If you don't specify a height, it will default to
    -- min(height_of_content, 5).
    h = 10,

    -- These elements are documented later on.
    gui.Label{label="I am a label!"},

    -- The second label will be positioned underneath the first one.
    gui.Label{label="I am a second label!"},
}
```

### Minetest formspec elements

There is an auto-generated `elements.md` file which contains a list of elements
and parameters. Elements in this list haven't been tested and might not work.
