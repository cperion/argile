-- Raylib Backend Demo for Argile (Pure Terra C interop)
-- Uses Terra-generated C bindings (terralib.includec / includecstring), not LuaJIT ffi/cdef.
-- Consumes the portable Argile scene ABI exported by build/libargile.so.
--
-- Platform note: raylib uses GLFW for windowing and may crash on some Wayland setups.
-- If that happens, try X11/XWayland (e.g. `GLFW_PLATFORM=x11` with a working DISPLAY).

local bindings = require("backends.raylib.bindings")
local C = bindings.C
local arg = bindings.arg
local ray = bindings.ray
local shim = bindings.shim

local KEY_F = 70
local KEY_S = 83
local KEY_D = 68
local KEY_R = 82
local MOUSE_LEFT_BUTTON = 0

struct RGBA8 {
    r : uint8;
    g : uint8;
    b : uint8;
    a : uint8;
}

terra clamp01(v: float) : float
    if v < 0.0 then return 0.0 end
    if v > 1.0 then return 1.0 end
    return v
end

terra to_u8_from_unit(v: float) : uint8
    var c = clamp01(v) * 255.0 + 0.5
    if c < 0.0 then c = 0.0 end
    if c > 255.0 then c = 255.0 end
    return [uint8](c)
end

terra argile_to_rgba8(c: arg.Color) : RGBA8
    return RGBA8 {
        r = to_u8_from_unit(c.r),
        g = to_u8_from_unit(c.g),
        b = to_u8_from_unit(c.b),
        a = to_u8_from_unit(c.a),
    }
end

terra unit_bg_color() : RGBA8
    return RGBA8 { r = 15, g = 20, b = 30, a = 255 }
end

terra white_color() : RGBA8
    return RGBA8 { r = 255, g = 255, b = 255, a = 255 }
end

terra dup_cstring_from_slice(s: arg.StringSlice) : &int8
    var n = s.length
    if n < 0 then
        n = 0
    end
    var p = [&int8](C.malloc([uint64](n + 1)))
    if p == nil then
        return nil
    end
    if s.chars ~= nil and n > 0 then
        C.memcpy(p, s.chars, [uint64](n))
    end
    p[n] = 0
    return p
end

terra compute_roundness(radius: float, width: float, height: float) : float
    if radius <= 0.0 then
        return 0.0
    end
    var min_side = width
    if height < min_side then
        min_side = height
    end
    if min_side <= 0.0 then
        return 0.0
    end
    var roundness = radius / min_side
    if roundness > 1.0 then
        roundness = 1.0
    end
    if roundness < 0.0 then
        roundness = 0.0
    end
    return roundness
end

terra measure_text_callback(text_slice: &arg.StringSlice, text_config: &arg.TextConfig, _user_data: &opaque, out_dims: &arg.Dimensions) : int32
    if out_dims == nil then
        return 0
    end

    out_dims.width = 0.0
    out_dims.height = 0.0

    if text_slice == nil then
        return 1
    end

    var tmp = dup_cstring_from_slice(@text_slice)
    if tmp == nil then
        return 0
    end

    var font_size: int32 = 16
    if text_config ~= nil and text_config.fontSize > 0 then
        font_size = [int32](text_config.fontSize)
    end

    out_dims.width = [float](ray.MeasureText(tmp, font_size))
    out_dims.height = [float](font_size)

    C.free(tmp)
    return 1
end

terra draw_rectangle(cmd: &arg.RenderCommand)
    var bb = cmd.boundingBox
    var r = cmd.renderData.rectangle.cornerRadius.topLeft
    var color = argile_to_rgba8(cmd.renderData.rectangle.backgroundColor)

    if r > 0.0 then
        var roundness = compute_roundness(r, bb.width, bb.height)
        shim.argile_ray_draw_rectangle_rounded_rgba(bb.x, bb.y, bb.width, bb.height, roundness, 8,
            color.r, color.g, color.b, color.a)
    else
        shim.argile_ray_draw_rectangle_rgba([int32](bb.x), [int32](bb.y), [int32](bb.width), [int32](bb.height),
            color.r, color.g, color.b, color.a)
    end
end

terra draw_border(cmd: &arg.RenderCommand)
    var b = cmd.renderData.border
    var w: uint16 = b.width.left
    if b.width.right > w then w = b.width.right end
    if b.width.top > w then w = b.width.top end
    if b.width.bottom > w then w = b.width.bottom end
    if w == 0 then
        return
    end

    var bb = cmd.boundingBox
    var color = argile_to_rgba8(b.color)
    var rx = bb.x + [float](w) * 0.5
    var ry = bb.y + [float](w) * 0.5
    var rw = bb.width - [float](w)
    var rh = bb.height - [float](w)
    if rw < 0.0 then rw = 0.0 end
    if rh < 0.0 then rh = 0.0 end
    shim.argile_ray_draw_rectangle_lines_ex_rgba(rx, ry, rw, rh, [float](w),
        color.r, color.g, color.b, color.a)
