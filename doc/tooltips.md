# Tooltips

You can add tooltips to elements using the `tooltip` field:

```lua
gui.Image{
    w = 2, h = 2,
    texture_name = "air.png",
    tooltip = "Air",
}
```

There is also a [`gui.Tooltip`](elements.md#guitooltip) element which lets you
change the background colour of the tooltip. As with `gui.Style`, it is
invisible and won't affect padding.
