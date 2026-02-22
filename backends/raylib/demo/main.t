-- Raylib Backend Demo for Argile
-- Loads raylib via Terra's FFI module and renders Argile commands
-- Uses the same portable scene ABI as Love2D
-- 
-- NOTE: This demo uses Terra's FFI module (ffi.*) not pure terralib C interop.
-- Pure Terra C interop (terralib.includecstring) has limitations with complex
-- headers, so we use FFI for practical reasons.
--
-- Platform limitation: May crash on Wayland due to GLFW/raylib.
-- Use X11/XWayland session if available.
local C = ffi.C

-- Load Argile FFI bindings
dofile("build/argile_api_ffi.lua")
local argile = ffi.load("build/libargile.so")

-- C standard library functions
ffi.cdef[[
void* malloc(size_t size);
void free(void* ptr);
]]

-- Raylib FFI definitions (core subset needed for demo)
-- Note: struct names are prefixed with RL_ to avoid conflicts with Argile FFI
ffi.cdef[[
// Window and rendering
void InitWindow(int width, int height, const char *title);
void CloseWindow(void);
bool WindowShouldClose(void);
void SetTargetFPS(int fps);
void BeginDrawing(void);
void EndDrawing(void);
void ClearBackground(unsigned int color);
int GetScreenWidth(void);
int GetScreenHeight(void);
double GetTime(void);

// Colors (raylib specific)
struct RL_Color { unsigned char r, g, b, a; };

// Drawing
void DrawRectangle(int posX, int posY, int width, int height, struct RL_Color color);
void DrawRectangleRounded(struct RL_Rectangle rec, float roundness, int segments, struct RL_Color color);
void DrawRectangleLines(int posX, int posY, int width, int height, struct RL_Color color);
void DrawRectangleLinesEx(struct RL_Rectangle rec, float lineThick, struct RL_Color color);
void DrawCircle(int centerX, int centerY, float radius, struct RL_Color color);
void DrawLine(int startPosX, int startPosY, int endPosX, int endPosY, struct RL_Color color);
void DrawLineEx(struct RL_Vector2 startPos, struct RL_Vector2 endPos, float thick, struct RL_Color color);

// Rectangle
struct RL_Rectangle { float x, y, width, height; };

// Vector2
struct RL_Vector2 { float x, y; };

// Text
struct RL_Font { void* data; };
void DrawText(const char *text, int posX, int posY, int fontSize, struct RL_Color color);
struct RL_Vector2 MeasureTextEx(struct RL_Font font, const char *text, float fontSize, float spacing);
void DrawTextEx(struct RL_Font font, const char *text, struct RL_Vector2 position, float fontSize, float spacing, struct RL_Color tint);
struct RL_Font GetFontDefault(void);

// Input
bool IsMouseButtonDown(int button);
bool IsMouseButtonPressed(int button);
bool IsMouseButtonReleased(int button);
struct RL_Vector2 GetMousePosition(void);
float GetMouseWheelMove(void);
bool IsKeyPressed(int key);
bool IsKeyDown(int key);

// Keyboard keys
enum { KEY_F = 70, KEY_S = 83, KEY_D = 68, KEY_R = 82, KEY_NULL = 0 };
enum { MOUSE_LEFT_BUTTON = 0, MOUSE_RIGHT_BUTTON = 1 };
]]

-- Load raylib
local raylib = ffi.load("raylib")

-- ============================================================================
-- Argile-to-Raylib Color conversion
-- ============================================================================

local function argile_to_raylib_color(c)
    return ffi.new("struct RL_Color", {
        r = math.floor((c.r or 0) * 255),
        g = math.floor((c.g or 0) * 255),
        b = math.floor((c.b or 0) * 255),
        a = math.floor((c.a or 1) * 255)
    })
end

-- ============================================================================
-- Text Measurement Callback
-- ============================================================================
-- New FFI-friendly signature: int32_t (*)(StringSlice*, TextConfig*, void*, Dimensions*)

local text_measure_callback = nil
local default_font = nil

local function init_text_measure_callback()
    default_font = raylib.GetFontDefault()
    
    text_measure_callback = ffi.cast(
        "int32_t (*)(struct StringSlice*, struct TextConfig*, void*, struct Dimensions*)",
        function(text_slice_ptr, text_config, user_data, out_dims)
            local text_slice = text_slice_ptr[0]
            local text = ""
            if text_slice.chars ~= nil and text_slice.length > 0 then
                text = ffi.string(text_slice.chars, tonumber(text_slice.length))
            end
            
            local font_size = 16
            if text_config ~= nil then
                font_size = tonumber(text_config.fontSize) or 16
            end
            
            local m = raylib.MeasureTextEx(default_font, text, font_size, 0)
            out_dims.width = m.x
            out_dims.height = m.y
            return 1  -- success
        end
    )
end

-- ============================================================================
-- Render Command Dispatch
-- ============================================================================

