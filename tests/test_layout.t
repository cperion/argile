local C = terralib.includecstring[[
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
]]
local ui = require("src.init")

print("=== Layout Engine Test ===")

terra open_empty()
    var desc: ui.ElementDesc
    desc.flags = 0
    ui.OpenElementWithDesc(&desc)
end

terra open_empty_with_id(id: ui.ElementId)
    var desc: ui.ElementDesc
    desc.flags = 0
    ui.OpenElementWithIdAndDesc(id, &desc)
end

terra test_basic_layout()
    var arena: ui.Arena
    arena.nextAllocation = 0
    arena.capacity = 1024 * 1024
    arena.memory = [&int8](C.malloc([uint64](arena.capacity)))
    
    var ctx: ui.Context
    ui.SetCurrentContext(&ctx)
    var initResult = ctx:initialize(&arena, 100)
    
    if not initResult then
        C.printf("FAIL: Could not initialize context\n")
        C.free(arena.memory)
        return 1
    end
    
    ui.BeginLayout(800.0, 600.0)
    
    open_empty()
    var childCfg: ui.LayoutConfig
    childCfg.sizing.width.type = ui.SIZING_FIXED
    childCfg.sizing.width.size.min = 200.0
    childCfg.sizing.width.size.max = 200.0
    childCfg.sizing.height.type = ui.SIZING_FIXED
    childCfg.sizing.height.size.min = 100.0
    childCfg.sizing.height.size.max = 100.0
    childCfg.padding.left = 10
    childCfg.padding.right = 10
    childCfg.padding.top = 10
    childCfg.padding.bottom = 10
    childCfg.childGap = 0
    childCfg.childAlignment.x = ui.ALIGN_X_LEFT
    childCfg.childAlignment.y = ui.ALIGN_Y_TOP
    childCfg.layoutDirection = ui.LEFT_TO_RIGHT
    
    var openElem = ctx:getOpenLayoutElement()
    if openElem ~= nil then
        openElem.layoutConfig = ctx:storeLayoutConfig(childCfg)
        
        var sharedCfg: ui.SharedConfig
        sharedCfg.backgroundColor.r = 255
        sharedCfg.backgroundColor.g = 0
        sharedCfg.backgroundColor.b = 0
        sharedCfg.backgroundColor.a = 255
        sharedCfg.cornerRadius.topLeft = 0
        sharedCfg.cornerRadius.topRight = 0
        sharedCfg.cornerRadius.bottomLeft = 0
        sharedCfg.cornerRadius.bottomRight = 0
        sharedCfg.userData = nil
        
        var sharedCfgPtr = ctx:storeSharedConfig(sharedCfg)
        
        if sharedCfgPtr ~= nil then
            var cfgUnion: ui.ElementConfigUnion
            cfgUnion.sharedConfig = sharedCfgPtr
            ctx:attachElementConfig(cfgUnion, ui.CONFIG_SHARED)
        end
    end
    ui.CloseElement()
    
    var cmds = ui.EndLayout()
    
    var passed = true
    
    if cmds == nil then
        C.printf("FAIL: EndLayout returned nil\n")
        passed = false
    else
        C.printf("Render commands count: %d\n", cmds.length)
        if cmds.length < 1 then
            C.printf("FAIL: Expected at least 1 render command\n")
            passed = false
        else
            var cmd = cmds:get(0)
            if cmd == nil then
                C.printf("FAIL: First command is nil\n")
                passed = false
            else
                C.printf("First command: type=%d, bbox=(%.1f,%.1f,%.1f,%.1f)\n", 
                    cmd.commandType, 
                    cmd.boundingBox.x, 
                    cmd.boundingBox.y, 
                    cmd.boundingBox.width, 
                    cmd.boundingBox.height)
            end
        end
    end
    
    C.free(arena.memory)
    
    if passed then
        C.printf("test_basic_layout: PASS\n")
        return 0
    else
        return 1
    end
end

test_basic_layout()

print("\n=== Border Rendering Test ===")

terra test_border_rendering()
    var arena: ui.Arena
    arena.nextAllocation = 0
    arena.capacity = 1024 * 1024
    arena.memory = [&int8](C.malloc([uint64](arena.capacity)))
    
    var ctx: ui.Context
    ui.SetCurrentContext(&ctx)
    var initResult = ctx:initialize(&arena, 100)
    
    if not initResult then
        C.printf("FAIL: Could not initialize context\n")
        C.free(arena.memory)
        return 1
    end
    
    ui.BeginLayout(800.0, 600.0)
    
    open_empty()
    var childCfg: ui.LayoutConfig
    childCfg.sizing.width.type = ui.SIZING_FIXED
    childCfg.sizing.width.size.min = 200.0
    childCfg.sizing.width.size.max = 200.0
    childCfg.sizing.height.type = ui.SIZING_FIXED
    childCfg.sizing.height.size.min = 100.0
    childCfg.sizing.height.size.max = 100.0
    childCfg.padding.left = 10
    childCfg.padding.right = 10
    childCfg.padding.top = 10
    childCfg.padding.bottom = 10
    childCfg.childGap = 0
    childCfg.childAlignment.x = ui.ALIGN_X_LEFT
    childCfg.childAlignment.y = ui.ALIGN_Y_TOP
    childCfg.layoutDirection = ui.LEFT_TO_RIGHT
    
    var openElem = ctx:getOpenLayoutElement()
    if openElem ~= nil then
        openElem.layoutConfig = ctx:storeLayoutConfig(childCfg)
        
        var sharedCfg: ui.SharedConfig
        sharedCfg.backgroundColor.r = 100
        sharedCfg.backgroundColor.g = 100
        sharedCfg.backgroundColor.b = 100
        sharedCfg.backgroundColor.a = 255
        sharedCfg.cornerRadius.topLeft = 0
        sharedCfg.cornerRadius.topRight = 0
        sharedCfg.cornerRadius.bottomLeft = 0
        sharedCfg.cornerRadius.bottomRight = 0
        sharedCfg.userData = nil
        
        var sharedCfgPtr = ctx:storeSharedConfig(sharedCfg)
        if sharedCfgPtr ~= nil then
            var cfgUnion: ui.ElementConfigUnion
            cfgUnion.sharedConfig = sharedCfgPtr
            ctx:attachElementConfig(cfgUnion, ui.CONFIG_SHARED)
        end
        
        var borderCfg: ui.BorderConfig
        borderCfg.color.r = 255
        borderCfg.color.g = 0
        borderCfg.color.b = 0
        borderCfg.color.a = 255
        borderCfg.width.left = 2
        borderCfg.width.right = 2
        borderCfg.width.top = 2
        borderCfg.width.bottom = 2
        borderCfg.width.betweenChildren = 0
        
        var borderCfgPtr = ctx:storeBorderConfig(borderCfg)
        if borderCfgPtr ~= nil then
            var cfgUnion: ui.ElementConfigUnion
            cfgUnion.borderConfig = borderCfgPtr
            ctx:attachElementConfig(cfgUnion, ui.CONFIG_BORDER)
        end
    end
    ui.CloseElement()
    
    var cmds = ui.EndLayout()
    
    var passed = true
    var borderFound = false
    
    if cmds == nil then
        C.printf("FAIL: EndLayout returned nil\n")
        passed = false
    else
        C.printf("Render commands count: %d\n", cmds.length)
        for i = 0, cmds.length do
            var cmd = cmds:get(i)
            if cmd ~= nil then
                C.printf("  cmd[%d]: type=%d\n", i, cmd.commandType)
                if cmd.commandType == ui.RENDER_BORDER then
                    borderFound = true
                end
            end
        end
        
        if not borderFound then
            C.printf("FAIL: No border command found\n")
            passed = false
        end
    end
    
    C.free(arena.memory)
    
    if passed then
        C.printf("test_border_rendering: PASS\n")
        return 0
    else
        return 1
    end
