local ui = require("src.init")
local C = terralib.includecstring[[
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
]]

local IntArray = ui.Array(int)

terra test_arena_alignment()
    var mem : &int8 = [&int8](C.malloc(1024))
    var arena : ui.Arena
    arena:reset()
    arena.capacity = 1024
    arena.memory = mem
    
    var p1 = arena:allocate(1, 4)
    var offset1 = [&uint8](p1) - [&uint8](mem)
    
    arena:allocate(1, 1)
    var p2 = arena:allocate(1, 4)
    var offset2 = [&uint8](p2) - [&uint8](mem)
    
    var aligned = (offset2 % 64) == 0
    
    C.free(mem)
    
    if offset1 == 0 and aligned then
        C.printf("test_arena_alignment: PASS\n")
        return 0
    else
        C.printf("test_arena_alignment: FAIL (offset1=%d, offset2=%d, aligned=%d)\n", 
                 offset1, offset2, aligned)
        return 1
    end
end

terra test_arena_capacity()
    var mem : &int8 = [&int8](C.malloc(64))
    var arena : ui.Arena
    arena.nextAllocation = 0
    arena.capacity = 64
    arena.memory = mem
    
    var p1 = arena:allocate(1, 32)
    var p2 = arena:allocate(1, 64)
    
    C.free(mem)
    
    if p1 ~= nil and p2 == nil then
        C.printf("test_arena_capacity: PASS\n")
        return 0
    else
        C.printf("test_arena_capacity: FAIL\n")
        return 1
    end
end

terra test_array_basic()
    var mem : &int8 = [&int8](C.malloc(4096))
    var arena : ui.Arena
    arena.nextAllocation = 0
    arena.capacity = 4096
    arena.memory = mem
    
    var arr : IntArray
    arr:allocate(10, &arena)
    
    arr:add(1)
    arr:add(2)
    arr:add(3)
    
    var v0 = arr:getValue(0)
    var v1 = arr:getValue(1)
    var v2 = arr:getValue(2)
    var len = arr.length
    
    C.free(mem)
    
    if v0 == 1 and v1 == 2 and v2 == 3 and len == 3 then
        C.printf("test_array_basic: PASS\n")
        return 0
    else
        C.printf("test_array_basic: FAIL\n")
        return 1
    end
end

terra test_array_bounds()
    var mem : &int8 = [&int8](C.malloc(4096))
    var arena : ui.Arena
    arena.nextAllocation = 0
    arena.capacity = 4096
    arena.memory = mem
    
    var arr : IntArray
    arr:allocate(3, &arena)
    arr:add(10)
    arr:add(20)
    
    var p_valid = arr:get(0)
    var p_invalid = arr:get(5)
    var v_valid = arr:getValue(0)
    
    C.free(mem)
    
    if p_valid ~= nil and p_invalid == nil and v_valid == 10 then
        C.printf("test_array_bounds: PASS\n")
        return 0
    else
        C.printf("test_array_bounds: FAIL\n")
        return 1
    end
end

terra test_array_set_and_remove()
    var mem : &int8 = [&int8](C.malloc(4096))
    var arena : ui.Arena
    arena.nextAllocation = 0
    arena.capacity = 4096
    arena.memory = mem
    
    var arr : IntArray
    arr:allocate(10, &arena)
    arr:add(100)
    arr:add(200)
    arr:add(300)
    
    arr:set(5, 500)
    var len_after_set = arr.length
    
    var removed = arr:removeSwapback(0)
    var len_after_remove = arr.length
    var first_now = arr:getValue(0)
    
    C.free(mem)
    
    if removed == 100 and len_after_set == 6 and len_after_remove == 5 and first_now == 500 then
        C.printf("test_array_set_and_remove: PASS\n")
        return 0
    else
        C.printf("test_array_set_and_remove: FAIL\n")
        return 1
    end
end

terra test_string_basic()
    var str : ui.String
    str.isStaticallyAllocated = true
    str.length = 5
    str.chars = "hello"
    
    var c0 = str:get(0)
    var c4 = str:get(4)
    var c_bad = str:get(10)
    
    if c0 == 104 and c4 == 111 and c_bad == 0 then
        C.printf("test_string_basic: PASS\n")
        return 0
    else
        C.printf("test_string_basic: FAIL\n")
        return 1
    end
