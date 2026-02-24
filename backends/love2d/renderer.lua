-- Love2D renderer for Argile render commands
-- Stateful backend with scissor correctness, state caching, and extensible
-- dispatch hooks for image/custom commands.

local ffi = require("ffi")
local dispatcher = require("render.dispatcher")

local lg = love.graphics

local renderer = {}
renderer.dispatcher = dispatcher

local state = {
    font_cache = {},
    image_registry = {},
    scissor_stack = {},
    base_scissor = nil,
    saved = nil,
    cache = {
        color = nil,
        line_width = nil,
        font = nil,
        line_style = nil,
        line_join = nil,
    },
    config = {
        preserve_host_state = true,
        preserve_host_scissor = true,
        default_line_style = "rough",
        default_line_join = "miter",
        collect_stats = false,
    },
    hooks = {
        image = nil,
        custom = nil,
        unknown_command = nil,
    },
    frame_stats = nil,
    last_stats = nil,
}

local function copy_table_shallow(t)
    if t == nil then return nil end
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

local function ptr_key(ptr)
    if ptr == nil then return nil end
    local tv = type(ptr)
    if tv == "number" then
        return ("n:%s"):format(tostring(ptr))
    end
    if tv == "string" then
        return ("s:%s"):format(ptr)
    end
    -- LuaJIT cdata (e.g. void*) stringifies to an address-bearing token and is
    -- stable enough for process-local registry keys.
    return ("c:%s"):format(tostring(ptr))
end

local function clamp_nonnegative(v)
    if v < 0 then return 0 end
    return v
end

local function approx_equal(a, b)
    return math.abs((a or 0) - (b or 0)) <= 0.0001
end

local function intersect_rect(a, b)
    local x1 = math.max(a.x, b.x)
    local y1 = math.max(a.y, b.y)
    local x2 = math.min(a.x + a.w, b.x + b.w)
    local y2 = math.min(a.y + a.h, b.y + b.h)
    if x2 <= x1 or y2 <= y1 then
        return { x = x1, y = y1, w = 0, h = 0 }
    end
    return { x = x1, y = y1, w = x2 - x1, h = y2 - y1 }
end

local function normalize_scissor_rect(rect)
    -- LÖVE's setScissor/intersectScissor Lua wrappers consume integer values.
    -- Expand float bounds to integer bounds to avoid accidental pixel clipping.
    local x = tonumber(rect.x) or 0
    local y = tonumber(rect.y) or 0
    local w = clamp_nonnegative(tonumber(rect.w) or 0)
    local h = clamp_nonnegative(tonumber(rect.h) or 0)

    local x1 = math.floor(x)
    local y1 = math.floor(y)
    local x2 = math.ceil(x + w)
    local y2 = math.ceil(y + h)
    if x2 < x1 then x2 = x1 end
    if y2 < y1 then y2 = y1 end

    return { x = x1, y = y1, w = x2 - x1, h = y2 - y1 }
end

local function get_bbox(cmd)
    local bb = cmd.boundingBox
    return {
        x = tonumber(bb.x) or 0,
        y = tonumber(bb.y) or 0,
        w = clamp_nonnegative(tonumber(bb.width) or 0),
        h = clamp_nonnegative(tonumber(bb.height) or 0),
    }
end

local function color_to_rgba(c)
    local r = tonumber(c.r or 0)
    local g = tonumber(c.g or 0)
    local b = tonumber(c.b or 0)
    local a = tonumber(c.a or 1)
    -- Argile emits normalized floats. Keep compatibility with byte inputs.
    if r > 1 or g > 1 or b > 1 or a > 1 then
        r = r / 255.0
        g = g / 255.0
        b = b / 255.0
        a = a / 255.0
    end
    return r, g, b, a
end

local function has_visible_alpha(c)
    local _, _, _, a = color_to_rgba(c)
    return a > 0
end

