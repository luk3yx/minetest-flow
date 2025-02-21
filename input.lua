--
-- Flow: Formspec input processor
--
-- Copyright © 2025 by luk3yx
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

local ceil, floor, max = math.ceil, math.floor, math.max

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
    checkbox = simple_transformer(core.is_yes),

    -- Scrollbars do have min/max values but scrollbars are only really used by
    -- ScrollableVBox which doesn't need the extra checks
    scrollbar = simple_transformer(function(value)
        return core.explode_scrollbar_event(value).value
    end),
}

-- Field value transformers that depend on some property of the element
function field_value_transformers.tabheader(node)
    return range_check_transformer(node.captions and #node.captions or 0)
end

function field_value_transformers.dropdown(node, _, formspec_version)
    local items = node.items or {}
    if node.index_event and not node._index_event_hack then
        return range_check_transformer(#items)
    end

    -- MT will start sanitising formspec fields on its own at some point
    -- (https://github.com/minetest/minetest/pull/14878), however it may strip
    -- escape sequences from dropdowns as well. Since we know what the actual
    -- value of the dropdown is anyway, we can just enable index_event for new
    -- clients and keep the same behaviour
    if (formspec_version and formspec_version >= 4) or
            (core.global_exists("fs51") and
             fs51.monkey_patching_enabled) then
        node.index_event = true

        -- Detect reuse of the same Dropdown element (this is unsupported and
        -- will break in other ways)
        node._index_event_hack = true

        return function(value)
            return items[tonumber(value)]
        end
    elseif node._index_event_hack then
        node.index_event = nil
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
        local row = floor(core.explode_table_event(value).row)
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
        local index = floor(core.explode_textlist_event(value).index)
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
    pwdfield = "default",
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
        replace_backgrounds, formspec_version)
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
                -- Update ctx.form if there is no current value, otherwise
                -- change the node's value to the saved one.
                local value = ctx_form[node_name]
                if node.type == "dropdown" and (not node.index_event or
                        node._index_event_hack) then
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

                -- Add the corresponding value transformer transformer to
                -- saved_fields
                local get_transformer = field_value_transformers[node.type]
                saved_fields[node_name] = get_transformer and
                    get_transformer(node, tablecolumn_count,
                        formspec_version) or
                    default_field_value_transformer
            elseif node.type == "hypertext" then
                -- Experimental (may be broken in the future): Allow accessing
                -- hypertext fields with "ctx.form.hypertext_name" as this is
                -- the most straightforward way of doing it.
                saved_fields[node_name] = default_field_value_transformer
            end
        end

        -- Add the on_event callback (if any) to the callbacks table
        if node.on_event then
            local is_btn = button_types[node.type]
            if not node_name then
                -- Flow internal field names start with "_#" to avoid
                -- conflicts with user-provided fields.
                node_name = ("_#%x"):format(auto_name_id)
                node.name = node_name
                auto_name_id = auto_name_id + 1
            elseif btn_callbacks[node_name] or
                    (is_btn and saved_fields[node_name]) or
                    (callbacks and callbacks[node_name]) then
                core.log("warning", ("[flow] Multiple callbacks have " ..
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

return parse_callbacks
