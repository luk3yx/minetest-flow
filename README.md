# flow

[![ContentDB](https://content.minetest.net/packages/luk3yx/flow/shields/downloads/)](https://content.minetest.net/packages/luk3yx/flow/)

An experimental layout manager and formspec API replacement for Minetest.
Vaguely inspired by Flutter and GTK.

[Online tutorial/demo](https://luk3yx.gitlab.io/minetest-flow-playground/)
([source](https://gitlab.com/luk3yx/minetest-flow-playground))

## Features

#### Layouting

 - No manual positioning of elements.
 - Automatic layouting using `HBox` and `VBox` containers
 - Some elements have an automatic size.
 - The size of elements can optionally expand to fit larger spaces

#### Other features

 - No form names. Form names are still used internally, however they are
   hidden from the API.
 - No having to worry about state.
 - Values of fields, scrollbars, checkboxes, etc are remembered when
   redrawing a form and are automatically applied.
 - Has an [inspector mod](https://content.minetest.net/packages/luk3yx/flow_inspector/)
   to help with developing and debugging forms.

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

-- You can provide an initial value for `ctx` by adding a second parameter to
-- show(). In the below example, `ctx.value` will be "test".
my_gui:show(player, {value = "test"})

-- Close the form
my_gui:close(player)

-- Alternatively, the GUI can be shown as a non-interactive HUD (requires
-- hud_fs to be installed).
my_gui:show_hud(player)
my_gui:close_hud(player)
```

### Updating forms

If some data displayed inside a form changes (for example a timer or progress
indicator), you can use `form:update` to update the form without resetting
`ctx` or showing the form again if the player has closed it.

Due to formspec limitations, players may lose text typed into fields that
hasn't been sent to the server when `form:update` is called.

```lua
-- Re-shows the form for one player if they have the form open
my_gui:update(player)

-- Re-shows the form for all players that have the form open and where
-- ctx.test == 123
my_gui:update_where(function(player, ctx)
    return ctx.test == 123
end)

-- Re-shows the form for all players with the "server" privilege
my_gui:update_where(function(player, ctx)
    return minetest.check_player_privs(player, "server")
end)

-- Re-shows the form for all players with the form open
my_gui:update_where(function() return true end)
```

Inside an `on_event` handler, you can use `return true` instead.

```lua
gui.Button{
    label = "Update form",
    on_event = function(player, ctx)
        return true
    end,
}
```

## Other formspec libraries/utilities

These utilities likely aren't compatible with flow.

 - [fs_layout](https://github.com/fluxionary/minetest-fs_layout/) is another mod library that does automatic formspec element positioning.
 - [fslib](https://content.minetest.net/packages/LMD/fslib/) is a small mod library that lets you build formspec strings.
 - [Just_Visiting's formspec editor](https://content.minetest.net/packages/Just_Visiting/formspec_editor) is a Minetest (sub)game that lets you edit formspecs and preview them as you go
 - [kuto](https://github.com/TerraQuest-Studios/kuto/) is a formspec library that has some extra widgets/components and has a callback API. Some automatic sizing can be done for buttons.
   - It may be possible to use kuto's components with flow somehow as they both use formspec_ast internally.
   - kuto was the the source of the "on_event" function idea.
 - [My web-based formspec editor](https://forum.minetest.net/viewtopic.php?f=14&t=24130) lets you add elements and drag+drop them, however it doesn't support all formspec features.

## Elements

You should do `local gui = flow.widgets` in your code.

### Layouting elements

These elements are used to lay out elements in the form. They don't have a
direct equivalent in formspecs.

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

Elements inside boxes have a spacing of 0.2 between them. To change this, you
can add `spacing = <number>` to the box definition. For example, `spacing = 0`
will remove all spacing between the elements.

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
        gui.Image{w=1, h=1, texture_name="default_dirt.png", align_h="centre"},
        gui.Label{label="Dirt", expand=true, align_h="centre"},
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

#### `gui.Spacer`

A "flexible space" element that expands by default. Example usage:

```lua
gui.HBox{
    -- These buttons will be on the left-hand side of the screen
    gui.Button{label = "Cancel"},
    gui.Button{label = "< Back"},

    gui.Spacer{},

    -- These buttons will be on the right-hand side of the screen
    gui.Button{label = "Next >"},
    gui.Button{label = "Confirm"},
}
```

I advise against using spacers when `expand = true` and `align = ...` would
work just as well since spacers are implemented hackily and won't account for
some special cases.

You can replicate the above example without spacers, however the code doesn't
look as clean:

```lua
gui.HBox{
    -- These buttons will be on the left-hand side of the screen
    gui.Button{label = "Cancel"},
    gui.Button{label = "< Back", expand = true, align_h = "left"},

    -- These buttons will be on the right-hand side of the screen
    gui.Button{label = "Next >"},
    gui.Button{label = "Confirm"},
}
```

You should not use spacers to centre elements as it creates unnecessary boxes,
and labels may be slightly off-centre (because label widths depend on screen
size, DPI, etc and this code doesn't trigger the centering hack):

```lua
-- This is bad!
gui.HBox{
    gui.Spacer{},
    gui.Label{label="I am not properly centered!"},
    gui.Spacer{},
}
```

You should do this instead:

```lua
gui.Label{label="I am centered!", align_h = "centre"},
```

This applies to other elements as well, because using HBox and Spacer to centre
elements creates unnecessary containers.

#### `gui.Nil`

A tool to allow for ternary-ish conditional widgets:

```lua
gui.VBox{
    gui.Label{ label = "The box below is only present if the boolean is truthy" },
    the_boolean and gui.Box{ color = "#FF0000" } or gui.Nil{},
}
```

Use sparingly, flow still has to process each `Nil` object to be able to know to
remove it, and thus could still slow things down. The fastest element is one
that doesn't exist, and thus doesn't need processing.

#### `gui.Stack`

This container element places its children on top of each other. All child
elements are expanded in both directions.

Note that some elements (such as centred labels) won't pass clicks through to
the element below them.

Example:

```lua
gui.Stack{
    min_w = 10,
    gui.Button{label = "Hello world!"},
    gui.Image{w = 1, h = 1, texture_name = "air.png", padding = 0.2, align_h = "left"},
}
```

![Screenshot](https://user-images.githubusercontent.com/3182651/215946217-3705dbd1-4ec8-4aed-a9eb-381fecb2d8f2.png)

### Minetest formspec elements

There is an auto-generated
[`elements.md`](https://gitlab.com/luk3yx/minetest-flow/-/blob/main/elements.md)
file which contains a list of elements and parameters. Elements in this list
haven't been tested and might not work.

#### Dynamic element types

If you want to generate element types from a variable, you can use
`{type = "label", label = "Hello world!"}` instead of
`gui.Label{label="Hello world!"}`. HBoxes and VBoxes can be created
this way as well (with `type = "hbox"` and `type = "vbox"`), however other
layouting elements (such as ScrollableVBox and Spacer)
won't work correctly.

An example of this is in `example.lua`.

## Padding, spacing, and backgrounds

All elements can have a `padding` value, which will add the specified amount of
padding around the element. The "root" element of the form (the one returned by
`build_func`) has a default padding of 0.3, everything else has a default
padding of 0.

`HBox` and `VBox` have a `spacing` field which specifies how much spacing there
is between elements inside the box. If unspecified, `spacing` will default to
0.2.

Container elements (HBox and VBox) can optionally have `bgimg` and `bgimg_middle`
parameters that specify a background for the container. The background will be
drawn behind any padding that the container has.

Example:

```lua
gui.VBox{
    padding = 0.5,
    spacing = 0.1,

    -- bgimg can be used without bgimg_middle
    bgimg = "air.png",
    bgimg_middle = 2,

    gui.Button{label="Button 1"},
    gui.Button{label="Button 2"},
}
```

![Screenshot](https://user-images.githubusercontent.com/3182651/198194381-4812c0fa-1909-48f8-b50d-6713c4c126ec.png)

The padding around the VBox is 0.5 and the spacing between the buttons inside
it is 0.1.

## Styling forms

To style forms, you use the `gui.Style` and `gui.StyleType` elements:

```lua
gui.Style{
    selectors = {"btn1"},
    props = {
        bgimg = "button.png",
        border = false,
    }
},

gui.Button{
    name = "btn1",
    label = "Button",
},
```

The style elements are invisible and won't affect padding.

## Hiding elements

Elements inside boxes can have `visible = false` set to hide them from the
player. Elements hidden this way will still take up space like with
`visibility: hidden;` in CSS.

## Experimental features

These features might be broken in the future.

<details>
<summary><b><code>no_prepend[]</code></b></summary>

You can set `no_prepend = true` on the "root" element to disable formspec
prepends.

Example:

```lua
local my_gui = flow.make_gui(function(player, ctx)
    return gui.VBox{
        no_prepend = true,

        gui.Button{label = "Button 1"},

        -- There will be an empty space where the second button would be
        gui.Button{label = "Button 2", visible = false},

        gui.Button{label = "Button 3"},
    }
end)
```

![Screenshot](https://user-images.githubusercontent.com/3182651/212222545-baee3669-15cd-410d-a638-c63b65a8811b.png)

</details><details>
<summary><b><code>bgcolor[]</code></b></summary>

You can set `bgcolor = "#123"`, `fbgcolor = "#123"`, and
`bg_fullscreen = true` on the root element to set a background colour. The
values for these correspond to the [`bgcolor` formspec element](https://minetest.gitlab.io/minetest/formspec/#bgcolorbgcolorfullscreenfbgcolor).

</details><details>
<summary><b>Using a form as an inventory</b></summary>

A form can be set as the player inventory. Flow internally generates the
formspec and passes it to `player:set_inventory_formspec()`. This will
completely replace your inventory and isn't compatible with inventory mods like
sfinv.

```lua
local example_inventory = flow.make_gui(function (player, context)
    return gui.Label{ label = "Inventory goes here!" }
end)
minetest.register_on_joinplayer(function(player)
    example_inventory:set_as_inventory_for(player)
end)
```

Like with the `show_hud` function, `update*` functions don't do anything, so to
update it, call `set_as_inventory_for` again with the new context. If the
context is not provided, it will reuse the existing context.

```lua
example_inventory:set_as_inventory_for(player, new_context)
```

While the form will of course be cleared when the player leaves, if you'd like
to unset the inventory manually, call `:unset_as_inventory_for(player)`,
analogue to `close_hud`:

```lua
example_inventory:unset_as_inventory_for(player)
```

This will set the inventory formspec string to `""` and stop flow from
processing inventory formspec input.

</details><details>
<summary><b>Rendering to a formspec</b></summary>

This API should only be used when necessary and may have breaking changes in
the future.

Some APIs in other mods, such as sfinv, expect formspec strings. You can use
this API to embed flow forms inside them. To use flow with these mods, you can
call `form:render_to_formspec_string(player, ctx, standalone)`.

 - By default the the `formspec_version` and `size` elements aren't included in
   the returned formspec and are included in a third return value. Set
   `standalone` to include them in the returned formspec string. The third
   return value will not be returned.
 - Returns `formspec, process_event[, info]`
 - The `process_event(fields)` callback will return true if the formspec should
   be redrawn, where `render_to_formspec_string` should be called and the new
   `process_event` should be used in the future. This function may return true
   even if fields.quit is sent.


**Do not use this API with node meta formspecs, it can and will break!**

</details>
