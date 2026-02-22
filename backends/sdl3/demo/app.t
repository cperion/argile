-- SDL3 + SDL_ttf Backend Demo for Argile
-- Simplified version following working pattern from parent directory

local bindings = require("backends.sdl3.bindings")
local C = bindings.C
local arg = bindings.arg
local sdl = bindings.sdl

-- Default font path
local DEFAULT_FONT_PATH = "/usr/share/fonts/liberation-narrow/LiberationSansNarrow-Regular.ttf"

-- SDL event types (from SDL_events.h)
local SDL_EVENT_QUIT = 0x100
local SDL_EVENT_KEY_DOWN = 0x300
local SDL_EVENT_MOUSE_MOTION = 0x400
local SDL_EVENT_MOUSE_BUTTON_DOWN = 0x401
local SDL_EVENT_MOUSE_BUTTON_UP = 0x402
local SDL_EVENT_MOUSE_WHEEL = 0x403

-- Keycodes (ASCII values)
local SDLK_F = 0x66  -- 'f'
local SDLK_S = 0x73  -- 's'
local SDLK_D = 0x64  -- 'd'
local SDLK_R = 0x72  -- 'r'

-- State struct to hold SDL resources (following working pattern)
local struct DemoState {
    renderer : &sdl.SDL_Renderer,
    window : &sdl.SDL_Window,
    font : &sdl.TTF_Font,
}

terra color_to_u8(v: float) : uint8
    if v < 0.0 then return 0 end
    if v > 1.0 then return 255 end
    return [uint8](v * 255.0 + 0.5)
end

terra dup_cstring(s: arg.StringSlice) : &int8
    if s.chars == nil or s.length <= 0 then
        return nil
    end
    var n = s.length
    var p = [&int8](C.malloc([uint64](n + 1)))
    if p == nil then
        return nil
    end
    C.memcpy(p, s.chars, [uint64](n))
    p[n] = 0
    return p
end

terra measure_text_callback(text: &arg.StringSlice, config: &arg.TextConfig, _user_data: &opaque, out: &arg.Dimensions) : int32
    if out == nil then return 0 end
    
    out.width = 0.0
    out.height = 0.0
    
    if text == nil then return 1 end
    
    -- Simple estimation
    var font_size: int = 16
    if config ~= nil and config.fontSize > 0 then
        font_size = [int](config.fontSize)
    end
    
    var char_count: int = [int](text.length)
    if char_count < 0 then char_count = 0 end
    
    out.width = [float](char_count) * [float](font_size) * 0.6
    out.height = [float](font_size)
    
    return 1
end

terra draw_rectangle(renderer: &sdl.SDL_Renderer, cmd: &arg.RenderCommand)
    var bb = cmd.boundingBox
    var color = cmd.renderData.rectangle.backgroundColor
    var r: sdl.SDL_FRect
    r.x = bb.x
    r.y = bb.y
    r.w = bb.width
    r.h = bb.height
    sdl.SDL_SetRenderDrawColor(renderer, color_to_u8(color.r), color_to_u8(color.g), color_to_u8(color.b), color_to_u8(color.a))
    sdl.SDL_RenderFillRect(renderer, &r)
end

terra draw_border(renderer: &sdl.SDL_Renderer, cmd: &arg.RenderCommand)
    var bb = cmd.boundingBox
    var b = cmd.renderData.border
    var color = b.color
    
    sdl.SDL_SetRenderDrawColor(renderer, color_to_u8(color.r), color_to_u8(color.g), color_to_u8(color.b), color_to_u8(color.a))
    
    var w: uint16 = b.width.left
    if b.width.right > w then w = b.width.right end
    if b.width.top > w then w = b.width.top end
    if b.width.bottom > w then w = b.width.bottom end
    if w == 0 then return end
    
    var top: sdl.SDL_FRect
    top.x = bb.x
    top.y = bb.y
    top.w = bb.width
    top.h = [float](w)
    sdl.SDL_RenderFillRect(renderer, &top)
    
    var bottom: sdl.SDL_FRect
    bottom.x = bb.x
    bottom.y = bb.y + bb.height - [float](w)
    bottom.w = bb.width
    bottom.h = [float](w)
    sdl.SDL_RenderFillRect(renderer, &bottom)
    
    var left: sdl.SDL_FRect
    left.x = bb.x
    left.y = bb.y
    left.w = [float](w)
    left.h = bb.height
    sdl.SDL_RenderFillRect(renderer, &left)
    
    var right: sdl.SDL_FRect
    right.x = bb.x + bb.width - [float](w)
    right.y = bb.y
    right.w = [float](w)
    right.h = bb.height
    sdl.SDL_RenderFillRect(renderer, &right)
end

