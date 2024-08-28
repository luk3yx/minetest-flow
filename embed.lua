--
-- Minetest formspec layout engine
--
-- Copyright © 2022 by luk3yx
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

local embed_create_ctx_mt = {}

function embed_create_ctx_mt:__index(key)
    -- rawget ensures we don't do recursion
    local ctx = rawget(self, "_flow_embed_parent_ctx")
    local prefix = rawget(self, "_flow_embed_prefix")
    return ctx.form[prefix .. key]
end

function embed_create_ctx_mt:__newindex(key, value)
    local ctx = rawget(self, "_flow_embed_parent_ctx")
    local prefix = rawget(self, "_flow_embed_prefix")
    ctx.form[prefix .. key] = value
end

local function embed_create_ctx(parent_ctx, name, prefix)
    if not parent_ctx[name] then
        parent_ctx[name] = {}
    end
    local new_ctx = parent_ctx[name]
    if not new_ctx.form then
        new_ctx.form = {}
    end

    if getmetatable(new_ctx.form) ~= embed_create_ctx_mt then
        new_ctx.form._flow_embed_prefix = prefix
        new_ctx.form._flow_embed_parent_ctx = parent_ctx
        setmetatable(new_ctx.form, embed_create_ctx_mt)
    end
    return new_ctx
end

local function embed_wrap_callback_func(func, name, prefix)
    return function(player, ctx)
        return func(player, embed_create_ctx(ctx, name, prefix))
    end
end

local function embed_add_prefix(node, name, prefix)
    if node.type == "style" and node.selectors then
        -- Add prefix to style[] selectors
        for i, selector in ipairs(node.selectors) do
            node.selectors[i] = prefix .. selector
        end
    elseif node.type == "scroll_container" and node.scrollbar_name then
        node.scrollbar_name = prefix .. node.scrollbar_name
    elseif node.type == "tooltip" and node.gui_element_name then
        node.gui_element_name = prefix .. node.gui_element_name
    end

    -- Add prefix to all names
    if node.name then
        node.name = prefix .. node.name
    end

    -- Wrap callback functions
    if node.on_event then
        node.on_event = embed_wrap_callback_func(node.on_event, name, prefix)
    end
    if node.on_quit then
        node.on_quit = embed_wrap_callback_func(node.on_quit, name, prefix)
    end

    -- Recurse to child nodes
    for _, child in ipairs(node) do
        embed_add_prefix(child, name, prefix)
    end
end

local change_ctx = ...

return function(self, fields)
    local player = fields.player
    local name = fields.name
    local parent_ctx = flow.get_context()
    if name == nil then
        -- Don't prefix anything if name is unspecified
        return self._build(player, parent_ctx)
    end

    local prefix = "_#" .. name .. "#"
    local child_ctx = embed_create_ctx(parent_ctx, name, prefix)
    change_ctx(child_ctx)
    local root_node = self._build(player, child_ctx)
    change_ctx(parent_ctx)

    embed_add_prefix(root_node, name, prefix)
    return root_node
end