local function draw_rectangle(cmd)
    local c = cmd.renderData.rectangle.backgroundColor
    local r = tonumber(cmd.renderData.rectangle.cornerRadius.topLeft or 0)
    local rc = argile_to_raylib_color(c)
    
    if r > 0 then
        local rec = ffi.new("struct RL_Rectangle", {
            x = cmd.boundingBox.x,
            y = cmd.boundingBox.y,
            width = cmd.boundingBox.width,
            height = cmd.boundingBox.height
        })
        -- roundness is ratio of corner radius to smaller side
        local roundness = math.min(1.0, r / math.min(cmd.boundingBox.width, cmd.boundingBox.height))
        raylib.DrawRectangleRounded(rec, roundness, 8, rc)
    else
        raylib.DrawRectangle(
            math.floor(cmd.boundingBox.x),
            math.floor(cmd.boundingBox.y),
            math.floor(cmd.boundingBox.width),
            math.floor(cmd.boundingBox.height),
            rc
        )
    end
end

local function draw_border(cmd)
    local b = cmd.renderData.border
    local w = math.max(tonumber(b.width.left), tonumber(b.width.right), 
                       tonumber(b.width.top), tonumber(b.width.bottom))
    if w <= 0 then return end
    
    local r = tonumber(b.cornerRadius.topLeft or 0)
    local bc = argile_to_raylib_color(b.color)
    
    if r > 0 then
        local rec = ffi.new("struct RL_Rectangle", {
            x = cmd.boundingBox.x + w * 0.5,
            y = cmd.boundingBox.y + w * 0.5,
            width = math.max(0, cmd.boundingBox.width - w),
            height = math.max(0, cmd.boundingBox.height - w)
        })
        local roundness = math.min(1.0, r / math.min(cmd.boundingBox.width, cmd.boundingBox.height))
        raylib.DrawRectangleLinesEx(rec, w, bc)
    else
        raylib.DrawRectangleLines(
            math.floor(cmd.boundingBox.x),
            math.floor(cmd.boundingBox.y),
            math.floor(cmd.boundingBox.width),
            math.floor(cmd.boundingBox.height),
            bc
        )
    end
end

local function draw_text(cmd)
    local t = cmd.renderData.text
    local slice = t.stringContents
    if slice == nil or slice.chars == nil or slice.length <= 0 then return end
    
    local s = ffi.string(slice.chars, tonumber(slice.length))
    local tc = argile_to_raylib_color(t.textColor)
    local font_size = tonumber(t.fontSize) or 16
    
    raylib.DrawText(s, 
        math.floor(cmd.boundingBox.x), 
        math.floor(cmd.boundingBox.y), 
        font_size, 
        tc
    )
end

local function draw_paint(cmd)
    local p = cmd.renderData.paint
    if p == nil or p.ops == nil or p.count <= 0 then return end
    local ox = cmd.boundingBox.x
    local oy = cmd.boundingBox.y

    local fill_color = argile_to_raylib_color({r=1, g=1, b=1, a=1})
    local stroke_color = argile_to_raylib_color({r=1, g=1, b=1, a=1})
    local stroke_width = 1

    local i = 0
    while i < tonumber(p.count) do
        local op = p.ops[i]
        local kind = tonumber(op.kind)
        if kind == argile.PAINT_OP_FILL then
            fill_color = argile_to_raylib_color(op.color)
        elseif kind == argile.PAINT_OP_STROKE then
            stroke_color = argile_to_raylib_color(op.color)
            stroke_width = tonumber(op.width)
        elseif kind == argile.PAINT_OP_RECT then
            raylib.DrawRectangle(
                math.floor(ox + op.x), 
                math.floor(oy + op.y), 
                math.floor(op.w), 
                math.floor(op.h), 
                fill_color
            )
        elseif kind == argile.PAINT_OP_ROUND_RECT then
            local rec = ffi.new("struct RL_Rectangle", {
                x = ox + op.x,
                y = oy + op.y,
                width = op.w,
                height = op.h
            })
            local roundness = math.min(1.0, op.r / math.min(op.w, op.h))
            raylib.DrawRectangleRounded(rec, roundness, 8, fill_color)
        elseif kind == argile.PAINT_OP_CIRCLE then
            raylib.DrawCircle(
                math.floor(ox + op.x), 
                math.floor(oy + op.y), 
                op.r, 
                fill_color
            )
        elseif kind == argile.PAINT_OP_LINE then
            local start_pos = ffi.new("struct RL_Vector2", { x = ox + op.x, y = oy + op.y })
            local end_pos = ffi.new("struct RL_Vector2", { x = ox + op.x2, y = oy + op.y2 })
            raylib.DrawLineEx(start_pos, end_pos, stroke_width, stroke_color)
        end
        i = i + 1
    end
end

-- ============================================================================
-- Main Demo
-- ============================================================================

local arena_bytes = 256 * 1024 * 1024
local arena_mem
local ctx
local demo_ids = ffi.new("struct ArgileDemoIds")

-- State toggles
local demo_focus = false
local demo_selected = false
local demo_disabled = false

-- Input tracking
local prev_pointer_down = false