-- Following working pattern: pass font explicitly, use direct C calls
terra draw_text(renderer: &sdl.SDL_Renderer, font: &sdl.TTF_Font, cmd: &arg.RenderCommand)
    if font == nil then return end
    
    var t = cmd.renderData.text
    if t.stringContents.chars == nil or t.stringContents.length <= 0 then
        return
    end
    
    var text_ptr = t.stringContents.chars
    var text_len = t.stringContents.length
    
    -- Create SDL_Color by value (following working pattern)
    var color: sdl.SDL_Color
    color.r = color_to_u8(t.textColor.r)
    color.g = color_to_u8(t.textColor.g)
    color.b = color_to_u8(t.textColor.b)
    color.a = color_to_u8(t.textColor.a)
    
    -- Use direct C function call (following working pattern)
    var surface = sdl.TTF_RenderText_Blended(font, text_ptr, [uint64](text_len), color)
    if surface == nil then return end
    
    var texture = sdl.SDL_CreateTextureFromSurface(renderer, surface)
    sdl.SDL_DestroySurface(surface)
    
    if texture == nil then return end
    
    var bb = cmd.boundingBox
    var dst: sdl.SDL_FRect
    dst.x = bb.x
    dst.y = bb.y
    
    var tex_w: float = 0
    var tex_h: float = 0
    sdl.SDL_GetTextureSize(texture, &tex_w, &tex_h)
    dst.w = tex_w
    dst.h = tex_h
    
    sdl.SDL_RenderTexture(renderer, texture, nil, &dst)
    sdl.SDL_DestroyTexture(texture)
end

terra draw_paint(renderer: &sdl.SDL_Renderer, cmd: &arg.RenderCommand)
    var p = cmd.renderData.paint
    if p.ops == nil or p.count == 0 then return end
    
    var ox = cmd.boundingBox.x
    var oy = cmd.boundingBox.y
    
    var i: uint32 = 0
    while i < p.count do
        var op = p.ops[i]
        if op.kind == [uint8](arg.PAINT_OP_RECT) then
            var r: sdl.SDL_FRect
            r.x = ox + op.x
            r.y = oy + op.y
            r.w = op.w
            r.h = op.h
            sdl.SDL_SetRenderDrawColor(renderer, color_to_u8(op.color.r), color_to_u8(op.color.g), color_to_u8(op.color.b), color_to_u8(op.color.a))
            sdl.SDL_RenderFillRect(renderer, &r)
        elseif op.kind == [uint8](arg.PAINT_OP_LINE) then
            sdl.SDL_SetRenderDrawColor(renderer, color_to_u8(op.color.r), color_to_u8(op.color.g), color_to_u8(op.color.b), color_to_u8(op.color.a))
            sdl.SDL_RenderLine(renderer, ox + op.x, oy + op.y, ox + op.x2, oy + op.y2)
        end
        i = i + 1
    end
end

-- Pass state struct to access font (following working pattern)
terra render_commands(state: &DemoState, cmds: &arg.RenderCommand, count: int32)
    if cmds == nil or count <= 0 then return end
    
    var i: int32 = 0
    while i < count do
        var cmd = &cmds[i]
        if cmd.commandType == [uint8](arg.RENDER_RECTANGLE) then
            draw_rectangle(state.renderer, cmd)
        elseif cmd.commandType == [uint8](arg.RENDER_BORDER) then
            draw_border(state.renderer, cmd)
        elseif cmd.commandType == [uint8](arg.RENDER_TEXT) then
            -- Pass font from state (following working pattern)
            draw_text(state.renderer, state.font, cmd)
        elseif cmd.commandType == [uint8](arg.RENDER_PAINT) then
            draw_paint(state.renderer, cmd)
        end
        i = i + 1
    end
end

