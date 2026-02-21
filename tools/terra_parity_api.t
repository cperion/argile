local ui = require("src.init")
local C = terralib.includecstring[[
    #include <stdlib.h>
    #include <string.h>
]]

local api = {}

local MAX_PROBES = 200000
local SCENARIO_COUNT = 15
local ProbeIdBuffer = terralib.types.array(uint32, MAX_PROBES)

local g_ctx = global(ui.Context)
local g_arena = global(ui.Arena)
local g_mem = global(&int8, nil)
local g_initialized = global(bool, false)
local g_width = global(int32, 1920)
local g_height = global(int32, 1080)
local g_probe_ids = global(ProbeIdBuffer)
local g_probe_count = global(int32, 0)

terra api.measure_text(text: ui.StringSlice, text_cfg: &ui.TextConfig, user_data: &opaque) : ui.Dimensions
    var out: ui.Dimensions
    out.width = [float](text.length * 8)
    out.height = 16.0
    return out
end

terra api.make_string(chars: &int8) : ui.String
    var s: ui.String
    s.isStaticallyAllocated = true
    s.length = [int32](C.strlen(chars))
    s.chars = chars
    return s
end

terra api.make_id(base: &int8, index: uint32) : ui.ElementId
    return ui.GetElementIdWithIndex(api.make_string(base), index)
end

terra api.push_probe(id: ui.ElementId)
    if g_probe_count >= MAX_PROBES then
        return
    end
    g_probe_ids[g_probe_count] = id.id
    g_probe_count = g_probe_count + 1
end

terra api.configure_current(
    ctx: &ui.Context,
    width_type: ui.SizingType,
    width_min: float,
    width_max: float,
    width_percent: float,
    height_type: ui.SizingType,
    height_min: float,
    height_max: float,
    height_percent: float,
    dir: ui.LayoutDirection,
    pad: uint16,
    gap: uint16,
    r: float,
    g: float,
    b: float,
    a: float
)
    if ctx == nil then return end

    var elem = ctx:getOpenLayoutElement()
    if elem == nil then return end

    var lc: ui.LayoutConfig
    lc.sizing.width.type = width_type
    lc.sizing.width.size.min = width_min
    lc.sizing.width.size.max = width_max
    lc.sizing.width.percent = 0
    if width_type == ui.SIZING_PERCENT then
        lc.sizing.width.percent = width_percent
    end

    lc.sizing.height.type = height_type
    lc.sizing.height.size.min = height_min
    lc.sizing.height.size.max = height_max
    lc.sizing.height.percent = 0
    if height_type == ui.SIZING_PERCENT then
        lc.sizing.height.percent = height_percent
    end

    lc.padding.left = pad
    lc.padding.right = pad
    lc.padding.top = pad
    lc.padding.bottom = pad
    lc.childGap = gap
    lc.childAlignment.x = ui.ALIGN_X_LEFT
    lc.childAlignment.y = ui.ALIGN_Y_TOP
    lc.layoutDirection = dir

    elem.layoutConfig = ctx:storeLayoutConfig(lc)

    var shared: ui.SharedConfig
    shared.backgroundColor.r = r
    shared.backgroundColor.g = g
    shared.backgroundColor.b = b
    shared.backgroundColor.a = a
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

terra api.open_fixed_probe(ctx: &ui.Context, base: &int8, index: uint32, w: float, h: float, dir: ui.LayoutDirection, pad: uint16, gap: uint16, r: float, g: float, b: float, a: float)
    var id = api.make_id(base, index)
    ui.OpenElementWithIdForContext(ctx, id)
    api.configure_current(ctx,
        ui.SIZING_FIXED, w, w, 0.0,
        ui.SIZING_FIXED, h, h, 0.0,
        dir, pad, gap, r, g, b, a)
    api.push_probe(id)
end

terra api.open_fit_probe(ctx: &ui.Context, base: &int8, index: uint32, dir: ui.LayoutDirection, pad: uint16, gap: uint16, r: float, g: float, b: float, a: float)
    var id = api.make_id(base, index)
    ui.OpenElementWithIdForContext(ctx, id)
    api.configure_current(ctx,
        ui.SIZING_FIT, 0.0, 0.0, 0.0,
        ui.SIZING_FIT, 0.0, 0.0, 0.0,
        dir, pad, gap, r, g, b, a)
    api.push_probe(id)
end

terra api.open_percent_probe(ctx: &ui.Context, base: &int8, index: uint32, width_percent: float, dir: ui.LayoutDirection, pad: uint16, gap: uint16, r: float, g: float, b: float, a: float)
    var id = api.make_id(base, index)
    ui.OpenElementWithIdForContext(ctx, id)
    api.configure_current(ctx,
        ui.SIZING_PERCENT, 0.0, 0.0, width_percent,
        ui.SIZING_GROW, 0.0, 0.0, 0.0,
        dir, pad, gap, r, g, b, a)
    api.push_probe(id)
end

terra api.attach_border(ctx: &ui.Context, width: uint16, r: float, g: float, b: float, a: float)
    if ctx == nil then return end
    var border: ui.BorderConfig
    border.color.r = r
    border.color.g = g
    border.color.b = b
    border.color.a = a
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
    if ctx == nil then return end
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
    if ctx == nil then return end
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
    if ctx == nil then return end
    var image: ui.ImageConfig
    image.imageData = nil
    var image_ptr = ctx:storeImageConfig(image)
    if image_ptr ~= nil then
        var cu: ui.ElementConfigUnion
        cu.imageConfig = image_ptr
        ctx:attachElementConfig(cu, ui.CONFIG_IMAGE)
    end
end

