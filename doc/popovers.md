# Popovers (highly experimental)

**This API will likely have breaking changes in the future.**

Flow supports a highly experimental low-level API for defining popovers.
Popovers appear over top of all other elements and are anchored to their parent.

This API is intended to be used for creating themed widgets like dropdowns, or
for a higher level popover API that adds styling and is easier to use.

You add a `popover` attribute to any container element to define a popover.
Flow does not manage the lifecycle (opening/closing) of popovers, you must
ensure that you do this yourself like in the example.

See the below example for details on how to use the API:

```lua
gui.Stack{
    gui.Button{
        label = "Open popover",

        -- When the popover button is clicked, open the popover
        on_event = function(player, ctx)
            ctx.show_popover = true
            return true
        end,
    },

    -- The actual element to overlay
    -- "popover" is set to the gui.VBox element if (and only if)
    -- ctx.show_popover is true, otherwise it's nil so no popover is shown.
    popover = ctx.show_popover and gui.VBox{
        -- Specifying padding and bgcolor is optional, but is probably a good
        -- idea since flow doesn't do any styling on its own.
        padding = 0.2,
        bgcolor = "#222e",

        -- "anchor" specifies how the popover is positioned relative to the
        -- parent, and can be "bottom" (default), "top", "left", or "right".
        anchor = ctx.form.anchor,

        -- align_h and align_v align the popover according to its parent
        -- element. You only need to specify align_h for
        -- anchor = "top"/"bottom" or align_v for anchor = "left"/"right", this
        -- example specifies both so that it can demonstrate switching between
        -- different anchor types.
        align_h = "fill",
        align_v = "center",

        -- Popover contents
        gui.Label{label = "Hi there!"},
        gui.Dropdown{
            name = "anchor",
            items = {
                "bottom",
                "top",
                "left",
                "right",
            },
        },
    } or nil,

    -- Clicking outside the popover will call this function, which should
    -- probably close the popover.
    on_close_popover = function(player, ctx)
        ctx.show_popover = false
        return true
    end,
}
```

There are some restrictions on popovers:

 - They must not extend outside the form, otherwise they'll only be partially
   visible (unless everything is styled with `noclip = true`). Flow does not
   attempt to detect this.
 - You can only define `popover` on container elements, like gui.Stack,
   gui.HBox, and gui.VBox.
 - Only one popover is shown at a time.
 - Players can still use tab to interact with things behind the popover,
   despite being unable to use their mouse to do so.
 - You cannot show popovers inside of other popovers.
