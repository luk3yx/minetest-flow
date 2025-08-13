--
-- Flow: Layout expansion/stretching pass
--
-- Copyright © 2022-2025 by luk3yx
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation, either version 2.1 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.
--

local DEFAULT_SPACING, LABEL_HEIGHT, apply_padding, get_and_fill_in_sizes,
    invisible_elems, modpath = ...
local align_types = {}

function align_types.fill(node, x, w, extra_space)
    -- Special cases
    if node.type == "list" or node.type == "checkbox" or node._label_hack then
        return align_types.centre(node, x, w, extra_space)
    elseif node.type == "label" then
        if x == "y" then
            node.y = node.y + extra_space / 2
            return
        end

        -- Hack
        node.type = "container"

        -- Reset bgimg, some games apply styling to all image_buttons inside
        -- the formspec prepend
        node[1] = {
            type = "style",
            -- MT 5.1.0 only supports one style selector
            selectors = {"_#"},

            -- bgimg_pressed is included for 5.1.0 support
            -- bgimg_hovered is unnecessary as it was added in 5.2.0 (which
            -- also adds support for :hovered and :pressed)
            props = {bgimg = "", bgimg_pressed = ""},
        }

        -- Use the newer pressed selector as well in case the deprecated one is
        -- removed
        node[2] = {
            type = "style",
            selectors = {"_#:hovered", "_#:pressed"},
            props = {bgimg = ""},
        }

        node[3] = {
            type = "image_button",
            texture_name = "blank.png",
            drawborder = false,
            x = 0, y = 0,
            w = node.w + extra_space, h = node.h,
            name = "_#", label = node.label,
            style = node.style,
        }

        -- Overlay button to prevent clicks from doing anything
        node[4] = {
            type = "image_button",
            texture_name = "blank.png",
            drawborder = false,
            x = 0, y = 0,
            w = node.w + extra_space, h = node.h,
            name = "_#", label = "",
        }

        node.y = node.y - (node._flow_font_height or LABEL_HEIGHT) / 2
        node.label = nil
        node.style = nil
        node._label_hack = true
        assert(#node == 4)
    end

    if node[w] then
        node[w] = node[w] + extra_space
    else
        core.log("warning", "[flow] Unknown element: \"" ..
            tostring(node.type) .. "\". Please make sure that flow is " ..
            "up-to-date and the element has a size set (if required).")
        node[w] = extra_space
    end
end

function align_types.start()
    -- No alterations required
end

-- "end" is a Lua keyword
align_types["end"] = function(node, x, _, extra_space)
    node[x] = node[x] + extra_space
end

-- Aliases for convenience
align_types.top, align_types.bottom = align_types.start, align_types["end"]
align_types.left, align_types.right = align_types.start, align_types["end"]

function align_types.centre(node, x, w, extra_space)
    if node.type == "label" then
        return align_types.fill(node, x, w, extra_space)
    elseif node.type == "checkbox" and x == "y" then
        node.y = (node.h + extra_space) / 2
        return
    end
    node[x] = node[x] + extra_space / 2
end

align_types.center = align_types.centre

-- Try to guess at what the best expansion setting is
local auto_align_centre = {
    image = true, animated_image = true, model = true, item_image_button = true
}
function align_types.auto(node, x, w, extra_space, cross)
    if auto_align_centre[node.type] then
        return align_types.centre(node, x, w, extra_space)
    end

    if x == "y" or (node.type ~= "label" and node.type ~= "checkbox") or
            (node.expand and not cross) then
        return align_types.fill(node, x, w, extra_space)
    end
end

local expand_child_boxes, handle_popovers
local function expand(box)
    local x, w, align_h, y, h, align_v
    local box_type = box.type
    if box_type == "hbox" then
        x, w, align_h, y, h, align_v = "x", "w", "align_h", "y", "h", "align_v"
    elseif box_type == "vbox" then
        x, w, align_h, y, h, align_v = "y", "h", "align_v", "x", "w", "align_h"
    elseif box_type == "stack" or
            (box_type == "padding" and box[1].expand) then
        box.type = "container"
        box._enable_bgimg_hack = true
        for _, node in ipairs(box) do
            if not invisible_elems[node.type] then
                local width, height = node.w or 0, node.h or 0
                if node.type == "list" then
                    width, height = get_and_fill_in_sizes(node)
                end
                local padding_x2 = (node.padding or 0) * 2
                align_types[node.align_h or "auto"](node, "x", "w", box.w -
                    width - padding_x2)
                align_types[node.align_v or "auto"](node, "y", "h", box.h -
                    height - padding_x2 - (node._padding_top or 0))
            end
        end
        return expand_child_boxes(box)
    elseif box_type == "container" or box_type == "scroll_container" then
        for _, node in ipairs(box) do
            if node.x == 0 and node.expand and box.w then
                node.w = box.w
            end
            expand(node)
            handle_popovers(box, node)
        end
        return
    elseif box_type == "padding" then
        box.type = "container"
        return expand_child_boxes(box)
    else
        return
    end

    box.type = "container"

    -- Calculate the amount of free space and put expand nodes into a table
    local box_h = box[h]
    local free_space = box[w]
    local expandable = {}
    local expand_count = 0
    local first = true
    for i, node in ipairs(box) do
        local width, height = node[w] or 0, node[h] or 0
        if not invisible_elems[node.type] then
            if first then
                first = false
            else
                free_space = free_space - (box.spacing or DEFAULT_SPACING)
            end

            if node.type == "list" then
                width, height = get_and_fill_in_sizes(node)
                if y == "x" then
                    width, height = height, width
                end
            end
            free_space = free_space - width - (node.padding or 0) * 2 -
                (y == "x" and node._padding_top or 0)

            if node.expand then
                expandable[node] = i
                expand_count = expand_count + 1
            elseif node.type == "label" and align_h == "align_h" then
                -- Use the image_button hack even if the label isn't expanded
                align_types[node.align_h or "auto"](node, "x", "w", 0)
            end

            -- Nodes are expanded in the other direction no matter what their
            -- expand setting is
            if box_h > height or (node.type == "label" and
                    align_v == "align_h") then
                align_types[node[align_v] or "auto"](node, y, h,
                    box_h - height - (node.padding or 0) * 2 -
                    (y == "y" and node._padding_top or 0), true)
            end
        end
    end

    -- If there's any free space then expand the nodes to fit
    if free_space > 0 then
        local extra_space = free_space / expand_count
        for node, node_idx in pairs(expandable) do
            align_types[node[align_h] or "auto"](node, x, w, extra_space)

            -- Shift other elements along
            for j = node_idx + 1, #box do
                if box[j][x] then
                    box[j][x] = box[j][x] + extra_space
                end
            end
        end
    elseif align_h == "align_h" then
        -- Use the image_button hack on labels regardless of the amount of free
        -- space if this is in a horizontal box.
        for node in pairs(expandable) do
            if node.type == "label" then
                align_types[node.align_h or "auto"](node, "x", "w", 0)
            end
        end
    end

    expand_child_boxes(box)
end

function expand_child_boxes(box)
    -- Recursively expand and remove any invisible nodes
    for i = #box, 1, -1 do
        local node = box[i]
        -- node.visible ~= nil and not node.visible
        if node.visible == false then
            -- There's no need to try and expand anything inside invisible
            -- nodes since it won't affect the overall size.
            table.remove(box, i)
        else
            expand(node)
        end

        handle_popovers(box, node)
    end
end

handle_popovers = assert(loadfile(modpath .. "/popover.lua"))(
    align_types, apply_padding, get_and_fill_in_sizes, expand
)

return expand
