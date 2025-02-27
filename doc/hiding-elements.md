# Hiding elements

Elements inside boxes can have `visible = false` set to hide them from the
player. Elements hidden this way will still take up space like with
`visibility: hidden;` in CSS.

## Example

```lua
gui.VBox{
    gui.Button{label = "First button"},
    gui.Button{label = "Hidden", visible = false},
    gui.Button{label = "Last button"},
}
```

## Alternatives

If you don't want hidden elements to take up any space, see the documentation
for [gui.Nil](layout-elements.md#guinil).