end

terra draw_text(cmd: &arg.RenderCommand)
    var t = cmd.renderData.text
    if t.stringContents.chars == nil or t.stringContents.length <= 0 then
        return
    end

    var tmp = dup_cstring_from_slice(t.stringContents)
    if tmp == nil then
        return
    end

    var color = argile_to_rgba8(t.textColor)
    var font_size: int32 = 16
    if t.fontSize > 0 then
        font_size = [int32](t.fontSize)
    end
    shim.argile_ray_draw_text_rgba(tmp, [int32](cmd.boundingBox.x), [int32](cmd.boundingBox.y), font_size,
        color.r, color.g, color.b, color.a)
    C.free(tmp)
end

terra draw_paint(cmd: &arg.RenderCommand)
    var p = cmd.renderData.paint
    if p.ops == nil or p.count == 0 then
        return
    end

    var ox = cmd.boundingBox.x
    var oy = cmd.boundingBox.y

    var fill_color = RGBA8 { r = 255, g = 255, b = 255, a = 255 }
    var stroke_color = RGBA8 { r = 255, g = 255, b = 255, a = 255 }
    var stroke_width: float = 1.0

    var i: uint32 = 0
    while i < p.count do
        var op = p.ops[i]
        if op.kind == [uint8](arg.PAINT_OP_FILL) then
            fill_color = argile_to_rgba8(op.color)
        elseif op.kind == [uint8](arg.PAINT_OP_STROKE) then
            stroke_color = argile_to_rgba8(op.color)
            stroke_width = [float](op.width)
        elseif op.kind == [uint8](arg.PAINT_OP_RECT) then
            shim.argile_ray_draw_rectangle_rgba([int32](ox + op.x), [int32](oy + op.y), [int32](op.w), [int32](op.h),
                fill_color.r, fill_color.g, fill_color.b, fill_color.a)
        elseif op.kind == [uint8](arg.PAINT_OP_ROUND_RECT) then
            var roundness = compute_roundness(op.r, op.w, op.h)
            shim.argile_ray_draw_rectangle_rounded_rgba(ox + op.x, oy + op.y, op.w, op.h, roundness, 8,
                fill_color.r, fill_color.g, fill_color.b, fill_color.a)
        elseif op.kind == [uint8](arg.PAINT_OP_CIRCLE) then
            shim.argile_ray_draw_circle_rgba([int32](ox + op.x), [int32](oy + op.y), op.r,
                fill_color.r, fill_color.g, fill_color.b, fill_color.a)
        elseif op.kind == [uint8](arg.PAINT_OP_LINE) then
            shim.argile_ray_draw_line_ex_rgba(ox + op.x, oy + op.y, ox + op.x2, oy + op.y2, stroke_width,
                stroke_color.r, stroke_color.g, stroke_color.b, stroke_color.a)
        end
        i = i + 1
    end
end

terra render_commands(cmds: &arg.RenderCommand, count: int32)
    if cmds == nil or count <= 0 then
        return
    end

    var i: int32 = 0
    while i < count do
        var cmd = &cmds[i]
        if cmd.commandType == [uint8](arg.RENDER_RECTANGLE) then
            draw_rectangle(cmd)
        elseif cmd.commandType == [uint8](arg.RENDER_BORDER) then
            draw_border(cmd)
        elseif cmd.commandType == [uint8](arg.RENDER_TEXT) then
            draw_text(cmd)
        elseif cmd.commandType == [uint8](arg.RENDER_PAINT) then
            draw_paint(cmd)
        end
        i = i + 1
    end
end

