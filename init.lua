--
-- Minetest formspec layout engine
--
-- Copyright © 2022 by luk3yx
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.

-- You should have received a copy of the GNU Lesser General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.
--

local DEBUG_MODE = false
local hot_reload = (DEBUG_MODE and minetest.global_exists("flow") and
                    flow.hot_reload or {})
flow = {}


local Form = {}

local min, max = math.min, math.max

local function strip_escape_sequences(str)
    return (str:gsub("\27%([^)]+%)", ""):gsub("\27.", ""))
end

local LABEL_HEIGHT = 0.4
local LABEL_OFFSET = LABEL_HEIGHT / 2
local CHARS_PER_UNIT = 4.8 -- 5
local function get_lines_size(lines)
    local w = 0
    for _, line in ipairs(lines) do
        w = max(w, #strip_escape_sequences(line) / CHARS_PER_UNIT)
    end
    return w, LABEL_HEIGHT * #lines
end

local function get_label_size(label)
    return get_lines_size((label or ""):split("\n", true))
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
    if not node._padding_top and node.label and #node.label > 0 then
        node._padding_top = label_h
    end

    local w, h = get_label_size(node.default)
    return max(w, label_w, 3), max(h, MIN_BUTTON_HEIGHT)
end
size_getters.pwdfield = size_getters.field
size_getters.textarea = size_getters.field

function size_getters.vertlabel(node)
    return 1 / CHARS_PER_UNIT, #node.label * LABEL_HEIGHT
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

local function apply_padding(node, x, y, extra_padding)
    local w, h = get_and_fill_in_sizes(node)

    if extra_padding then
        w = w + extra_padding
        h = h + extra_padding
    end

    if node.type == "label" or node.type == "checkbox" then
        y = y + LABEL_OFFSET
    end

    if node._padding_top then
        y = y + node._padding_top
        h = h + node._padding_top
    end

    if node.padding then
        x = x + node.padding
        y = y + node.padding
        w = w + node.padding * 2
        h = h + node.padding * 2
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

    -- Special cases
    for _, node in ipairs(hbox) do
        if node.type == "checkbox" then
            node.y = height / 2
        end
    end

    return x, height
end

function size_getters.padding(node)
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
    if node.type == "list" or node.type == "checkbox" then
        return align_types.centre(node, x, w, extra_space)
    elseif node.type == "label" then
        if x == "y" then
            node.y = node.y + extra_space / 2
            return
        end

        -- Hack
        node.type = "container"
        node[1] = {
            type = "image_button",
            texture_name = "blank.png",
            drawborder = false,
            x = 0, y = 0,
            w = node.w + extra_space, h = node.h,
            label = node.label,
        }

        -- Overlay button to prevent clicks from doing anything
        node[2] = {
            type = "image_button",
            texture_name = "blank.png",
            drawborder = false,
            x = 0, y = 0,
            w = node.w + extra_space, h = node.h,
            label = "",
        }

        node.y = node.y - LABEL_OFFSET
        node.label = nil
        assert(#node == 2)
    end
    node[w] = node[w] + extra_space
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

local function expand(box)
    local x, w, align_h, y, h, align_v
    if box.type == "hbox" then
        x, w, align_h, y, h, align_v = "x", "w", "align_h", "y", "h", "align_v"
    elseif box.type == "vbox" then
        x, w, align_h, y, h, align_v = "y", "h", "align_v", "x", "w", "align_h"
    elseif box.type == "padding" then
        box.type = "container"
        local node = box[1]
        if node.expand then
            align_types[node.align_h or "auto"](node, "x", "w", box.w -
                node.w - ((node.padding or 0) + (box.padding or 0)) * 2)
            align_types[node.align_v or "auto"](node, "y", "h", box.h -
                node.h - ((node.padding or 0) + (box.padding or 0)) * 2 -
                (node._padding_top or 0) - (box._padding_top or 0))
        end
        return expand(node)
    elseif box.type == "container" or box.type == "scroll_container" then
        for _, node in ipairs(box) do
            if node.x == 0 and node.expand and box.w then
                node.w = box.w
            end
            expand(node)
        end
        return
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
            free_space = free_space - width

            if node.expand then
                expandable[node] = i
                expand_count = expand_count + 1
            end

            -- Nodes are expanded in the other direction no matter what their
            -- expand setting is
            if box_h > height then
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
            align_types[node[align_h] or "auto"](node, x, w,
                extra_space - (node.padding or 0) * 2)

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
                local align = node.align_h or "auto"
                if align == "centre" or align == "center" or align == "fill" or
                        (align == "auto" and node.expand) then
                    align_types.fill(node, "x", "w", 0)
                end
            end
        end
    end

    -- Recursively expand
    for _, node in ipairs(box) do
        expand(node)
    end
end

-- Renders the GUI into hopefully valid AST
-- This won't fill in names
local function render_ast(node)
    local t1 = DEBUG_MODE and minetest.get_us_time()
    local w, h = apply_padding(node, 0.3, 0.3, 0.6, 0.6)
    local t2 = DEBUG_MODE and minetest.get_us_time()
    expand(node)
    local t3 = DEBUG_MODE and minetest.get_us_time()
    local res = {
        formspec_version = 5,
        {type = "size", w = w, h = h},
    }
    for field in formspec_ast.find(node, 'field') do
        res[#res + 1] = {
            type = 'field_close_on_enter',
            name = field.name,
            close_on_enter = false,
        }
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

-- Try and create short (2 byte) names
local function get_identifier(i)
    if i > 127 then
        -- Give up and use long (but unique) names
        return '\1\1' .. tostring(i)
    end
    return string.char(1, i)
end

local function chain_cb(f1, f2)
    return function(...)
        f1(...)
        f2(...)
    end
end

local field_value_transformers = {
    tabheader = tonumber,
    dropdown = tonumber,
    checkbox = minetest.is_yes,
    table = function(value)
        return minetest.explode_table_event(value).row
    end,
    textlist = function(value)
        return minetest.explode_textlist_event(value).index
    end,
    scrollbar = function(value)
        return minetest.explode_scrollbar_event(value).value
    end,
}

local function default_field_value_transformer(value)
    return value
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
    default = "", selected = false, selected_idx = 1, value = 1,
}

-- Removes on_event from a formspec_ast tree and returns a callbacks table
local function parse_callbacks(tree, ctx_form)
    local i = 0
    local callbacks = {}
    local saved_fields = {}
    local seen_scroll_container = false
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
            if node.on_quit then
                if callbacks.quit then
                    -- HACK
                    callbacks.quit = chain_cb(callbacks.quit, node.on_quit)
                else
                    callbacks.quit = node.on_quit
                end
            end
        elseif seen_scroll_container then
            -- Work around a Minetest bug with scroll containers not scrolling
            -- backgrounds.
            if (node.type == "background" or node.type == "background9") and
                    not node.auto_clip then
                node.type = "image"
            end
        elseif node.type == "scroll_container" then
            seen_scroll_container = true
        end

        local node_name = node.name
        if node_name then
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
                    if node.items then
                        if value == nil then
                            ctx_form[node_name] = node.items[
                                node.selected_idx or 1
                            ]
                        else
                            local idx = table.indexof(node.items, value)
                            if idx > 0 then
                                node.selected_idx = idx
                            end
                        end
                    end

                    saved_fields[node_name] = default_field_value_transformer
                elseif value == nil then
                    ctx_form[node_name] = node[value_field] or
                        sensible_defaults[value_field]
                else
                    node[value_field] = value or sensible_defaults[value_field]
                end
            end
        end

        if node.on_event then
            if not node_name then
                i = i + 1
                node_name = get_identifier(i)
                node.name = node_name
            end

            callbacks[node_name] = node.on_event
            node.on_event = nil
        end

        if node._after_positioned then
            node:_after_positioned()
            node._after_positioned = nil
        end
    end
    return callbacks, saved_fields
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
function Form:_render(player, ctx, formspec_version)
    local used_ctx_vars = {}

    -- Wrap ctx.form
    local orig_form = ctx.form or {}
    local wrapped_form = setmetatable({}, {
        __index = function(_, key)
            used_ctx_vars[key] = true
            return orig_form[key]
        end,
        __newindex = function(_, key, value)
            orig_form[key] = value
        end,
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

    local tree = render_ast(box)
    local callbacks, saved_fields = parse_callbacks(tree, orig_form)

    local redraw_if_changed = {}
    for var in pairs(used_ctx_vars) do
        -- Only add it if there is no callback and the name exists in the
        -- formspec.
        if saved_fields[var] and not callbacks[var] then
            redraw_if_changed[var] = true
        end
    end

    return tree, {
        self = self,
        formname = self._formname,
        callbacks = callbacks,
        saved_fields = saved_fields,
        redraw_if_changed = redraw_if_changed,
        ctx = ctx,
    }
end

local open_formspecs = {}
function Form:show(player, ctx)
    if type(player) == "string" then
        player = minetest.get_player_by_name(player)
        if not player then return end
    end

    local t = minetest.get_us_time()
    ctx = ctx or {}

    local name = player:get_player_name()
    local info = minetest.get_player_information(name)
    local tree, form_info = self:_render(player, ctx,
        info and info.formspec_version)

    local t2 = minetest.get_us_time()
    local fs = assert(formspec_ast.unparse(tree))
    local t3 = minetest.get_us_time()

    open_formspecs[name] = form_info
    if DEBUG_MODE then
        print(t3 - t, t2 - t, t3 - t2)
    end
    minetest.show_formspec(name, self._formname, fs)
end

function Form:show_hud(player, ctx)
    local tree = self:_render(player, ctx or {})
    hud_fs.show_hud(player, self._formname, tree)
end

function Form:close(player)
    minetest.close_formspec(player:get_player_name(), self._formname)
end

function Form:close_hud(player)
    hud_fs.close_hud(player, self._formname)
end

local used_ids = {}
setmetatable(used_ids, {__mode = "v"})

local formname_prefix = minetest.get_current_modname() .. ":"

local form_mt = {__index = Form}
function flow.make_gui(build_func)
    local res = setmetatable({}, form_mt)

    -- Reserve a formname
    local id = #used_ids + 1
    used_ids[id] = gui

    res._formname = formname_prefix .. get_identifier(id)
    res._build = build_func

    return res
end

local function on_fs_input(player, formname, fields)
    local name = player:get_player_name()
    local form_info = open_formspecs[name]
    if not form_info then return end

    if formname ~= form_info.formname then return end

    local callbacks = form_info.callbacks
    local ctx = form_info.ctx
    local redraw_if_changed = form_info.redraw_if_changed
    local ctx_form = ctx.form

    -- Update the context before calling any callbacks
    local redraw_fs = false
    for field, transformer in pairs(form_info.saved_fields) do
        if fields[field] then
            local new_value = transformer(fields[field])
            if redraw_if_changed[field] and ctx_form[field] ~= new_value then
                if DEBUG_MODE then
                    print('Modified:', dump(field), dump(ctx_form[field]),
                        '->', dump(new_value))
                end
                redraw_fs = true
            end
            ctx_form[field] = new_value
        end
    end

    -- Some callbacks may be false to indicate that they're valid fields but
    -- don't need to be called
    for field, value in pairs(fields) do
        if callbacks[field] and callbacks[field](player, ctx, value) then
            redraw_fs = true
        end
    end

    if open_formspecs[name] ~= form_info then return end

    if fields.quit then
        open_formspecs[name] = nil
    elseif redraw_fs then
        form_info.self:show(player, ctx)
    end
end

local function on_leaveplayer(player)
    open_formspecs[player:get_player_name()] = nil
end

if DEBUG_MODE then
    flow.hot_reload = {on_fs_input, on_leaveplayer}
    if not hot_reload[1] then
        minetest.register_on_player_receive_fields(function(...)
            return flow.hot_reload[1](...)
        end)
    end
    if not hot_reload[2] then
        minetest.register_on_leaveplayer(function(...)
            return flow.hot_reload[2](...)
        end)
    end
else
    minetest.register_on_player_receive_fields(on_fs_input)
    minetest.register_on_leaveplayer(on_leaveplayer)
end

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
                label = "Page " .. current_page .. " of " .. #pages,
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
    if def.expand == nil then
        def.expand = true
    end
    assert(#def == 0)
    return def
end

-- Prevent any further modifications to the gui table
function gui_mt.__newindex()
    error("Cannot modifiy gui table")
end

local modpath = minetest.get_modpath("flow")
local example_form
minetest.register_chatcommand("flow-example", {
    privs = {server = true},
    help = "Shows an example formspec",
    func = function(name)
        -- Only load example.lua when it's needed
        if not example_form then
            example_form = dofile(modpath .. "/example.lua")
        end
        example_form:show(name)
    end,
})

if DEBUG_MODE then
    local f, err = loadfile(modpath .. "/test-fs.lua")
    if not f then
        minetest.log("error", "[flow] " .. tostring(err))
    end
    return f()
end
