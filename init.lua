--
-- Minetest formspec layout engine
--
-- Copyright © 2022 by luk3yx
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
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

local DEBUG_MODE = false
flow = {}
local S = minetest.get_translator("flow")

local Form = {}

local ceil, floor, min, max = math.ceil, math.floor, math.min, math.max

-- Estimates the width of a valid UTF-8 string, ignoring any escape sequences.
-- This function hopefully works with most (but not all) scripts, maybe it
-- could still be improved.
local byte = string.byte
local LPAREN = byte("(")
local function naive_str_width(str)
    local w = 0
    local prev_w = 0
    local line_count = 1
    local i = 1
    local str_length = #str
    while i <= str_length do
        local char = byte(str, i)
        if char == 0x1b then
            -- Ignore escape sequences
            i = i + 1
            if byte(str, i) == LPAREN then
                i = str:find(")", i + 1, true) or str_length
            end
        elseif char == 0xe1 then
            if (byte(str, i + 1) or 0) < 0x84 then
                -- U+1000 - U+10FF
                w = w + 1
            else
                -- U+1100 - U+2000
                w = w + 2
            end
            i = i + 2
        elseif char > 0xe1 and char < 0xf5 then
            -- U+2000 - U+10FFFF
            w = w + 2
            i = i + 2
        elseif char == 0x0a then
            -- Newlines: Reset the width and increase the line count
            prev_w = max(prev_w, w)
            w = 0
            line_count = line_count + 1
        elseif char < 0x80 or char > 0xbf then
            -- Everything except UTF-8 continuation sequences
            w = w + 1
        end
        i = i + 1
    end
    return max(w, prev_w), line_count
end

local LABEL_HEIGHT = 0.4
local LABEL_OFFSET = LABEL_HEIGHT / 2
local CHAR_WIDTH = 0.21

-- The "current_lang" variable isn't ideal but means that the language will be
-- known inside ScrollableVBox etc
local current_lang

-- get_translated_string doesn't exist in MT 5.2.0 and older
local get_translated_string = minetest.get_translated_string or function(_, s)
    return s
end

local function get_lines_size(lines)
    local w = 0
    for _, line in ipairs(lines) do
        -- Translate the string if necessary
        if current_lang and current_lang ~= "" and current_lang ~= "en" then
            line = get_translated_string(current_lang, line)
        end

        w = max(w, naive_str_width(line) * CHAR_WIDTH)
    end
    return w, LABEL_HEIGHT * #lines
end

local function get_label_size(label)
    label = label or ""
    if current_lang and current_lang ~= "" and current_lang ~= "en" then
        label = get_translated_string(current_lang, label)
    end

    local longest_line_width, line_count = naive_str_width(label)
    return longest_line_width * CHAR_WIDTH, line_count * LABEL_HEIGHT
end

local size_getters = {}

local function get_and_fill_in_sizes(node)
    if node.type == "list" then
        return node.w * 1.25 - 0.25, node.h * 1.25 - 0.25
    end

    if node.w and node.h then
        return node.w, node.h
    end

    local f = size_getters[node.type]
    if not f then return 0, 0 end

    local w, h = f(node)
    node.w = node.w or max(w, node.min_w or 0)
    node.h = node.h or max(h, node.min_h or 0)
    return node.w, node.h
end

function size_getters.container(node)
    local w, h = 0, 0
    for _, n in ipairs(node) do
        local w2, h2 = get_and_fill_in_sizes(n)
        w = max(w, (n.x or 0) + w2)
        h = max(h, (n.y or 0) + h2)
    end
    return w, h
end
size_getters.scroll_container = size_getters.container

function size_getters.label(node)
    local w, h = get_label_size(node.label)
    return w, LABEL_HEIGHT + (h - LABEL_HEIGHT) * 1.25
end

local MIN_BUTTON_HEIGHT = 0.8
function size_getters.button(node)
    local x, y = get_label_size(node.label)
    return max(x, MIN_BUTTON_HEIGHT * 2), max(y, MIN_BUTTON_HEIGHT)
end

size_getters.button_exit = size_getters.button
size_getters.image_button = size_getters.button
size_getters.image_button_exit = size_getters.button
size_getters.item_image_button = size_getters.button

function size_getters.field(node)
    local label_w, label_h = get_label_size(node.label)

    -- This is done in apply_padding as well but the label size has already
    -- been calculated here
    if not node._padding_top and node.label and #node.label > 0 then
        node._padding_top = label_h
    end

    local w, h = get_label_size(node.default)
    return max(w, label_w, 3), max(h, MIN_BUTTON_HEIGHT)