terra api.attach_aspect(ctx: &ui.Context, ratio: float)
    if ctx == nil then return end
    var aspect: ui.AspectRatioConfig
    aspect.aspectRatio = ratio
    var aspect_ptr = ctx:storeAspectRatioConfig(aspect)
    if aspect_ptr ~= nil then
        var cu: ui.ElementConfigUnion
        cu.aspectRatioConfig = aspect_ptr
        ctx:attachElementConfig(cu, ui.CONFIG_ASPECT)
    end
end

terra api.attach_clip_offset(ctx: &ui.Context, horizontal: bool, vertical: bool, offset_x: float, offset_y: float)
    if ctx == nil then return end
    var clip: ui.ClipConfig
    clip.horizontal = horizontal
    clip.vertical = vertical
    clip.childOffset.x = offset_x
    clip.childOffset.y = offset_y
    var clip_ptr = ctx:storeClipConfig(clip)
    if clip_ptr ~= nil then
        var cu: ui.ElementConfigUnion
        cu.clipConfig = clip_ptr
        ctx:attachElementConfig(cu, ui.CONFIG_CLIP)
    end
end

terra api.attach_border_between(ctx: &ui.Context, width: uint16, between_children: uint16, r: float, g: float, b: float, a: float)
    if ctx == nil then return end
    var border: ui.BorderConfig
    border.color.r = r
    border.color.g = g
    border.color.b = b
    border.color.a = a
    border.width.left = width
    border.width.right = width
    border.width.top = width
    border.width.bottom = width
    border.width.betweenChildren = between_children
    var border_ptr = ctx:storeBorderConfig(border)
    if border_ptr ~= nil then
        var cu: ui.ElementConfigUnion
        cu.borderConfig = border_ptr
        ctx:attachElementConfig(cu, ui.CONFIG_BORDER)
    end
end

terra api.attach_point_from_index(idx: int32) : ui.AttachPoint
    var v = idx % 9
    if v == 0 then return ui.ATTACH_LEFT_TOP end
    if v == 1 then return ui.ATTACH_LEFT_CENTER end
    if v == 2 then return ui.ATTACH_LEFT_BOTTOM end
    if v == 3 then return ui.ATTACH_CENTER_TOP end
    if v == 4 then return ui.ATTACH_CENTER_CENTER end
    if v == 5 then return ui.ATTACH_CENTER_BOTTOM end
    if v == 6 then return ui.ATTACH_RIGHT_TOP end
    if v == 7 then return ui.ATTACH_RIGHT_CENTER end
    return ui.ATTACH_RIGHT_BOTTOM
end

terra api.attach_floating(
    ctx: &ui.Context,
    parent_id: uint32,
    attach_to: ui.AttachToElement,
    element_attach: ui.AttachPoint,
    parent_attach: ui.AttachPoint,
    offset_x: float,
    offset_y: float,
    z_index: int16,
    clip_to: ui.ClipToElement
)
    if ctx == nil then return end
    var floating: ui.FloatingConfig
    floating.offset.x = offset_x
    floating.offset.y = offset_y
    floating.expand.width = 0
    floating.expand.height = 0
    floating.parentId = parent_id
    floating.zIndex = z_index
    floating.attachPoints.element = element_attach
    floating.attachPoints.parent = parent_attach
    floating.pointerCaptureMode = ui.POINTER_CAPTURE
    floating.attachTo = attach_to
    floating.clipTo = clip_to
    var floating_ptr = ctx:storeFloatingConfig(floating)
    if floating_ptr ~= nil then
        var cu: ui.ElementConfigUnion
        cu.floatingConfig = floating_ptr
        ctx:attachElementConfig(cu, ui.CONFIG_FLOATING)
    end
end

terra api.text_cfg(
    ctx: &ui.Context,
    wrap_mode: ui.TextWrapMode,
    alignment: ui.TextAlignment,
    line_height: uint16,
    letter_spacing: uint16,
    font_size: uint16
) : &ui.TextConfig
    if ctx == nil then return nil end
    var tc: ui.TextConfig
    tc.userData = nil
    tc.textColor.r = 240
    tc.textColor.g = 240
    tc.textColor.b = 240
    tc.textColor.a = 255
    tc.fontId = 0
    tc.fontSize = font_size
    tc.letterSpacing = letter_spacing
    tc.lineHeight = line_height
    tc.wrapMode = wrap_mode
    tc.textAlignment = alignment
    return ctx:storeTextConfig(tc)
end

terra api.rng_next(state: &uint32) : uint32
    if state == nil then
        return 0
    end
    state[0] = state[0] * 1664525 + 1013904223
    return state[0]
end

terra api.scenario_fixed_grid(ctx: &ui.Context)
    var rows = 18
    var cols = 30
    var row_w = [float](g_width) - 28.0

    var root_id = api.make_id("s0_root", 0)
    ui.OpenElementWithIdForContext(ctx, root_id)
    api.configure_current(ctx,
        ui.SIZING_FIXED, [float](g_width) - 4.0, [float](g_width) - 4.0, 0.0,
        ui.SIZING_FIXED, [float](g_height) - 4.0, [float](g_height) - 4.0, 0.0,
        ui.TOP_TO_BOTTOM, 0, 0, 18, 24, 34, 255)

    var y = 0
    while y < rows do
        api.open_fixed_probe(ctx, "s0_row", [uint32](y), row_w, 18.0, ui.LEFT_TO_RIGHT, 1, 2, 32, 44, 62, 255)

        var x = 0
        while x < cols do
            var idx = y * cols + x
            var cw = 12.0 + [float](x % 5) * 2.0
            var ch = 10.0 + [float](y % 3) * 2.0
            api.open_fixed_probe(ctx, "s0_cell", [uint32](idx), cw, ch, ui.LEFT_TO_RIGHT, 0, 0, 76, 112, 166, 255)
            ui.CloseElementForContext(ctx)
            x = x + 1
        end

        ui.CloseElementForContext(ctx)
        y = y + 1
    end

    ui.CloseElementForContext(ctx)
