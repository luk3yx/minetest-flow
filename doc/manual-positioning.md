# Manual positioning

## Dynamic element types

This is only recommended for elements inside `gui.Container` (see below)
outside of some rare use cases that need it, as it does not support flow's
layouting elements.

If you want to generate element types from a variable, you can use
`{type = "label", label = "Hello world!"}` instead of
`gui.Label{label="Hello world!"}`. HBoxes and VBoxes can be created
this way as well (with `type = "hbox"` and `type = "vbox"`), however other
layouting elements (such as ScrollableVBox and Spacer) won't work correctly.

An example of this is in `example.lua`.

## Manual positioning of elements

You can use `gui.Container` elements to contain manually positioned elements.

```lua
gui.VBox{
    gui.Label{label = "Automatically positioned"},
    gui.Container{
        -- You can specify a width and height if you don't want flow to try and
        -- guess at the size of the container.
        -- w = 3, h = 2,

        -- You may embed most formspec_ast elements inside gui.Container
        {type = "box", x = 0, y = 0, w = 1, h = 1, color = "red"},
        {type = "box", x = 0.3, y = 0.3, w = 1, h = 1, color = "green"},
        {type = "box", x = 0.6, y = 0.6, w = 1, h = 1, color = "blue"},

        {type = "label", x = 2, y = 1.1, label = "Manually positioned"}
    },
}
```

Note that you should not nest layouted elements (like `gui.VBox`) inside
`gui.Container`.