end
size_getters.pwdfield = size_getters.field
size_getters.textarea = size_getters.field

function size_getters.vertlabel(node)
    return CHAR_WIDTH, #node.label * LABEL_HEIGHT
end

function size_getters.textlist(node)
    local w, h = get_lines_size(node.listelems)
    return w, h * 1.1
end

function size_getters.dropdown(node)
    return max(get_lines_size(node.items) + 0.3, 2), MIN_BUTTON_HEIGHT
end

function size_getters.checkbox(node)
    local w, h = get_label_size(node.label)
    return w + 0.4, h
end

local field_elems = {field = true, pwdfield = true, textarea = true}

local function apply_padding(node, x, y)
    local w, h = get_and_fill_in_sizes(node)

    -- Labels are positioned from the centre of the first line and checkboxes
    -- are positioned from the centre.
    if node.type == "label" then
        y = y + LABEL_OFFSET
    elseif node.type == "checkbox" then
        y = y + h / 2
    elseif field_elems[node.type] and not node._padding_top and node.label and
            #node.label > 0 then
        -- Add _padding_top to fields with labels that have a fixed size set
        local _, label_h = get_label_size(node.label)
        node._padding_top = label_h
    elseif node.type == "tabheader" and w > 0 and h > 0 then
        -- Handle tabheader if the width and height are set
        -- I'm not sure what to do with tabheaders that don't have a width or
        -- height set.
        y = y + h
    end

    if node._padding_top then
        y = y + node._padding_top
        h = h + node._padding_top
    end

    local padding = node.padding
    if padding then
        x = x + padding
        y = y + padding
        w = w + padding * 2
        h = h + padding * 2
    end

    node.x, node.y = x, y
    return w, h
end

local invisible_elems = {
    style = true, listring = true, scrollbaroptions = true, tableoptions = true,
    tablecolumns = true, tooltip = true, style_type = true, set_focus = true,
}

local DEFAULT_SPACING = 0.2
function size_getters.vbox(vbox)
    local spacing = vbox.spacing or DEFAULT_SPACING
    local width = 0
    local y = 0
    for _, node in ipairs(vbox) do
        if not invisible_elems[node.type] then
            if y > 0 then
                y = y + spacing
            end

            local w, h = apply_padding(node, 0, y)
            width = max(width, w)
            y = y + h
        end
    end

    return width, y
end

function size_getters.hbox(hbox)
    local spacing = hbox.spacing or DEFAULT_SPACING
    local x = 0
    local height = 0
    for _, node in ipairs(hbox) do
        if not invisible_elems[node.type] then
            if x > 0 then
                x = x + spacing
            end

            local w, h = apply_padding(node, x, 0)
            height = max(height, h)
            x = x + w
        end
    end

    return x, height
end

function size_getters.stack(stack)
    local width, height = 0, 0
    for _, node in ipairs(stack) do
        if not invisible_elems[node.type] then
            local w, h = apply_padding(node, 0, 0)
            width = max(width, w)
            height = max(height, h)
        end
    end

    return width, height
end

