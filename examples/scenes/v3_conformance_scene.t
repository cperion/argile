-- Conformance test scene for backend adapter validation
-- Emits a deterministic command stream covering all render command types
-- Used to verify backend adapters handle commands correctly

local ui = require("src.builder")
local hash = require("src.hash")
import "src/lang.argile_v3"

-- Simple text measurement for conformance
terra conformance_measure_text(text: ui.StringSlice, textCfg: &ui.TextConfig, _userData: &opaque) : ui.Dimensions
    var out: ui.Dimensions
    out.width = [float](text.length * 8)
    out.height = 16.0
    return out
end

-- Conformance scene with all command types
conformance_scene = argile
    el
        id("conformance_root")
        layout
            width_grow()
            height_grow()
            dir(top_to_bottom)
            padding(20)
            gap(10)
        end
        style
            bg({ r = 0.1, g = 0.1, b = 0.1, a = 1.0 })
        end

        -- Rectangle command
        el
            id("conformance_rect")
            layout
                width_fixed(100)
                height_fixed(50)
            end
            style
                bg({ r = 1.0, g = 0.0, b = 0.0, a = 1.0 })
                radius(5)
            end
        end

        -- Border command
        el
            id("conformance_border")
            layout
                width_fixed(100)
                height_fixed(50)
            end
            style
                bg({ r = 0.0, g = 1.0, b = 0.0, a = 0.5 })
                radius(5)
                border_width(2)
                border_color({ r = 0.0, g = 0.0, b = 1.0, a = 1.0 })
            end
        end

        -- Text command
        el
            id("conformance_text_container")
            layout
                width_fixed(200)
                height_fit()
            end
            style
                bg({ r = 0.2, g = 0.2, b = 0.2, a = 1.0 })
            end
            
            text("Conformance")
                id("conformance_text")
                typography
                    color({ r = 1.0, g = 1.0, b = 1.0, a = 1.0 })
                    font_size(16)
                end
            end
        end

        -- Paint command
        el
            id("conformance_paint")
            layout
                width_fixed(100)
                height_fixed(100)
            end
            style
                bg({ r = 0.3, g = 0.3, b = 0.3, a = 1.0 })
            end
            paint
                fill({ r = 1.0, g = 1.0, b = 0.0, a = 1.0 })
                rect(10, 10, 30, 30)
                fill({ r = 0.0, g = 1.0, b = 1.0, a = 1.0 })
                round_rect(50, 10, 40, 25, 5)
                fill({ r = 1.0, g = 0.0, b = 1.0, a = 1.0 })
                circle(75, 75, 15)
                stroke({ r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 2)
                line(10, 80, 40, 90)
            end
        end
    end
end

local compiled_scene = ui.compileResolved(conformance_scene)

terra ArgileConformanceFrameForContext(ctx: &ui.Context, input: &ui.ArgileFrameInput) : int32
    ui.SetCurrentContext(ctx)
    ui.SetMeasureTextFunctionForContext(ctx, conformance_measure_text, nil)
    ui.ResetMeasureTextCacheForContext(ctx)
    
    var p: ui.Vector2
    p.x = input.pointer_x
    p.y = input.pointer_y
    ui.SetPointerStateForContext(ctx, p, input.pointer_down)
    
    ui.BeginLayoutForContext(ctx, input.width, input.height)
    [compiled_scene]
    return ui.FinalizeLayoutForContext(ctx)
end

return {
    ArgileConformanceFrameForContext = ArgileConformanceFrameForContext,
}