# Using a form as an inventory

> Consider using [Sway](https://content.luanti.org/packages/lazerbeak12345/sway/)
> instead if you want to use flow as an inventory replacement while still
> having some way for other mods to extend the inventory.

A form can be set as the player inventory. Flow internally generates the
formspec and passes it to `player:set_inventory_formspec()`. This will
completely replace your inventory and isn't compatible with inventory mods like
sfinv.

```lua
local example_inventory = flow.make_gui(function (player, context)
    return gui.Label{ label = "Inventory goes here!" }
end)
minetest.register_on_joinplayer(function(player)
    example_inventory:set_as_inventory_for(player)
end)
```

Like with the `show_hud` function, `update*` functions don't do anything, so to
update it, call `set_as_inventory_for` again with the new context. If the
context is not provided, it will reuse the existing context.

```lua
example_inventory:set_as_inventory_for(player, new_context)
```

While the form will of course be cleared when the player leaves, if you'd like
to unset the inventory manually, call `:unset_as_inventory_for(player)`,
analogue to `close_hud`:

```lua
example_inventory:unset_as_inventory_for(player)
```

This will set the inventory formspec string to `""` and stop flow from
processing inventory formspec input.