function size_getters.padding(node)
    minetest.log("warning", "[flow] The gui.Padding element is deprecated")
    assert(#node == 1, "Padding can only have one element inside.")
    local n = node[1]
    local x, y = apply_padding(n, 0, 0)
    if node.expand == nil then
        node.expand = n.expand
    end
    return x, y
end

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
            selectors = {"\1"},

            -- bgimg_pressed is included for 5.1.0 support
            -- bgimg_hovered is unnecessary as it was added in 5.2.0 (which
            -- also adds support for :hovered and :pressed)
            props = {bgimg = "", bgimg_pressed = ""},
        }

        -- Use the newer pressed selector as well in case the deprecated one is
        -- removed
        node[2] = {
            type = "style",
            selectors = {"\1:hovered", "\1:pressed"},
            props = {bgimg = ""},
        }

        node[3] = {
            type = "image_button",
            texture_name = "blank.png",
            drawborder = false,
            x = 0, y = 0,
            w = node.w + extra_space, h = node.h,
            name = "\1", label = node.label,
        }

        -- Overlay button to prevent clicks from doing anything
        node[4] = {
            type = "image_button",
            texture_name = "blank.png",
            drawborder = false,
            x = 0, y = 0,
            w = node.w + extra_space, h = node.h,
            name = "\1", label = "",
        }

        node.y = node.y - LABEL_OFFSET
        node.label = nil
        node._label_hack = true
        assert(#node == 4)
    end

    if node[w] then
        node[w] = node[w] + extra_space
    else
        minetest.log("warning", "[flow] Unknown element: \"" ..
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

local expand_child_boxes
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
                    width = width * 1.25 - 0.25
                    height = height * 1.25 - 0.25
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
                width = width * 1.25 - 0.25
                height = height * 1.25 - 0.25
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
    end
end

-- Renders the GUI into hopefully valid AST
-- This won't fill in names
local function render_ast(node, embedded)
    local t1 = DEBUG_MODE and minetest.get_us_time()
    node.padding = node.padding or 0.3
    local w, h = apply_padding(node, 0, 0)
    local t2 = DEBUG_MODE and minetest.get_us_time()
    expand(node)
    local t3 = DEBUG_MODE and minetest.get_us_time()
    local res = {
        formspec_version = 6,
        {type = "size", w = w, h = h},
    }

    -- TODO: Consider a nicer place to put these parameters
    if node.no_prepend and not embedded then
        res[#res + 1] = {type = "no_prepend"}
    end
    if node.fbgcolor or node.bgcolor or node.bg_fullscreen ~= nil then
        -- Hack to prevent breaking mods that rely on the old (broken)
        -- behaviour of fbgcolor
        if node.fbgcolor == "#08080880" and node.bgcolor == nil and
                node.bg_fullscreen == nil then
            node.bg_fullscreen = true
            node.fbgcolor = nil
        end

        res[#res + 1] = {
            type = "bgcolor",
            bgcolor = node.bgcolor,
            fbgcolor = node.fbgcolor,
            fullscreen = node.bg_fullscreen
        }
        node.bgcolor = nil
        node.fbgcolor = nil
        node.bg_fullscreen = nil
    end

    for field in formspec_ast.find(node, 'field') do
        res[#res + 1] = {
            type = 'field_close_on_enter',
            name = field.name,
            close_on_enter = false,
        }
    end

    -- Add the root element's background image as a fullscreen one
    if node.bgimg and not embedded then
        res[#res + 1] = {
            type = node.bgimg_middle and "background9" or "background",
            texture_name = node.bgimg, middle_x = node.bgimg_middle,
            x = 0, y = 0, w = 0, h = 0, auto_clip = true,
        }
        node.bgimg = nil
    end

    res[#res + 1] = node

    if DEBUG_MODE then
        local t4 = minetest.get_us_time()
        print('apply_padding', t2 - t1)
        print('expand', t3 - t2)
        print('field_close_on_enter', t4 - t3)
    end
    return res
end

local function chain_cb(f1, f2)
    return function(...)
        f1(...)
        f2(...)
    end
end

local function range_check_transformer(items_length)
    return function(value)
        local num = tonumber(value)
        if num and num == num then
            num = floor(num)
            if num >= 1 and num <= items_length then
                return num
            end
        end
    end
end

local function simple_transformer(func)
    return function() return func end
end

-- Functions that transform field values into the easiest to use type
local C1_CHARS = "\194[\128-\159]"
local field_value_transformers = {
    field = simple_transformer(function(value)
        -- Remove control characters and newlines
        return value:gsub("[%z\1-\8\10-\31\127]", ""):gsub(C1_CHARS, "")
    end),
    checkbox = simple_transformer(minetest.is_yes),

    -- Scrollbars do have min/max values but scrollbars are only really used by
    -- ScrollableVBox which doesn't need the extra checks
    scrollbar = simple_transformer(function(value)
        return minetest.explode_scrollbar_event(value).value
    end),
}

-- Field value transformers that depend on some property of the element
function field_value_transformers.tabheader(node)
    return range_check_transformer(node.captions and #node.captions or 0)
end

function field_value_transformers.dropdown(node)
    local items = node.items or {}
    if node.index_event then
        return range_check_transformer(#items)
    end

    -- Make sure that the value sent by the client is in the list of items
    return function(value)
        if table.indexof(items, value) > 0 then
            return value
        end
    end
end

function field_value_transformers.table(node, tablecolumn_count)
    -- Figure out how many rows the table has
    local cells = node.cells and #node.cells or 0
    local rows = ceil(cells / tablecolumn_count)

    return function(value)
        local row = floor(minetest.explode_table_event(value).row)
        -- Tables and textlists can have values of 0 (nothing selected) but I
        -- don't think the client can un-select a row so it should be safe to
        -- ignore any 0 sent by the client to guarantee that the row will be
        -- valid if the default value is valid
        if row >= 1 and row <= rows then
            return row
        end
    end
end

function field_value_transformers.textlist(node)
    local rows = node.listelems and #node.listelems or 0
    return function(value)
        local index = floor(minetest.explode_textlist_event(value).index)
        if index >= 1 and index <= rows then
            return index
        end
    end
end

local function default_field_value_transformer(value)
    -- Remove control characters (but preserve newlines)
    -- Pattern by https://github.com/appgurueu
    return value:gsub("[%z\1-\8\11-\31\127]", ""):gsub(C1_CHARS, "")
end

local default_value_fields = {
    field = "default",
    textarea = "default",
    checkbox = "selected",
    dropdown = "selected_idx",
    table = "selected_idx",
    textlist = "selected_idx",
    scrollbar = "value",
    tabheader = "current_tab",
}

local sensible_defaults = {
    default = "", selected = false, selected_idx = 1, value = 0,
}

local button_types = {
    button = true, image_button = true, item_image_button = true,
    button_exit = true, image_button_exit = true
}

-- Removes on_event from a formspec_ast tree and returns a callbacks table
local function parse_callbacks(tree, ctx_form, auto_name_id,
        replace_backgrounds)
    local callbacks
    local btn_callbacks = {}
    local saved_fields = {}
    local tablecolumn_count = 1
    for node in formspec_ast.walk(tree) do
        if node.type == "container" then
            if node.bgcolor then
                local padding = node.padding or 0
                table.insert(node, 1, {
                    type = "box", color = node.bgcolor,
                    x = -padding, y = -padding,
                    w = node.w + padding * 2, h = node.h + padding * 2,
                })
            end
            if node.bgimg then
                local padding = node.padding or 0
                table.insert(node, 1, {
                    type = node.bgimg_middle and "background9" or "background",
                    texture_name = node.bgimg, middle_x = node.bgimg_middle,
                    x = -padding, y = -padding,
                    w = node.w + padding * 2, h = node.h + padding * 2,
                })
            end

            -- The on_quit callback is undocumented and not recommended, it
            -- only gets called when the client tells the server that it's
            -- closing the form and not when another form is shown.
            if node.on_quit then
                callbacks = callbacks or {}
                if callbacks.quit then
                    -- HACK
                    callbacks.quit = chain_cb(callbacks.quit, node.on_quit)
                else
                    callbacks.quit = node.on_quit
                end
            end
            replace_backgrounds = replace_backgrounds or node._enable_bgimg_hack
        elseif node.type == "tablecolumns" and node.tablecolumns then
            -- Store the amount of columns for input validation
            tablecolumn_count = max(#node.tablecolumns, 1)
        elseif replace_backgrounds then
            if (node.type == "background" or node.type == "background9") and
                    not node.auto_clip then
                node.type = "image"
            end
        elseif node.type == "scroll_container" then
            -- Work around a Minetest bug with scroll containers not scrolling
            -- backgrounds.
            replace_backgrounds = true
        end

        local node_name = node.name
        if node_name and node_name ~= "" then
            local value_field = default_value_fields[node.type]
            if value_field then
                -- Add the corresponding value transformer transformer to
                -- saved_fields
                saved_fields[node_name] = (
                    field_value_transformers[node.type] or
                    default_field_value_transformer
                )

                -- Update ctx.form if there is no current value, otherwise
                -- change the node's value to the saved one.
                local value = ctx_form[node_name]
                if node.type == "dropdown" and not node.index_event then
                    -- Special case for dropdowns without index_event
                    local items = node.items or {}
                    if value == nil then
                        ctx_form[node_name] = items[node.selected_idx or 1]
                    else
                        local idx = table.indexof(items, value)
                        if idx > 0 then
                            node.selected_idx = idx
                        end
                    end

                    node.selected_idx = node.selected_idx or 1
                elseif value == nil then
                    -- If ctx.form[node_name] doesn't exist, then check whether
                    -- a default value is specified.
                    local default_value = node[value_field]
                    local sensible_default = sensible_defaults[value_field]
                    if default_value == nil then
                        -- If the element doesn't have a default set, set it to
                        -- the sensible default value and update ctx.form in
                        -- case the client doesn't send the field value back.
                        node[value_field] = sensible_default
                        ctx_form[node_name] = sensible_default
                    else
                        -- Update ctx.form to the default value
                        ctx_form[node_name] = default_value
                    end
                else
                    -- Set the node's value to the one saved in ctx.form
                    node[value_field] = value
                end

                local get_transformer = field_value_transformers[node.type]
                saved_fields[node_name] = get_transformer and
                    get_transformer(node, tablecolumn_count) or
                    default_field_value_transformer
            end
        end

        -- Add the on_event callback (if any) to the callbacks table
        if node.on_event then
            local is_btn = button_types[node.type]
            if not node_name then
                node_name = ("\1%x"):format(auto_name_id)
                node.name = node_name
                auto_name_id = auto_name_id + 1
            elseif btn_callbacks[node_name] or
                    (is_btn and saved_fields[node_name]) or
                    (callbacks and callbacks[node_name]) then
                minetest.log("warning", ("[flow] Multiple callbacks have " ..
                    "been registered for elements with the same name (%q), " ..
                    "this will not work properly."):format(node_name))

                -- Preserve previous behaviour
                btn_callbacks[node_name] = nil
                if callbacks then
                    callbacks[node_name] = nil
                end
                is_btn = is_btn and not saved_fields[node_name]
            end

            -- Put buttons into a separate callback table so that malicious
            -- clients can't send multiple button presses in one submission
            if is_btn then
                btn_callbacks[node_name] = node.on_event
            else
                callbacks = callbacks or {}
                callbacks[node_name] = node.on_event
            end
            node.on_event = nil
        end

        -- Call _after_positioned (used internally for ScrollableVBox)
        if node._after_positioned then
            node:_after_positioned()
            node._after_positioned = nil
        end
    end
    return callbacks, btn_callbacks, saved_fields, auto_name_id
end

local gui_mt = {
    __index = function(gui, k)
        local elem_type = k
        if elem_type ~= "ScrollbarOptions" and elem_type ~= "TableOptions" and
                elem_type ~= "TableColumns" then
            elem_type = elem_type:gsub("([a-z])([A-Z])", function(a, b)
                return a .. "_" .. b
            end)
        end
        elem_type = elem_type:lower()
        local function f(t)
            t.type = elem_type
            return t
        end
        rawset(gui, k, f)
        return f
    end,
}
local gui = setmetatable({
    embed = function(fs, w, h)
        minetest.log("warning", "[flow] gui.embed() is deprecated")
        if type(fs) ~= "table" then
            fs = formspec_ast.parse(fs)
        end
        fs.type = "container"
        fs.w = w
        fs.h = h
        return fs
    end,
    formspec_version = 0,
}, gui_mt)
flow.widgets = gui

local current_ctx
function flow.get_context()
    if not current_ctx then
        error("get_context() was called outside of a GUI function!", 2)
    end
    return current_ctx
end


-- Renders a GUI into a formspec_ast tree and a table with callbacks.
function Form:_render(player, ctx, formspec_version, id1, embedded, lang_code)
    local used_ctx_vars = {}
    current_lang = lang_code

    -- Wrap ctx.form
    local orig_form = ctx.form or {}
    local wrapped_form = setmetatable({}, {
        __index = function(_, key)
            used_ctx_vars[key] = true
            return orig_form[key]
        end,
        __newindex = orig_form,
    })
    ctx.form = wrapped_form

    gui.formspec_version = formspec_version or 0
    current_ctx = ctx
    local box = self._build(player, ctx)
    current_ctx = nil
    gui.formspec_version = 0

    -- Restore the original ctx.form
    assert(ctx.form == wrapped_form,
        "Changing the value of ctx.form is not supported!")
    ctx.form = orig_form

    -- The numbering of automatically named elements is continued from previous
    -- iterations of the form to work around race conditions
    if not id1 or id1 > 1e6 then id1 = 0 end

    local tree = render_ast(box, embedded)
    local callbacks, btn_callbacks, saved_fields, id2 = parse_callbacks(
        tree, orig_form, id1, embedded
    )

    local redraw_if_changed = {}
    for var in pairs(used_ctx_vars) do
        -- Only add it if there is no callback and the name exists in the
        -- formspec.
        if saved_fields[var] and (not callbacks or not callbacks[var]) then
            redraw_if_changed[var] = true
        end
    end

    current_lang = nil

    return tree, {
        self = self,
        callbacks = callbacks,
        btn_callbacks = btn_callbacks,
        saved_fields = saved_fields,
        redraw_if_changed = redraw_if_changed,
        ctx = ctx,
        auto_name_id = id2,
    }
end

local function prepare_form(self, player, formname, ctx, auto_name_id)
    local name = player:get_player_name()
    -- local t = DEBUG_MODE and minetest.get_us_time()
    local info = minetest.get_player_information(name)
    local tree, form_info = self:_render(player, ctx,
        info and info.formspec_version, auto_name_id, false,
        info and info.lang_code)

    -- local t2 = DEBUG_MODE and minetest.get_us_time()
    local fs = assert(formspec_ast.unparse(tree))
    -- local t3 = DEBUG_MODE and minetest.get_us_time()

    form_info.formname = formname
    -- if DEBUG_MODE then
    --     print(t3 - t, t2 - t, t3 - t2)
    -- end
    return fs, form_info
end

local open_formspecs = {}
local function show_form(self, player, formname, ctx, auto_name_id)
    local name = player:get_player_name()
    local fs, form_info = prepare_form(self, player, formname, ctx,
        auto_name_id)

    open_formspecs[name] = form_info
    minetest.show_formspec(name, formname, fs)
end

local next_formname = 0
function Form:show(player, ctx)
    if type(player) == "string" then
        minetest.log("warning",
            "[flow] Calling form:show() with a player name is deprecated")
        player = minetest.get_player_by_name(player)
        if not player then return end
    end

    -- Use a unique form name every time a new form is shown
    show_form(self, player, ("flow:%x"):format(next_formname), ctx or {})

    -- Form name collisions are theoretically possible but probably won't
    -- happen in practice (and if they do the impact will be minimal)
    next_formname = (next_formname + 1) % 2^53
end

function Form:show_hud(player, ctx)
    local info = minetest.get_player_information(player:get_player_name())
    local tree = self:_render(player, ctx or {}, nil, nil, nil,
        info and info.lang_code)
    hud_fs.show_hud(player, self, tree)
end

local open_inv_formspecs = {}
function Form:set_as_inventory_for(player, ctx)
    local name = player:get_player_name()
    local old_form_info = open_inv_formspecs[name]
    if not ctx and old_form_info and old_form_info.self == self then
        ctx = old_form_info.ctx
    end

    -- Formname of "" is inventory
    local fs, form_info = prepare_form(self, player, "", ctx or {},
        old_form_info and old_form_info.auto_name_id)

    open_inv_formspecs[name] = form_info
    player:set_inventory_formspec(fs)
end

-- Declared here to be accessible by render_to_formspec_string
local fs_process_events

-- Prevent collisions in forms, but also ensure they don't happen across
-- mutliple embedded forms within a single parent.
-- Unique per-user to prevent players from making the counter wrap around for
-- other players.
local render_to_formspec_auto_name_ids = {}
-- If `standalone` is set, this will return a standalone formspec, otherwise it
-- will return a formspec that can be embedded and a table with its size and
-- target formspec version
function Form:render_to_formspec_string(player, ctx, standalone)
    local name = player:get_player_name()
    local info = minetest.get_player_information(name)
    local tree, form_info = self:_render(player, ctx or {},
        info and info.formspec_version, render_to_formspec_auto_name_ids[name],
        not standalone, info and info.lang_code)
    local public_form_info
    if not standalone then
        local size = table.remove(tree, 1)
        public_form_info = {w = size.w, h = size.h,
            formspec_version = tree.formspec_version}
        tree.formspec_version = nil
    end
    local fs = assert(formspec_ast.unparse(tree))
    render_to_formspec_auto_name_ids[name] = form_info.auto_name_id
    local function event(fields)
        -- Just in case the player goes offline, we should not keep the player
        -- reference. Nothing prevents the user from calling this function when
        -- the player is offline, unlike the _real_ formspec submission.
        local player = minetest.get_player_by_name(name)
        if not player then
            minetest.log("warning", "[flow] Player " .. name ..
                " was offline when render_to_formspec_string event was" ..
                " triggered. Events were not passed through.")
            return nil
        end
        return fs_process_events(player, form_info, fields)
    end
    return fs, event, public_form_info
end

function Form:close(player)
    local name = player:get_player_name()
    local form_info = open_formspecs[name]
    if form_info and form_info.self == self then
        open_formspecs[name] = nil
        minetest.close_formspec(name, form_info.formname)
    end
end

function Form:close_hud(player)
    hud_fs.close_hud(player, self)
end

function Form:unset_as_inventory_for(player)
    local name = player:get_player_name()
    local form_info = open_inv_formspecs[name]
    if form_info and form_info.self == self then
        open_inv_formspecs[name] = nil
        player:set_inventory_formspec("")
    end
end

-- This function may eventually call minetest.update_formspec if/when it gets
-- added (https://github.com/minetest/minetest/issues/13142)
local function update_form(self, player, form_info)
    show_form(self, player, form_info.formname, form_info.ctx,
        form_info.auto_name_id)
end

function Form:update(player)
    local form_info = open_formspecs[player:get_player_name()]
    if form_info and form_info.self == self then
        update_form(self, player, form_info)
    end
end

function Form:update_where(func)
    for name, form_info in pairs(open_formspecs) do
        if form_info.self == self then
            local player = minetest.get_player_by_name(name)
            if player and func(player, form_info.ctx) then
                update_form(self, player, form_info)
            end
        end
    end
end

local form_mt = {__index = Form}
function flow.make_gui(build_func)
    return setmetatable({_build = build_func}, form_mt)
end

-- Declared locally above to be accessible to render_to_formspec_string
function fs_process_events(player, form_info, fields)
    local callbacks = form_info.callbacks
    local btn_callbacks = form_info.btn_callbacks
    local ctx = form_info.ctx
    local redraw_if_changed = form_info.redraw_if_changed
    local ctx_form = ctx.form

    -- Update the context before calling any callbacks
    local redraw_fs = false
    for field, transformer in pairs(form_info.saved_fields) do
        local raw_value = fields[field]
        if raw_value then
            if #raw_value > 60000 then
                -- There's probably no legitimate reason for a client send a
                -- large amount of data and very long strings have the
                -- potential to break things. Please open an issue if you
                -- (somehow) need to use longer text in fields.
                local name = player:get_player_name()
                minetest.log("warning", "[flow] Player " .. name .. " tried" ..
                    " submitting a large field value (>60 kB), ignoring.")
            else
                local new_value = transformer(raw_value)
                if new_value ~= nil then
                    if ctx_form[field] ~= new_value then
                        if redraw_if_changed[field] then
                            redraw_fs = true
                        elseif form_info.formname == "" then
                            -- Update the inventory when the player closes it
                            form_info.ctx_form_modified = true
                        end
                    end
                    ctx_form[field] = new_value
                end
            end
        end
    end

    -- Run on_event callbacks
    -- The callbacks table may be nil as adding callbacks to non-buttons is
    -- likely uncommon (so allocating an empty table would be useless)
    if callbacks then
        for field in pairs(fields) do
            if callbacks[field] and callbacks[field](player, ctx) then
                redraw_fs = true
            end
        end
    end

    -- Run button callbacks after all other callbacks as that seems to be the
    -- most intuitive thing to do
    -- Note: Try not to rely on the order of on_event callbacks, I may change
    -- it in the future.
    for field in pairs(fields) do
        if btn_callbacks[field] then
            redraw_fs = btn_callbacks[field](player, ctx) or redraw_fs

            -- Only run a single button callback
            break
        end
    end

    return redraw_fs
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    local name = player:get_player_name()
    local form_infos = formname == "" and open_inv_formspecs or open_formspecs
    local form_info = form_infos[name]
    if not form_info or formname ~= form_info.formname then return end

    local redraw_fs = fs_process_events(player, form_info, fields)

    if form_infos[name] ~= form_info then return true end

    if formname == "" then
        -- Special case for inventory forms
        if redraw_fs or (fields.quit and form_info.ctx_form_modified) then
            form_info.self:set_as_inventory_for(player)
        end
    elseif fields.quit then
        open_formspecs[name] = nil
    elseif redraw_fs then
        update_form(form_info.self, player, form_info)
    end
    return true
end)

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    open_formspecs[name] = nil
    open_inv_formspecs[name] = nil
    render_to_formspec_auto_name_ids[name] = nil
end)

-- Extra GUI elements

-- Please don't modify the gui table in your own code
function gui.PaginatedVBox(def)
    local w, h = def.w, def.h
    def.w, def.h = nil, nil
    local paginator_name = "_paginator-" .. assert(def.name)

    def.type = "vbox"
    local inner_w, inner_h = get_and_fill_in_sizes(def)
    h = h or min(inner_h, 5)

    local ctx = flow.get_context()

    -- Build a list of pages
    local page = {}
    local pages = {page}
    local max_y = h
    for _, node in ipairs(def) do
        if node.y and node.y + (node.h or 0) > max_y then
            -- Something overflowed, go to a new page
            page = {}
            pages[#pages + 1] = page
            max_y = node.y + h
        end

        -- Add to the current page
        node.x, node.y = nil, nil
        page[#page + 1] = node
    end

    -- Get the current page
    local current_page = ctx.form[paginator_name] or 1
    if current_page > #pages then
        current_page = #pages
        ctx.form[paginator_name] = current_page
    end

    page = pages[current_page] or {}
    page.h = h

    return gui.VBox {
        min_w = w or inner_w,
        gui.VBox(page),
        gui.HBox {
            gui.Button {
                label = "<",
                on_event = function(_, ctx)
                    ctx.form[paginator_name] = max(current_page - 1, 1)
                    return true
                end,
            },
            gui.Label {
                label = S("Page @1 of @2", current_page, #pages),
                align_h = "centre",
                expand = true,
            },
            gui.Button {
                label = ">",
                on_event = function(_, ctx)
                    ctx.form[paginator_name] = current_page + 1
                    return true
                end,
            },
        }
    }
end

function gui.ScrollableVBox(def)
    -- On older clients fall back to a paginated vbox
    if gui.formspec_version < 4 then
        return gui.PaginatedVBox(def)
    end

    local w, h = def.w, def.h
    local scrollbar_name = "_scrollbar-" .. assert(
        def.name, "Please provide a name for all ScrollableVBox elements!"
    )
    local align_h, align_v, expand_box = def.align_h, def.align_v, def.expand

    def.type = "vbox"
    def.x, def.y = 0, 0
    def.w, def.h = nil, nil
    local inner_w, inner_h = get_and_fill_in_sizes(def)
    def.w = w or inner_w
    def.expand = true
    h = h or min(inner_h, 5)

    local scrollbar = {
        w = 0.5, h = 0.5, orientation = "vertical",
        name = scrollbar_name,
    }

    -- Allow properties of the scrollbar (such as the width) to be overridden
    if def.custom_scrollbar then
        for k, v in pairs(def.custom_scrollbar) do
            scrollbar[k] = v
        end
    end

    local opts = {}
    return gui.HBox {
        align_h = align_h,
        align_v = align_v,
        expand = expand_box,

        gui.ScrollContainer{
            expand = true,
            w = w or inner_w,
            h = h,
            scrollbar_name = scrollbar_name,
            orientation = "vertical",
            def,

            -- Calculate the scrollbar maximum after the scroll container is
            -- expanded
            _after_positioned = function(self)
                opts.max = max(inner_h - self.h + 0.05, 0) * 10
                opts.thumbsize = (self.h / inner_h) * (inner_h - self.h) * 10
            end,
        },
        gui.ScrollbarOptions{opts = opts},
        gui.Scrollbar(scrollbar)
    }
end

function gui.Flow(def)
    local vbox = {
        type = "vbox",
        bgcolor = def.bgcolor,
        bgimg = def.bgimg,
        align_h = "centre",
        align_v = "centre",
    }
    local width = assert(def.w)

    local spacing = def.spacing or DEFAULT_SPACING
    local line = {spacing = spacing}
    for _, node in ipairs(def) do
        local w = get_and_fill_in_sizes(node)
        if w > width then
            width = def.w
            vbox[#vbox + 1] = gui.HBox(line)
            line = {spacing = spacing}
        end
        line[#line + 1] = node
        width = width - w - spacing
    end
    vbox[#vbox + 1] = gui.HBox(line)
    return vbox
end

function gui.Spacer(def)
    def.type = "container"
    assert(#def == 0)

    -- Spacers default to expanding
    if def.expand == nil then
        def.expand = true
    end

    -- Prevent an empty container from being added to the resulting form
    def.visible = false

    return def
end

-- For use in inline <bool> and <a> or <b> type inline ifs
function gui.Nil(def)
    -- Tooltip elements are ignored when layouting and setting visible = false
    -- ensures that the element won't get added to the resulting formspec
    def.visible = false
    return gui.Tooltip(def)
end

-- Prevent any further modifications to the gui table
function gui_mt.__newindex()
    error("Cannot modifiy gui table")
end

local modpath = minetest.get_modpath("flow")
if minetest.is_singleplayer() then
    local example_form
    minetest.register_chatcommand("flow-example", {
        privs = {server = true},
        help = S"Shows an example form",
        func = function(name)
            -- Only load example.lua when it's needed
            if not example_form then
                example_form = dofile(modpath .. "/example.lua")
            end
            example_form:show(minetest.get_player_by_name(name))
        end,
    })
end

if DEBUG_MODE then
    local f, err = loadfile(modpath .. "/test-fs.lua")
    if f then
        return f()
    end
    minetest.log("error", "[flow] " .. tostring(err))
end
