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
