--
-- Flow: Luanti formspec layout engine
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

local DEBUG_MODE = false
flow = {}
local modpath = core.get_modpath("flow")

local apply_padding, get_and_fill_in_sizes, set_current_lang,
    DEFAULT_SPACING, LABEL_OFFSET, invisible_elems =
    dofile(modpath .. "/layout.lua")

local expand = assert(loadfile(modpath .. "/expand.lua"))(
    DEFAULT_SPACING, LABEL_OFFSET, invisible_elems
)

local parse_callbacks = dofile(modpath .. "/input.lua")

assert(loadfile(modpath .. "/widgets.lua"))(
    DEFAULT_SPACING, get_and_fill_in_sizes
)

-- Renders the GUI into hopefully valid AST
-- This won't fill in names
local function render_ast(node, embedded)
    node.padding = node.padding or 0.3
    local w, h = apply_padding(node, 0, 0)
    expand(node)
    local res = {
        formspec_version = 7,
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

    return res
end

local Form = {}

local current_ctx
function flow.get_context()
    if not current_ctx then
        error("get_context() was called outside of a GUI function!", 2)
    end
    return current_ctx
end

-- Returns the new index of the affected element
local function insert_style_elem(tree, idx, node, props, sels)
    if not next(props) then
        -- No properties, don't try and add an empty style element
        return idx
    end

    local style_type = node.name == "_#" or not node.name
    local base_selector = style_type and node.type or node.name
    local selectors = {}
    if sels then
        for i, sel in ipairs(sels) do
            local suffix = sel:match("^%s*$(.-)%s*$")
            if suffix then
                selectors[i] = base_selector .. ":" .. suffix
            else
                core.log("warning", "[flow] Invalid style selector: " ..
                    tostring(sel))
            end
        end
    else
        selectors[1] = base_selector
    end


    table.insert(tree, idx, {
        type = style_type and "style_type" or "style",
        selectors = selectors,
        props = props,
    })

    if style_type then
        -- Undo style_type modifications
        local reset_props = {}
        for k in pairs(props) do
            -- The style table might have substyles which haven't been removed
            -- yet
            reset_props[k] = ""
        end

        table.insert(tree, idx + 2, {
            type = "style_type",
            selectors = selectors,
            props = reset_props,
        })
    end

    return idx + 1
end

local function extract_props(t)
    local res = {}
    for k, v in pairs(t) do
        if k ~= "sel" and type(k) == "string" then
            res[k] = v
        end
    end
    return res
end

-- I don't like the idea of making yet another pass over the element tree but I
-- can't think of a clean way of integrating shorthand elements into one of the
-- other loops.
local function insert_shorthand_elements(tree)
    for i = #tree, 1, -1 do
        local node = tree[i]

        -- Insert styles
        if node.style then
            local props = node.style
            if #node.style > 0 then
                -- Make a copy of node.style without the numeric keys. This
                -- avoids modifying node.style in case it's used for multiple
                -- elements.
                props = extract_props(props)
            end
            local next_idx = insert_style_elem(tree, i, node, props)

            for _, substyle in ipairs(node.style) do
                next_idx = insert_style_elem(tree, next_idx, node,
                    extract_props(substyle), substyle.sel:split(","))
            end
        end

        -- Insert tooltips
        if node.tooltip then
            if node.name then
                table.insert(tree, i, {
                    type = "tooltip",
                    gui_element_name = node.name,
                    tooltip_text = node.tooltip,
                })
            else
                local w, h = get_and_fill_in_sizes(node)
                table.insert(tree, i, {
                    type = "tooltip",
                    x = node.x, y = node.y, w = w, h = h,
                    tooltip_text = node.tooltip,
                })
            end
        end

        if node.type == "container" or node.type == "scroll_container" then
            insert_shorthand_elements(node)
        elseif node.type == "field" then
            table.insert(tree, i, {
                type = 'field_close_on_enter',
                name = node.name,
                close_on_enter = false,
            })

            if node.enter_after_edit then
                table.insert(tree, i, {
                    type = 'field_enter_after_edit',
                    name = node.name,
                    enter_after_edit = true,
                })
            end
        end
    end
end

-- Renders a GUI into a formspec_ast tree and a table with callbacks.
local gui = flow.widgets
function Form:_render(player, ctx, formspec_version, id1, embedded, lang_code)
    local used_ctx_vars = {}
    set_current_lang(lang_code)

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
        tree, orig_form, id1, embedded, formspec_version
    )

    -- This should be after parse_callbacks so it can take advantage of
    -- automatic field naming
    insert_shorthand_elements(tree)

    local redraw_if_changed = {}
    for var in pairs(used_ctx_vars) do
        -- Only add it if there is no callback and the name exists in the
        -- formspec.
        if saved_fields[var] and (not callbacks or not callbacks[var]) then
            redraw_if_changed[var] = true
        end
    end

    set_current_lang(nil)

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
    -- local t = DEBUG_MODE and core.get_us_time()
    local info = core.get_player_information(name)
    local tree, form_info = self:_render(player, ctx,
        info and info.formspec_version, auto_name_id, false,
        info and info.lang_code)

    -- local t2 = DEBUG_MODE and core.get_us_time()
    local fs = assert(formspec_ast.unparse(tree))
    -- local t3 = DEBUG_MODE and core.get_us_time()

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
    core.show_formspec(name, formname, fs)
end

local next_formname = 0
function Form:show(player, ctx)
    if type(player) == "string" then
        core.log("warning",
            "[flow] Calling form:show() with a player name is deprecated")
        player = core.get_player_by_name(player)
        if not player then return end
    end

    -- Use a unique form name every time a new form is shown
    show_form(self, player, ("flow:%x"):format(next_formname), ctx or {})

    -- Form name collisions are theoretically possible but probably won't
    -- happen in practice (and if they do the impact will be minimal)
    next_formname = (next_formname + 1) % 2^53
end

function Form:show_hud(player, ctx)
    local info = core.get_player_information(player:get_player_name())
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
    local info = core.get_player_information(name)
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
        local player = core.get_player_by_name(name)
        if not player then
            core.log("warning", "[flow] Player " .. name ..
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
        core.close_formspec(name, form_info.formname)
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

-- This function may eventually call core.update_formspec if/when it gets
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
            local player = core.get_player_by_name(name)
            if player and func(player, form_info.ctx) then
                update_form(self, player, form_info)
            end
        end
    end
end

Form.embed = assert(loadfile(modpath .. "/embed.lua"))(function(new_context)
    current_ctx = new_context
end)

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
                core.log("warning", "[flow] Player " .. name .. " tried" ..
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

core.register_on_player_receive_fields(function(player, formname, fields)
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

core.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    open_formspecs[name] = nil
    open_inv_formspecs[name] = nil
    render_to_formspec_auto_name_ids[name] = nil
end)

if core.is_singleplayer() then
    local S = core.get_translator("flow")

    local example_form
    core.register_chatcommand("flow-example", {
        privs = {server = true},
        help = S("Shows an example form"),
        func = function(name)
            -- Only load example.lua when it's needed
            if not example_form then
                example_form = dofile(modpath .. "/example.lua")
            end
            example_form:show(core.get_player_by_name(name))
        end,
    })
end

if DEBUG_MODE then
    local f, err = loadfile(modpath .. "/test-fs.lua")
    if f then
        return f()
    end
    core.log("error", "[flow] " .. tostring(err))
end
