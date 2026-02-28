local ffi = require("ffi")

local M = {}

local function ensure_paths()
    local p = package.path or ""
    if not p:find("%?%.t", 1, true) then
        package.path = "./?.t;" .. p
    end
end

local function load_ffi_defs(path)
    path = path or "build/argile_api_ffi.lua"
    return dofile(path)
end

local function load_lib(path)
    path = path or "./build/libargile.so"
    return ffi.load(path)
end

local function has_symbol(lib, name)
    return pcall(function() return lib[name] end)
end

local function to_bool(v)
    return not not v
end

local function element_data_to_table(ed)
    local bb = ed.boundingBox
    local x = tonumber(bb.x) or 0
    local y = tonumber(bb.y) or 0
    local w = tonumber(bb.width) or 0
    local h = tonumber(bb.height) or 0
    return {
        found = to_bool(ed.found),
        x = x,
        y = y,
        width = w,
        height = h,
        boundingBox = {
            x = x,
            y = y,
            width = w,
            height = h,
        },
    }
end

local function vec2_to_table(v)
    return {
        x = tonumber(v.x) or 0,
        y = tonumber(v.y) or 0,
    }
end

local function normalize_vec2(ffi_obj, a, b)
    if type(a) == "cdata" then
        return a
    end
    if type(a) == "table" then
        return ffi_obj.new("struct Vector2", {
            x = a.x or 0,
            y = a.y or 0,
        })
    end
    return ffi_obj.new("struct Vector2", {
        x = a or 0,
        y = b or 0,
    })
end

local function scroll_container_data_to_table(sd)
    local out = {
        found = to_bool(sd.found),
        scroll = { x = 0, y = 0 },
        scroll_position = { x = 0, y = 0 },
        viewport = {
            width = tonumber(sd.scrollContainerDimensions.width) or 0,
            height = tonumber(sd.scrollContainerDimensions.height) or 0,
        },
        content = {
            width = tonumber(sd.contentDimensions.width) or 0,
            height = tonumber(sd.contentDimensions.height) or 0,
        },
        config = {
            horizontal = to_bool(sd.config.horizontal),
            vertical = to_bool(sd.config.vertical),
            childOffset = vec2_to_table(sd.config.childOffset),
        },
    }
    if sd.scrollPosition ~= nil then
        local sp = sd.scrollPosition[0]
        local x = tonumber(sp.x) or 0
        local y = tonumber(sp.y) or 0
        out.scroll = { x = x, y = y }
        out.scroll_position = { x = x, y = y }
    end
    return out
end

function M.load(opts)
    opts = opts or {}
    ensure_paths()
    load_ffi_defs(opts.ffi_def_path)
    local lib = load_lib(opts.lib_path)
    return setmetatable({
        ffi = ffi,
        lib = lib,
        ffi_def_path = opts.ffi_def_path or "build/argile_api_ffi.lua",
        lib_path = opts.lib_path or "./build/libargile.so",
    }, { __index = M })
end

function M:has_symbol(name)
    return has_symbol(self.lib, name)
end