end

terra api.build_nested_fit :: {&ui.Context, int32, int32, &int32} -> {}
terra api.build_nested_fit(ctx: &ui.Context, depth: int32, branch: int32, counter: &int32)
    if counter == nil then
        return
    end

    var idx = [uint32](counter[0])
    counter[0] = counter[0] + 1

    if depth > 1 then
        var dir = ui.TOP_TO_BOTTOM
        if depth % 2 == 0 then
            dir = ui.LEFT_TO_RIGHT
        end

        var r = 40.0 + [float](depth * 10)
        var g = 70.0 + [float](depth * 8)
        var b = 110.0 + [float](depth * 6)
        api.open_fit_probe(ctx, "s1_node", idx, dir, 1, 1, r, g, b, 255)

        var i = 0
        while i < branch do
            api.build_nested_fit(ctx, depth - 1, branch, counter)
            i = i + 1
        end
    else
        var w = 24.0 + [float](idx % 5) * 3.0
        var h = 14.0 + [float](idx % 4) * 2.0
        api.open_fixed_probe(ctx, "s1_node", idx, w, h, ui.LEFT_TO_RIGHT, 0, 0, 110, 148, 204, 255)
    end

    ui.CloseElementForContext(ctx)
end

terra api.scenario_nested(ctx: &ui.Context)
    var counter: int32 = 0
    api.build_nested_fit(ctx, 5, 3, &counter)
end

terra api.scenario_percent_and_grow(ctx: &ui.Context)
    api.open_fixed_probe(ctx, "s2_root", 0, [float](g_width) - 28.0, [float](g_height) - 28.0, ui.LEFT_TO_RIGHT, 4, 6, 20, 24, 30, 255)

    var p = 0
    while p < 4 do
        var split = 0.25
        if p == 0 then
            split = 0.20
        elseif p == 1 then
            split = 0.30
        elseif p == 2 then
            split = 0.25
        else
            split = 0.25
        end

        api.open_percent_probe(ctx, "s2_col", [uint32](p), split, ui.TOP_TO_BOTTOM, 3, 2,
            28 + [float](p * 8), 36 + [float](p * 6), 52 + [float](p * 7), 255)

        var i = 0
        while i < 35 do
            var idx = [uint32](p * 1000 + i)
            var id = api.make_id("s2_item", idx)
            ui.OpenElementWithIdForContext(ctx, id)
            api.configure_current(ctx,
                ui.SIZING_GROW, 0.0, 0.0, 0.0,
                ui.SIZING_FIXED, 10.0 + [float](i % 4), 10.0 + [float](i % 4), 0.0,
                ui.LEFT_TO_RIGHT, 0, 0, 70, 90, 120, 255)
            api.push_probe(id)
            ui.CloseElementForContext(ctx)
            i = i + 1
        end

        ui.CloseElementForContext(ctx)
        p = p + 1
    end

    ui.CloseElementForContext(ctx)
end

terra api.text_cfg_default(ctx: &ui.Context) : &ui.TextConfig
    if ctx == nil then return nil end
    var tc: ui.TextConfig
    tc.userData = nil
    tc.textColor.r = 240
    tc.textColor.g = 240
    tc.textColor.b = 240
    tc.textColor.a = 255
    tc.fontId = 0
    tc.fontSize = 14
    tc.letterSpacing = 0
    tc.lineHeight = 16
    tc.wrapMode = ui.TEXT_WRAP_WORDS
    tc.textAlignment = ui.TEXT_ALIGN_LEFT
    return ctx:storeTextConfig(tc)
end

terra api.scenario_text_flow(ctx: &ui.Context)
    api.open_fixed_probe(ctx, "s3_root", 0, [float](g_width) - 24.0, [float](g_height) - 24.0, ui.TOP_TO_BOTTOM, 3, 4, 16, 20, 26, 255)

    var short_text = api.make_string("argile parity short text")
    var med_text = api.make_string("argile parity medium text line for wrapping checks")
    var long_text = api.make_string("argile parity long text block with several words to force line breaks and exercise fit sizing in parent containers")

    var i = 0
    while i < 160 do
        var bw = 260.0 + [float](i % 3) * 30.0
        api.open_fit_probe(ctx, "s3_box", [uint32](i), ui.TOP_TO_BOTTOM, 2, 1, 52, 68, 92, 255)

        var box = ctx:getOpenLayoutElement()
        if box ~= nil and box.layoutConfig ~= nil then
            box.layoutConfig.sizing.width.type = ui.SIZING_FIXED
            box.layoutConfig.sizing.width.size.min = bw
            box.layoutConfig.sizing.width.size.max = bw
            box.layoutConfig.sizing.width.percent = 0
            box.layoutConfig.sizing.height.type = ui.SIZING_FIT
            box.layoutConfig.sizing.height.size.min = 0
            box.layoutConfig.sizing.height.size.max = ui.MAXFLOAT
            box.layoutConfig.sizing.height.percent = 0
        end

        var tc = api.text_cfg_default(ctx)
        if tc ~= nil then
            if i % 3 == 0 then
                ui.OpenTextElementForContext(ctx, short_text, tc)
            elseif i % 3 == 1 then
                ui.OpenTextElementForContext(ctx, med_text, tc)
            else
                ui.OpenTextElementForContext(ctx, long_text, tc)
            end
        end

        ui.CloseElementForContext(ctx)
        i = i + 1
    end

    ui.CloseElementForContext(ctx)
end