end

test_border_rendering()

print("\n=== All Render Commands Coverage Test ===")

terra test_all_render_commands()
    var arena: ui.Arena
    arena.nextAllocation = 0
    arena.capacity = 1024 * 1024
    arena.memory = [&int8](C.malloc([uint64](arena.capacity)))
    
    var ctx: ui.Context
    ui.SetCurrentContext(&ctx)
    var initResult = ctx:initialize(&arena, 100)
    
    if not initResult then
        C.printf("FAIL: Could not initialize context\n")
        C.free(arena.memory)
        return 1
    end
    
    ui.BeginLayout(800.0, 600.0)
    
    -- Child 1: Image element
    open_empty()
    var imgCfg: ui.LayoutConfig
    imgCfg.sizing.width.type = ui.SIZING_FIXED
    imgCfg.sizing.width.size.min = 100.0
    imgCfg.sizing.width.size.max = 100.0
    imgCfg.sizing.height.type = ui.SIZING_FIXED
    imgCfg.sizing.height.size.min = 50.0
    imgCfg.sizing.height.size.max = 50.0
    imgCfg.padding.left = 0
    imgCfg.padding.right = 0
    imgCfg.padding.top = 0
    imgCfg.padding.bottom = 0
    imgCfg.childGap = 0
    imgCfg.childAlignment.x = ui.ALIGN_X_LEFT
    imgCfg.childAlignment.y = ui.ALIGN_Y_TOP
    imgCfg.layoutDirection = ui.LEFT_TO_RIGHT
    
    var imgElem = ctx:getOpenLayoutElement()
    if imgElem ~= nil then
        imgElem.layoutConfig = ctx:storeLayoutConfig(imgCfg)
        
        var imageCfg: ui.ImageConfig
        imageCfg.imageData = nil
        
        var imageCfgPtr = ctx:storeImageConfig(imageCfg)
        if imageCfgPtr ~= nil then
            var cfgUnion: ui.ElementConfigUnion
            cfgUnion.imageConfig = imageCfgPtr
            ctx:attachElementConfig(cfgUnion, ui.CONFIG_IMAGE)
        end
    end
    ui.CloseElement()
    
    -- Child 2: Custom element
    open_empty()
    var customCfg: ui.LayoutConfig
    customCfg.sizing.width.type = ui.SIZING_FIXED
    customCfg.sizing.width.size.min = 100.0
    customCfg.sizing.width.size.max = 100.0
    customCfg.sizing.height.type = ui.SIZING_FIXED
    customCfg.sizing.height.size.min = 50.0
    customCfg.sizing.height.size.max = 50.0
    customCfg.padding.left = 0
    customCfg.padding.right = 0
    customCfg.padding.top = 0
    customCfg.padding.bottom = 0
    customCfg.childGap = 0
    customCfg.childAlignment.x = ui.ALIGN_X_LEFT
    customCfg.childAlignment.y = ui.ALIGN_Y_TOP
    customCfg.layoutDirection = ui.LEFT_TO_RIGHT
    
    var customElem = ctx:getOpenLayoutElement()
    if customElem ~= nil then
        customElem.layoutConfig = ctx:storeLayoutConfig(customCfg)
        
        var customDataCfg: ui.CustomConfig
        customDataCfg.customData = nil
        
        var customDataCfgPtr = ctx:storeCustomConfig(customDataCfg)
        if customDataCfgPtr ~= nil then
            var cfgUnion: ui.ElementConfigUnion
            cfgUnion.customConfig = customDataCfgPtr
            ctx:attachElementConfig(cfgUnion, ui.CONFIG_CUSTOM)
        end
    end
    ui.CloseElement()
    
    -- Child 3: Clip element with children (and border)
    open_empty()
    var clipCfg: ui.LayoutConfig
    clipCfg.sizing.width.type = ui.SIZING_FIXED
    clipCfg.sizing.width.size.min = 200.0
    clipCfg.sizing.width.size.max = 200.0
    clipCfg.sizing.height.type = ui.SIZING_FIXED
    clipCfg.sizing.height.size.min = 100.0
    clipCfg.sizing.height.size.max = 100.0
    clipCfg.padding.left = 5
    clipCfg.padding.right = 5
    clipCfg.padding.top = 5
    clipCfg.padding.bottom = 5
    clipCfg.childGap = 0
    clipCfg.childAlignment.x = ui.ALIGN_X_LEFT
    clipCfg.childAlignment.y = ui.ALIGN_Y_TOP
    clipCfg.layoutDirection = ui.TOP_TO_BOTTOM
    
    var clipElem = ctx:getOpenLayoutElement()
    if clipElem ~= nil then
        clipElem.layoutConfig = ctx:storeLayoutConfig(clipCfg)
        
        var clipDataCfg: ui.ClipConfig
        clipDataCfg.horizontal = true
        clipDataCfg.vertical = true
        clipDataCfg.childOffset.x = 0
        clipDataCfg.childOffset.y = 0
        
        var clipDataCfgPtr = ctx:storeClipConfig(clipDataCfg)
        if clipDataCfgPtr ~= nil then
            var cfgUnion: ui.ElementConfigUnion
            cfgUnion.clipConfig = clipDataCfgPtr
            ctx:attachElementConfig(cfgUnion, ui.CONFIG_CLIP)
        end
        
        -- Add border to clip element
        var borderCfg: ui.BorderConfig
        borderCfg.color.r = 0
        borderCfg.color.g = 128
        borderCfg.color.b = 255
        borderCfg.color.a = 255
        borderCfg.width.left = 2
        borderCfg.width.right = 2
        borderCfg.width.top = 2
        borderCfg.width.bottom = 2
        borderCfg.width.betweenChildren = 0
        
        var borderCfgPtr = ctx:storeBorderConfig(borderCfg)
        if borderCfgPtr ~= nil then
            var cfgUnion2: ui.ElementConfigUnion
            cfgUnion2.borderConfig = borderCfgPtr
            ctx:attachElementConfig(cfgUnion2, ui.CONFIG_BORDER)
        end
        
        -- Nested child inside clip
        open_empty()
        var nestedCfg: ui.LayoutConfig
        nestedCfg.sizing.width.type = ui.SIZING_FIXED
        nestedCfg.sizing.width.size.min = 50.0
        nestedCfg.sizing.width.size.max = 50.0
        nestedCfg.sizing.height.type = ui.SIZING_FIXED
        nestedCfg.sizing.height.size.min = 30.0
        nestedCfg.sizing.height.size.max = 30.0
        nestedCfg.padding.left = 0
        nestedCfg.padding.right = 0
        nestedCfg.padding.top = 0
        nestedCfg.padding.bottom = 0
        nestedCfg.childGap = 0
        nestedCfg.childAlignment.x = ui.ALIGN_X_LEFT
        nestedCfg.childAlignment.y = ui.ALIGN_Y_TOP
        nestedCfg.layoutDirection = ui.LEFT_TO_RIGHT
        
        var nestedElem = ctx:getOpenLayoutElement()
        if nestedElem ~= nil then
            nestedElem.layoutConfig = ctx:storeLayoutConfig(nestedCfg)
            
            var nestedSharedCfg: ui.SharedConfig
            nestedSharedCfg.backgroundColor.r = 0
            nestedSharedCfg.backgroundColor.g = 255
            nestedSharedCfg.backgroundColor.b = 0
            nestedSharedCfg.backgroundColor.a = 255
            nestedSharedCfg.cornerRadius.topLeft = 0
            nestedSharedCfg.cornerRadius.topRight = 0
            nestedSharedCfg.cornerRadius.bottomLeft = 0
            nestedSharedCfg.cornerRadius.bottomRight = 0
            nestedSharedCfg.userData = nil
            
            var nestedSharedCfgPtr = ctx:storeSharedConfig(nestedSharedCfg)
            if nestedSharedCfgPtr ~= nil then
                var cfgUnion: ui.ElementConfigUnion
                cfgUnion.sharedConfig = nestedSharedCfgPtr
                ctx:attachElementConfig(cfgUnion, ui.CONFIG_SHARED)
            end
        end
        ui.CloseElement()
    end
    ui.CloseElement()
    
    -- Child 4: Text element
    var textStr: ui.String
    textStr.isStaticallyAllocated = true
    textStr.length = 5
    textStr.chars = "Hello"
    
    var textConfig: ui.TextConfig
    textConfig.userData = nil
    textConfig.textColor.r = 255
    textConfig.textColor.g = 255
    textConfig.textColor.b = 255
    textConfig.textColor.a = 255
    textConfig.fontId = 0
    textConfig.fontSize = 16
    textConfig.letterSpacing = 0
    textConfig.lineHeight = 0
    textConfig.wrapMode = ui.TEXT_WRAP_WORDS
    textConfig.textAlignment = ui.TEXT_ALIGN_LEFT
    
    ui.OpenTextElement(textStr, &textConfig)
    
    var cmds = ui.EndLayout()
    
    var passed = true
    var foundRectangle = false
    var foundBorder = false
    var foundText = false
    var foundImage = false
    var foundCustom = false
    var foundScissorStart = false
    var foundScissorEnd = false
    
    if cmds == nil then
        C.printf("FAIL: EndLayout returned nil\n")
        passed = false
    else
        C.printf("Render commands count: %d\n", cmds.length)
        for i = 0, cmds.length do
            var cmd = cmds:get(i)
            if cmd ~= nil then
                C.printf("  cmd[%d]: type=%d, id=%u\n", i, cmd.commandType, cmd.id)
                if cmd.commandType == ui.RENDER_RECTANGLE then
                    foundRectangle = true
                elseif cmd.commandType == ui.RENDER_BORDER then
                    foundBorder = true
                elseif cmd.commandType == ui.RENDER_TEXT then
                    foundText = true
                elseif cmd.commandType == ui.RENDER_IMAGE then
                    foundImage = true
                elseif cmd.commandType == ui.RENDER_CUSTOM then
                    foundCustom = true
                elseif cmd.commandType == ui.RENDER_SCISSOR_START then
                    foundScissorStart = true
                elseif cmd.commandType == ui.RENDER_SCISSOR_END then
                    foundScissorEnd = true
                end
            end
        end
        
        if not foundRectangle then
            C.printf("FAIL: No RECTANGLE command found\n")
            passed = false
        end
        if not foundImage then
            C.printf("FAIL: No IMAGE command found\n")
            passed = false
        end
        if not foundCustom then
            C.printf("FAIL: No CUSTOM command found\n")
            passed = false
        end
        if not foundScissorStart then
            C.printf("FAIL: No SCISSOR_START command found\n")
            passed = false
        end
        if not foundScissorEnd then
            C.printf("FAIL: No SCISSOR_END command found\n")
            passed = false
        end
    end
    
    C.free(arena.memory)
    
    if passed then
        C.printf("test_all_render_commands: PASS\n")
        if foundRectangle then C.printf("  - RENDER_RECTANGLE: YES\n") else C.printf("  - RENDER_RECTANGLE: NO\n") end
        if foundBorder then C.printf("  - RENDER_BORDER: YES\n") else C.printf("  - RENDER_BORDER: NO\n") end
        if foundText then C.printf("  - RENDER_TEXT: YES\n") else C.printf("  - RENDER_TEXT: NO\n") end
        if foundImage then C.printf("  - RENDER_IMAGE: YES\n") else C.printf("  - RENDER_IMAGE: NO\n") end
        if foundCustom then C.printf("  - RENDER_CUSTOM: YES\n") else C.printf("  - RENDER_CUSTOM: NO\n") end
        if foundScissorStart then C.printf("  - RENDER_SCISSOR_START: YES\n") else C.printf("  - RENDER_SCISSOR_START: NO\n") end
        if foundScissorEnd then C.printf("  - RENDER_SCISSOR_END: YES\n") else C.printf("  - RENDER_SCISSOR_END: NO\n") end
        return 0
    else
        return 1
    end