end

terra run_tests() : int
    var failures = 0
    failures = failures + test_arena_alignment()
    failures = failures + test_arena_capacity()
    failures = failures + test_array_basic()
    failures = failures + test_array_bounds()
    failures = failures + test_array_set_and_remove()
    failures = failures + test_string_basic()
    return failures
end

local failures = run_tests()
if failures == 0 then
    print("All tests passed!")
else
    print("Tests failed: " .. failures)
end

local ui_hash = require("src.hash")

terra test_hash_string()
    var str : ui.String
    str.isStaticallyAllocated = true
    str.length = 5
    str.chars = "hello"
    
    var id1 = ui_hash.HashString(str, 0)
    var id2 = ui_hash.HashString(str, 0)
    
    if id1.id == id2.id and id1.id ~= 0 and id1.baseId == id1.id then
        C.printf("test_hash_string: PASS\n")
        return 0
    else
        C.printf("test_hash_string: FAIL\n")
        return 1
    end
end

terra test_hash_string_determinism()
    var str1 : ui.String
    str1.isStaticallyAllocated = true
    str1.length = 5
    str1.chars = "hello"
    
    var str2 : ui.String
    str2.isStaticallyAllocated = true
    str2.length = 5
    str2.chars = "hello"
    
    var id1 = ui_hash.HashString(str1, 0)
    var id2 = ui_hash.HashString(str2, 0)
    
    var str3 : ui.String
    str3.isStaticallyAllocated = true
    str3.length = 5
    str3.chars = "world"
    
    var id3 = ui_hash.HashString(str3, 0)
    
    if id1.id == id2.id and id1.id ~= id3.id then
        C.printf("test_hash_string_determinism: PASS\n")
        return 0
    else
        C.printf("test_hash_string_determinism: FAIL\n")
        return 1
    end
end

terra test_hash_string_with_offset()
    var str : ui.String
    str.isStaticallyAllocated = true
    str.length = 4
    str.chars = "item"
    
    var id0 = ui_hash.HashStringWithOffset(str, 0, 0)
    var id1 = ui_hash.HashStringWithOffset(str, 1, 0)
    var id5 = ui_hash.HashStringWithOffset(str, 5, 0)
    
    if id0.id ~= id1.id and id1.id ~= id5.id and 
       id0.baseId == id1.baseId and id1.baseId == id5.baseId and
       id0.offset == 0 and id1.offset == 1 and id5.offset == 5 then
        C.printf("test_hash_string_with_offset: PASS\n")
        return 0
    else
        C.printf("test_hash_string_with_offset: FAIL\n")
        return 1
    end
end

terra test_hash_number()
    var id0 = ui_hash.HashNumber(0, 0)
    var id1 = ui_hash.HashNumber(1, 0)
    var id5 = ui_hash.HashNumber(5, 100)
    
    if id0.id ~= 0 and id1.id ~= 0 and id5.id ~= 0 and
       id0.id ~= id1.id and id0.offset == 0 and id5.offset == 5 and id5.baseId == 100 then
        C.printf("test_hash_number: PASS\n")
        return 0
    else
        C.printf("test_hash_number: FAIL\n")
        return 1
    end
end

terra run_hash_tests() : int
    var failures = 0
    failures = failures + test_hash_string()
    failures = failures + test_hash_string_determinism()
    failures = failures + test_hash_string_with_offset()
    failures = failures + test_hash_number()
    return failures
end

local hash_failures = run_hash_tests()
if hash_failures == 0 then
    print("All hash tests passed!")
else
    print("Hash tests failed: " .. hash_failures)
end

local ui_config = require("src.config")

