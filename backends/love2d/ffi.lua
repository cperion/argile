-- Shared FFI helpers for Love2D Argile integration
-- Loads libargile.so and provides utility functions

local ffi = require("ffi")
local runtime = require("bindings.luajit.argile_lj.runtime")

local argile_ffi = {}

-- Initialize and return the loaded library
function argile_ffi.init()
    local client = runtime.load({
        ffi_def_path = "build/argile_api_ffi.lua",
        lib_path = "build/libargile.so",
    })
    local lib = client.lib
    argile_ffi.runtime_client = client
    argile_ffi.lib = lib
    
    -- Add C standard library functions we need
    ffi.cdef[[
        void* malloc(size_t size);
        void free(void* ptr);
    ]]
    
    return lib
end

-- String helper: create FFI String struct from Lua string
function argile_ffi.mk_string(s)
    return ffi.new("struct String", {
        isStaticallyAllocated = true,
        length = #s,
        chars = ffi.cast("char*", s),
    })
end

-- StringSlice to Lua string
function argile_ffi.slice_to_string(slice)
    return runtime.slice_to_string(slice)
end

-- Element ID from string
function argile_ffi.mk_id(lib, id_string)
    local str = argile_ffi.mk_string(id_string)
    return lib.GetElementId(str)
end

-- Create ArgileFrameInput struct
function argile_ffi.mk_frame_input(opts)
    opts = opts or {}
    return ffi.new("struct ArgileFrameInput", {
        width = opts.width or 800,
        height = opts.height or 600,
        pointer_x = opts.pointer_x or 0,
        pointer_y = opts.pointer_y or 0,
        pointer_down = opts.pointer_down or false,
        pointer_pressed = opts.pointer_pressed or false,
        pointer_released = opts.pointer_released or false,
        scroll_delta_x = opts.scroll_delta_x or 0,
        scroll_delta_y = opts.scroll_delta_y or 0,
        delta_time = opts.delta_time or 0,
    })
end

-- Color helpers (creates Color struct)
function argile_ffi.mk_color(r, g, b, a)
    return ffi.new("struct Color", {
        r = r or 0,
        g = g or 0,
        b = b or 0,
        a = a or 1,
    })
end

function argile_ffi.mk_color_bytes(r, g, b, a)
    return ffi.new("struct Color", {
        r = (r or 0) / 255.0,
        g = (g or 0) / 255.0,
        b = (b or 0) / 255.0,
        a = (a or 255) / 255.0,
    })
end

-- Vector2 helper
function argile_ffi.mk_vector2(x, y)
    return ffi.new("struct Vector2", {
        x = x or 0,
        y = y or 0,
    })
end

-- Dimensions helper
function argile_ffi.mk_dimensions(width, height)
    return ffi.new("struct Dimensions", {
        width = width or 0,
        height = height or 0,
    })
end

-- Padding helper
function argile_ffi.mk_padding(left, right, top, bottom)
    return ffi.new("struct Padding", {
        left = left or 0,
        right = right or 0,
        top = top or 0,
        bottom = bottom or 0,
    })
end

-- ChildAlignment helper
function argile_ffi.mk_alignment(x, y)
    local lib = argile_ffi.lib or error("Call init() first")
    local align_x = lib.ALIGN_X_LEFT
    if x == "center" then align_x = lib.ALIGN_X_CENTER
    elseif x == "right" then align_x = lib.ALIGN_X_RIGHT end
    
    local align_y = lib.ALIGN_Y_TOP
    if y == "center" then align_y = lib.ALIGN_Y_CENTER
    elseif y == "bottom" then align_y = lib.ALIGN_Y_BOTTOM end
    
    return ffi.new("struct ChildAlignment", { x = align_x, y = align_y })
end

-- LayoutConfig helper
function argile_ffi.mk_layout(sizing, padding, gap, alignment, direction)
    local lib = argile_ffi.lib or error("Call init() first")
    return ffi.new("struct LayoutConfig", {
        sizing = sizing,
        padding = padding,
        childGap = gap or 0,
        childAlignment = alignment,
        layoutDirection = direction == "col" and lib.TOP_TO_BOTTOM or lib.LEFT_TO_RIGHT,
    })
end

-- CornerRadius helper
function argile_ffi.mk_corner_radius(radius)
    return ffi.new("struct CornerRadius", {
        topLeft = radius or 0,
        topRight = radius or 0,
        bottomLeft = radius or 0,
        bottomRight = radius or 0,
    })
end

-- SharedConfig helper
function argile_ffi.mk_shared_config(bg_color, corner_radius, user_data)
    return ffi.new("struct SharedConfig", {
        backgroundColor = bg_color,
        cornerRadius = corner_radius or argile_ffi.mk_corner_radius(0),
        userData = user_data or nil,
    })
end

-- BorderConfig helper
function argile_ffi.mk_border_config(color, width)
    local w = width or 1
    return ffi.new("struct BorderConfig", {
        color = color,
        width = ffi.new("struct BorderWidth", {
            left = w,
            right = w,
            top = w,
            bottom = w,
            betweenChildren = 0,
        }),
    })
end

-- TextConfig helper
function argile_ffi.mk_text_config(opts)
    opts = opts or {}
    local lib = argile_ffi.lib or error("Call init() first")
    return ffi.new("struct TextConfig", {
        userData = nil,
        textColor = opts.color or argile_ffi.mk_color(0.9, 0.9, 0.9, 1.0),
        fontId = opts.font_id or 0,
        fontSize = opts.size or 16,
        letterSpacing = opts.letter_spacing or 0,
        lineHeight = opts.line_height or 0,
        wrapMode = lib.TEXT_WRAP_NONE,
        textAlignment = lib.TEXT_ALIGN_LEFT,
    })
end

return argile_ffi