end

test_all_render_commands()

print("\n=== Text Rendering with Manual Wrapped Lines Test ===")

terra test_text_with_wrapped_lines()
    var arena: ui.Arena
    arena.nextAllocation = 0
    arena.capacity = 1024 * 1024
    arena.memory = [&int8](C.malloc([uint64](arena.capacity)))
    
    var ctx: ui.Context
    ui.SetCurrentContext(&ctx)
    var initResult = ctx:initialize(&arena, 100)
    
    if not initResult then
        C.printf("FAIL: Could not initialize context\n")
        C.free(arena.memory)
        return 1
    end
    
    ui.BeginLayout(800.0, 600.0)
    
    -- Create text element with manually populated wrapped lines
    var textStr: ui.String
    textStr.isStaticallyAllocated = true
    textStr.length = 5
    textStr.chars = "Hello"
    
    var textConfig: ui.TextConfig
    textConfig.userData = nil
    textConfig.textColor.r = 255
    textConfig.textColor.g = 255
    textConfig.textColor.b = 255
    textConfig.textColor.a = 255
    textConfig.fontId = 0
    textConfig.fontSize = 16
    textConfig.letterSpacing = 0
    textConfig.lineHeight = 20
    textConfig.wrapMode = ui.TEXT_WRAP_WORDS
    textConfig.textAlignment = ui.TEXT_ALIGN_LEFT
    
    ui.OpenTextElement(textStr, &textConfig)
    
    -- Manually populate wrapped lines (normally done by text measurement callback)
    var textElemIdx = ctx.layoutElements.length - 1
    var textElem = ctx.layoutElements:get(textElemIdx)
    if textElem ~= nil and textElem.childrenOrTextContent.textElementData ~= nil then
        var textData = textElem.childrenOrTextContent.textElementData
        textData.preferredDimensions.width = 50.0
        textData.preferredDimensions.height = 20.0
        
        -- Allocate wrapped lines array
        ctx.wrappedTextLines.length = 0
        var wrappedLine: ui.WrappedTextLine
        wrappedLine.dimensions.width = 50.0
        wrappedLine.dimensions.height = 20.0
        wrappedLine.line.isStaticallyAllocated = true
        wrappedLine.line.length = 5
        wrappedLine.line.chars = "Hello"
        ctx.wrappedTextLines:add(wrappedLine)
        
        textData.wrappedLines.internalArray = &ctx.wrappedTextLines.internalArray[0]
        textData.wrappedLines.length = 1
        
        -- Update element dimensions
        textElem.dimensions.width = 50.0
        textElem.dimensions.height = 20.0
    end
    
    var cmds = ui.EndLayout()
    
    var passed = true
    var foundText = false
    
    if cmds == nil then
        C.printf("FAIL: EndLayout returned nil\n")
        passed = false
    else
        C.printf("Render commands count: %d\n", cmds.length)
        for i = 0, cmds.length do
            var cmd = cmds:get(i)
            if cmd ~= nil then
                C.printf("  cmd[%d]: type=%d\n", i, cmd.commandType)
                if cmd.commandType == ui.RENDER_TEXT then
                    foundText = true
                    C.printf("    text color: (%.0f,%.0f,%.0f,%.0f)\n", 
                        cmd.renderData.text.textColor.r,
                        cmd.renderData.text.textColor.g,
                        cmd.renderData.text.textColor.b,
                        cmd.renderData.text.textColor.a)
                end
            end
        end
        
        if not foundText then
            C.printf("FAIL: No TEXT command found\n")
            passed = false
        end
    end
    
    C.free(arena.memory)
    
    if passed then
        C.printf("test_text_with_wrapped_lines: PASS\n")
        return 0
    else
        return 1
    end
