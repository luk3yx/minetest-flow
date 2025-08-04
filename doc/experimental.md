# Experimental features

These features might be broken in the future.

## `no_prepend[]`

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

## `bgcolor[]`

You can set `bgcolor = "#123"`, `fbgcolor = "#123"`, and
`bg_fullscreen = true` on the root element to set a background colour. The
values for these correspond to the [`bgcolor` formspec element](https://api.luanti.org/formspec/#bgcolorbgcolorfullscreenfbgcolor).

## Putting the form somewhere else on the screen (likely required for most HUDs)

These values allow the position of the displayed form to be moved around and
adjust how it is scaled.

Example:

```lua
local my_gui = flow.make_gui(function(player, ctx)
    return gui.VBox{
        -- Adjusts where on the screen the form/HUD is rendered.
        -- 0 is the top/left, 1 is the bottom/right
        -- You probably want to set `window_position` and `window_anchor` to
        -- the same value.
        -- This puts the form in the bottom-right corner.
        window_position = {x = 1, y = 1},
        window_anchor = {x = 1, y = 1},

        -- Equivalent to padding[0.1,0.2], adjusts the minimum amount of
        -- padding around the form in terms of total screen size. If the form
        -- is too big, it will be scaled down
        -- Default for formspecs: {x = 0.05, y = 0.05} (i.e. 5% of screen size)
        -- HUDs default to a hardcoded pixel size, if you want them to roughly
        -- line up with formspecs then you may explicitly specify this.
        window_padding = {x = 0.1, y = 0.2},

        gui.Label{label = "Hello world"},
    }
end)
```

See [the formspec documentation](https://api.luanti.org/formspec/#positionxy)
for more information.

## Rendering to a formspec

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


> **Warning:**
> Do not use this API with node meta formspecs, it can and will break!

## Embedding a form into another form

You can embed form objects inside others like this:

```lua
local parent_form = flow.make_gui(function(player, ctx)
    return gui.VBox{
        gui.Label{label = "Hello world"},
        other_form:embed{
            -- You can optionally pass in the player object to support older
            -- versions of flow (before 2025-06-17).
            player = player,

            -- A name for the embed. If this is specified, the embedded form
            -- will get its own context (accessible at ctx.my_embed_name) and
            -- field names will be rewritten to avoid conflicts with the
            -- parent form. If name is not specified, the embedded form will
            -- share ctx and ctx.form with the parent, and will not have field
            -- names rewritten.
            name = "my_embed_name",
        },
    }
end)
```

Special characters (excluding `-` and `_`) are not allowed in embed names.

## Running code when a form is closed

`gui.Container`, `gui.HBox`, `gui.VBox`, and `gui.Stack` elements support an
`on_quit` callback which gets run when a player closes a form.

Note that this function is not called in some cases, such as when the player
leaves without closing the form or when another form/formspec is shown.

This function must not return anything, behaviour may get added to return
values in the future.

```lua
local parent_form = flow.make_gui(function(player, ctx)
    return gui.VBox{
        on_quit = function(player, ctx)
            core.chat_send_player(player:get_player_name(), "Form closed!")
        end,
    }
end)
```

If multiple `on_quit` callbacks are specified in different elements, they will
all get called.

## Handling enter keypresses in fields

`gui.Field` and `gui.Pwdfield` support an `on_key_enter` callback that gets
called if enter is pressed:

```lua
local form = flow.make_gui(function(player, ctx)
    return gui.VBox{
        gui.Field{
            label = "Press enter!",
            name = "field",
            on_key_enter = function(player, ctx)
                core.chat_send_player(player:get_player_name(),
                    "Field value: " .. dump(ctx.form.field))
            end,

            -- You can also specify close_on_enter to close the form when enter
            -- is pressed.
            close_on_enter = true,
        },
    }
end)
```

Notes:

 - If you're using this callback, please make sure there's some other way to
   trigger the enter action (like a button) to support older flow versions and
   in case I replace this API with a better one in the future.
 - If you want recent mobile clients to call this callback when editing text,
   add `enter_after_edit = true` to the field definition.
 - The similarly named `on_event` gets called whenever the client submits the
   field to the server, which could be at any time, and is not very useful, but
   is still supported for compatibility (and there may be uses for it, such as
   sanitising field values). Be careful not to accidentally use the wrong
   callback.

## Getting a reference to the current player and context

If you're making a custom widget, it might be useful to get a reference to
`ctx` and `player` so you don't have to pass them in manually.

```lua
local function HelloWorld(def)
    local ctx, player = flow.get_context()
    return gui.Label{
        label = "Hello, " .. player:get_player_name() .. "!\n" ..
            "some_value=" .. ctx.some_value,
        style = def.style,
    }
end

local form = flow.make_gui(function(player, ctx)
    ctx.some_value = 123
    return HelloWorld{style = {font_size = "*2"}}
end)
```

`flow.get_context()` will error when called outside a build function (as you
should not normally do this).

## `gui.Flow` container

`gui.Flow` is a fixed-width container that wraps items around if they don't
fit. Unlike other elements, you must specify a width, and some options like
`min_w` and `padding` aren't supported.

This is similar to GTK's `FlowBox`, but with a lot fewer features.

```lua
gui.Flow{
    -- Fits 3 items
    w = 3 * (1 + 0.2),

    gui.Image{w = 1, h = 1, texture_name = "default_mese_crystal.png"},
    gui.Image{w = 1, h = 1, texture_name = "default_mese_crystal.png"},
    gui.Image{w = 1, h = 1, texture_name = "default_mese_crystal.png"},
    gui.Image{w = 1, h = 1, texture_name = "default_mese_crystal.png"},
    gui.Image{w = 1, h = 1, texture_name = "default_mese_crystal.png"},
}
```