terra test_config_layout()
    var padding : ui_config.Padding
    padding.left = 10
    padding.right = 10
    padding.top = 5
    padding.bottom = 5
    
    var alignment : ui_config.ChildAlignment
    alignment.x = ui_config.ALIGN_X_CENTER
    alignment.y = ui_config.ALIGN_Y_CENTER
    
    var sizingMinMax : ui_config.SizingMinMax
    sizingMinMax.min = 0
    sizingMinMax.max = 1000
    
    var sizingAxis : ui_config.SizingAxis
    sizingAxis.size = sizingMinMax
    sizingAxis.percent = 0
    sizingAxis.type = ui_config.SIZING_GROW
    
    var sizing : ui_config.Sizing
    sizing.width = sizingAxis
    sizing.height = sizingAxis
    
    var layout : ui_config.LayoutConfig
    layout.sizing = sizing
    layout.padding = padding
    layout.childGap = 8
    layout.childAlignment = alignment
    layout.layoutDirection = ui_config.TOP_TO_BOTTOM
    
    if layout.padding.left == 10 and 
       layout.childAlignment.x == ui_config.ALIGN_X_CENTER and
       layout.sizing.width.type == ui_config.SIZING_GROW and
       layout.layoutDirection == ui_config.TOP_TO_BOTTOM then
        C.printf("test_config_layout: PASS\n")
        return 0
    else
        C.printf("test_config_layout: FAIL\n")
        return 1
    end
end

terra test_config_text()
    var textColor : ui_config.Color
    textColor.r = 255
    textColor.g = 128
    textColor.b = 0
    textColor.a = 255
    
    var textConfig : ui_config.TextConfig
    textConfig.userData = nil
    textConfig.textColor = textColor
    textConfig.fontId = 1
    textConfig.fontSize = 16
    textConfig.letterSpacing = 0
    textConfig.lineHeight = 20
    textConfig.wrapMode = ui_config.TEXT_WRAP_WORDS
    textConfig.textAlignment = ui_config.TEXT_ALIGN_LEFT
    
    if textConfig.textColor.r == 255 and
       textConfig.fontSize == 16 and
       textConfig.wrapMode == ui_config.TEXT_WRAP_WORDS then
        C.printf("test_config_text: PASS\n")
        return 0
    else
        C.printf("test_config_text: FAIL\n")
        return 1
    end
end

terra test_config_render_command()
    var bbox : ui_config.BoundingBox
    bbox.x = 10
    bbox.y = 20
    bbox.width = 100
    bbox.height = 50
    
    var cornerRadius : ui_config.CornerRadius
    cornerRadius.topLeft = 4
    cornerRadius.topRight = 4
    cornerRadius.bottomLeft = 4
    cornerRadius.bottomRight = 4
    
    var bgColor : ui_config.Color
    bgColor.r = 100
    bgColor.g = 150
    bgColor.b = 200
    bgColor.a = 255
    
    var rectData : ui_config.RectangleRenderData
    rectData.backgroundColor = bgColor
    rectData.cornerRadius = cornerRadius
    
    var cmd : ui_config.RenderCommand
    cmd.boundingBox = bbox
    cmd.renderData.rectangle = rectData
    cmd.userData = nil
    cmd.id = 12345
    cmd.zIndex = 0
    cmd.commandType = ui_config.RENDER_RECTANGLE
    
    if cmd.boundingBox.width == 100 and
       cmd.renderData.rectangle.backgroundColor.r == 100 and
       cmd.commandType == ui_config.RENDER_RECTANGLE then
        C.printf("test_config_render_command: PASS\n")
        return 0
    else
        C.printf("test_config_render_command: FAIL\n")
        return 1
    end
end

terra test_config_floating()
    var attachPoints : ui_config.FloatingAttachPoints
    attachPoints.element = ui_config.ATTACH_CENTER_CENTER
    attachPoints.parent = ui_config.ATTACH_RIGHT_TOP
    
    var offset : ui_config.Vector2
    offset.x = 10
    offset.y = -5
    
    var expand : ui_config.Dimensions
    expand.width = 0
    expand.height = 0
    
    var floating : ui_config.FloatingConfig
    floating.offset = offset
    floating.expand = expand
    floating.parentId = 0
    floating.zIndex = 10
    floating.attachPoints = attachPoints
    floating.pointerCaptureMode = ui_config.POINTER_CAPTURE
    floating.attachTo = ui_config.ATTACH_PARENT
    floating.clipTo = ui_config.CLIP_NONE
    
    if floating.attachPoints.element == ui_config.ATTACH_CENTER_CENTER and
       floating.attachPoints.parent == ui_config.ATTACH_RIGHT_TOP and
       floating.zIndex == 10 then
        C.printf("test_config_floating: PASS\n")
        return 0
    else
        C.printf("test_config_floating: FAIL\n")
        return 1
    end