terra api.scenario_clip_lists(ctx: &ui.Context)
    var list_count = 10
    var rows_per = 90

    var root_id = api.make_id("s4_root", 0)
    ui.OpenElementWithIdForContext(ctx, root_id)
    api.configure_current(ctx,
        ui.SIZING_FIXED, [float](g_width) - 6.0, [float](g_width) - 6.0, 0.0,
        ui.SIZING_FIXED, [float](g_height) - 6.0, [float](g_height) - 6.0, 0.0,
        ui.LEFT_TO_RIGHT, 2, 2, 12, 16, 24, 255)

    var i = 0
    while i < list_count do
        api.open_fixed_probe(ctx, "s4_list", [uint32](i), 300.0, 210.0, ui.TOP_TO_BOTTOM, 3, 1, 20, 26, 34, 255)
        api.attach_clip(ctx, true, true)
        api.attach_border(ctx, 1, 38, 50, 70, 255)

        var r = 0
        while r < rows_per do
            var idx = [uint32](i * 1000 + r)
            api.open_fixed_probe(ctx, "s4_row", idx, 270.0, 15.0 + [float](r % 3), ui.LEFT_TO_RIGHT, 0, 0, 72, 95, 122, 255)
            ui.CloseElementForContext(ctx)
            r = r + 1
        end

        ui.CloseElementForContext(ctx)
        i = i + 1
    end

    ui.CloseElementForContext(ctx)
end

terra api.scenario_aspect_sweep(ctx: &ui.Context)
    api.open_fixed_probe(ctx, "s5_root", 0, [float](g_width) - 20.0, [float](g_height) - 20.0, ui.LEFT_TO_RIGHT, 2, 2, 18, 22, 30, 255)

    var i = 0
    while i < 420 do
        var w = 42.0 + [float](i % 8) * 8.0
        api.open_fixed_probe(ctx, "s5_card", [uint32](i), w, 18.0, ui.LEFT_TO_RIGHT, 0, 0, 62, 102, 152, 255)
        api.attach_aspect(ctx, 1.2 + [float](i % 6) * 0.1)
        ui.CloseElementForContext(ctx)
        i = i + 1
    end

    ui.CloseElementForContext(ctx)
end

terra api.scenario_mixed_stress(ctx: &ui.Context)
    var n = 3500

    var root_id = api.make_id("s6_root", 0)
    ui.OpenElementWithIdForContext(ctx, root_id)
    api.configure_current(ctx,
        ui.SIZING_FIXED, [float](g_width) - 6.0, [float](g_width) - 6.0, 0.0,
        ui.SIZING_FIXED, [float](g_height) - 6.0, [float](g_height) - 6.0, 0.0,
        ui.LEFT_TO_RIGHT, 2, 2, 10, 14, 20, 255)

    var i = 0
    while i < n do
        var w = 16.0 + [float](i % 7) * 5.0
        var h = 12.0 + [float](i % 5) * 4.0
        api.open_fixed_probe(ctx, "s6_elem", [uint32](i), w, h, ui.LEFT_TO_RIGHT, 0, 0,
            35.0 + [float](i % 170), 45.0 + [float](i % 140), 80.0 + [float](i % 120), 255.0)

        if i % 5 == 0 then
            api.attach_border(ctx, 1, 170, 145, 90, 255)
        elseif i % 5 == 1 then
            api.attach_custom(ctx)
        elseif i % 5 == 2 then
            api.attach_image(ctx)
        elseif i % 5 == 3 then
            api.attach_aspect(ctx, 1.1 + [float](i % 4) * 0.15)
        end

        ui.CloseElementForContext(ctx)
        i = i + 1
    end

    ui.CloseElementForContext(ctx)
end

terra api.scenario_floating_matrix(ctx: &ui.Context)
    api.open_fixed_probe(ctx, "s7_root", 0, [float](g_width) - 8.0, [float](g_height) - 8.0, ui.TOP_TO_BOTTOM, 4, 8, 16, 22, 30, 255)

    var row = 0
    while row < 2 do
        api.open_fixed_probe(ctx, "s7_row", [uint32](row), [float](g_width) - 24.0, 170.0, ui.LEFT_TO_RIGHT, 2, 14, 28, 36, 48, 255)
        var col = 0
        while col < 3 do
            var a = row * 3 + col
            api.open_fixed_probe(ctx, "s7_anchor", [uint32](a), 220.0, 110.0, ui.LEFT_TO_RIGHT, 2, 0, 62, 82, 110, 255)
            api.attach_border(ctx, 1, 90, 110, 136, 255)
            ui.CloseElementForContext(ctx)
            col = col + 1
        end
        ui.CloseElementForContext(ctx)
        row = row + 1
    end

    var i = 0
    while i < 18 do
        var w = 58.0 + [float](i % 3) * 9.0
        var h = 22.0 + [float](i % 2) * 7.0
        api.open_fixed_probe(ctx, "s7_float", [uint32](i), w, h, ui.LEFT_TO_RIGHT, 0, 0, 204, 112 + [float](i % 5) * 14.0, 96 + [float](i % 4) * 18.0, 255)

        var parent_id = api.make_id("s7_anchor", [uint32](i % 6)).id
        var clip_to = ui.CLIP_NONE
        if i % 3 == 0 then
            clip_to = ui.CLIP_ATTACHED_PARENT
        end
        api.attach_floating(
            ctx,
            parent_id,
            ui.ATTACH_ELEMENT_WITH_ID,
            api.attach_point_from_index(i),
            api.attach_point_from_index(i * 2 + 1),
            [float]((i % 5) - 2) * 7.0,
            [float]((i % 4) - 1) * 5.0,
            [int16](i % 7),
            clip_to
        )
        ui.CloseElementForContext(ctx)
        i = i + 1
    end

    api.open_fixed_probe(ctx, "s7_root_float", 0, 92.0, 30.0, ui.LEFT_TO_RIGHT, 0, 0, 248, 160, 92, 255)
    api.attach_floating(
        ctx,
        0,
        ui.ATTACH_ROOT,
        ui.ATTACH_RIGHT_BOTTOM,
        ui.ATTACH_RIGHT_BOTTOM,
        -36.0,
        -28.0,
        120,
        ui.CLIP_NONE
    )
    ui.CloseElementForContext(ctx)

    api.open_fixed_probe(ctx, "s7_parent_wrap", 0, 160.0, 90.0, ui.LEFT_TO_RIGHT, 2, 0, 34, 44, 58, 255)
    api.open_fixed_probe(ctx, "s7_parent_float", 0, 66.0, 32.0, ui.LEFT_TO_RIGHT, 0, 0, 236, 132, 100, 255)
    api.attach_floating(
        ctx,
        0,
        ui.ATTACH_PARENT,
        ui.ATTACH_RIGHT_BOTTOM,
        ui.ATTACH_LEFT_TOP,
        4.0,
        -6.0,
        64,
        ui.CLIP_NONE
    )
    ui.CloseElementForContext(ctx)
    ui.CloseElementForContext(ctx)

    ui.CloseElementForContext(ctx)
