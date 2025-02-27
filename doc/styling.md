# Styling forms

## Inline syntax

At the moment I suggest only using this syntax if your form won't look broken
without the style - older versions of flow don't support this syntax, and I may
make breaking changes to the sub-style syntax in the future.

You can add inline styles to elements with the `style` field:

```lua
gui.Button{
    label = "Test",
    style = {
        bgcolor = "red",

        -- You can style specific states of elements:
        {sel = "$hovered", bgcolor = "green"},

        -- Or a combination of states:
        {sel = "$hovered, $pressed", bgcolor = "blue"},
        {sel = "$hovered+pressed", bgcolor = "white"},
    },
}
```

If you need to style multiple elements, you can reuse the `style` table:

```lua
local my_style = {bgcolor = "red", {sel = "$hovered", bgcolor = "green"}}

local gui = flow.make_gui(function(player, ctx)
    return gui.VBox{
        gui.Button{label = "Styled button", style = my_style},
        gui.Button{label = "Unstyled button"},
        gui.Button{label = "Second styled button", style = my_style},
    }
end)
```

Note that this may inadvertently reset styles on subsequent elements if used on
elements without a name due to formspec limitations.

## Separate style elements

Alternatively, you can use the `gui.Style` and `gui.StyleType` elements if you
need to style a large group of elements or need to support older versions of
flow:

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

The `Style` and `StyleType` elements are invisible and won't affect padding.
