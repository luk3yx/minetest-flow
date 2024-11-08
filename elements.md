# Auto-generated elements list

This is probably broken.

### `gui.AnimatedImage`

Equivalent to Luanti's `animated_image[]` element.

**Example**
```lua
gui.AnimatedImage{
    w = 1,
    h = 2,
    name = "my_animated_image", -- Optional

    -- The image to use.
    texture_name = "texture.png",

    -- The number of frames animating the image.
    frame_count = 3,

    -- Milliseconds between each frame. `0` means the frames don't advance.
    frame_duration = 4,

    -- The index of the frame to start on. Default `1`.
    frame_start = 5, -- Optional
    middle_x = 6, -- Optional
    middle_y = 7, -- Optional
    middle_x2 = 8, -- Optional
    middle_y2 = 9, -- Optional
}
```

### `gui.Box`

Equivalent to Luanti's `box[]` element.

**Example**
```lua
gui.Box{
    w = 1, -- Optional
    h = 2, -- Optional
    color = "#FF0000",
}
```

### `gui.Button`

Equivalent to Luanti's `button[]` element.

**Example**
```lua
gui.Button{
    w = 1, -- Optional
    h = 2, -- Optional
    name = "my_button", -- Optional
    label = "Hello world!",
}
```

### `gui.ButtonExit`

Equivalent to Luanti's `button_exit[]` element.

**Example**
```lua
gui.ButtonExit{
    w = 1, -- Optional
    h = 2, -- Optional
    name = "my_button_exit", -- Optional
    label = "Hello world!",
}
```

### `gui.ButtonURL`

Equivalent to Luanti's `button_url[]` element.

**Example**
```lua
gui.ButtonURL{
    w = 1, -- Optional
    h = 2, -- Optional
    name = "my_button_url", -- Optional
    label = "Hello world!",
    url = "Hello world!",
}
```

### `gui.ButtonUrlExit`

Equivalent to Luanti's `button_url_exit[]` element.

**Example**
```lua
gui.ButtonUrlExit{
    w = 1, -- Optional
    h = 2, -- Optional
    name = "my_button_url_exit", -- Optional
    label = "Hello world!",
    url = "Hello world!",
}
```

### `gui.Checkbox`

Equivalent to Luanti's `checkbox[]` element.

**Example**
```lua
gui.Checkbox{
    name = "my_checkbox", -- Optional
    label = "Hello world!",
    selected = false, -- Optional
}
```

### `gui.Dropdown`

Equivalent to Luanti's `dropdown[]` element.

**Example**
```lua
gui.Dropdown{
    w = 1, -- Optional
    h = 2, -- Optional
    name = "my_dropdown", -- Optional
    items = {"Hello world!", ...},
    selected_idx = 3,
    index_event = false, -- Optional
}
```

### `gui.Field`

Equivalent to Luanti's `field[]` element.

**Example**
```lua
gui.Field{
    w = 1, -- Optional
    h = 2, -- Optional
    name = "my_field", -- Optional
    label = "Hello world!",
    default = "Hello world!",

    -- Makes changing the field submit it on mobile devices.
    -- Requires a recent version of formspec_ast.
    enter_after_edit = false, -- Optional
}
```

### `gui.Hypertext`

Equivalent to Luanti's `hypertext[]` element.

**Example**
```lua
gui.Hypertext{
    w = 1,
    h = 2,
    name = "my_hypertext", -- Optional
    text = "Hello world!",
}
```

### `gui.Image`

Equivalent to Luanti's `image[]` element.

**Example**
```lua
gui.Image{
    w = 1,
    h = 2,
    texture_name = "texture.png",
    middle_x = 3, -- Optional
    middle_y = 4, -- Optional
    middle_x2 = 5, -- Optional
    middle_y2 = 6, -- Optional
}
```

### `gui.ImageButton`

Equivalent to Luanti's `image_button[]` element.

**Example**
```lua
gui.ImageButton{
    w = 1,
    h = 2,
    texture_name = "texture.png",
    name = "my_image_button", -- Optional
    label = "Hello world!",
    noclip = false, -- Optional
    drawborder = false, -- Optional
    pressed_texture_name = "texture.png", -- Optional
}
```

### `gui.ImageButtonExit`

Equivalent to Luanti's `image_button_exit[]` element.