end

terra api.scenario_zindex_overlap(ctx: &ui.Context)
    api.open_fixed_probe(ctx, "s8_root", 0, [float](g_width) - 12.0, [float](g_height) - 12.0, ui.LEFT_TO_RIGHT, 4, 0, 12, 18, 24, 255)
    api.open_fixed_probe(ctx, "s8_anchor", 0, 620.0, 420.0, ui.LEFT_TO_RIGHT, 0, 0, 34, 48, 66, 255)
    ui.CloseElementForContext(ctx)

    var anchor_id = api.make_id("s8_anchor", 0).id
    var i = 0
    while i < 16 do
        api.open_fixed_probe(ctx, "s8_float", [uint32](i), 122.0, 48.0, ui.LEFT_TO_RIGHT, 0, 0, 160 + [float](i * 4), 100 + [float](i * 3), 84 + [float](i * 2), 220)
        api.attach_floating(
            ctx,
            anchor_id,
            ui.ATTACH_ELEMENT_WITH_ID,
            ui.ATTACH_LEFT_TOP,
            ui.ATTACH_LEFT_TOP,
            18.0 + [float](i % 4) * 7.0,
            22.0 + [float](i % 5) * 5.0,
            [int16](i - 8),
            ui.CLIP_NONE
        )
        ui.CloseElementForContext(ctx)
        i = i + 1
    end

    i = 0
    while i < 6 do
        api.open_fixed_probe(ctx, "s8_root_float", [uint32](i), 86.0, 34.0, ui.LEFT_TO_RIGHT, 0, 0, 220, 168, 102 + [float](i * 12), 255)
        api.attach_floating(
            ctx,
            0,
            ui.ATTACH_ROOT,
            ui.ATTACH_LEFT_TOP,
            ui.ATTACH_LEFT_TOP,
            26.0 + [float](i) * 5.0,
            42.0 + [float](i) * 3.0,
            [int16](100 + i),
            ui.CLIP_NONE
        )
        ui.CloseElementForContext(ctx)
        i = i + 1
    end

    ui.CloseElementForContext(ctx)
end

terra api.scenario_nested_clip_offsets(ctx: &ui.Context)
    api.open_fixed_probe(ctx, "s9_root", 0, [float](g_width) - 10.0, [float](g_height) - 10.0, ui.LEFT_TO_RIGHT, 2, 8, 14, 18, 24, 255)

    var lane = 0
    while lane < 3 do
        api.open_fixed_probe(ctx, "s9_outer", [uint32](lane), 420.0, 300.0, ui.TOP_TO_BOTTOM, 4, 2, 26, 32, 42, 255)
        api.attach_clip_offset(ctx, true, true, -30.0 - [float](lane) * 10.0, -20.0 - [float](lane) * 7.0)
        api.attach_border_between(ctx, 1, 1, 68, 86, 114, 255)

        var c = 0
        while c < 3 do
            var inner = lane * 10 + c
            api.open_fixed_probe(ctx, "s9_inner", [uint32](inner), 360.0, 220.0, ui.TOP_TO_BOTTOM, 2, 1, 44, 58, 78, 255)
            api.attach_clip_offset(ctx, true, true, -12.0 - [float](c) * 5.0, -18.0 - [float](c) * 4.0)
            var r = 0
            while r < 35 do
                var idx = [uint32](lane * 1000 + c * 100 + r)
                api.open_fixed_probe(ctx, "s9_row", idx, 340.0, 14.0 + [float](r % 3), ui.LEFT_TO_RIGHT, 0, 0, 76, 98, 124, 255)
                ui.CloseElementForContext(ctx)
                r = r + 1
            end
            ui.CloseElementForContext(ctx)
            c = c + 1
        end

        ui.CloseElementForContext(ctx)
        lane = lane + 1
    end

    ui.CloseElementForContext(ctx)
end