end

terra run_config_tests() : int
    var failures = 0
    failures = failures + test_config_layout()
    failures = failures + test_config_text()
    failures = failures + test_config_render_command()
    failures = failures + test_config_floating()
    return failures
end

local config_failures = run_config_tests()
if config_failures == 0 then
    print("All config tests passed!")
else
    print("Config tests failed: " .. config_failures)
end

local ui_context = require("src.context")
local ui_layout = require("src.layout")

terra test_context_init()
    var mem : &int8 = [&int8](C.malloc(1024 * 1024))
    var arena : ui.Arena
    arena.nextAllocation = 0
    arena.capacity = 1024 * 1024
    arena.memory = mem
    
    var ctx : ui_context.Context
    var success = ctx:initialize(&arena, 100)
    
    C.free(mem)
    
    if success and ctx.maxElementCount == 100 then
        C.printf("test_context_init: PASS\n")
        return 0
    else
        C.printf("test_context_init: FAIL\n")
        return 1
    end
end

terra test_context_begin_end_layout()
    var mem : &int8 = [&int8](C.malloc(2 * 1024 * 1024))
    var arena : ui.Arena
    arena.nextAllocation = 0
    arena.capacity = 2 * 1024 * 1024
    arena.memory = mem
    
    var ctx : ui_context.Context
    ctx:initialize(&arena, 100)
    ui_context.SetCurrentContext(&ctx)
    
    ctx:beginLayout(800, 600)
    
    if ctx.layoutElements.length == 1 and ctx.openLayoutElementStack.length == 1 then
        ctx:endLayout()
        C.free(mem)
        C.printf("test_context_begin_end_layout: PASS\n")
        return 0
    else
        C.free(mem)
        C.printf("test_context_begin_end_layout: FAIL\n")
        return 1
    end
end

terra test_context_open_close_element()
    var mem : &int8 = [&int8](C.malloc(2 * 1024 * 1024))
    var arena : ui.Arena
    arena.nextAllocation = 0
    arena.capacity = 2 * 1024 * 1024
    arena.memory = mem
    
    var ctx : ui_context.Context
    ctx:initialize(&arena, 100)
    ui_context.SetCurrentContext(&ctx)
    
    ctx:beginLayout(800, 600)
    
    ctx:openElement()
    var openElem = ctx:getOpenLayoutElement()
    
    if openElem ~= nil then
        var layoutCfg : ui_config.LayoutConfig
        layoutCfg.sizing.width.type = ui_config.SIZING_FIXED
        layoutCfg.sizing.width.size.min = 100
        layoutCfg.sizing.width.size.max = 100
        layoutCfg.sizing.height.type = ui_config.SIZING_FIXED
        layoutCfg.sizing.height.size.min = 50
        layoutCfg.sizing.height.size.max = 50
        layoutCfg.padding.left = 0
        layoutCfg.padding.right = 0
        layoutCfg.padding.top = 0
        layoutCfg.padding.bottom = 0
        layoutCfg.childGap = 0
        layoutCfg.layoutDirection = ui_config.TOP_TO_BOTTOM
        openElem.layoutConfig = ctx:storeLayoutConfig(layoutCfg)
    end
    
    ctx:closeElement()
    ctx:endLayout()
    
    var success = ctx.layoutElements.length == 2
    
    C.free(mem)
    
    if success then
        C.printf("test_context_open_close_element: PASS\n")
        return 0
    else
        C.printf("test_context_open_close_element: FAIL\n")
        return 1
    end
end

terra run_context_tests() : int
    var failures = 0
    failures = failures + test_context_init()
    failures = failures + test_context_begin_end_layout()
    failures = failures + test_context_open_close_element()
    return failures
end

local context_failures = run_context_tests()
if context_failures == 0 then
    print("All context tests passed!")
else
    print("Context tests failed: " .. context_failures)
end