terra run_demo() : int32
    -- Initialize SDL
    if not sdl.SDL_Init(0x00000020) then  -- SDL_INIT_VIDEO
        C.printf("SDL_Init failed\n")
        return 1
    end
    
    -- Initialize TTF
    if not sdl.TTF_Init() then
        C.printf("TTF_Init failed\n")
        sdl.SDL_Quit()
        return 1
    end
    
    -- Create state struct (following working pattern)
    var state: DemoState
    state.renderer = nil
    state.window = nil
    state.font = nil
    
    -- Load font into state
    state.font = sdl.TTF_OpenFont(DEFAULT_FONT_PATH, 16.0)
    if state.font == nil then
        C.printf("Failed to load font: %s\n", DEFAULT_FONT_PATH)
        sdl.TTF_Quit()
        sdl.SDL_Quit()
        return 1
    end
    
    -- Create window
    state.window = sdl.SDL_CreateWindow("Argile + SDL3 Demo", 1280, 720, 0)
    if state.window == nil then
        C.printf("Failed to create window\n")
        sdl.TTF_CloseFont(state.font)
        sdl.TTF_Quit()
        sdl.SDL_Quit()
        return 1
    end
    
    -- Create renderer
    state.renderer = sdl.SDL_CreateRenderer(state.window, nil)
    if state.renderer == nil then
        C.printf("Failed to create renderer\n")
        sdl.SDL_DestroyWindow(state.window)
        sdl.TTF_CloseFont(state.font)
        sdl.TTF_Quit()
        sdl.SDL_Quit()
        return 1
    end
    
    -- Initialize Argile
    var arena_bytes: uint64 = 256 * 1024 * 1024
    var arena_mem = C.malloc(arena_bytes)
    if arena_mem == nil then
        C.printf("Failed to allocate arena\n")
        sdl.SDL_DestroyRenderer(state.renderer)
        sdl.SDL_DestroyWindow(state.window)
        sdl.TTF_CloseFont(state.font)
        sdl.TTF_Quit()
        sdl.SDL_Quit()
        return 1
    end
    
    var arena = arg.CreateArenaWithCapacityAndMemory(arena_bytes, [&int8](arena_mem))
    var dims: arg.Dimensions
    dims.width = 1280.0
    dims.height = 720.0
    
    var ctx = arg.Initialize(arena, dims)
    if ctx == nil then
        C.printf("Argile Initialize failed\n")
        C.free(arena_mem)
        sdl.SDL_DestroyRenderer(state.renderer)
        sdl.SDL_DestroyWindow(state.window)
        sdl.TTF_CloseFont(state.font)
        sdl.TTF_Quit()
        sdl.SDL_Quit()
        return 1
    end
    
    if arg.GetApiVersion() ~= [uint32](arg.ARGILE_API_VERSION) then
        C.printf("API version mismatch\n")
        C.free(arena_mem)
        sdl.SDL_DestroyRenderer(state.renderer)
        sdl.SDL_DestroyWindow(state.window)
        sdl.TTF_CloseFont(state.font)
        sdl.TTF_Quit()
        sdl.SDL_Quit()
        return 1
    end
    
    var demo_ids: arg.ArgileDemoIds
    arg.ArgileDemoGetIds(&demo_ids)
    
    arg.SetMeasureTextFunctionForContext(ctx, measure_text_callback, nil)
    
    var demo_focus = false
    var demo_selected = false
    var demo_disabled = false
    var running = true
    var mouse_x: float = 0.0
    var mouse_y: float = 0.0
    var mouse_down = false
    var last_ticks = sdl.SDL_GetTicks()
    
    while running do
        var event: sdl.SDL_Event
        while sdl.SDL_PollEvent(&event) do
            if event.type == SDL_EVENT_QUIT then
                running = false
            elseif event.type == SDL_EVENT_KEY_DOWN then
                var key = event.key.key
                if key == SDLK_F then
                    demo_focus = not demo_focus
                elseif key == SDLK_S then
                    demo_selected = not demo_selected
                elseif key == SDLK_D then
                    demo_disabled = not demo_disabled
                elseif key == SDLK_R then
                    demo_focus = false
                    demo_selected = false
                    demo_disabled = false
                end
            elseif event.type == SDL_EVENT_MOUSE_MOTION then
                mouse_x = event.motion.x
                mouse_y = event.motion.y
            elseif event.type == SDL_EVENT_MOUSE_BUTTON_DOWN then
                mouse_down = true
            elseif event.type == SDL_EVENT_MOUSE_BUTTON_UP then
                mouse_down = false
            end
        end
        
        var ww: int = 0
        var wh: int = 0
        sdl.SDL_GetWindowSize(state.window, &ww, &wh)
        
        var now_ticks = sdl.SDL_GetTicks()
        var dt = [float](now_ticks - last_ticks) / 1000.0
        last_ticks = now_ticks
        
        var input: arg.ArgileFrameInput
        input.width = [float](ww)
        input.height = [float](wh)
        input.pointer_x = mouse_x
        input.pointer_y = mouse_y
        input.pointer_down = mouse_down
        input.pointer_pressed = false
        input.pointer_released = false
        input.scroll_delta_x = 0.0
        input.scroll_delta_y = 0.0
        input.delta_time = dt
        
        arg.SetElementFocusedForContext(ctx, demo_ids.card, demo_focus)
        arg.SetElementSelectedForContext(ctx, demo_ids.card, demo_selected)
        arg.SetElementDisabledForContext(ctx, demo_ids.card, demo_disabled)
        
        var cmd_count = arg.ArgileDemoFrameForContext(ctx, &input)
        var cmd_buffer = arg.GetRenderCommandBufferForContext(ctx)
        
        sdl.SDL_SetRenderDrawColor(state.renderer, 15, 20, 30, 255)
        sdl.SDL_RenderClear(state.renderer)
        
        -- Pass state to render_commands
        render_commands(&state, cmd_buffer, cmd_count)
        
        sdl.SDL_RenderPresent(state.renderer)
    end
    
    C.free(arena_mem)
    sdl.SDL_DestroyRenderer(state.renderer)
    sdl.SDL_DestroyWindow(state.window)
    sdl.TTF_CloseFont(state.font)
    sdl.TTF_Quit()
    sdl.SDL_Quit()
    return 0
end

return {
    run_demo = run_demo,
}