terra api.scenario_text_wrap_matrix(ctx: &ui.Context)
    api.open_fixed_probe(ctx, "s10_root", 0, [float](g_width) - 10.0, [float](g_height) - 10.0, ui.TOP_TO_BOTTOM, 3, 3, 18, 22, 28, 255)

    var text0 = api.make_string("short text for argile parity")
    var text1 = api.make_string("line one\nline two with newline wrapping")
    var text2 = api.make_string("long content for text wrapping checks across wrap modes and alignments in parity suite")

    var wrap = 0
    while wrap < 3 do
        var align = 0
        while align < 3 do
            var idx = wrap * 10 + align
            var bw = 220.0 + [float](align) * 36.0
            api.open_fit_probe(ctx, "s10_block", [uint32](idx), ui.TOP_TO_BOTTOM, 2, 1, 52 + [float](wrap * 18), 66 + [float](align * 11), 92 + [float](wrap * 9), 255)

            var box = ctx:getOpenLayoutElement()
            if box ~= nil and box.layoutConfig ~= nil then
                box.layoutConfig.sizing.width.type = ui.SIZING_FIXED
                box.layoutConfig.sizing.width.size.min = bw
                box.layoutConfig.sizing.width.size.max = bw
                box.layoutConfig.sizing.width.percent = 0
                box.layoutConfig.sizing.height.type = ui.SIZING_FIT
                box.layoutConfig.sizing.height.size.min = 0
                box.layoutConfig.sizing.height.size.max = ui.MAXFLOAT
                box.layoutConfig.sizing.height.percent = 0
            end

            var tc = api.text_cfg(ctx, [ui.TextWrapMode](wrap), [ui.TextAlignment](align), [uint16](14 + wrap * 2), [uint16](align), [uint16](13 + wrap))
            if tc ~= nil then
                if (wrap + align) % 3 == 0 then
                    ui.OpenTextElementForContext(ctx, text0, tc)
                elseif (wrap + align) % 3 == 1 then
                    ui.OpenTextElementForContext(ctx, text1, tc)
                else
                    ui.OpenTextElementForContext(ctx, text2, tc)
                end
            end
            ui.CloseElementForContext(ctx)
            align = align + 1
        end
        wrap = wrap + 1
    end

    ui.CloseElementForContext(ctx)
end

terra api.scenario_sizing_edge_cases(ctx: &ui.Context)
    api.open_fixed_probe(ctx, "s11_root", 0, [float](g_width) - 10.0, [float](g_height) - 10.0, ui.TOP_TO_BOTTOM, 4, 6, 16, 21, 28, 255)

    api.open_fixed_probe(ctx, "s11_h", 0, [float](g_width) - 40.0, 190.0, ui.LEFT_TO_RIGHT, 3, 4, 28, 36, 48, 255)
    var i = 0
    while i < 4 do
        var p = 0.40
        if i == 0 then p = 0.05 elseif i == 1 then p = 0.20 elseif i == 2 then p = 0.35 else p = 0.40 end
        var id = api.make_id("s11_pct", [uint32](i))
        ui.OpenElementWithIdForContext(ctx, id)
        api.configure_current(
            ctx,
            ui.SIZING_PERCENT, 0.0, 0.0, p,
            ui.SIZING_FIXED, 30.0 + [float](i) * 6.0, 30.0 + [float](i) * 6.0, 0.0,
            ui.LEFT_TO_RIGHT, 0, 0, 78 + [float](i * 20), 106, 142, 255
        )
        api.push_probe(id)
        ui.CloseElementForContext(ctx)
        i = i + 1
    end

    i = 0
    while i < 5 do
        var id = api.make_id("s11_grow", [uint32](i))
        ui.OpenElementWithIdForContext(ctx, id)
        api.configure_current(
            ctx,
            ui.SIZING_GROW, 0.0, 0.0, 0.0,
            ui.SIZING_FIXED, 26.0 + [float](i) * 4.0, 26.0 + [float](i) * 4.0, 0.0,
            ui.LEFT_TO_RIGHT, 0, 0, 126, 82 + [float](i * 12), 74 + [float](i * 8), 255
        )
        var e = ctx:getOpenLayoutElement()
        if e ~= nil and e.layoutConfig ~= nil then
            e.layoutConfig.sizing.width.size.min = 44.0 + [float](i) * 16.0
            e.layoutConfig.sizing.width.size.max = 96.0 + [float](i) * 22.0
        end
        api.push_probe(id)
        ui.CloseElementForContext(ctx)
        i = i + 1
    end
    ui.CloseElementForContext(ctx)

    api.open_fixed_probe(ctx, "s11_v", 0, 420.0, 280.0, ui.TOP_TO_BOTTOM, 3, 3, 30, 40, 56, 255)
    i = 0
    while i < 3 do
        var p = 0.60
        if i == 0 then p = 0.15 elseif i == 1 then p = 0.25 else p = 0.60 end
        var id = api.make_id("s11_vpct", [uint32](i))
        ui.OpenElementWithIdForContext(ctx, id)
        api.configure_current(
            ctx,
            ui.SIZING_GROW, 0.0, 0.0, 0.0,
            ui.SIZING_PERCENT, 0.0, 0.0, p,
            ui.LEFT_TO_RIGHT, 0, 0, 74 + [float](i * 22), 94 + [float](i * 14), 136, 255
        )
        api.push_probe(id)
        ui.CloseElementForContext(ctx)
        i = i + 1
    end
    ui.CloseElementForContext(ctx)

    ui.CloseElementForContext(ctx)
end

terra api.scenario_border_between_children(ctx: &ui.Context)
    api.open_fixed_probe(ctx, "s12_root", 0, [float](g_width) - 10.0, [float](g_height) - 10.0, ui.TOP_TO_BOTTOM, 4, 10, 16, 22, 30, 255)

    api.open_fixed_probe(ctx, "s12_h", 0, [float](g_width) - 26.0, 130.0, ui.LEFT_TO_RIGHT, 2, 8, 36, 46, 64, 255)
    api.attach_border_between(ctx, 2, 3, 176, 120, 74, 255)
    var i = 0
    while i < 8 do
        api.open_fixed_probe(ctx, "s12_hc", [uint32](i), 56.0 + [float](i % 3) * 12.0, 72.0, ui.LEFT_TO_RIGHT, 0, 0, 86, 112 + [float](i * 8), 146, 255)
        ui.CloseElementForContext(ctx)
        i = i + 1
    end
    ui.CloseElementForContext(ctx)

    api.open_fixed_probe(ctx, "s12_v", 0, 520.0, 280.0, ui.TOP_TO_BOTTOM, 2, 6, 28, 36, 52, 255)
    api.attach_border_between(ctx, 2, 4, 90, 168, 120, 255)
    i = 0
    while i < 10 do
        api.open_fixed_probe(ctx, "s12_vc", [uint32](i), 480.0, 18.0 + [float](i % 4) * 6.0, ui.LEFT_TO_RIGHT, 0, 0, 96, 124, 164, 255)
        ui.CloseElementForContext(ctx)
        i = i + 1
    end
    ui.CloseElementForContext(ctx)

    ui.CloseElementForContext(ctx)