**Example**
```lua
gui.ImageButtonExit{
    w = 1,
    h = 2,
    texture_name = "texture.png",
    name = "my_image_button_exit", -- Optional
    label = "Hello world!",
    noclip = false, -- Optional
    drawborder = false, -- Optional
    pressed_texture_name = "texture.png", -- Optional
}
```

### `gui.ItemImage`

Equivalent to Luanti's `item_image[]` element.

**Example**
```lua
gui.ItemImage{
    w = 1,
    h = 2,
    item_name = "Hello world!",
}
```

### `gui.ItemImageButton`

Equivalent to Luanti's `item_image_button[]` element.

**Example**
```lua
gui.ItemImageButton{
    w = 1,
    h = 2,
    item_name = "Hello world!",
    name = "my_item_image_button", -- Optional
    label = "Hello world!",
}
```

### `gui.Label`

Equivalent to Luanti's `label[]` element.

**Example**
```lua
gui.Label{
    label = "Hello world!",
}
```

### `gui.List`

Equivalent to Luanti's `list[]` element.

**Example**
```lua
gui.List{
    inventory_location = "Hello world!",
    list_name = "Hello world!",
    w = 1,
    h = 2,

    -- The index of the first (upper-left) item to draw.
    -- Indices start at `0`. Default is `0`.
    starting_item_index = 3, -- Optional
}
```

### `gui.Model`

Equivalent to Luanti's `model[]` element.

**Example**
```lua
gui.Model{
    w = 1,
    h = 2,
    name = "my_model", -- Optional

    -- The mesh model to use.
    mesh = "Hello world!",

    -- The mesh textures to use according to the mesh materials.
    textures = {"texture.png", ...},
    rotation_x = 3, -- Optional
    rotation_y = 4, -- Optional

    -- Whether the rotation is continuous. Default `false`.
    continuous = false, -- Optional

    -- Whether the model can be controlled with the mouse. Default `true`.
    mouse_control = false, -- Optional
    frame_loop_begin = 5, -- Optional
    frame_loop_end = 6, -- Optional

    -- Sets the animation speed. Default 0 FPS.
    animation_speed = 7, -- Optional
}
```

### `gui.Pwdfield`

Equivalent to Luanti's `pwdfield[]` element.

**Example**
```lua
gui.Pwdfield{
    w = 1, -- Optional
    h = 2, -- Optional
    name = "my_pwdfield", -- Optional
    label = "Hello world!",
}
```

### `gui.Table`

Equivalent to Luanti's `table[]` element.

**Example**
```lua
gui.Table{
    w = 1, -- Optional
    h = 2, -- Optional
    name = "my_table", -- Optional
    cells = {"Hello world!", ...},

    -- index of row to be selected within table (first row = `1`)
    selected_idx = 3,
}
```

### `gui.TableColumns`

Equivalent to Luanti's `tablecolumns[]` element.

**Example**
```lua
gui.TableColumns{
    tablecolumns = {
        {
            type = "text",
            opts = {field = "value"},
        },
        ...
    }
}
```

### `gui.TableOptions`

Equivalent to Luanti's `tableoptions[]` element.

**Example**
```lua
gui.TableOptions{
    opts = {field = "value"},
}
```

### `gui.Textarea`

Equivalent to Luanti's `textarea[]` element.

**Example**
```lua
gui.Textarea{
    w = 1, -- Optional
    h = 2, -- Optional
    name = "my_textarea", -- Optional
    label = "Hello world!",
    default = "Hello world!",
}
```

### `gui.Textlist`

Equivalent to Luanti's `textlist[]` element.

**Example**
```lua
gui.Textlist{
    w = 1, -- Optional
    h = 2, -- Optional
    name = "my_textlist", -- Optional
    listelems = {"Hello world!", ...},
    selected_idx = 3, -- Optional
    transparent = false, -- Optional
}
```

### `gui.Tooltip`

Equivalent to Luanti's `tooltip[]` element.

**Example**
```lua
gui.Tooltip{
    tooltip_text = "Hello world!",
    bgcolor = "#FF0000", -- Optional
    fontcolor = "#FF0000", -- Optional
    gui_element_name = "my_button",
}
```

### `gui.Vertlabel`

Equivalent to Luanti's `vertlabel[]` element.

**Example**
```lua
gui.Vertlabel{
    label = "Hello world!",
}
```