end

test_text_with_wrapped_lines()

print("\n=== Advanced Features Test ===")

local measureTextCalls = global(int32, 0)

-- New FFI-friendly signature: out pointer + int32 return
terra mock_measure_text(text: &ui.StringSlice, textCfg: &ui.TextConfig, userData: &opaque, out: &ui.Dimensions) : int32
    measureTextCalls = measureTextCalls + 1
    out.width = [float](text.length * 8)
    if textCfg ~= nil and textCfg.lineHeight > 0 then
        out.height = [float](textCfg.lineHeight)
    else
        out.height = 16.0
    end
    return 1  -- success
end

terra test_measure_text_cache_hit_and_reset()
    var arena: ui.Arena
    arena.nextAllocation = 0
    arena.capacity = 1024 * 1024
    arena.memory = [&int8](C.malloc([uint64](arena.capacity)))

    var ctx: ui.Context
    ui.SetCurrentContext(&ctx)
    if not ctx:initialize(&arena, 128) then
        C.free(arena.memory)
        C.printf("test_measure_text_cache_hit_and_reset: FAIL (init)\n")
        return 1
    end

    measureTextCalls = 0
    ui.SetMeasureTextFunction(mock_measure_text, nil)

    var t: ui.String
    t.isStaticallyAllocated = true
    t.length = 10
    t.chars = "HelloCache"

    var tc: ui.TextConfig
    tc.userData = nil
    tc.textColor.r = 255
    tc.textColor.g = 255
    tc.textColor.b = 255
    tc.textColor.a = 255
    tc.fontId = 0
    tc.fontSize = 16
    tc.letterSpacing = 0
    tc.lineHeight = 16
    tc.wrapMode = ui.TEXT_WRAP_WORDS
    tc.textAlignment = ui.TEXT_ALIGN_LEFT

    ui.BeginLayout(400, 200)
    ui.OpenTextElement(t, &tc)
    ui.EndLayout()
    var firstCalls = measureTextCalls

    ui.BeginLayout(400, 200)
    ui.OpenTextElement(t, &tc)
    ui.EndLayout()
    var secondCalls = measureTextCalls

    ui.ResetMeasureTextCache()
    ui.BeginLayout(400, 200)
    ui.OpenTextElement(t, &tc)
    ui.EndLayout()
    var thirdCalls = measureTextCalls

    C.free(arena.memory)
    if firstCalls > 0 and secondCalls == firstCalls and thirdCalls > secondCalls then
        C.printf("test_measure_text_cache_hit_and_reset: PASS\n")
        return 0
    end
    C.printf("test_measure_text_cache_hit_and_reset: FAIL\n")
    return 1
end

terra test_measure_text_callback()
    var arena: ui.Arena
    arena.nextAllocation = 0
    arena.capacity = 1024 * 1024
    arena.memory = [&int8](C.malloc([uint64](arena.capacity)))

    var ctx: ui.Context
    ui.SetCurrentContext(&ctx)
    if not ctx:initialize(&arena, 128) then
        C.printf("FAIL: init failed\n")
        C.free(arena.memory)
        return 1
    end

    ui.SetMeasureTextFunction(mock_measure_text, nil)
    ui.BeginLayout(400.0, 200.0)

    var t: ui.String
    t.isStaticallyAllocated = true
    t.length = 5
    t.chars = "Hello"

    var tc: ui.TextConfig
    tc.userData = nil
    tc.textColor.r = 255
    tc.textColor.g = 255
    tc.textColor.b = 255
    tc.textColor.a = 255
    tc.fontId = 0
    tc.fontSize = 16
    tc.letterSpacing = 0
    tc.lineHeight = 16
    tc.wrapMode = ui.TEXT_WRAP_WORDS
    tc.textAlignment = ui.TEXT_ALIGN_LEFT

    ui.OpenTextElement(t, &tc)
    var cmds = ui.EndLayout()

    var ok = false
    if cmds ~= nil then
        for i = 0, cmds.length do
            var cmd = cmds:get(i)
            if cmd ~= nil and cmd.commandType == ui.RENDER_TEXT then
                if cmd.boundingBox.width == 40.0 then
                    ok = true
                end
            end
        end
    end

    C.free(arena.memory)
    if ok then
        C.printf("test_measure_text_callback: PASS\n")
        return 0
    end
    C.printf("test_measure_text_callback: FAIL\n")
    return 1
end

terra test_text_words_wrap_under_root_compression()
    var arena: ui.Arena
    arena.nextAllocation = 0
    arena.capacity = 1024 * 1024
    arena.memory = [&int8](C.malloc([uint64](arena.capacity)))

    var ctx: ui.Context
    ui.SetCurrentContext(&ctx)
    if not ctx:initialize(&arena, 128) then
        C.printf("test_text_words_wrap_under_root_compression: FAIL (init)\n")
        C.free(arena.memory)
        return 1
    end

    ui.SetMeasureTextFunction(mock_measure_text, nil)
    ui.BeginLayout(400.0, 200.0)

    var t: ui.String
    t.isStaticallyAllocated = true
    t.length = 11
    t.chars = "hello world"

    var tc: ui.TextConfig
    tc.userData = nil
    tc.textColor.r = 255
    tc.textColor.g = 255
    tc.textColor.b = 255
    tc.textColor.a = 255
    tc.fontId = 0
    tc.fontSize = 16
    tc.letterSpacing = 0
    tc.lineHeight = 16
    tc.wrapMode = ui.TEXT_WRAP_WORDS
    tc.textAlignment = ui.TEXT_ALIGN_LEFT

    var i = 0
    while i < 5 do
        ui.OpenTextElement(t, &tc)
        i = i + 1
    end
    var cmds = ui.EndLayout()

    var textCmds = 0
    if cmds ~= nil then
        for i = 0, cmds.length do
            var cmd = cmds:get(i)
            if cmd ~= nil and cmd.commandType == ui.RENDER_TEXT then
                textCmds = textCmds + 1
            end
        end
    end

    C.free(arena.memory)
    if textCmds == 10 then
        C.printf("test_text_words_wrap_under_root_compression: PASS\n")
        return 0
    end
    C.printf("test_text_words_wrap_under_root_compression: FAIL (text commands=%d)\n", textCmds)
    return 1
end