end

terra api.scenario_relayout_phase(ctx: &ui.Context, phase: int32)
    api.open_fixed_probe(ctx, "s13_root", 0, [float](g_width) - 8.0, [float](g_height) - 8.0, ui.TOP_TO_BOTTOM, 3, 4, 14, 18, 24, 255)

    if phase == 0 then
        var i = 0
        while i < 120 do
            api.open_fixed_probe(ctx, "s13_box", [uint32](i), 120.0 + [float](i % 5) * 14.0, 18.0 + [float](i % 3) * 4.0, ui.LEFT_TO_RIGHT, 0, 0, 72, 88, 118, 255)
            if i % 6 == 0 then
                api.attach_clip_offset(ctx, true, false, -6.0, 0.0)
            end
            ui.CloseElementForContext(ctx)
            i = i + 1
        end
    elseif phase == 1 then
        var i = 0
        while i < 90 do
            api.open_fixed_probe(ctx, "s13_box", [uint32](i), 80.0 + [float](i % 4) * 18.0, 28.0 + [float](i % 5) * 5.0, ui.LEFT_TO_RIGHT, 0, 0, 90, 104, 130, 255)
            if i % 4 == 0 then
                api.attach_aspect(ctx, 1.1 + [float](i % 3) * 0.2)
            end
            ui.CloseElementForContext(ctx)
            i = i + 1
        end
    else
        api.open_fixed_probe(ctx, "s13_final_h", 0, [float](g_width) - 26.0, 220.0, ui.LEFT_TO_RIGHT, 2, 4, 34, 46, 66, 255)
        var i = 0
        while i < 40 do
            api.open_fixed_probe(ctx, "s13_final", [uint32](i), 26.0 + [float](i % 7) * 8.0, 24.0 + [float](i % 4) * 6.0, ui.LEFT_TO_RIGHT, 0, 0, 118, 146, 188, 255)
            if i % 3 == 0 then
                api.attach_aspect(ctx, 1.0 + [float](i % 5) * 0.12)
            end
            ui.CloseElementForContext(ctx)
            i = i + 1
        end
        ui.CloseElementForContext(ctx)
    end

    ui.CloseElementForContext(ctx)
end

terra api.scenario_seeded_fuzz(ctx: &ui.Context)
    var state: uint32 = 0xC0FFEE

    api.open_fixed_probe(ctx, "s14_root", 0, [float](g_width) - 8.0, [float](g_height) - 8.0, ui.LEFT_TO_RIGHT, 3, 3, 12, 16, 22, 255)

    var columns = 5
    var col_width = ([float](g_width) - 40.0) / [float](columns)
    var c = 0
    while c < columns do
        api.open_fixed_probe(ctx, "s14_col", [uint32](c), col_width, [float](g_height) - 40.0, ui.TOP_TO_BOTTOM, 2, 1, 24 + [float](c * 8), 32 + [float](c * 9), 46 + [float](c * 10), 255)

        var i = 0
        while i < 180 do
            var rv = api.rng_next(&state)
            var idx = [uint32](c * 1000 + i)
            var w = 14.0 + [float](rv % 56)
            var h = 12.0 + [float]((rv >> 8) % 38)

            var id = api.make_id("s14_elem", idx)
            ui.OpenElementWithIdForContext(ctx, id)

            var wt = ui.SIZING_FIXED
            var ht = ui.SIZING_FIXED
            if (rv % 8) == 0 then
                wt = ui.SIZING_GROW
            elseif (rv % 8) == 1 then
                wt = ui.SIZING_FIT
            end
            if (((rv >> 3) % 8)) == 0 then
                ht = ui.SIZING_GROW
            end

            api.configure_current(
                ctx,
                wt, w, w, 0.0,
                ht, h, h, 0.0,
                ui.LEFT_TO_RIGHT, 0, 0,
                64 + [float](rv % 160), 72 + [float]((rv >> 5) % 130), 82 + [float]((rv >> 11) % 120), 255
            )

            var e = ctx:getOpenLayoutElement()
            if e ~= nil and e.layoutConfig ~= nil and wt == ui.SIZING_GROW then
                e.layoutConfig.sizing.width.size.min = 18.0 + [float](rv % 22)
                e.layoutConfig.sizing.width.size.max = 74.0 + [float](rv % 54)
            end

            if (rv % 9) == 0 then
                api.attach_border(ctx, 1, 176, 136, 86, 255)
            elseif (rv % 9) == 1 then
                api.attach_custom(ctx)
            elseif (rv % 9) == 2 then
                api.attach_image(ctx)
            elseif (rv % 9) == 3 then
                api.attach_aspect(ctx, 1.0 + [float](rv % 5) * 0.17)
            elseif (rv % 9) == 4 then
                api.attach_clip_offset(ctx, true, false, -4.0, 0.0)
            end

            api.push_probe(id)

            if (rv % 11) == 0 then
                api.open_fixed_probe(ctx, "s14_leaf", idx, 8.0 + [float](rv % 20), 8.0 + [float]((rv >> 7) % 16), ui.LEFT_TO_RIGHT, 0, 0, 208, 154, 106, 255)
                ui.CloseElementForContext(ctx)
            end

            ui.CloseElementForContext(ctx)
            i = i + 1
        end

        ui.CloseElementForContext(ctx)
        c = c + 1
    end

    ui.CloseElementForContext(ctx)
end