terra run_demo() : int32
    var arena_bytes: uint64 = 256 * 1024 * 1024
    var arena_mem = C.malloc(arena_bytes)
    if arena_mem == nil then
        C.printf("Argile raylib demo: failed to allocate arena memory\n")
        return 1
    end

    var arena = arg.CreateArenaWithCapacityAndMemory(arena_bytes, [&int8](arena_mem))
    var dims: arg.Dimensions
    dims.width = 1280.0
    dims.height = 720.0

    var ctx = arg.Initialize(arena, dims)
    if ctx == nil then
        C.printf("Argile raylib demo: Initialize failed\n")
        C.free(arena_mem)
        return 1
    end

    if arg.GetApiVersion() ~= [uint32](arg.ARGILE_API_VERSION) then
        C.printf("Argile raylib demo: API version mismatch (got %u expected %u)\n",
            arg.GetApiVersion(), [uint32](arg.ARGILE_API_VERSION))
        C.free(arena_mem)
        return 1
    end

    var demo_ids: arg.ArgileDemoIds
    arg.ArgileDemoGetIds(&demo_ids)

    arg.SetMeasureTextFunctionForContext(ctx, measure_text_callback, nil)

    var demo_focus = false
    var demo_selected = false
    var demo_disabled = false

    ray.InitWindow(1280, 720, "Argile + Raylib (Portable Scene ABI Demo)")
    ray.SetTargetFPS(60)

    while not ray.WindowShouldClose() do
        if shim.argile_ray_is_key_pressed_i32(KEY_F) ~= 0 then
            demo_focus = not demo_focus
        elseif shim.argile_ray_is_key_pressed_i32(KEY_S) ~= 0 then
            demo_selected = not demo_selected
        elseif shim.argile_ray_is_key_pressed_i32(KEY_D) ~= 0 then
            demo_disabled = not demo_disabled
        elseif shim.argile_ray_is_key_pressed_i32(KEY_R) ~= 0 then
            demo_focus = false
            demo_selected = false
            demo_disabled = false
        end

        var input: arg.ArgileFrameInput
        input.width = [float](ray.GetScreenWidth())
        input.height = [float](ray.GetScreenHeight())
        input.pointer_x = [float](shim.argile_ray_get_mouse_x_i32())
        input.pointer_y = [float](shim.argile_ray_get_mouse_y_i32())
        input.pointer_down = shim.argile_ray_is_mouse_button_down_i32(MOUSE_LEFT_BUTTON) ~= 0
        input.pointer_pressed = shim.argile_ray_is_mouse_button_pressed_i32(MOUSE_LEFT_BUTTON) ~= 0
        input.pointer_released = shim.argile_ray_is_mouse_button_released_i32(MOUSE_LEFT_BUTTON) ~= 0
        input.scroll_delta_x = 0.0
        input.scroll_delta_y = ray.GetMouseWheelMove()
        input.delta_time = ray.GetFrameTime()

        arg.SetElementFocusedForContext(ctx, demo_ids.card, demo_focus)
        arg.SetElementSelectedForContext(ctx, demo_ids.card, demo_selected)
        arg.SetElementDisabledForContext(ctx, demo_ids.card, demo_disabled)

        var cmd_count = arg.ArgileDemoFrameForContext(ctx, &input)
        var cmd_buffer = arg.GetRenderCommandBufferForContext(ctx)

        ray.BeginDrawing()
        var bg = unit_bg_color()
        shim.argile_ray_clear_background_rgba(bg.r, bg.g, bg.b, bg.a)
        render_commands(cmd_buffer, cmd_count)

        var hud = white_color()
        shim.argile_ray_draw_text_rgba("Argile + Raylib (Portable Scene ABI Demo)", 10, 10, 20, hud.r, hud.g, hud.b, hud.a)
        shim.argile_ray_draw_text_rgba("Mouse hover/click card. F=focus S=selected D=disabled R=reset", 10, 35, 18, hud.r, hud.g, hud.b, hud.a)
        shim.argile_ray_draw_text_rgba("Portable scene ABI: ArgileDemoFrameForContext()", 10, 58, 18, hud.r, hud.g, hud.b, hud.a)
        if demo_focus then
            shim.argile_ray_draw_text_rgba("focus=true", 10, 82, 18, hud.r, hud.g, hud.b, hud.a)
        else
            shim.argile_ray_draw_text_rgba("focus=false", 10, 82, 18, hud.r, hud.g, hud.b, hud.a)
        end
        if demo_selected then
            shim.argile_ray_draw_text_rgba("selected=true", 120, 82, 18, hud.r, hud.g, hud.b, hud.a)
        else
            shim.argile_ray_draw_text_rgba("selected=false", 120, 82, 18, hud.r, hud.g, hud.b, hud.a)
        end
        if demo_disabled then
            shim.argile_ray_draw_text_rgba("disabled=true", 260, 82, 18, hud.r, hud.g, hud.b, hud.a)
        else
            shim.argile_ray_draw_text_rgba("disabled=false", 260, 82, 18, hud.r, hud.g, hud.b, hud.a)
        end
        if input.pointer_down then
            shim.argile_ray_draw_text_rgba("mouse_down=true", 10, 104, 18, hud.r, hud.g, hud.b, hud.a)
        else
            shim.argile_ray_draw_text_rgba("mouse_down=false", 10, 104, 18, hud.r, hud.g, hud.b, hud.a)
        end
        ray.DrawFPS(10, 128)

        ray.EndDrawing()
    end

    ray.CloseWindow()
    C.free(arena_mem)
    return 0
end

return {
    run_demo = run_demo,
}
