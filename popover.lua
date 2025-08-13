local align_types, apply_padding, get_and_fill_in_sizes, expand = ...

local function handle_popovers(box, node)
    local popover = node.popover
    if not popover then
        return
    end

    -- Copy popovers to their parent
    assert(node.type == "container" or node.type == "scroll_container",
        "Popovers are currently only supported on container elements")

    local offset_x, offset_y = node.x, node.y
    if not popover._flow_popover_root then
        local p_w, p_h = apply_padding(popover, 0, 0)
        local n_w, n_h = get_and_fill_in_sizes(node)

        if popover.anchor == "top" then
            offset_y = offset_y - p_h
        elseif popover.anchor == "left" then
            offset_x = offset_x - p_w
        elseif popover.anchor == "right" then
            offset_x = offset_x + n_w
        else
            offset_y = offset_y + n_h
        end

        if popover.anchor == "left" or popover.anchor == "right" then
            align_types[popover.align_v or "auto"](popover, "y", "h", n_h - p_h)
        else
            align_types[popover.align_h or "auto"](popover, "x", "w", n_w - p_w)
        end

        popover._flow_popover_root = true
    end

    if node.type == "scroll_container" then
        local ctx = flow.get_context()
        local offset = (ctx.form[node.scrollbar_name] or 0) *
            (node.scroll_factor or 0.1)
        if node.orientation == "horizontal" then
            offset_x = offset_x - offset
        else
            offset_y = offset_y - offset
        end
    end

    popover.x = popover.x + offset_x
    popover.y = popover.y + offset_y

    box.popover = popover
    box.on_close_popover = node.on_close_popover

    expand(popover)

    -- Reduce the impact of API misuse
    node.popover = nil
    node.on_close_popover = nil
end

return handle_popovers
