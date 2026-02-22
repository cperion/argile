-- State matrix test scene for runtime state overlay validation
-- Tests hover, active, focus, selected, disabled state rendering
-- Used by core correctness tests and backend smoke tests

local ui = require("src.builder")
local hash = require("src.hash")
import "src/lang.argile_v3"

-- New FFI-friendly signature: out pointer + int32 return
terra state_measure_text(text: &ui.StringSlice, textCfg: &ui.TextConfig, _userData: &opaque, out: &ui.Dimensions) : int32
    out.width = [float](text.length * 8)
    out.height = 16.0
    return 1  -- success
end

-- State matrix scene with all runtime states
state_matrix_scene = argile
    el
        id("state_matrix_root")
        layout
            width_grow()
            height_grow()
            dir(top_to_bottom)
            padding(20)
            gap(15)
        end
        style
            bg({ r = 0.08, g = 0.08, b = 0.10, a = 1.0 })
        end

        -- Hover state element
        el
            id("state_hover")
            layout
                width_fixed(200)
                height_fixed(40)
                align_x(center)
            end
            style
                bg({ r = 0.3, g = 0.3, b = 0.3, a = 1.0 })
                radius(5)
            end
            state hover
                style
                    bg({ r = 0.4, g = 0.6, b = 0.8, a = 1.0 })
                end
            end
            
            text("Hover")
                id("state_hover_text")
                typography
                    color({ r = 1.0, g = 1.0, b = 1.0, a = 1.0 })
                    font_size(14)
                end
            end
        end

        -- Active state element (hover + pointer down)
        el
            id("state_active")
            layout
                width_fixed(200)
                height_fixed(40)
                align_x(center)
            end
            style
                bg({ r = 0.3, g = 0.3, b = 0.3, a = 1.0 })
                radius(5)
            end
            state active
                style
                    bg({ r = 0.8, g = 0.4, b = 0.4, a = 1.0 })
                end
            end
            
            text("Active")
                id("state_active_text")
                typography
                    color({ r = 1.0, g = 1.0, b = 1.0, a = 1.0 })
                    font_size(14)
                end
            end
        end

        -- Focus state element
        el
            id("state_focus")
            layout
                width_fixed(200)
                height_fixed(40)
                align_x(center)
            end
            style
                bg({ r = 0.3, g = 0.3, b = 0.3, a = 1.0 })
                radius(5)
            end
            state focus
                style
                    bg({ r = 0.4, g = 0.8, b = 0.4, a = 1.0 })
                end
            end
            
            text("Focus")
                id("state_focus_text")
                typography
                    color({ r = 1.0, g = 1.0, b = 1.0, a = 1.0 })
                    font_size(14)
                end
            end
        end

        -- Selected state element
        el
            id("state_selected")
            layout
                width_fixed(200)
                height_fixed(40)
                align_x(center)
            end
            style
                bg({ r = 0.3, g = 0.3, b = 0.3, a = 1.0 })
                radius(5)
            end
            state selected
                style
                    bg({ r = 0.8, g = 0.8, b = 0.4, a = 1.0 })
                end
            end
            
            text("Selected")
                id("state_selected_text")
                typography
                    color({ r = 1.0, g = 1.0, b = 1.0, a = 1.0 })
                    font_size(14)
                end
            end
        end

        -- Disabled state element
        el
            id("state_disabled")
            layout
                width_fixed(200)
                height_fixed(40)
                align_x(center)
            end
            style
                bg({ r = 0.3, g = 0.3, b = 0.3, a = 1.0 })
                radius(5)
            end
            state disabled
                style
                    bg({ r = 0.5, g = 0.5, b = 0.5, a = 0.5 })
                end
            end
            
            text("Disabled")
                id("state_disabled_text")
                typography
                    color({ r = 0.7, g = 0.7, b = 0.7, a = 1.0 })
                    font_size(14)
                end
            end
        end
    end
end

local compiled_scene = ui.compileResolved(state_matrix_scene)

terra ArgileStateMatrixFrameForContext(ctx: &ui.Context, input: &ui.ArgileFrameInput) : int32
    ui.SetCurrentContext(ctx)
    ui.SetMeasureTextFunctionForContext(ctx, state_measure_text, nil)
    ui.ResetMeasureTextCacheForContext(ctx)
    
    var p: ui.Vector2
    p.x = input.pointer_x
    p.y = input.pointer_y
    ui.SetPointerStateForContext(ctx, p, input.pointer_down)
    
    ui.BeginLayoutForContext(ctx, input.width, input.height)
    [compiled_scene]
    return ui.FinalizeLayoutForContext(ctx)
end

-- Helper to get IDs for programmatic state control
terra ArgileStateMatrixGetIds(ids: &ui.ArgileDemoIds)
    ids.card = ui.GetElementIdFromChars("state_matrix_root", 17)
    ids.title = ui.GetElementIdFromChars("state_hover", 11)
    ids.body = ui.GetElementIdFromChars("state_active", 12)
end

return {
    ArgileStateMatrixFrameForContext = ArgileStateMatrixFrameForContext,
    ArgileStateMatrixGetIds = ArgileStateMatrixGetIds,
}
