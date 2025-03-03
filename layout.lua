--
-- Flow: Layouting (initial pass)
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

local max = math.max

-- Estimates the width of a valid UTF-8 string, ignoring any escape sequences.
-- This function hopefully works with most (but not all) scripts, maybe it
-- could still be improved.
local byte, strlen = string.byte, string.len
local LPAREN = byte("(")
local function naive_str_width(str)
    local w = 0
    local prev_w = 0
    local line_count = 1
    local i = 1
    -- string.len() is used so that numbers are coerced to strings without any
    -- extra checking
    local str_length = strlen(str)
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
local CHAR_WIDTH = 0.21

-- The "current_lang" variable isn't ideal but means that the language will be
-- known inside ScrollableVBox etc
local current_lang

-- get_translated_string doesn't exist in MT 5.2.0 and older
local get_translated_string = core.get_translated_string or function(_, s)
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

local ASTERISK = ("*"):byte()
local function parse_font_size(str)
    -- Only support *1.1 etc for now, I don't know if the other formats are
    -- used
    if str and type(str) == "string" and str:byte(1) == ASTERISK then
        return tonumber(str:sub(2)) or 1
    end
    return 1
end

local function get_label_size(label, style, line_spacing)
    label = label or ""
    if current_lang and current_lang ~= "" and current_lang ~= "en" then
        label = get_translated_string(current_lang, label)
    end

    local longest_line_width, line_count = naive_str_width(label)
    local font_size_frac = parse_font_size(style and style.font_size)

    local font_height = font_size_frac * LABEL_HEIGHT
    return longest_line_width * CHAR_WIDTH * font_size_frac,
        font_height + (line_count - 1) * (line_spacing or font_height),
        font_height
end

local size_getters = {}

local function parse_v2f(str, default_x, default_y)
    if str and type(str) == "string" then
        local x, y = str:match("^%s-(%d+)%s-,%s-(%d+)%s-$")
        return tonumber(x) or default_x, tonumber(y) or default_y
    end

    return default_x, default_y
end

local function get_and_fill_in_sizes(node)
    if node.type == "list" then
        if node._flow_w and node._flow_h then
            return node._flow_w, node._flow_h
        end

        local style = node.style
        local slot_w, slot_h = parse_v2f(style and style.size, 1, 1)
        local spacing_w, spacing_h = parse_v2f(
            style and style.spacing, 0.25, 0.25
        )

        local w = node.w * (slot_w + spacing_w) - spacing_w
        local h = node.h * (slot_h + spacing_h) - spacing_h

        -- Cache calculated size so we don't have to parse the list style again
        node._flow_w, node._flow_h = w, h

        return w, h
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
    local style = node.style
    if node.h and style and style.font_size then
        core.log("warning", "[flow] Labels with a fixed height set will be " ..
            "positioned as if font_size was not specified for backwards " ..
            "compatibility reasons. This behaviour is deprecated, please " ..
            "avoid relying on it if possible.")
        style = nil
    end

    -- Labels always have a distance of 0.5 between each line regardless of the
    -- font size
    local w, h, font_height = get_label_size(node.label, style, 0.5)
    node._flow_font_height = font_height
    return w, h
end

local MIN_BUTTON_HEIGHT = 0.8
function size_getters.button(node)
    local x, y = get_label_size(node.label, node.style)
    return max(x, MIN_BUTTON_HEIGHT * 2), max(y, MIN_BUTTON_HEIGHT)
end

size_getters.button_exit = size_getters.button
size_getters.image_button = size_getters.button
size_getters.image_button_exit = size_getters.button
size_getters.item_image_button = size_getters.button
size_getters.button_url = size_getters.button

function size_getters.field(node)
    -- Field labels ignore the "font_size" style
    local label_w, label_h = get_label_size(node.label)

    -- This is done in apply_padding as well but the label size has already
    -- been calculated here
    if not node._padding_top and node.label and #node.label > 0 then
        node._padding_top = label_h
    end

    local w, h = get_label_size(node.default, node.style)
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
    -- Checkboxes don't support font_size
    local w, h = get_label_size(node.label)
    return w + 0.4, h
end

local field_elems = {field = true, pwdfield = true, textarea = true}

local function apply_padding(node, x, y)
    local w, h = get_and_fill_in_sizes(node)

    -- Labels are positioned from the centre of the first line and checkboxes
    -- are positioned from the centre.
    if node.type == "label" then
        y = y + (node._flow_font_height or LABEL_HEIGHT) / 2
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
    listcolors = true
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
    core.log("warning", "[flow] The gui.Padding element is deprecated")
    assert(#node == 1, "Padding can only have one element inside.")
    local n = node[1]
    local x, y = apply_padding(n, 0, 0)
    if node.expand == nil then
        node.expand = n.expand
    end
    return x, y
end

local function set_current_lang(lang)
    current_lang = lang
end

return apply_padding, get_and_fill_in_sizes, set_current_lang,
    DEFAULT_SPACING, LABEL_HEIGHT, invisible_elems
