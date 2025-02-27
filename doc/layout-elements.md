# Layouting elements

You should do `local gui = flow.widgets` in your code to improve readability.
All examples will assume that this line exists.

These elements are used to lay out elements in the form. They don't have a
direct equivalent in formspecs.

## `gui.VBox`

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

## `gui.HBox`

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

## `gui.ScrollableVBox`

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

## `gui.Spacer`

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

## `gui.Nil`

A tool to allow for ternary-ish conditional widgets:

```lua
local form = flow.make_gui(function(player, ctx)
    local the_boolean = false
    return gui.VBox{
        gui.Label{label = "The box below is only present if the boolean is truthy"},
        the_boolean and gui.Box{w = 1, h = 1, color = "#FF0000"} or gui.Nil{},
    }
end)
```

Use sparingly, flow still has to process each `Nil` object to be able to know to
remove it, and thus could still slow things down. The fastest element is one
that doesn't exist, and thus doesn't need processing.

## `gui.Stack`

This container element places its children on top of each other. All child
elements are expanded in both directions.

Note that some elements (such as centred labels) won't pass clicks through to
the element below them.

### Example

```lua
gui.Stack{
    min_w = 10,
    gui.Button{label = "Hello world!"},
    gui.Image{w = 1, h = 1, texture_name = "air.png", padding = 0.2, align_h = "left"},
}
```

![Screenshot](https://user-images.githubusercontent.com/3182651/215946217-3705dbd1-4ec8-4aed-a9eb-381fecb2d8f2.png)