local function corner_radius_uniform_for_love(cr, w, h)
    local tl = math.max(0, tonumber(cr.topLeft or 0))
    local tr = math.max(0, tonumber(cr.topRight or 0))
    local bl = math.max(0, tonumber(cr.bottomLeft or 0))
    local br = math.max(0, tonumber(cr.bottomRight or 0))
    local r = tl

    -- LÖVE rectangle API supports one radius pair. If Argile emits asymmetric
    -- radii, use the minimum to stay inside the requested shape.
    if not (approx_equal(tl, tr) and approx_equal(tl, bl) and approx_equal(tl, br)) then
        r = math.min(tl, tr, bl, br)
    end

    local max_r = math.max(0, math.min((w or 0) * 0.5, (h or 0) * 0.5))
    return math.max(0, math.min(r, max_r))
end

local function get_font(size, line_height)
    size = math.max(1, math.floor(tonumber(size) or 16))
    line_height = math.floor(tonumber(line_height) or 0)

    -- Include DPI scale in the cache key since newFont() defaults can depend on
    -- the window's current DPI scale.
    local dpi = 1
    if lg.getDPIScale then
        local ok, v = pcall(lg.getDPIScale)
        if ok and type(v) == "number" and v > 0 then dpi = v end
    end

    local key = ("%d:%d:%.4f"):format(size, line_height, dpi)
    local font = state.font_cache[key]
    if font ~= nil then return font end

    font = lg.newFont(size)
    if line_height > 0 then
        local base_h = font:getHeight()
        if base_h > 0 then
            -- Font:setLineHeight expects a multiplier (docs), not pixels.
            font:setLineHeight(line_height / base_h)
        end
    end
    state.font_cache[key] = font
    return font
end

local function cache_set_color(c)
    local r, g, b, a = color_to_rgba(c)
    local prev = state.cache.color
    if prev ~= nil and approx_equal(prev[1], r) and approx_equal(prev[2], g)
        and approx_equal(prev[3], b) and approx_equal(prev[4], a) then
        return
    end
    lg.setColor(r, g, b, a)
    state.cache.color = { r, g, b, a }
end

local function cache_set_line_width(w)
    w = tonumber(w) or 1
    if w <= 0 then w = 1 end
    if state.cache.line_width ~= nil and approx_equal(state.cache.line_width, w) then
        return
    end
    lg.setLineWidth(w)
    state.cache.line_width = w
end

local function cache_set_font(font)
    if state.cache.font == font then return end
    lg.setFont(font)
    state.cache.font = font
end

local function cache_set_line_style(style)
    if lg.setLineStyle == nil or style == nil then return end
    if state.cache.line_style == style then return end
    lg.setLineStyle(style)
    state.cache.line_style = style
end

local function cache_set_line_join(join)
    if lg.setLineJoin == nil or join == nil then return end
    if state.cache.line_join == join then return end
    lg.setLineJoin(join)
    state.cache.line_join = join
end

local function reset_runtime_caches()
    state.cache.color = nil
    state.cache.line_width = nil
    state.cache.font = nil
    state.cache.line_style = nil
    state.cache.line_join = nil
end

local function save_host_state()
    local saved = {}

    if lg.getColor then
        local r, g, b, a = lg.getColor()
        saved.color = { r, g, b, a }
    end
    if lg.getLineWidth then
        saved.line_width = lg.getLineWidth()
    end
    if lg.getFont then
        saved.font = lg.getFont()
    end
    if lg.getLineStyle then
        local ok, v = pcall(lg.getLineStyle)
        if ok then saved.line_style = v end
    end
    if lg.getLineJoin then
        local ok, v = pcall(lg.getLineJoin)
        if ok then saved.line_join = v end
    end

    local sx, sy, sw, sh = lg.getScissor()
    if sx ~= nil then
        saved.scissor = normalize_scissor_rect({ x = sx, y = sy, w = sw, h = sh })
    else
        saved.scissor = nil
    end

    state.saved = saved
end

local function restore_host_state()
    local saved = state.saved
    if saved == nil then
        lg.setScissor()
        return
    end

    if saved.scissor ~= nil then
        lg.setScissor(saved.scissor.x, saved.scissor.y, saved.scissor.w, saved.scissor.h)
    else
        lg.setScissor()
    end

    if saved.line_style ~= nil then cache_set_line_style(saved.line_style) end
    if saved.line_join ~= nil then cache_set_line_join(saved.line_join) end
    if saved.line_width ~= nil then cache_set_line_width(saved.line_width) end
    if saved.font ~= nil then cache_set_font(saved.font) end
    if saved.color ~= nil then
        lg.setColor(saved.color[1], saved.color[2], saved.color[3], saved.color[4])
        state.cache.color = {
            saved.color[1], saved.color[2], saved.color[3], saved.color[4],
        }
    end
