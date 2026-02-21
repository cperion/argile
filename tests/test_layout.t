local C = terralib.includecstring[[
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
]]
local ui = require("src.init")

print("=== Layout Engine Test ===")

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
    
    ui.OpenElement()
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
    
    ui.OpenElement()
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
    ui.OpenElement()
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
    ui.OpenElement()
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
    ui.OpenElement()
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
        ui.OpenElement()
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

terra mock_measure_text(text: ui.StringSlice, textCfg: &ui.TextConfig, userData: &opaque) : ui.Dimensions
    var out: ui.Dimensions
    out.width = [float](text.length * 8)
    if textCfg ~= nil and textCfg.lineHeight > 0 then
        out.height = [float](textCfg.lineHeight)
    else
        out.height = 16.0
    end
    return out
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
    ui.OpenElement()
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
    ui.OpenElement()
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
    ui.OpenElementWithId(sid)
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

        ui.OpenElement()
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

local advancedFailures = 0
advancedFailures = advancedFailures + test_measure_text_callback()
advancedFailures = advancedFailures + test_aspect_ratio_layout()
advancedFailures = advancedFailures + test_floating_attach_points()
advancedFailures = advancedFailures + test_scroll_momentum_state()
if advancedFailures == 0 then
    print("Advanced features: PASS")
else
    print("Advanced features failures: " .. advancedFailures)
end