terra test_aspect_ratio_layout()
    var arena: ui.Arena
    arena.nextAllocation = 0
    arena.capacity = 1024 * 1024
    arena.memory = [&int8](C.malloc([uint64](arena.capacity)))

    var ctx: ui.Context
    ui.SetCurrentContext(&ctx)
    if not ctx:initialize(&arena, 128) then
        C.free(arena.memory)
        return 1
    end

    ui.BeginLayout(400.0, 300.0)
    open_empty()
    var e = ctx:getOpenLayoutElement()
    var targetId: uint32 = 0
    if e ~= nil then
        targetId = e.id
        var lc: ui.LayoutConfig
        lc.sizing.width.type = ui.SIZING_FIXED
        lc.sizing.width.size.min = 200
        lc.sizing.width.size.max = 200
        lc.sizing.height.type = ui.SIZING_FIT
        lc.sizing.height.size.min = 0
        lc.sizing.height.size.max = ui.MAXFLOAT
        lc.padding.left = 0
        lc.padding.right = 0
        lc.padding.top = 0
        lc.padding.bottom = 0
        lc.childGap = 0
        lc.childAlignment.x = ui.ALIGN_X_LEFT
        lc.childAlignment.y = ui.ALIGN_Y_TOP
        lc.layoutDirection = ui.LEFT_TO_RIGHT
        e.layoutConfig = ctx:storeLayoutConfig(lc)

        var shared: ui.SharedConfig
        shared.backgroundColor.r = 100
        shared.backgroundColor.g = 100
        shared.backgroundColor.b = 100
        shared.backgroundColor.a = 255
        shared.cornerRadius.topLeft = 0
        shared.cornerRadius.topRight = 0
        shared.cornerRadius.bottomLeft = 0
        shared.cornerRadius.bottomRight = 0
        shared.userData = nil
        var sharedPtr = ctx:storeSharedConfig(shared)
        if sharedPtr ~= nil then
            var cu: ui.ElementConfigUnion
            cu.sharedConfig = sharedPtr
            ctx:attachElementConfig(cu, ui.CONFIG_SHARED)
        end

        var aspect: ui.AspectRatioConfig
        aspect.aspectRatio = 2.0
        var aspectPtr = ctx:storeAspectRatioConfig(aspect)
        if aspectPtr ~= nil then
            var cu: ui.ElementConfigUnion
            cu.aspectRatioConfig = aspectPtr
            ctx:attachElementConfig(cu, ui.CONFIG_ASPECT)
        end
    end
    ui.CloseElement()
    var cmds = ui.EndLayout()

    var ok = false
    if cmds ~= nil then
        for i = 0, cmds.length do
            var cmd = cmds:get(i)
            if cmd ~= nil and cmd.id == targetId and cmd.commandType == ui.RENDER_RECTANGLE then
                if cmd.boundingBox.height == 100.0 then
                    ok = true
                end
            end
        end
    end
    C.free(arena.memory)
    if ok then
        C.printf("test_aspect_ratio_layout: PASS\n")
        return 0
    end
    C.printf("test_aspect_ratio_layout: FAIL\n")
    return 1
end

terra test_floating_attach_points()
    var arena: ui.Arena
    arena.nextAllocation = 0
    arena.capacity = 1024 * 1024
    arena.memory = [&int8](C.malloc([uint64](arena.capacity)))

    var ctx: ui.Context
    ui.SetCurrentContext(&ctx)
    if not ctx:initialize(&arena, 128) then
        C.free(arena.memory)
        return 1
    end

    ui.BeginLayout(800.0, 600.0)
    open_empty()
    var floatingId: uint32 = 0
    var e = ctx:getOpenLayoutElement()
    if e ~= nil then
        floatingId = e.id
        var lc: ui.LayoutConfig
        lc.sizing.width.type = ui.SIZING_FIXED
        lc.sizing.width.size.min = 50
        lc.sizing.width.size.max = 50
        lc.sizing.height.type = ui.SIZING_FIXED
        lc.sizing.height.size.min = 20
        lc.sizing.height.size.max = 20
        lc.padding.left = 0
        lc.padding.right = 0
        lc.padding.top = 0
        lc.padding.bottom = 0
        lc.childGap = 0
        lc.childAlignment.x = ui.ALIGN_X_LEFT
        lc.childAlignment.y = ui.ALIGN_Y_TOP
        lc.layoutDirection = ui.LEFT_TO_RIGHT
        e.layoutConfig = ctx:storeLayoutConfig(lc)

        var shared: ui.SharedConfig
        shared.backgroundColor.r = 255
        shared.backgroundColor.g = 0
        shared.backgroundColor.b = 255
        shared.backgroundColor.a = 255
        shared.cornerRadius.topLeft = 0
        shared.cornerRadius.topRight = 0
        shared.cornerRadius.bottomLeft = 0
        shared.cornerRadius.bottomRight = 0
        shared.userData = nil
        var sharedPtr = ctx:storeSharedConfig(shared)
        if sharedPtr ~= nil then
            var cu: ui.ElementConfigUnion
            cu.sharedConfig = sharedPtr
            ctx:attachElementConfig(cu, ui.CONFIG_SHARED)
        end

        var floating: ui.FloatingConfig
        floating.offset.x = -20
        floating.offset.y = -30
        floating.expand.width = 0
        floating.expand.height = 0
        floating.parentId = 0
        floating.zIndex = 10
        floating.attachPoints.element = ui.ATTACH_LEFT_TOP
        floating.attachPoints.parent = ui.ATTACH_RIGHT_BOTTOM
        floating.pointerCaptureMode = ui.POINTER_CAPTURE
        floating.attachTo = ui.ATTACH_ROOT
        floating.clipTo = ui.CLIP_NONE
        var floatingPtr = ctx:storeFloatingConfig(floating)
        if floatingPtr ~= nil then
            var cu: ui.ElementConfigUnion
            cu.floatingConfig = floatingPtr
            ctx:attachElementConfig(cu, ui.CONFIG_FLOATING)
        end
    end
    ui.CloseElement()
    var cmds = ui.EndLayout()

    var ok = false
    if cmds ~= nil then
        for i = 0, cmds.length do
            var cmd = cmds:get(i)
            if cmd ~= nil and cmd.id == floatingId and cmd.commandType == ui.RENDER_RECTANGLE then
                if cmd.boundingBox.x == 780.0 and cmd.boundingBox.y == 570.0 then
                    ok = true
                end
            end
        end
    end
    C.free(arena.memory)
    if ok then
        C.printf("test_floating_attach_points: PASS\n")
        return 0
    end
    C.printf("test_floating_attach_points: FAIL\n")
    return 1
end

terra test_scroll_momentum_state()
    var arena: ui.Arena
    arena.nextAllocation = 0
    arena.capacity = 1024 * 1024
    arena.memory = [&int8](C.malloc([uint64](arena.capacity)))

    var ctx: ui.Context
    ui.SetCurrentContext(&ctx)
    if not ctx:initialize(&arena, 128) then
        C.free(arena.memory)
        return 1
    end

    ui.BeginLayout(400.0, 300.0)
    var sid = ui.HashString(ui.String { isStaticallyAllocated = true, length = 6, chars = "scroll" }, 0)
    open_empty_with_id(sid)
    var container = ctx:getOpenLayoutElement()
    if container ~= nil then
        var lc: ui.LayoutConfig
        lc.sizing.width.type = ui.SIZING_FIXED
        lc.sizing.width.size.min = 100
        lc.sizing.width.size.max = 100
        lc.sizing.height.type = ui.SIZING_FIXED
        lc.sizing.height.size.min = 100
        lc.sizing.height.size.max = 100
        lc.padding.left = 0
        lc.padding.right = 0
        lc.padding.top = 0
        lc.padding.bottom = 0
        lc.childGap = 0
        lc.childAlignment.x = ui.ALIGN_X_LEFT
        lc.childAlignment.y = ui.ALIGN_Y_TOP
        lc.layoutDirection = ui.TOP_TO_BOTTOM
        container.layoutConfig = ctx:storeLayoutConfig(lc)

        var clipCfg: ui.ClipConfig
        clipCfg.horizontal = true
        clipCfg.vertical = true
        clipCfg.childOffset.x = 0
        clipCfg.childOffset.y = 0
        var clipPtr = ctx:storeClipConfig(clipCfg)
        if clipPtr ~= nil then
            var cu: ui.ElementConfigUnion
            cu.clipConfig = clipPtr
            ctx:attachElementConfig(cu, ui.CONFIG_CLIP)
        end

        open_empty()
        var child = ctx:getOpenLayoutElement()
        if child ~= nil then
            var cc: ui.LayoutConfig
            cc.sizing.width.type = ui.SIZING_FIXED
            cc.sizing.width.size.min = 300
            cc.sizing.width.size.max = 300
            cc.sizing.height.type = ui.SIZING_FIXED
            cc.sizing.height.size.min = 300
            cc.sizing.height.size.max = 300
            cc.padding.left = 0
            cc.padding.right = 0
            cc.padding.top = 0
            cc.padding.bottom = 0
            cc.childGap = 0
            cc.childAlignment.x = ui.ALIGN_X_LEFT
            cc.childAlignment.y = ui.ALIGN_Y_TOP
            cc.layoutDirection = ui.LEFT_TO_RIGHT
            child.layoutConfig = ctx:storeLayoutConfig(cc)
        end
        ui.CloseElement()
    end
    ui.CloseElement()
    ui.EndLayout()

    var data = ui.GetScrollContainerData(sid)
    var ok = data.found
    if ok then
        var zero: ui.Vector2
        zero.x = 0
        zero.y = 0
        ui.SetPointerState(zero, false)
        var wheel: ui.Vector2
        wheel.x = -1
        wheel.y = -2
        ui.UpdateScrollContainers(false, wheel, 0.016)

        var p: ui.Vector2
        p.x = 10
        p.y = 10
        ui.SetPointerState(p, true)
        ui.UpdateScrollContainers(true, zero, 0.016)
        p.x = 30
        p.y = 45
        ui.SetPointerState(p, true)
        ui.UpdateScrollContainers(true, zero, 0.016)
        ui.SetPointerState(p, false)
        ui.UpdateScrollContainers(true, zero, 0.016)

        if data.scrollPosition == nil then
            ok = false
        else
            if data.scrollPosition.x > 0 or data.scrollPosition.y > 0 then
                ok = false
            end
        end
    end

    C.free(arena.memory)
    if ok then
        C.printf("test_scroll_momentum_state: PASS\n")
        return 0
    end
    C.printf("test_scroll_momentum_state: FAIL\n")
    return 1