end

local function current_scissor_parent()
    local top = state.scissor_stack[#state.scissor_stack]
    if top ~= nil then return top end
    return state.base_scissor
end

local function apply_scissor_rect(rect)
    if rect ~= nil then
        lg.setScissor(rect.x, rect.y, rect.w, rect.h)
    else
        lg.setScissor()
    end
end

local function init_frame_stats()
    if not state.config.collect_stats then
        state.frame_stats = nil
        return
    end
    state.frame_stats = {
        commands = 0,
        by_type = {},
        scissor_depth_max = 0,
        unknown_commands = 0,
    }
end

local function bump_stat_command(kind)
    local fs = state.frame_stats
    if fs == nil then return end
    fs.commands = fs.commands + 1
    fs.by_type[kind] = (fs.by_type[kind] or 0) + 1
end

local function update_stat_scissor_depth()
    local fs = state.frame_stats
    if fs == nil then return end
    fs.scissor_depth_max = math.max(fs.scissor_depth_max, #state.scissor_stack)
end

local function snap_stroked_rect(x, y, w, h, line_w)
    local lw = tonumber(line_w) or 1
    local iw = math.floor(lw + 0.5)
    local offset = 0

    if approx_equal(lw, iw) then
        lw = iw
        if (iw % 2) == 1 then
            offset = 0.5
        end
    end

    return {
        x = x + offset,
        y = y + offset,
        w = math.max(0, w - lw),
        h = math.max(0, h - lw),
        line_w = lw,
    }
end

local function draw_filled_rounded_rect(bb, color, cr)
    if bb.w <= 0 or bb.h <= 0 then return end
    if not has_visible_alpha(color) then return end
    cache_set_color(color)
    local r = corner_radius_uniform_for_love(cr, bb.w, bb.h)
    lg.rectangle("fill", bb.x, bb.y, bb.w, bb.h, r, r)
end

local function drawable_dimensions(drawable, quad)
    if drawable == nil then return nil, nil end
    if quad ~= nil and quad.getViewport ~= nil then
        local ok, _, _, w, h = pcall(quad.getViewport, quad)
        if ok and w ~= nil and h ~= nil then
            return tonumber(w) or 0, tonumber(h) or 0
        end
    end
    if drawable.getDimensions ~= nil then
        local ok, w, h = pcall(drawable.getDimensions, drawable)
        if ok and w ~= nil and h ~= nil then
            return tonumber(w) or 0, tonumber(h) or 0
        end
    end
    if drawable.getWidth ~= nil and drawable.getHeight ~= nil then
        local ok_w, w = pcall(drawable.getWidth, drawable)
        local ok_h, h = pcall(drawable.getHeight, drawable)
        if ok_w and ok_h and w ~= nil and h ~= nil then
            return tonumber(w) or 0, tonumber(h) or 0
        end
    end
    return nil, nil
end

local function compute_image_draw_transform(bb, src_w, src_h, mode)
    if src_w == nil or src_h == nil or src_w <= 0 or src_h <= 0 then
        return bb.x, bb.y, 0, 0
    end
    mode = mode or "stretch"
    if mode == "stretch" then
        return bb.x, bb.y, bb.w / src_w, bb.h / src_h
    end

    if mode == "center" then
        local x = bb.x + math.floor((bb.w - src_w) * 0.5 + 0.5)
        local y = bb.y + math.floor((bb.h - src_h) * 0.5 + 0.5)
        return x, y, 1, 1
    end

    local sx = bb.w / src_w
    local sy = bb.h / src_h
    local s = (mode == "cover") and math.max(sx, sy) or math.min(sx, sy)
    if not (s > 0) then s = 1 end
    local dw = src_w * s
    local dh = src_h * s
    local x = bb.x + (bb.w - dw) * 0.5
    local y = bb.y + (bb.h - dh) * 0.5
    return x, y, s, s
end

local function draw_registered_image_entry(entry, cmd, bb)
    if entry == nil then return false end

    if type(entry) == "function" then
        return entry(cmd, renderer) == true
    end

    if type(entry) == "table" and type(entry.draw) == "function" then
        return entry.draw(cmd, renderer, entry) == true
    end

    local drawable = entry
    local quad = nil
    local mode = "stretch"
    local tint = nil
    local bg = nil
    local ox, oy = 0, 0
    local rot = 0

    if type(entry) == "table" then
        drawable = entry.drawable or entry.image or entry.texture or entry[1]
        quad = entry.quad
        mode = entry.mode or mode
        tint = entry.color or entry.tint
        bg = entry.backgroundColor or entry.background or entry.bg
        ox = entry.ox or 0
        oy = entry.oy or 0
        rot = entry.rotation or entry.rot or 0
    end

    if drawable == nil then return false end

    if bg ~= nil then
        draw_filled_rounded_rect(bb, bg, cmd.renderData.image.cornerRadius)
    end

    local src_w, src_h = drawable_dimensions(drawable, quad)
    if src_w == nil or src_h == nil or src_w <= 0 or src_h <= 0 then
        return false
    end

    local x, y, sx, sy = compute_image_draw_transform(bb, src_w, src_h, mode)
    if tint ~= nil then
        cache_set_color(tint)
    else
        cache_set_color({ r = 1, g = 1, b = 1, a = 1 })
    end

    if quad ~= nil then
        lg.draw(drawable, quad, x, y, rot, sx, sy, ox, oy)
    else
        lg.draw(drawable, x, y, rot, sx, sy, ox, oy)
    end
    return true
end

local function lookup_registered_image(cmd)
    local d = cmd.renderData.image
    if d == nil then return nil end
    local key = ptr_key(d.imageData)
    if key == nil then return nil end
    return state.image_registry[key]
end

local function draw_border_uniform(cmd, b, bb)
    local w_left = tonumber(b.width.left) or 0
    if w_left <= 0 then return end

    cache_set_color(b.color)
    cache_set_line_style(state.config.default_line_style)
    cache_set_line_join(state.config.default_line_join)
    cache_set_line_width(w_left)

    local stroke = snap_stroked_rect(bb.x, bb.y, bb.w, bb.h, w_left)
    local outer_r = corner_radius_uniform_for_love(b.cornerRadius, bb.w, bb.h)
    local stroke_r = math.max(0, outer_r - (stroke.line_w * 0.5))
    lg.rectangle("line", stroke.x, stroke.y, stroke.w, stroke.h, stroke_r, stroke_r)
end

local function draw_border_per_side(cmd, b, bb)
    local bw = b.width
    local l = math.max(0, tonumber(bw.left) or 0)
    local r = math.max(0, tonumber(bw.right) or 0)
    local t = math.max(0, tonumber(bw.top) or 0)
    local bo = math.max(0, tonumber(bw.bottom) or 0)
    if l <= 0 and r <= 0 and t <= 0 and bo <= 0 then return end

    -- Fallback for non-uniform border widths. This preserves the per-side
    -- widths exactly but does not represent rounded corners perfectly.
    cache_set_color(b.color)

    if t > 0 then
        lg.rectangle("fill", bb.x, bb.y, bb.w, t)
    end
    if bo > 0 then
        lg.rectangle("fill", bb.x, bb.y + bb.h - bo, bb.w, bo)
    end

    local inner_top = bb.y + t
    local inner_bottom = bb.y + bb.h - bo
    local side_h = math.max(0, inner_bottom - inner_top)
    if l > 0 and side_h > 0 then
        lg.rectangle("fill", bb.x, inner_top, l, side_h)
    end
    if r > 0 and side_h > 0 then
        lg.rectangle("fill", bb.x + bb.w - r, inner_top, r, side_h)
    end
end

function renderer.configure(opts)
    opts = opts or {}
    for k, v in pairs(opts) do
        if k == "hooks" and type(v) == "table" then
            for hk, hv in pairs(v) do
                state.hooks[hk] = hv
            end
        else
            state.config[k] = v
        end
    end
    return renderer
end

function renderer.set_hooks(hooks)
    hooks = hooks or {}
    for k, v in pairs(hooks) do
        state.hooks[k] = v
    end
    return renderer
end

function renderer.reset_caches()
    state.font_cache = {}
    reset_runtime_caches()
end

function renderer.register_image(image_data_key, entry)
    local key = ptr_key(image_data_key)
    assert(key ~= nil, "register_image requires a non-nil image key/pointer")
    state.image_registry[key] = entry
    return renderer
end

function renderer.unregister_image(image_data_key)
    local key = ptr_key(image_data_key)
    if key ~= nil then
        state.image_registry[key] = nil
    end
    return renderer
end

function renderer.clear_image_registry()
    state.image_registry = {}
    return renderer
end

function renderer.begin_frame()
    state.scissor_stack = {}
    state.base_scissor = nil
    state.saved = nil
    reset_runtime_caches()
    init_frame_stats()

    if state.config.preserve_host_state then
        save_host_state()
        if state.config.preserve_host_scissor then
            state.base_scissor = state.saved and state.saved.scissor or nil
        end
    elseif state.config.preserve_host_scissor then
        local sx, sy, sw, sh = lg.getScissor()
        if sx ~= nil then
            state.base_scissor = normalize_scissor_rect({ x = sx, y = sy, w = sw, h = sh })
        end
    end

    if state.base_scissor == nil then
        lg.setScissor()
    else
        lg.setScissor(state.base_scissor.x, state.base_scissor.y, state.base_scissor.w, state.base_scissor.h)
    end

    cache_set_line_style(state.config.default_line_style)
    cache_set_line_join(state.config.default_line_join)
end

function renderer.end_frame()
    state.last_stats = state.frame_stats and copy_table_shallow(state.frame_stats) or nil
    if state.last_stats and state.frame_stats and state.frame_stats.by_type then
        state.last_stats.by_type = copy_table_shallow(state.frame_stats.by_type)
    end
    state.frame_stats = nil

    if state.config.preserve_host_state then
        restore_host_state()
    else
        apply_scissor_rect(state.base_scissor)
    end

    state.scissor_stack = {}
    state.base_scissor = nil
end

function renderer.get_last_stats()
    return state.last_stats
end

function renderer.set_color(c)
    cache_set_color(c)
end

function renderer.draw_rectangle(cmd)
    local bb = get_bbox(cmd)
    if bb.w <= 0 or bb.h <= 0 then return end
    draw_filled_rounded_rect(bb, cmd.renderData.rectangle.backgroundColor, cmd.renderData.rectangle.cornerRadius)
end

function renderer.draw_image(cmd)
    local hook = state.hooks.image
    if hook ~= nil and hook(cmd, renderer) == true then
        return
    end

    local bb = get_bbox(cmd)
    if bb.w <= 0 or bb.h <= 0 then return end
    local d = cmd.renderData.image
    if draw_registered_image_entry(lookup_registered_image(cmd), cmd, bb) then
        return
    end

    -- Generic fallback: draw the backgroundColor and let host apps install an
    -- image hook / registry binding when they can map imageData pointers.
    draw_filled_rounded_rect(bb, d.backgroundColor, d.cornerRadius)
end

function renderer.draw_border(cmd)
    local b = cmd.renderData.border
    local bb = get_bbox(cmd)
    if bb.w <= 0 or bb.h <= 0 then return end

    local l = tonumber(b.width.left) or 0
    local r = tonumber(b.width.right) or 0
    local t = tonumber(b.width.top) or 0
    local bo = tonumber(b.width.bottom) or 0
    if l <= 0 and r <= 0 and t <= 0 and bo <= 0 then return end

    local uniform = approx_equal(l, r) and approx_equal(l, t) and approx_equal(l, bo)
    if uniform then
        draw_border_uniform(cmd, b, bb)
    else
        draw_border_per_side(cmd, b, bb)
    end
end

function renderer.draw_text(cmd)
    local t = cmd.renderData.text
    local slice = t.stringContents
    if slice == nil or slice.chars == nil or slice.length <= 0 then return end

    cache_set_color(t.textColor)

    local prev_font = state.cache.font
    local font = get_font(t.fontSize, t.lineHeight)
    cache_set_font(font)

    local s = ffi.string(slice.chars, tonumber(slice.length))
    local x = tonumber(cmd.boundingBox.x) or 0
    local y = tonumber(cmd.boundingBox.y) or 0
    -- Argile already emits positioned/wrapped text slices.
    lg.print(s, x, y)

    if prev_font ~= nil and prev_font ~= font then
        cache_set_font(prev_font)
    end
end

-- Paint operation kinds from FFI: PAINT_OP_FILL=0, PAINT_OP_STROKE=1, etc.
-- Shapes consume the current fill color; line uses stroke color/width.
function renderer.draw_paint(cmd, argile)
    local p = cmd.renderData.paint
    if p == nil or p.ops == nil or p.count <= 0 then return end

    local ox = tonumber(cmd.boundingBox.x) or 0
    local oy = tonumber(cmd.boundingBox.y) or 0

    local fill_color = { r = 255, g = 255, b = 255, a = 255 }
    local stroke_color = { r = 255, g = 255, b = 255, a = 255 }
    local stroke_width = 1

    local i = 0
    while i < tonumber(p.count) do
        local op = p.ops[i]
        local kind = tonumber(op.kind)

        if kind == argile.PAINT_OP_FILL then
            fill_color = op.color
        elseif kind == argile.PAINT_OP_STROKE then
            stroke_color = op.color
            stroke_width = tonumber(op.width) or 1
        elseif kind == argile.PAINT_OP_RECT then
            cache_set_color(fill_color)
            lg.rectangle("fill", ox + op.x, oy + op.y, op.w, op.h)
        elseif kind == argile.PAINT_OP_ROUND_RECT then
            cache_set_color(fill_color)
            lg.rectangle("fill", ox + op.x, oy + op.y, op.w, op.h, op.r, op.r)
        elseif kind == argile.PAINT_OP_CIRCLE then
            cache_set_color(fill_color)
            lg.circle("fill", ox + op.x, oy + op.y, op.r)
        elseif kind == argile.PAINT_OP_LINE then
            cache_set_color(stroke_color)
            cache_set_line_style(state.config.default_line_style)
            cache_set_line_join(state.config.default_line_join)
            cache_set_line_width(stroke_width)
            lg.line(ox + op.x, oy + op.y, ox + op.x2, oy + op.y2)
        else
            local fs = state.frame_stats
            if fs ~= nil then fs.unknown_commands = fs.unknown_commands + 1 end
        end

        i = i + 1
    end
end

function renderer.draw_custom(cmd, argile)
    local hook = state.hooks.custom
    if hook ~= nil then
        return hook(cmd, renderer, argile)
    end
end

function renderer.draw_scissor_start(cmd)
    local bb = get_bbox(cmd)
    local rect = { x = bb.x, y = bb.y, w = bb.w, h = bb.h }

    local parent = current_scissor_parent()
    if parent ~= nil then
        rect = intersect_rect(parent, rect)
    end

    rect = normalize_scissor_rect(rect)
    state.scissor_stack[#state.scissor_stack + 1] = rect
    apply_scissor_rect(rect)
    update_stat_scissor_depth()
end

function renderer.draw_scissor_end()
    if #state.scissor_stack > 0 then
        state.scissor_stack[#state.scissor_stack] = nil
    end
    apply_scissor_rect(current_scissor_parent())
end

function renderer.on_unknown_command(cmd, argile, cmd_type)
    local hook = state.hooks.unknown_command
    if hook ~= nil then hook(cmd, renderer, argile, cmd_type) end
    local fs = state.frame_stats
    if fs ~= nil then fs.unknown_commands = fs.unknown_commands + 1 end
end

function renderer.draw_command(cmd, argile)
    local t = tonumber(cmd.commandType)
    bump_stat_command(t)
    return dispatcher.draw_command(cmd, renderer, argile)
end

function renderer.draw_commands(cmd_buffer, cmd_count, argile)
    if cmd_buffer == nil or cmd_count == nil then return 0 end
    local n = tonumber(cmd_count) or 0
    for i = 0, n - 1 do
        renderer.draw_command(cmd_buffer[i], argile)
    end
    return n
end

return renderer
