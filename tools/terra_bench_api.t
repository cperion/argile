local ui = require("src.init")
local C = terralib.includecstring[[
    #include <stdlib.h>
]]

local api = {}

local g_ctx = global(ui.Context)
local g_arena = global(ui.Arena)
local g_mem = global(&int8, nil)
local g_initialized = global(bool, false)
local g_width = global(float, 800.0)
local g_height = global(float, 600.0)

terra api.measure_text(text: &ui.StringSlice, text_cfg: &ui.TextConfig, _user_data: &opaque, out: &ui.Dimensions) : int32
    if out == nil then
        return 0
    end

    if text ~= nil then
        out.width = [float](text.length * 8)
    else
        out.width = 0.0
    end

    if text_cfg ~= nil and text_cfg.lineHeight > 0 then
        out.height = [float](text_cfg.lineHeight)
    else
        out.height = 16.0
    end
    return 1
end

terra api.configure_box(ctx: &ui.Context, elem: &ui.LayoutElement, w: float, h: float, r: float, g: float, b: float)
    if ctx == nil or elem == nil then return end

    var lc: ui.LayoutConfig
    lc.sizing.width.type = ui.SIZING_FIXED
    lc.sizing.width.size.min = w
    lc.sizing.width.size.max = w
    lc.sizing.width.percent = 0
    lc.sizing.height.type = ui.SIZING_FIXED
    lc.sizing.height.size.min = h
    lc.sizing.height.size.max = h
    lc.sizing.height.percent = 0
    lc.padding.left = 0
    lc.padding.right = 0
    lc.padding.top = 0
    lc.padding.bottom = 0
    lc.childGap = 0
    lc.childAlignment.x = ui.ALIGN_X_LEFT
    lc.childAlignment.y = ui.ALIGN_Y_TOP
    lc.layoutDirection = ui.LEFT_TO_RIGHT
    elem.layoutConfig = ctx:storeLayoutConfig(lc)

    var shared: ui.SharedConfig
    shared.backgroundColor.r = r
    shared.backgroundColor.g = g
    shared.backgroundColor.b = b
    shared.backgroundColor.a = 255
    shared.cornerRadius.topLeft = 0
    shared.cornerRadius.topRight = 0
    shared.cornerRadius.bottomLeft = 0
    shared.cornerRadius.bottomRight = 0
    shared.userData = nil
    var shared_ptr = ctx:storeSharedConfig(shared)
    if shared_ptr ~= nil then
        var cu: ui.ElementConfigUnion
        cu.sharedConfig = shared_ptr
        ctx:attachElementConfig(cu, ui.CONFIG_SHARED)
    end
end

terra api.attach_border(ctx: &ui.Context, width: uint16, r: float, g: float, b: float)
    var border: ui.BorderConfig
    border.color.r = r
    border.color.g = g
    border.color.b = b
    border.color.a = 255
    border.width.left = width
    border.width.right = width
    border.width.top = width
    border.width.bottom = width
    border.width.betweenChildren = 0
    var border_ptr = ctx:storeBorderConfig(border)
    if border_ptr ~= nil then
        var cu: ui.ElementConfigUnion
        cu.borderConfig = border_ptr
        ctx:attachElementConfig(cu, ui.CONFIG_BORDER)
    end
end

terra api.attach_clip(ctx: &ui.Context, horizontal: bool, vertical: bool)
    var clip: ui.ClipConfig
    clip.horizontal = horizontal
    clip.vertical = vertical
    clip.childOffset.x = 0
    clip.childOffset.y = 0
    var clip_ptr = ctx:storeClipConfig(clip)
    if clip_ptr ~= nil then
        var cu: ui.ElementConfigUnion
        cu.clipConfig = clip_ptr
        ctx:attachElementConfig(cu, ui.CONFIG_CLIP)
    end
end

terra api.attach_custom(ctx: &ui.Context)
    var custom: ui.CustomConfig
    custom.customData = nil
    var custom_ptr = ctx:storeCustomConfig(custom)
    if custom_ptr ~= nil then
        var cu: ui.ElementConfigUnion
        cu.customConfig = custom_ptr
        ctx:attachElementConfig(cu, ui.CONFIG_CUSTOM)
    end
end

terra api.attach_image(ctx: &ui.Context)
    var image: ui.ImageConfig
    image.imageData = nil
    var image_ptr = ctx:storeImageConfig(image)
    if image_ptr ~= nil then
        var cu: ui.ElementConfigUnion
        cu.imageConfig = image_ptr
        ctx:attachElementConfig(cu, ui.CONFIG_IMAGE)
    end
