# flow

[![ContentDB](https://content.luanti.org/packages/luk3yx/flow/shields/downloads/)](https://content.luanti.org/packages/luk3yx/flow/)

An experimental layout manager and formspec API replacement for Luanti (formerly Minetest).
Vaguely inspired by Flutter and GTK.

[Online tutorial/demo](https://luk3yx.gitlab.io/minetest-flow-playground/)
([source](https://gitlab.com/luk3yx/minetest-flow-playground))

## Features

#### Layouting

 - No manual positioning of elements.
 - Automatic layouting using `HBox` and `VBox` containers
 - Some elements have an automatic size.
 - The size of elements can optionally expand to fit larger spaces
 - Elements which get their size based on their label length automatically become
   larger/smaller to fit long translations[^label-size].

[^label-size]: This isn't perfect, the actual size of labels depends on the client's font, DPI, window size, and formspec-related scaling settings.

#### Other features

 - No form names. Form names are still used internally, however they are
   hidden from the API.
 - No having to worry about state.
 - Values of fields, scrollbars, checkboxes, etc are remembered when
   redrawing a form and are automatically applied.
 - Has an [inspector mod](https://content.luanti.org/packages/luk3yx/flow_inspector/)
   to help with developing and debugging forms.
 - Some common security issues with formspec input handling are mitigated.

## Limitations

 - This mod doesn't support all of the features that regular formspecs do.
 - [FS51](https://content.luanti.org/packages/luk3yx/fs51/) is required if
   you want to have full support for Minetest 5.3 and below.
 - Make sure you're using the latest version of flow if you are on MT 5.10-dev
   or later, older versions used a hack which no longer works.

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
                core.chat_send_player(player:get_player_name(), "You have selected item #" .. selected_idx .. "!")
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

## Updating forms

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
    return core.check_player_privs(player, "server")
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

If you're using a form as a HUD, you must call `form:show_hud` to update it.

## Security

Flow ignores potentially malicious formspec input from clients, such as
buttons or fields that haven't been shown to the client, out-of-bounds dropdown
selections, and newlines in `Field` elements (where it's impossible to enter
a newline without pasting it in).

## Other formspec libraries/utilities

These utilities likely aren't compatible with flow.

 - [fs_layout](https://github.com/fluxionary/minetest-fs_layout/) is another mod library that does automatic formspec element positioning.
 - [fslib](https://content.luanti.org/packages/LMD/fslib/) is a small mod library that lets you build formspec strings.
 - [Just_Visiting's formspec editor](https://content.luanti.org/packages/Just_Visiting/formspec_editor) is a Minetest (sub)game that lets you edit formspecs and preview them as you go
 - [kuto](https://github.com/TerraQuest-Studios/kuto/) is a formspec library that has some extra widgets/components and has a callback API. Some automatic sizing can be done for buttons.
    - It may be possible to use kuto's components with flow somehow as they both use formspec_ast internally.
    - kuto was the the source of the "on_event" function idea.
 - [My web-based formspec editor](https://forum.luanti.org/viewtopic.php?f=14&t=24130) lets you add elements and drag+drop them, however it doesn't support all formspec features.

## Documentation

More detailed documentation is available at
https://luk3yx.gitlab.io/minetest-flow/. Some code snippets have a "run" button
which will open them in a web-based playground, not all of these will work
properly as the playground doesn't support all formspec elements.
