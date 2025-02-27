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
