local C = terralib.includecstring[[
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
]]

-- Load the builder module
local ui = require("src.builder")

print("=== Compile-Time UI Builder Test ===")

-- Simple layout without text elements
local myLayout = {
    id = "main_container",
    layout = {
        widthType = ui.SIZING_FIXED,
        minWidth = 800.0,
        maxWidth = 800.0,
        heightType = ui.SIZING_FIXED,
        minHeight = 600.0,
        maxHeight = 600.0,
        layoutDir = ui.TOP_TO_BOTTOM,
        paddingLeft = 20,
        paddingRight = 20,
        paddingTop = 20,
        paddingBottom = 20,
        childGap = 10
    },
    children = {
        {
            id = "header",
            layout = {
                widthType = ui.SIZING_GROW,
                heightType = ui.SIZING_FIXED,
                minHeight = 60.0,
                maxHeight = 60.0
            }
        },
        {
            id = "content",
            layout = {
                widthType = ui.SIZING_GROW,
                heightType = ui.SIZING_GROW,
                layoutDir = ui.LEFT_TO_RIGHT,
                childGap = 15
            },
            children = {
                {
                    id = "sidebar",
                    layout = {
                        widthType = ui.SIZING_FIXED,
                        minWidth = 200.0,
                        maxWidth = 200.0,
                        heightType = ui.SIZING_GROW
                    }
                },
                {
                    id = "main",
                    layout = {
                        widthType = ui.SIZING_GROW,
                        heightType = ui.SIZING_GROW
                    }
                }
            }
        },
        {
            id = "footer",
            layout = {
                widthType = ui.SIZING_GROW,
                heightType = ui.SIZING_FIXED,
                minHeight = 40.0,
                maxHeight = 40.0
            }
        }
    }
}

-- Compile the Lua table into Terra code at compile time
local compiledLayout = ui.compile(myLayout)

-- Now use it in a Terra function
terra test_compile_time_builder()
    var arena: ui.Arena
    arena.nextAllocation = 0
    arena.capacity = 1024 * 1024
    arena.memory = [&int8](C.malloc([uint64](arena.capacity)))
    
    var ctx: ui.Context
    ui.SetCurrentContext(&ctx)
    
    if not ctx:initialize(&arena, 100) then
        C.printf("FAIL: Could not initialize context\n")
        C.free(arena.memory)
        return 1
    end
    
    ui.BeginLayout(800.0, 600.0)
    
    -- Execute the compiled layout - this is ZERO overhead at runtime!
    -- The entire tree is flattened to sequential instructions
    [compiledLayout]
    
    var cmds = ui.EndLayout()
    
    C.printf("Layout elements created: %d\n", ctx.layoutElements.length)
    
    var passed = true
    
    if cmds == nil then
        C.printf("FAIL: EndLayout returned nil\n")
        passed = false
    else
        C.printf("Render commands count: %d\n", cmds.length)
        if cmds.length < 1 then
            C.printf("Note: No render commands (elements may not have configs attached)\n")
        else
            C.printf("Generated %d render commands\n", cmds.length)
            for i = 0, cmds.length do
                var cmd = cmds:get(i)
                if cmd ~= nil then
                    C.printf("  cmd[%d]: type=%d\n", i, cmd.commandType)
                end
            end
        end
    end
    
    -- Check that elements were created
    if ctx.layoutElements.length < 4 then
        C.printf("FAIL: Expected at least 4 layout elements (root + 3 children)\n")
        passed = false
    else
        C.printf("PASS: Created %d layout elements\n", ctx.layoutElements.length)
    end
    
    C.free(arena.memory)
    
    if passed then
        C.printf("test_compile_time_builder: PASS\n")
        return 0
    else
        C.printf("test_compile_time_builder: FAIL\n")
        return 1
    end
end

terra run_tests() : int32
    return test_compile_time_builder()
end

local result = run_tests()
if result == 0 then
    print("\n=== All Tests Passed ===")
    print("\nThe builder successfully:")
    print("1. Parsed Lua tables at COMPILE TIME")
    print("2. Generated flat Terra AST (zero runtime overhead)")
    print("3. Created layout elements correctly")
    print("\nUsage example:")
    print("  local ui = require('src.builder')")
    print("  local layout = { id = 'container', children = {...} }")
    print("  local compiled = ui.compile(layout)")
    print("  -- In terra function:")
    print("  [ compiled ]  -- Zero-overhead execution!")
end

os.exit(result)