end

terra api.build_nested :: {&ui.Context, int, int} -> {}
terra api.build_nested(ctx: &ui.Context, depth: int, branch: int)
    if depth <= 0 then
        return
    end

    var i = 0
    while i < branch do
        ui.OpenElement()
        var elem = ctx:getOpenLayoutElement()
        api.configure_box(ctx, elem, 20.0 + [float](depth), 20.0 + [float](depth), 80, 140, 240)

        if depth > 1 then
            api.build_nested(ctx, depth - 1, branch)
        end

        ui.CloseElement()
        i = i + 1
    end
end

terra api.bench_init(width: int, height: int, max_elements: int, arena_bytes: int) : int
    if g_mem ~= nil then
        C.free(g_mem)
        g_mem = nil
    end

    var bytes = arena_bytes
    if bytes <= 0 then
        bytes = 32 * 1024 * 1024
    end

    g_mem = [&int8](C.malloc([uint64](bytes)))
    if g_mem == nil then
        return 0
    end

    g_arena.nextAllocation = 0
    g_arena.capacity = [uint64](bytes)
    g_arena.memory = g_mem

    g_width = [float](width)
    g_height = [float](height)

    ui.SetCurrentContext(&g_ctx)
    var ok = g_ctx:initialize(&g_arena, max_elements)
    if not ok then
        C.free(g_mem)
        g_mem = nil
        g_initialized = false
        return 0
    end

    ui.SetCullingEnabled(false)
    ui.SetMeasureTextFunction(api.measure_text, nil)
    g_initialized = true
    return 1
end

terra api.bench_shutdown() : int
    if g_mem ~= nil then
        C.free(g_mem)
        g_mem = nil
    end
    g_initialized = false
    return 1
end

terra api.bench_frame_fixed_children(child_count: int) : int
    if not g_initialized then return -1 end

    ui.BeginLayout(g_width, g_height)

    var i = 0
    while i < child_count do
        ui.OpenElement()
        var elem = g_ctx:getOpenLayoutElement()
        if elem ~= nil then
            api.configure_box(&g_ctx, elem, 24.0, 24.0, 220, 120, 90)
        end
        ui.CloseElement()
        i = i + 1
    end

    var cmds = ui.EndLayout()
    if cmds == nil then return -1 end
    return cmds.length
end

terra api.bench_frame_nested(depth: int, branch: int) : int
    if not g_initialized then return -1 end

    ui.BeginLayout(g_width, g_height)
    api.build_nested(&g_ctx, depth, branch)

    var cmds = ui.EndLayout()
    if cmds == nil then return -1 end
    return cmds.length
end

terra api.bench_frame_text_rows(row_count: int) : int
    if not g_initialized then return -1 end

    ui.BeginLayout(g_width, g_height)

    var tc: ui.TextConfig
    tc.userData = nil
    tc.textColor.r = 255
    tc.textColor.g = 255
    tc.textColor.b = 255
    tc.textColor.a = 255
    tc.fontId = 0
    tc.fontSize = 14
    tc.letterSpacing = 0
    tc.lineHeight = 16
    tc.wrapMode = ui.TEXT_WRAP_WORDS
    tc.textAlignment = ui.TEXT_ALIGN_LEFT

    var s: ui.String
    s.isStaticallyAllocated = true
    s.length = 11
    s.chars = "hello world"

    var i = 0
    while i < row_count do
        ui.OpenTextElement(s, &tc)
        i = i + 1
    end

    var cmds = ui.EndLayout()
    if cmds == nil then return -1 end
    return cmds.length
end

