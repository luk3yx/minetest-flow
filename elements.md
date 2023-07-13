# Auto-generated elements list

This is probably broken.

### `gui.AnimatedImage`

Equivalent to Minetest's `animated_image[]` element.

**Example**
```lua
gui.AnimatedImage {
    w = 1,
    h = 2,
    name = "my_animated_image", -- Optional
    texture_name = "texture.png",
    frame_count = 3,
    frame_duration = 4,
    frame_start = 5, -- Optional
    middle_x = 6, -- Optional
    middle_y = 7, -- Optional
    middle_x2 = 8, -- Optional
    middle_y2 = 9, -- Optional
}
```

### `gui.Box`

Equivalent to Minetest's `box[]` element.

**Example**
```lua
gui.Box {
    w = 1, -- Optional
    h = 2, -- Optional
    color = "#FF0000",
}
```

### `gui.Button`

Equivalent to Minetest's `button[]` element.

**Example**
```lua
gui.Button {
    w = 1, -- Optional
    h = 2, -- Optional
    name = "my_button", -- Optional
    label = "Hello world!",
}
```

### `gui.ButtonExit`

Equivalent to Minetest's `button_exit[]` element.

**Example**
```lua
gui.ButtonExit {
    w = 1, -- Optional
    h = 2, -- Optional
    name = "my_button_exit", -- Optional
    label = "Hello world!",
}
```

### `gui.Checkbox`

Equivalent to Minetest's `checkbox[]` element.

**Example**
```lua
gui.Checkbox {
    name = "my_checkbox", -- Optional
    label = "Hello world!",
    selected = false, -- Optional
}
```

### `gui.Dropdown`

Equivalent to Minetest's `dropdown[]` element.

**Example**
```lua
gui.Dropdown {
    w = 1, -- Optional
    h = 2, -- Optional
    name = "my_dropdown", -- Optional
    items = {"Hello world!", ...},
    selected_idx = 3,
    index_event = false, -- Optional
}
```

### `gui.Field`

Equivalent to Minetest's `field[]` element.

**Example**
```lua
gui.Field {
    w = 1, -- Optional
    h = 2, -- Optional
    name = "my_field", -- Optional
    label = "Hello world!",
    default = "Hello world!",
}
```

### `gui.Hypertext`

Equivalent to Minetest's `hypertext[]` element.

**Example**
```lua
gui.Hypertext {
    w = 1,
    h = 2,
    name = "my_hypertext", -- Optional
    text = "Hello world!",
}
```

### `gui.Image`

Equivalent to Minetest's `image[]` element.

**Example**
```lua
gui.Image {
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

Equivalent to Minetest's `image_button[]` element.

**Example**
```lua
gui.ImageButton {
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

Equivalent to Minetest's `image_button_exit[]` element.

**Example**
```lua
gui.ImageButtonExit {
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

Equivalent to Minetest's `item_image[]` element.

**Example**
```lua
gui.ItemImage {
    w = 1,
    h = 2,
    item_name = "Hello world!",
}
```

### `gui.ItemImageButton`

Equivalent to Minetest's `item_image_button[]` element.

**Example**
```lua
gui.ItemImageButton {
    w = 1,
    h = 2,
    item_name = "Hello world!",
    name = "my_item_image_button", -- Optional
    label = "Hello world!",
}
```

### `gui.Label`

Equivalent to Minetest's `label[]` element.

**Example**
```lua
gui.Label {
    label = "Hello world!",
}
```

### `gui.List`

Equivalent to Minetest's `list[]` element.

**Example**
```lua
gui.List {
    inventory_location = "Hello world!",
    list_name = "Hello world!",
    w = 1,
    h = 2,
    starting_item_index = 3, -- Optional
}
```

### `gui.Model`

Equivalent to Minetest's `model[]` element.

**Example**
```lua
gui.Model {
    w = 1,
    h = 2,
    name = "my_model", -- Optional
    mesh = "Hello world!",
    textures = {"texture.png", ...},
    rotation_x = 3, -- Optional
    rotation_y = 4, -- Optional
    continuous = false, -- Optional
    mouse_control = false, -- Optional
    frame_loop_begin = 5, -- Optional
    frame_loop_end = 6, -- Optional
    animation_speed = 7, -- Optional
}
```

### `gui.Pwdfield`

Equivalent to Minetest's `pwdfield[]` element.

**Example**
```lua
gui.Pwdfield {
    w = 1, -- Optional
    h = 2, -- Optional
    name = "my_pwdfield", -- Optional
    label = "Hello world!",
}
```

### `gui.Table`

Equivalent to Minetest's `table[]` element.

**Example**
```lua
gui.Table {
    w = 1, -- Optional
    h = 2, -- Optional
    name = "my_table", -- Optional
    cells = {"Hello world!", ...},
    selected_idx = 3,
}
```

### `gui.TableColumns`

Equivalent to Minetest's `tablecolumns[]` element.

**Example**
```lua
gui.TableColumns {
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

Equivalent to Minetest's `tableoptions[]` element.

**Example**
```lua
gui.TableOptions {
    opts = {field = "value"},
}
```

### `gui.Textarea`

Equivalent to Minetest's `textarea[]` element.

**Example**
```lua
gui.Textarea {
    w = 1, -- Optional
    h = 2, -- Optional
    name = "my_textarea", -- Optional
    label = "Hello world!",
    default = "Hello world!",
}
```

### `gui.Textlist`

Equivalent to Minetest's `textlist[]` element.

**Example**
```lua
gui.Textlist {
    w = 1, -- Optional
    h = 2, -- Optional
    name = "my_textlist", -- Optional
    listelems = {"Hello world!", ...},
    selected_idx = 3, -- Optional
    transparent = false, -- Optional
}
```

### `gui.Tooltip`

Equivalent to Minetest's `tooltip[]` element.

**Example**
```lua
gui.Tooltip {
    tooltip_text = "Hello world!",
    bgcolor = "#FF0000", -- Optional
    fontcolor = "#FF0000", -- Optional
    gui_element_name = "my_button",
}
```

### `gui.Vertlabel`

Equivalent to Minetest's `vertlabel[]` element.

**Example**
```lua
gui.Vertlabel {
    label = "Hello world!",
}
```