end

local hoverCallbackCount = global(int32, 0)
local errorCallbackCount = global(int32, 0)
local hoverCurrentCallbackCount = global(int32, 0)

-- New FFI-friendly callbacks using out pointers
terra hover_callback(_id: ui.ElementId, _pointer: &ui.PointerData, _userData: &opaque)
    hoverCallbackCount = hoverCallbackCount + 1
end

terra error_callback(_err: &ui.ErrorData)
    errorCallbackCount = errorCallbackCount + 1
end

terra hover_current_callback(_id: ui.ElementId, _pointer: &ui.PointerData, _userData: &opaque)
    hoverCurrentCallbackCount = hoverCurrentCallbackCount + 1
end

terra query_scroll_offset_callback(_id: uint32, _userData: &opaque, out: &ui.Vector2) : int32
    out.x = -7
    out.y = -11
    return 1  -- success
end

terra test_hover_and_element_data()
    var arena: ui.Arena
    arena.nextAllocation = 0
    arena.capacity = 1024 * 1024
    arena.memory = [&int8](C.malloc([uint64](arena.capacity)))

    var ctx: ui.Context
    ui.SetCurrentContext(&ctx)
    if not ctx:initialize(&arena, 128) then
        C.free(arena.memory)
        C.printf("test_hover_and_element_data: FAIL (init)\n")
        return 1
    end

    var hid = ui.HashString(ui.String { isStaticallyAllocated = true, length = 9, chars = "hoverable" }, 0)
    
    ui.BeginLayout(200, 150)
    open_empty_with_id(hid)
    var elem = ctx:getOpenLayoutElement()
    if elem ~= nil then
        var lc: ui.LayoutConfig
        lc.sizing.width.type = ui.SIZING_FIXED
        lc.sizing.width.size.min = 100
        lc.sizing.width.size.max = 100
        lc.sizing.height.type = ui.SIZING_FIXED
        lc.sizing.height.size.min = 80
        lc.sizing.height.size.max = 80
        lc.padding.left = 0
        lc.padding.right = 0
        lc.padding.top = 0
        lc.padding.bottom = 0
        lc.childGap = 0
        lc.childAlignment.x = ui.ALIGN_X_LEFT
        lc.childAlignment.y = ui.ALIGN_Y_TOP
        lc.layoutDirection = ui.LEFT_TO_RIGHT
        elem.layoutConfig = ctx:storeLayoutConfig(lc)
    end
    ui.CloseElement()
    ui.EndLayout()

    var pointer: ui.Vector2
    pointer.x = 20
    pointer.y = 20
    ui.SetPointerState(pointer, false)

    hoverCallbackCount = 0
    ui.OnHover(hid, hover_callback, nil)

    var data = ui.GetElementData(hid)
    var missingId = ui.HashString(ui.String { isStaticallyAllocated = true, length = 7, chars = "missing" }, 0)
    var missingData = ui.GetElementData(missingId)

    ui.SetCurrentContext(nil)
    var noCtxData = ui.GetElementData(hid)
    ui.SetCurrentContext(&ctx)

    var ok = ui.Hovered() and ui.PointerOver(hid) and data.found and hoverCallbackCount == 1
    if ok then
        if data.boundingBox.width < 99.0 or data.boundingBox.height < 79.0 then
            ok = false
        end
    end
    if ok then
        if missingData.found or missingData.boundingBox.width ~= 0 or missingData.boundingBox.height ~= 0 then
            ok = false
        end
    end
    if ok then
        if noCtxData.found or noCtxData.boundingBox.width ~= 0 or noCtxData.boundingBox.height ~= 0 then
            ok = false
        end
    end

    C.free(arena.memory)
    if ok then
        C.printf("test_hover_and_element_data: PASS\n")
        return 0
    end
    C.printf("test_hover_and_element_data: FAIL\n")
    return 1
end

terra build_offscreen_floating(ctx: &ui.Context, id: ui.ElementId)
    open_empty_with_id(id)
    var elem = ctx:getOpenLayoutElement()
    if elem ~= nil then
        var lc: ui.LayoutConfig
        lc.sizing.width.type = ui.SIZING_FIXED
        lc.sizing.width.size.min = 20
        lc.sizing.width.size.max = 20
        lc.sizing.height.type = ui.SIZING_FIXED
        lc.sizing.height.size.min = 20
        lc.sizing.height.size.max = 20
        lc.padding.left = 0
        lc.padding.right = 0
        lc.padding.top = 0
        lc.padding.bottom = 0
        lc.childGap = 0
        lc.childAlignment.x = ui.ALIGN_X_LEFT
        lc.childAlignment.y = ui.ALIGN_Y_TOP
        lc.layoutDirection = ui.LEFT_TO_RIGHT
        elem.layoutConfig = ctx:storeLayoutConfig(lc)

        var sharedCfg: ui.SharedConfig
        sharedCfg.backgroundColor.r = 255
        sharedCfg.backgroundColor.g = 100
        sharedCfg.backgroundColor.b = 100
        sharedCfg.backgroundColor.a = 255
        sharedCfg.cornerRadius.topLeft = 0
        sharedCfg.cornerRadius.topRight = 0
        sharedCfg.cornerRadius.bottomLeft = 0
        sharedCfg.cornerRadius.bottomRight = 0
        sharedCfg.userData = nil
        var sharedPtr = ctx:storeSharedConfig(sharedCfg)
        if sharedPtr ~= nil then
            var cu: ui.ElementConfigUnion
            cu.sharedConfig = sharedPtr
            ctx:attachElementConfig(cu, ui.CONFIG_SHARED)
        end

        var floating: ui.FloatingConfig
        floating.offset.x = 250
        floating.offset.y = 0
        floating.expand.width = 0
        floating.expand.height = 0
        floating.parentId = 0
        floating.zIndex = 1
        floating.attachPoints.element = ui.ATTACH_LEFT_TOP
        floating.attachPoints.parent = ui.ATTACH_LEFT_TOP
        floating.pointerCaptureMode = ui.POINTER_CAPTURE
        floating.attachTo = ui.ATTACH_ROOT
        floating.clipTo = ui.CLIP_NONE
        var floatingPtr = ctx:storeFloatingConfig(floating)
        if floatingPtr ~= nil then
            var cu: ui.ElementConfigUnion
            cu.floatingConfig = floatingPtr
            ctx:attachElementConfig(cu, ui.CONFIG_FLOATING)
        end
    end
    ui.CloseElement()