terra api.run_scenario_internal(ctx: &ui.Context, index: int32) : bool
    if index == 0 then
        api.scenario_fixed_grid(ctx)
    elseif index == 1 then
        api.scenario_nested(ctx)
    elseif index == 2 then
        api.scenario_percent_and_grow(ctx)
    elseif index == 3 then
        api.scenario_text_flow(ctx)
    elseif index == 4 then
        api.scenario_clip_lists(ctx)
    elseif index == 5 then
        api.scenario_aspect_sweep(ctx)
    elseif index == 6 then
        api.scenario_mixed_stress(ctx)
    elseif index == 7 then
        api.scenario_floating_matrix(ctx)
    elseif index == 8 then
        api.scenario_zindex_overlap(ctx)
    elseif index == 9 then
        api.scenario_nested_clip_offsets(ctx)
    elseif index == 10 then
        api.scenario_text_wrap_matrix(ctx)
    elseif index == 11 then
        api.scenario_sizing_edge_cases(ctx)
    elseif index == 12 then
        api.scenario_border_between_children(ctx)
    elseif index == 13 then
        api.scenario_relayout_phase(ctx, 2)
    elseif index == 14 then
        api.scenario_seeded_fuzz(ctx)
    else
        return false
    end
    return true
end

terra api.parity_init(width: int32, height: int32, max_elements: int32, arena_bytes: int32) : int32
    if g_mem ~= nil then
        C.free(g_mem)
        g_mem = nil
    end

    var elems = max_elements
    if elems <= 0 then
        elems = 60000
    end

    var bytes = arena_bytes
    if bytes <= 0 then
        bytes = 512 * 1024 * 1024
    end

    g_width = width
    g_height = height
    g_mem = [&int8](C.malloc([uint64](bytes)))
    if g_mem == nil then
        g_initialized = false
        return 0
    end

    g_arena = ui.CreateArenaWithCapacityAndMemory([uint64](bytes), g_mem)
    if not ui.InitializeContext(&g_ctx, g_arena, elems) then
        C.free(g_mem)
        g_mem = nil
        g_initialized = false
        return 0
    end

    ui.SetCurrentContext(&g_ctx)
    ui.SetMeasureTextFunction(api.measure_text, nil)

    g_probe_count = 0
    g_initialized = true
    return 1
end

terra api.parity_shutdown() : int32
    ui.SetCurrentContext(nil)
    if g_mem ~= nil then
        C.free(g_mem)
        g_mem = nil
    end
    g_probe_count = 0
    g_initialized = false
    return 1
end

terra api.parity_scenario_count() : int32
    return SCENARIO_COUNT
end

terra api.parity_scenario_name(index: int32) : &int8
    if index == 0 then
        return "fixed_grid"
    elseif index == 1 then
        return "nested_fit"
    elseif index == 2 then
        return "percent_and_grow"
    elseif index == 3 then
        return "text_flow_fit"
    elseif index == 4 then
        return "clip_lists"
    elseif index == 5 then
        return "aspect_sweep"
    elseif index == 6 then
        return "mixed_stress"
    elseif index == 7 then
        return "floating_matrix"
    elseif index == 8 then
        return "zindex_overlap"
    elseif index == 9 then
        return "nested_clip_offsets"
    elseif index == 10 then
        return "text_wrap_matrix"
    elseif index == 11 then
        return "sizing_edge_cases"
    elseif index == 12 then
        return "border_between_children"
    elseif index == 13 then
        return "relayout_state"
    elseif index == 14 then
        return "seeded_fuzz"
    end
    return ""
end

terra api.parity_run_scenario(index: int32) : int32
    if not g_initialized then
        return -1
    end
    if index < 0 or index >= SCENARIO_COUNT then
        return -1
    end

    g_probe_count = 0

    if index == 13 then
        var phase = 0
        while phase < 3 do
            g_probe_count = 0
            ui.BeginLayoutForContext(&g_ctx, [float](g_width), [float](g_height))
            api.scenario_relayout_phase(&g_ctx, phase)
            ui.FinalizeLayoutForContext(&g_ctx)
            phase = phase + 1
        end
        return g_probe_count
    end

    ui.BeginLayoutForContext(&g_ctx, [float](g_width), [float](g_height))
    if not api.run_scenario_internal(&g_ctx, index) then
        return -1
    end
    ui.FinalizeLayoutForContext(&g_ctx)

    return g_probe_count
end

terra api.parity_probe_count() : int32
    return g_probe_count
end

terra api.parity_probe_id(probe_index: int32) : uint32
    if probe_index < 0 or probe_index >= g_probe_count then
        return 0
    end
    return g_probe_ids[probe_index]
end

terra api.parity_probe_box(probe_index: int32, x: &float, y: &float, w: &float, h: &float) : int32
    if x ~= nil then x[0] = 0 end
    if y ~= nil then y[0] = 0 end
    if w ~= nil then w[0] = 0 end
    if h ~= nil then h[0] = 0 end

    if probe_index < 0 or probe_index >= g_probe_count then
        return 0
    end

    var id: ui.ElementId
    id.id = g_probe_ids[probe_index]
    id.offset = 0
    id.baseId = id.id
    id.stringId.isStaticallyAllocated = false
    id.stringId.length = 0
    id.stringId.chars = nil

    var data = ui.GetElementData(id)
    if not data.found then
        return 0
    end

    if x ~= nil then x[0] = data.boundingBox.x end
    if y ~= nil then y[0] = data.boundingBox.y end
    if w ~= nil then w[0] = data.boundingBox.width end
    if h ~= nil then h[0] = data.boundingBox.height end
    return 1
end

api.exports = {
    parity_init = api.parity_init,
    parity_shutdown = api.parity_shutdown,
    parity_scenario_count = api.parity_scenario_count,
    parity_scenario_name = api.parity_scenario_name,
    parity_run_scenario = api.parity_run_scenario,
    parity_probe_count = api.parity_probe_count,
    parity_probe_id = api.parity_probe_id,
    parity_probe_box = api.parity_probe_box,
}

return api