function M:get_element_id(name)
    name = name or ""
    return self.lib.GetElementIdFromChars(ffi.cast("char*", name), #name)
end

function M:element_data_to_table(ed)
    return element_data_to_table(ed)
end

function M:set_debug_mode_enabled(enabled)
    if not self:has_symbol("SetDebugModeEnabled") then return false end
    self.lib.SetDebugModeEnabled(to_bool(enabled))
    return true
end

function M:is_debug_mode_enabled()
    if not self:has_symbol("IsDebugModeEnabled") then return false end
    return to_bool(self.lib.IsDebugModeEnabled())
end

function M:mk_string(s)
    return ffi.new("struct String", {
        isStaticallyAllocated = true,
        length = #s,
        chars = ffi.cast("char*", s),
    })
end

function M.slice_to_string(slice)
    if slice == nil or slice.chars == nil or slice.length <= 0 then
        return ""
    end
    return ffi.string(slice.chars, tonumber(slice.length))
end

function M:mk_dimensions(w, h)
    return ffi.new("struct Dimensions", { width = w or 0, height = h or 0 })
end

function M:mk_vector2(x, y)
    return normalize_vec2(self.ffi, x, y)
end

function M:mk_color(r, g, b, a)
    return ffi.new("struct Color", { r = r or 0, g = g or 0, b = b or 0, a = a or 1 })
end

function M:mk_text_config(opts)
    opts = opts or {}
    local tc = ffi.new("struct TextConfig")
    tc.userData = nil
    tc.textColor = opts.textColor or self:mk_color(1, 1, 1, 1)
    tc.fontId = opts.fontId or 0
    tc.fontSize = opts.fontSize or 16
    tc.letterSpacing = opts.letterSpacing or 0
    tc.lineHeight = opts.lineHeight or 16
    tc.wrapMode = opts.wrapMode or self.lib.TEXT_WRAP_WORDS
    tc.textAlignment = opts.textAlignment or self.lib.TEXT_ALIGN_LEFT
    return tc
end

function M:mk_overflow_config(opts)
    opts = opts or {}
    local lib = self.lib

    local function resolve_mode(v)
        if type(v) == "number" then return v end
        if v == "clip" then return lib.OVERFLOW_CLIP or 1 end
        if v == "scroll" then return lib.OVERFLOW_SCROLL or 2 end
        return lib.OVERFLOW_VISIBLE or 0
    end

    return ffi.new("struct OverflowConfig", {
        xMode = resolve_mode(opts.xMode or opts.x or opts.overflow_x),
        yMode = resolve_mode(opts.yMode or opts.y or opts.overflow_y),
    })
end

function M:mk_element_desc(opts)
    opts = opts or {}
    local lib = self.lib
    local d = ffi.new("struct ElementDesc")
    local flags = tonumber(opts.flags) or 0

    local function assign(name, ctype, flag)
        local v = opts[name]
        if v == nil then return end
        if type(v) == "cdata" then
            d[name] = v
        else
            d[name] = ffi.new("struct " .. ctype, v)
        end
        if opts.flags == nil then
            flags = flags + tonumber(flag)
        end
    end

    assign("layout", "LayoutConfig", lib.DESC_HAS_LAYOUT)
    assign("shared", "SharedConfig", lib.DESC_HAS_SHARED)
    assign("border", "BorderConfig", lib.DESC_HAS_BORDER)
    assign("clip", "ClipConfig", lib.DESC_HAS_CLIP)
    assign("floating", "FloatingConfig", lib.DESC_HAS_FLOATING)
    assign("aspect", "AspectRatioConfig", lib.DESC_HAS_ASPECT)
    assign("image", "ImageConfig", lib.DESC_HAS_IMAGE)
    assign("custom", "CustomConfig", lib.DESC_HAS_CUSTOM)
    assign("paint", "PaintConfig", lib.DESC_HAS_PAINT)

    d.flags = flags
    return d
end

function M:create_context(opts)
    opts = opts or {}
    local lib = self.lib
    local dims = self:mk_dimensions(opts.width or 800, opts.height or 600)

    local min_mem = tonumber(lib.MinMemorySize and lib.MinMemorySize() or 0) or 0
    local arena_cap = math.max(min_mem, opts.arena_bytes or 0, 1024 * 1024)
    local arena_mem = ffi.new("char[?]", arena_cap)

    local arena = lib.CreateArenaWithCapacityAndMemory(arena_cap, arena_mem)
    local ctx = lib.Initialize(arena, dims)

    local ctx_storage = nil
    local init_mode = "Initialize"
    if ctx == nil or ctx == ffi.NULL then
        if has_symbol(lib, "GetContextSize") and has_symbol(lib, "InitializeContext") and has_symbol(lib, "SetLayoutDimensionsForContext") then
            local arena_manual = ffi.new("struct Arena")
            arena_manual.nextAllocation = 0
            arena_manual.capacity = arena_cap
            arena_manual.memory = arena_mem
            local ctx_size = tonumber(lib.GetContextSize())
            ctx_storage = ffi.new("uint8_t[?]", ctx_size)
            local ctx_ptr = ffi.cast("struct Context*", ctx_storage)
            local ok = lib.InitializeContext(ctx_ptr, arena_manual, opts.max_elements or 256)
            if ok then
                lib.SetLayoutDimensionsForContext(ctx_ptr, dims)
                ctx = ctx_ptr
                init_mode = "InitializeContext"
            end
        end
    end

    if ctx == nil or ctx == ffi.NULL then
        error("failed to initialize argile context from LuaJIT FFI")
    end

    local obj = {
        ffi = ffi,
        lib = lib,
        ctx = ctx,
        arena_mem = arena_mem,
        arena_capacity = arena_cap,
        ctx_storage = ctx_storage,
        init_mode = init_mode,
        _measure_cb = nil,
    }
    return setmetatable(obj, { __index = M.Context })
end

M.Context = {}

function M.Context:set_current()
    self.lib.SetCurrentContext(self.ctx)
end

function M.Context:set_debug_mode_enabled(enabled)
    if not has_symbol(self.lib, "SetDebugModeEnabled") then return false end
    self.lib.SetDebugModeEnabled(to_bool(enabled))
    return true
end

function M.Context:is_debug_mode_enabled()
    if not has_symbol(self.lib, "IsDebugModeEnabled") then return false end
    return to_bool(self.lib.IsDebugModeEnabled())
end

function M.Context:get_element_data(id_or_name)
    local id = id_or_name
    if type(id_or_name) == "string" then
        id = self.lib.GetElementIdFromChars(ffi.cast("char*", id_or_name), #id_or_name)
    end
    self:set_current()
    return element_data_to_table(self.lib.GetElementData(id))
end

function M.Context:update_scroll_containers(enable_drag_scrolling, scroll_delta, delta_time)
    local delta = normalize_vec2(self.ffi, scroll_delta, 0)
    self.lib.UpdateScrollContainersForContext(self.ctx, to_bool(enable_drag_scrolling), delta, delta_time or 0)
end

function M.Context:get_scroll_container_data(id_or_name)
    local id = id_or_name
    if type(id_or_name) == "string" then
        id = self.lib.GetElementIdFromChars(ffi.cast("char*", id_or_name), #id_or_name)
    end
    self:set_current()
    return scroll_container_data_to_table(self.lib.GetScrollContainerData(id))
end

function M.Context:set_element_scroll_offset(id_or_name, x, y)
    local id = id_or_name
    if type(id_or_name) == "string" then
        id = self.lib.GetElementIdFromChars(ffi.cast("char*", id_or_name), #id_or_name)
    end
    local offset = normalize_vec2(self.ffi, x, y)
    self:set_current()
    if has_symbol(self.lib, "SetElementScrollOffsetForContext") then
        return to_bool(self.lib.SetElementScrollOffsetForContext(self.ctx, id, offset))
    end
    local data = self.lib.GetScrollContainerData(id)
    if not data.found or data.scrollPosition == nil then return false end
    data.scrollPosition[0] = offset
    return true
end

function M.Context:get_element_scroll_offset(id_or_name)
    local id = id_or_name
    if type(id_or_name) == "string" then
        id = self.lib.GetElementIdFromChars(ffi.cast("char*", id_or_name), #id_or_name)
    end
    self:set_current()
    if has_symbol(self.lib, "GetElementScrollOffsetForContext") then
        return vec2_to_table(self.lib.GetElementScrollOffsetForContext(self.ctx, id))
    end
    local data = self.lib.GetScrollContainerData(id)
    if not data.found or data.scrollPosition == nil then
        return { x = 0, y = 0 }
    end
    return vec2_to_table(data.scrollPosition[0])
end

function M.Context:mk_element_desc(opts)
    return M.mk_element_desc(self, opts)
end

function M.Context:open_element_desc(desc_or_opts)
    local desc = desc_or_opts
    if type(desc_or_opts) ~= "cdata" then
        desc = self:mk_element_desc(desc_or_opts or {})
    end
    return to_bool(self.lib.OpenElementWithDescForContext(self.ctx, desc))
end

function M.Context:open_element_desc_with_id(id_or_name, desc_or_opts)
    local id = id_or_name
    if type(id_or_name) == "string" then
        id = self.lib.GetElementIdFromChars(ffi.cast("char*", id_or_name), #id_or_name)
    end
    local desc = desc_or_opts
    if type(desc_or_opts) ~= "cdata" then
        desc = self:mk_element_desc(desc_or_opts or {})
    end
    return to_bool(self.lib.OpenElementWithIdAndDescForContext(self.ctx, id, desc))
end

function M.Context:close_element()
    self.lib.CloseElementForContext(self.ctx)
end

function M.Context:set_measure_text(fn, user_data)
    if self._measure_cb ~= nil then
        self.lib.SetMeasureTextFunctionForContext(self.ctx, nil, nil)
        self._measure_cb:free()
        self._measure_cb = nil
    end
    if fn == nil then
        return
    end
    self._measure_cb = ffi.cast(
        "int32_t (*)(struct StringSlice*, struct TextConfig*, void*, struct Dimensions*)",
        fn
    )
    self.lib.SetMeasureTextFunctionForContext(self.ctx, self._measure_cb, user_data or nil)
end

function M.Context:begin_layout(w, h)
    self.lib.BeginLayoutForContext(self.ctx, w, h)
end

function M.Context:finalize_layout()
    return tonumber(self.lib.FinalizeLayoutForContext(self.ctx))
end

function M.Context:get_render_command_count()
    return tonumber(self.lib.GetRenderCommandCountForContext(self.ctx))
end

function M.Context:reset_measure_text_cache()
    self.lib.ResetMeasureTextCacheForContext(self.ctx)
end

function M.Context:open_text(text, text_config)
    self.lib.OpenTextElementWithLengthForContext(self.ctx, ffi.cast("char*", text), #text, text_config)
end

function M.Context:with_layout(w, h, fn)
    self:begin_layout(w, h)
    local ok, err = xpcall(fn, debug.traceback, self)
    local count = self:finalize_layout()
    if not ok then error(err) end
    return count
end

function M.Context:destroy()
    self:set_measure_text(nil, nil)
    self.ctx = ffi.NULL
    self.ctx_storage = nil
    self.arena_mem = nil
end

return M
