--
-- Flow: Widgets
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

local S = core.get_translator("flow")
local min, max = math.min, math.max

local DEFAULT_SPACING, get_and_fill_in_sizes = ...

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
        core.log("warning", "[flow] gui.embed() is deprecated")
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
    return gui.HBox{
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