terra api.bench_frame_dashboard(panel_count: int, widgets_per_panel: int) : int
    if not g_initialized then return -1 end
    ui.BeginLayout(g_width, g_height)

    var p = 0
    while p < panel_count do
        ui.OpenElement()
        var panel = g_ctx:getOpenLayoutElement()
        if panel ~= nil then
            api.configure_box(&g_ctx, panel, 360.0, 320.0, 25, 35, 50)
            panel.layoutConfig.layoutDirection = ui.TOP_TO_BOTTOM
            panel.layoutConfig.padding.left = 8
            panel.layoutConfig.padding.right = 8
            panel.layoutConfig.padding.top = 8
            panel.layoutConfig.padding.bottom = 8
            panel.layoutConfig.childGap = 4
            api.attach_border(&g_ctx, 1, 60, 70, 90)
        end

        var w = 0
        while w < widgets_per_panel do
            if w % 3 == 0 then
                var tc: ui.TextConfig
                tc.userData = nil
                tc.textColor.r = 230
                tc.textColor.g = 230
                tc.textColor.b = 240
                tc.textColor.a = 255
                tc.fontId = 0
                tc.fontSize = 13
                tc.letterSpacing = 0
                tc.lineHeight = 16
                tc.wrapMode = ui.TEXT_WRAP_WORDS
                tc.textAlignment = ui.TEXT_ALIGN_LEFT

                var s: ui.String
                s.isStaticallyAllocated = true
                s.length = 18
                s.chars = "widget title value"
                ui.OpenTextElement(s, &tc)
            else
                ui.OpenElement()
                var widget = g_ctx:getOpenLayoutElement()
                if widget ~= nil then
                    api.configure_box(&g_ctx, widget, 330.0, 24.0, 50, 80, 120)
                    if w % 2 == 0 then
                        api.attach_custom(&g_ctx)
                    else
                        api.attach_image(&g_ctx)
                    end
                end
                ui.CloseElement()
            end
            w = w + 1
        end

        ui.CloseElement()
        p = p + 1
    end

    var cmds = ui.EndLayout()
    if cmds == nil then return -1 end
    return cmds.length
end

terra api.bench_frame_clip_lists(list_count: int, rows_per_list: int) : int
    if not g_initialized then return -1 end
    ui.BeginLayout(g_width, g_height)

    var i = 0
    while i < list_count do
        ui.OpenElement()
        var list = g_ctx:getOpenLayoutElement()
        if list ~= nil then
            api.configure_box(&g_ctx, list, 280.0, 220.0, 20, 25, 32)
            list.layoutConfig.layoutDirection = ui.TOP_TO_BOTTOM
            list.layoutConfig.childGap = 2
            list.layoutConfig.padding.left = 4
            list.layoutConfig.padding.right = 4
            list.layoutConfig.padding.top = 4
            list.layoutConfig.padding.bottom = 4
            api.attach_clip(&g_ctx, true, true)
            api.attach_border(&g_ctx, 1, 40, 50, 70)
        end

        var r = 0
        while r < rows_per_list do
            ui.OpenElement()
            var row = g_ctx:getOpenLayoutElement()
            if row ~= nil then
                api.configure_box(&g_ctx, row, 260.0, 18.0, 70, 90, 110)
            end
            ui.CloseElement()
            r = r + 1
        end

        ui.CloseElement()
        i = i + 1
    end

    var cmds = ui.EndLayout()
    if cmds == nil then return -1 end
    return cmds.length
end

terra api.bench_frame_stress_mixed(element_count: int) : int
    if not g_initialized then return -1 end
    ui.BeginLayout(g_width, g_height)

    var i = 0
    while i < element_count do
        ui.OpenElement()
        var elem = g_ctx:getOpenLayoutElement()
        if elem ~= nil then
            var w = 16.0 + [float](i % 7) * 6.0
            var h = 12.0 + [float](i % 5) * 5.0
            api.configure_box(&g_ctx, elem, w, h, 30 + [float](i % 200), 40 + [float](i % 160), 80 + [float](i % 120))

            if i % 5 == 0 then
                api.attach_border(&g_ctx, 1, 180, 150, 90)
            elseif i % 5 == 1 then
                api.attach_custom(&g_ctx)
            elseif i % 5 == 2 then
                api.attach_image(&g_ctx)
            elseif i % 5 == 3 then
                var aspect: ui.AspectRatioConfig
                aspect.aspectRatio = 1.5
                var aspect_ptr = g_ctx:storeAspectRatioConfig(aspect)
                if aspect_ptr ~= nil then
                    var cu: ui.ElementConfigUnion
                    cu.aspectRatioConfig = aspect_ptr
                    g_ctx:attachElementConfig(cu, ui.CONFIG_ASPECT)
                end
            end
        end
        ui.CloseElement()
        i = i + 1
    end

    var cmds = ui.EndLayout()
    if cmds == nil then return -1 end
    return cmds.length
end

api.exports = {
    bench_init = api.bench_init,
    bench_shutdown = api.bench_shutdown,
    bench_frame_fixed_children = api.bench_frame_fixed_children,
    bench_frame_nested = api.bench_frame_nested,
    bench_frame_text_rows = api.bench_frame_text_rows,
    bench_frame_dashboard = api.bench_frame_dashboard,
    bench_frame_clip_lists = api.bench_frame_clip_lists,
    bench_frame_stress_mixed = api.bench_frame_stress_mixed,
}

return api