end

terra test_disable_culling_toggle()
    var arena: ui.Arena
    arena.nextAllocation = 0
    arena.capacity = 1024 * 1024
    arena.memory = [&int8](C.malloc([uint64](arena.capacity)))

    var ctx: ui.Context
    ui.SetCurrentContext(&ctx)
    if not ctx:initialize(&arena, 128) then
        C.free(arena.memory)
        C.printf("test_disable_culling_toggle: FAIL (init)\n")
        return 1
    end

    var id = ui.HashString(ui.String { isStaticallyAllocated = true, length = 13, chars = "offscreen-flt" }, 0)

    ui.SetDisableCulling(false)
    ui.BeginLayout(100, 100)
    build_offscreen_floating(&ctx, id)
    var cmds1 = ui.EndLayout()
    var foundWhenEnabled = false
    if cmds1 ~= nil then
        for i = 0, cmds1.length do
            var cmd = cmds1:get(i)
            if cmd ~= nil and cmd.id == id.id and cmd.commandType == ui.RENDER_RECTANGLE then
                foundWhenEnabled = true
            end
        end
    end

    ui.SetDisableCulling(true)
    ui.BeginLayout(100, 100)
    build_offscreen_floating(&ctx, id)
    var cmds2 = ui.EndLayout()
    var foundWhenDisabled = false
    if cmds2 ~= nil then
        for i = 0, cmds2.length do
            var cmd = cmds2:get(i)
            if cmd ~= nil and cmd.id == id.id and cmd.commandType == ui.RENDER_RECTANGLE then
                foundWhenDisabled = true
            end
        end
    end

    ui.SetDisableCulling(false)
    C.free(arena.memory)

    if (not foundWhenEnabled) and foundWhenDisabled then
        C.printf("test_disable_culling_toggle: PASS\n")
        return 0
    end
    C.printf("test_disable_culling_toggle: FAIL\n")
    return 1
end

terra test_api_coverage_smoke()
    var arena: ui.Arena
    arena.nextAllocation = 0
    arena.capacity = 16 * 1024 * 1024
    arena.memory = [&int8](C.malloc([uint64](arena.capacity)))
    var ok = true

    var dims: ui.Dimensions
    dims.width = 320
    dims.height = 240
    var newCtx = ui.Initialize(arena, dims)
    if newCtx == nil then
        C.free(arena.memory)
        C.printf("test_api_coverage_smoke: FAIL (Initialize)\n")
        return 1
    end
    var ctx = ui.GetCurrentContext()
    if ctx == nil then
        ok = false
    end

    var minMem = ui.MinMemorySize()
    if minMem == 0 then
        ok = false
    end

    ui.SetLayoutDimensions(ui.Dimensions { width = 500, height = 400 })
    if ctx.layoutDimensions.width ~= 500 or ctx.layoutDimensions.height ~= 400 then
        ok = false
    end

    var prevMax = ui.GetMaxElementCount()
    ui.SetMaxElementCount(321)
    if ui.GetMaxElementCount() ~= 321 then
        ok = false
    end
    ui.SetMaxElementCount(prevMax)

    var prevWords = ui.GetMaxMeasureTextCacheWordCount()
    ui.SetMaxMeasureTextCacheWordCount(2048)
    if ui.GetMaxMeasureTextCacheWordCount() ~= 2048 then
        ok = false
    end
    ui.SetMaxMeasureTextCacheWordCount(prevWords)

    ui.SetDebugModeEnabled(true)
    if not ui.IsDebugModeEnabled() then
        ok = false
    end
    ui.SetDebugModeEnabled(false)
    if ui.IsDebugModeEnabled() then
        ok = false
    end

    ui.SetCullingEnabled(true)
    ui.SetExternalScrollHandlingEnabled(true)
    ui.SetExternalScrollHandlingEnabled(false)
    ui.SetErrorHandler(error_callback, nil)
    errorCallbackCount = 0

    -- Trigger percentage-over-1 error callback while keeping layout valid.
    ui.BeginLayout(220, 120)
    open_empty()
    var errElem = ctx:getOpenLayoutElement()
    if errElem ~= nil then
        var ec: ui.LayoutConfig
        ec.sizing.width.type = ui.SIZING_PERCENT
        ec.sizing.width.percent = 1.5
        ec.sizing.height.type = ui.SIZING_PERCENT
        ec.sizing.height.percent = 1.2
        ec.sizing.width.size.min = 0
        ec.sizing.width.size.max = ui.MAXFLOAT
        ec.sizing.height.size.min = 0
        ec.sizing.height.size.max = ui.MAXFLOAT
        ec.padding.left = 0
        ec.padding.right = 0
        ec.padding.top = 0
        ec.padding.bottom = 0
        ec.childGap = 0
        ec.childAlignment.x = ui.ALIGN_X_LEFT
        ec.childAlignment.y = ui.ALIGN_Y_TOP
        ec.layoutDirection = ui.LEFT_TO_RIGHT
        errElem.layoutConfig = ctx:storeLayoutConfig(ec)
    end
    ui.CloseElement()
    ui.EndLayout()
    if errorCallbackCount <= 0 then
        ok = false
    end

    var idA = ui.GetElementId(ui.String { isStaticallyAllocated = true, length = 4, chars = "abcd" })
    var idB = ui.GetElementIdWithIndex(ui.String { isStaticallyAllocated = true, length = 4, chars = "abcd" }, 2)
    if idA.id == 0 or idB.id == 0 or idA.id == idB.id then
        ok = false
    end

    hoverCurrentCallbackCount = 0
    ui.BeginLayout(220, 180)
    open_empty_with_id(idA)
    var e = ctx:getOpenLayoutElement()
    if e ~= nil then
        var lc: ui.LayoutConfig
        lc.sizing.width.type = ui.SIZING_FIXED
        lc.sizing.width.size.min = 120
        lc.sizing.width.size.max = 120
        lc.sizing.height.type = ui.SIZING_FIXED
        lc.sizing.height.size.min = 80
        lc.sizing.height.size.max = 80
        lc.padding.left = 0
        lc.padding.right = 0
        lc.padding.top = 0
        lc.padding.bottom = 0
        lc.childGap = 0
        lc.childAlignment.x = ui.ALIGN_X_LEFT
        lc.childAlignment.y = ui.ALIGN_Y_TOP
        lc.layoutDirection = ui.TOP_TO_BOTTOM
        e.layoutConfig = ctx:storeLayoutConfig(lc)

        var clipCfg: ui.ClipConfig
        clipCfg.horizontal = true
        clipCfg.vertical = true
        clipCfg.childOffset.x = 0
        clipCfg.childOffset.y = 0
        var clipPtr = ctx:storeClipConfig(clipCfg)
        if clipPtr ~= nil then
            var cu: ui.ElementConfigUnion
            cu.clipConfig = clipPtr
            ctx:attachElementConfig(cu, ui.CONFIG_CLIP)
        end

        if not ui.ElementHasConfig(e, ui.CONFIG_CLIP) then
            ok = false
        end
        var foundCfg = ui.FindElementConfigWithType(e, ui.CONFIG_CLIP)
        if foundCfg == nil then
            ok = false
        end

        ui.OnHoverCurrent(hover_current_callback, nil)

        open_empty()
        var child = ctx:getOpenLayoutElement()
        if child ~= nil then
            var cc: ui.LayoutConfig
            cc.sizing.width.type = ui.SIZING_FIXED
            cc.sizing.width.size.min = 400
            cc.sizing.width.size.max = 400
            cc.sizing.height.type = ui.SIZING_FIXED
            cc.sizing.height.size.min = 300
            cc.sizing.height.size.max = 300
            cc.padding.left = 0
            cc.padding.right = 0
            cc.padding.top = 0
            cc.padding.bottom = 0
            cc.childGap = 0
            cc.childAlignment.x = ui.ALIGN_X_LEFT
            cc.childAlignment.y = ui.ALIGN_Y_TOP
            cc.layoutDirection = ui.LEFT_TO_RIGHT
            child.layoutConfig = ctx:storeLayoutConfig(cc)
        end
        ui.CloseElement()
    end
    ui.CloseElement()

    ui.SetQueryScrollOffsetFunction(query_scroll_offset_callback, nil)
    ui.EndLayout()

    var p: ui.Vector2
    p.x = 10
    p.y = 10
    ui.SetPointerState(p, false)
    if not ui.Hovered() or not ui.PointerOver(idA) then
        ok = false
    end
    if hoverCurrentCallbackCount <= 0 then
        ok = false
    end

    var scrollData = ui.GetScrollContainerData(idA)
    if not scrollData.found then
        ok = false
    else
        if scrollData.scrollPosition == nil or scrollData.scrollPosition.x ~= -7 or scrollData.scrollPosition.y ~= -11 then
            ok = false
        end
    end

    -- Explicit scroll state API by element id (setter clamps to container bounds).
    var setPos: ui.Vector2
    setPos.x = 1000
    setPos.y = -1000
    if not ui.SetElementScrollOffset(idA, setPos) then
        ok = false
    end
    var clampedPos = ui.GetElementScrollOffset(idA)
    if clampedPos.x ~= 0 or clampedPos.y > -219 or clampedPos.y < -221 then
        ok = false
    end
    scrollData = ui.GetScrollContainerData(idA)
    if not scrollData.found or scrollData.scrollPosition == nil then
        ok = false
    else
        if scrollData.scrollPosition.x ~= clampedPos.x or scrollData.scrollPosition.y ~= clampedPos.y then
            ok = false
        end
    end
    setPos.x = -7
    setPos.y = -11
    if not ui.SetElementScrollOffset(idA, setPos) then
        ok = false
    end

    -- GetScrollOffset on currently open clip container (fallback path via childOffset).
    ui.BeginLayout(100, 100)
    open_empty_with_id(idA)
    var offElem = ctx:getOpenLayoutElement()
    if offElem ~= nil then
        var oc: ui.LayoutConfig
        oc.sizing.width.type = ui.SIZING_FIXED
        oc.sizing.width.size.min = 50
        oc.sizing.width.size.max = 50
        oc.sizing.height.type = ui.SIZING_FIXED
        oc.sizing.height.size.min = 50
        oc.sizing.height.size.max = 50
        oc.padding.left = 0
        oc.padding.right = 0
        oc.padding.top = 0
        oc.padding.bottom = 0
        oc.childGap = 0
        oc.childAlignment.x = ui.ALIGN_X_LEFT
        oc.childAlignment.y = ui.ALIGN_Y_TOP
        oc.layoutDirection = ui.LEFT_TO_RIGHT
        offElem.layoutConfig = ctx:storeLayoutConfig(oc)
        var ccfg: ui.ClipConfig
        ccfg.horizontal = true
        ccfg.vertical = true
        ccfg.childOffset.x = -3
        ccfg.childOffset.y = -4
        var ccfgPtr = ctx:storeClipConfig(ccfg)
        if ccfgPtr ~= nil then
            var cu: ui.ElementConfigUnion
            cu.clipConfig = ccfgPtr
            ctx:attachElementConfig(cu, ui.CONFIG_CLIP)
        end
    end
    var offset = ui.GetScrollOffset()
    if offset.x ~= -7 or offset.y ~= -11 then
        ok = false
    end
    ui.CloseElement()
    ui.EndLayout()

    -- Basic overflow API surface smoke (maps to clip semantics in current M1 groundwork).
    ui.BeginLayout(64, 64)
    open_empty()
    var overflowElem = ctx:getOpenLayoutElement()
    if overflowElem ~= nil then
        var olc: ui.LayoutConfig
        olc.sizing.width.type = ui.SIZING_FIXED
        olc.sizing.width.size.min = 32
        olc.sizing.width.size.max = 32
        olc.sizing.height.type = ui.SIZING_FIXED
        olc.sizing.height.size.min = 32
        olc.sizing.height.size.max = 32
        olc.padding.left = 0
        olc.padding.right = 0
        olc.padding.top = 0
        olc.padding.bottom = 0
        olc.childGap = 0
        olc.childAlignment.x = ui.ALIGN_X_LEFT
        olc.childAlignment.y = ui.ALIGN_Y_TOP
        olc.layoutDirection = ui.LEFT_TO_RIGHT
        overflowElem.layoutConfig = ctx:storeLayoutConfig(olc)

        var clip_from_overflow: ui.ClipConfig
        clip_from_overflow.horizontal = true
        clip_from_overflow.vertical = true
        clip_from_overflow.childOffset.x = 0
        clip_from_overflow.childOffset.y = 0
        var clip_ptr = ctx:storeClipConfig(clip_from_overflow)
        if clip_ptr ~= nil then
            var cu2: ui.ElementConfigUnion
            cu2.clipConfig = clip_ptr
            if ctx:attachElementConfig(cu2, ui.CONFIG_CLIP) == nil then
                ok = false
            end
        else
            ok = false
        end
    else
        ok = false
    end
    ui.CloseElement()
    ui.EndLayout()

    if not ui.FloatEqual(1.0, 1.0 + ui.EPSILON * 0.5) then
        ok = false
    end
    if ui.clamp(-4.0, -2.0, 3.0) ~= -2.0 then
        ok = false
    end

    C.free(arena.memory)
    if ok then
        C.printf("test_api_coverage_smoke: PASS\n")
        return 0
    end
    C.printf("test_api_coverage_smoke: FAIL\n")
    return 1