local function init_argile()
    arena_mem = C.malloc(arena_bytes)
    if arena_mem == nil then
        error("Failed to allocate arena memory")
    end
    
    local arena = argile.CreateArenaWithCapacityAndMemory(arena_bytes, arena_mem)
    local dims = ffi.new("struct Dimensions", { width = 1280, height = 720 })
    ctx = argile.Initialize(arena, dims)
    if ctx == nil then
        error("Argile Initialize failed")
    end
    
    -- Verify API version
    local api_version = tonumber(argile.GetApiVersion())
    if api_version ~= tonumber(argile.ARGILE_API_VERSION) then
        error(("API version mismatch: got %d, expected %d"):format(api_version, argile.ARGILE_API_VERSION))
    end
    
    -- Check if scene exports are available
    if argile.ArgileDemoGetIds == nil then
        error("ArgileDemoGetIds not found. Scene modules may not be loaded.")
    end
    
    -- Get demo element IDs
    argile.ArgileDemoGetIds(demo_ids)
    
    -- Set text measure callback
    init_text_measure_callback()
end

local function cleanup()
    if arena_mem ~= nil then
        C.free(arena_mem)
        arena_mem = nil
    end
end

local function build_frame_input(dt)
    local ww = raylib.GetScreenWidth()
    local hh = raylib.GetScreenHeight()
    local mp = raylib.GetMousePosition()
    local down = raylib.IsMouseButtonDown(raylib.MOUSE_LEFT_BUTTON)
    local pressed = raylib.IsMouseButtonPressed(raylib.MOUSE_LEFT_BUTTON)
    local released = raylib.IsMouseButtonReleased(raylib.MOUSE_LEFT_BUTTON)
    local scroll = raylib.GetMouseWheelMove()
    
    local input = ffi.new("struct ArgileFrameInput")
    input.width = ww
    input.height = hh
    input.pointer_x = mp.x
    input.pointer_y = mp.y
    input.pointer_down = down
    input.pointer_pressed = pressed
    input.pointer_released = released
    input.scroll_delta_x = 0
    input.scroll_delta_y = scroll
    input.delta_time = dt
    
    return input
end

local function handle_input(dt)
    -- Key toggles
    if raylib.IsKeyPressed(raylib.KEY_F) then
        demo_focus = not demo_focus
    elseif raylib.IsKeyPressed(raylib.KEY_S) then
        demo_selected = not demo_selected
    elseif raylib.IsKeyPressed(raylib.KEY_D) then
        demo_disabled = not demo_disabled
    elseif raylib.IsKeyPressed(raylib.KEY_R) then
        demo_focus = false
        demo_selected = false
        demo_disabled = false
    end
end

-- ============================================================================
-- Main Loop
-- ============================================================================

raylib.InitWindow(1280, 720, "Argile + Raylib (Portable Scene ABI Demo)")
raylib.SetTargetFPS(60)

init_argile()

local prev_time = 0

while not raylib.WindowShouldClose() do
    local current_time = raylib.GetTime()
    local dt = current_time - prev_time
    prev_time = current_time
    
    -- Handle input
    handle_input(dt)
    
    -- Build frame input
    local input = build_frame_input(dt)
    
    -- Set element states
    argile.SetElementFocusedForContext(ctx, demo_ids.card, demo_focus)
    argile.SetElementSelectedForContext(ctx, demo_ids.card, demo_selected)
    argile.SetElementDisabledForContext(ctx, demo_ids.card, demo_disabled)
    
    -- Call portable scene frame function
    local cmd_count = tonumber(argile.ArgileDemoFrameForContext(ctx, input))
    local cmd_buffer = argile.GetRenderCommandBufferForContext(ctx)
    
    -- Render
    raylib.BeginDrawing()
    raylib.ClearBackground(ffi.new("struct RL_Color", {r=15, g=20, b=30, a=255}))
    
    if cmd_buffer ~= nil then
        for i = 0, cmd_count - 1 do
            local cmd = cmd_buffer[i]
            local cmd_type = tonumber(cmd.commandType)
            
            if cmd_type == argile.RENDER_RECTANGLE then
                draw_rectangle(cmd)
            elseif cmd_type == argile.RENDER_BORDER then
                draw_border(cmd)
            elseif cmd_type == argile.RENDER_TEXT then
                draw_text(cmd)
            elseif cmd_type == argile.RENDER_PAINT then
                draw_paint(cmd)
            end
        end
    end
    
    -- Debug HUD (using raylib text drawing)
    local hud_y = 10
    local hud_color = ffi.new("struct RL_Color", {r=255, g=255, b=255, a=255})
    raylib.DrawText(("Argile commands: %d"):format(cmd_count), 10, hud_y, 20, hud_color)
    raylib.DrawText(("FPS: %d"):format(raylib.GetFPS()), 10, hud_y + 25, 20, hud_color)
    raylib.DrawText(("States: [F]ocus=%s [S]elected=%s [D]isabled=%s [R]eset"):format(
        tostring(demo_focus), tostring(demo_selected), tostring(demo_disabled)
    ), 10, hud_y + 50, 20, hud_color)
    raylib.DrawText("Portable ArgileDemoFrameForContext()", 10, hud_y + 75, 20, hud_color)
    
    raylib.EndDrawing()
end

cleanup()
raylib.CloseWindow()