end

terra test_min_memory_size_is_sufficient_for_initialize()
    -- MinMemorySize() is part of the C ABI and is commonly used by FFI callers to size
    -- an arena before the first context is initialized.
    ui.SetCurrentContext(nil)

    var minMem = ui.MinMemorySize()
    if minMem == 0 then
        C.printf("test_min_memory_size_is_sufficient_for_initialize: FAIL (minMem == 0)\n")
        return 1
    end

    var arena: ui.Arena
    arena.nextAllocation = 0
    arena.capacity = minMem
    arena.memory = [&int8](C.malloc(minMem))
    if arena.memory == nil then
        C.printf("test_min_memory_size_is_sufficient_for_initialize: FAIL (malloc)\n")
        return 1
    end

    var dims: ui.Dimensions
    dims.width = 320
    dims.height = 240
    var ctx = ui.Initialize(arena, dims)

    C.free(arena.memory)

    if ctx == nil then
        C.printf("test_min_memory_size_is_sufficient_for_initialize: FAIL (Initialize)\n")
        return 1
    end

    C.printf("test_min_memory_size_is_sufficient_for_initialize: PASS\n")
    return 0
end

local advancedFailures = 0
advancedFailures = advancedFailures + test_measure_text_callback()
advancedFailures = advancedFailures + test_text_words_wrap_under_root_compression()
advancedFailures = advancedFailures + test_measure_text_cache_hit_and_reset()
advancedFailures = advancedFailures + test_aspect_ratio_layout()
advancedFailures = advancedFailures + test_floating_attach_points()
advancedFailures = advancedFailures + test_scroll_momentum_state()
advancedFailures = advancedFailures + test_hover_and_element_data()
advancedFailures = advancedFailures + test_disable_culling_toggle()
advancedFailures = advancedFailures + test_api_coverage_smoke()
advancedFailures = advancedFailures + test_min_memory_size_is_sufficient_for_initialize()
if advancedFailures == 0 then
    print("Advanced features: PASS")
else
    print("Advanced features failures: " .. advancedFailures)
end
