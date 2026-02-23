-- Backend-neutral DSL demo scene for Argile
-- Exports: ArgileDemoFrameForContext, ArgileDemoGetIds
-- This scene is used by all backend demos (Love2D, raylib, SDL3)

local ui = require("src.init")
local hash = require("src.hash")
local config = require("src.config")
import "src/lang.argile"

-- Demo-scene specific text measurement (8px per char fallback)
-- New FFI-friendly signature: out pointer + int32 return
terra demo_measure_text(text: &ui.StringSlice, textCfg: &ui.TextConfig, _userData: &opaque, out: &ui.Dimensions) : int32
    out.width = [float](text.length * 8)
    if textCfg ~= nil and textCfg.lineHeight > 0 then
        out.height = [float](textCfg.lineHeight)
    else
        out.height = 16.0
    end
    return 1  -- success
end

-- Theme definition for the demo card
theme demo_theme
    token color.bg = { r = 0.08, g = 0.10, b = 0.14, a = 1.0 }
    token color.panel = { r = 0.12, g = 0.15, b = 0.20, a = 1.0 }
    token color.border = { r = 0.23, g = 0.29, b = 0.37, a = 1.0 }
    token color.text = { r = 0.92, g = 0.95, b = 1.00, a = 1.0 }
    token color.muted = { r = 0.70, g = 0.77, b = 0.88, a = 1.0 }
    token color.hover = { r = 0.17, g = 0.25, b = 0.40, a = 1.0 }
    token color.active = { r = 0.12, g = 0.19, b = 0.33, a = 1.0 }
    token color.focus = { r = 0.13, g = 0.32, b = 0.25, a = 1.0 }
    token color.selected = { r = 0.40, g = 0.27, b = 0.12, a = 1.0 }
    token color.disabled = { r = 0.26, g = 0.26, b = 0.28, a = 1.0 }
    token color.accent = { r = 0.95, g = 0.62, b = 0.27, a = 1.0 }
    token color.accent_hover = { r = 1.00, g = 0.74, b = 0.35, a = 1.0 }
    token radius.card = 10

    recipe screen()
        layout
            width_grow()
            height_grow()
            dir(top_to_bottom)
            align_x(center)
            align_y(center)
            padding(20)
            gap(12)
        end
        style
            bg(token(color.bg))
        end
    end

    recipe card()
        layout
            width_fixed(440)
            height_fit()
            dir(top_to_bottom)
            padding(12)
            gap(8)
        end
        style
            bg(token(color.panel))
            radius(token(radius.card))
            border_width(1)
            border_color(token(color.border))
        end
        paint
            fill(token(color.accent))
            round_rect(10, 10, 28, 8, 2)
        end
    end

    recipe title()
        typography
            color(token(color.text))
            font_size(18)
            line_height(18)
        end
    end

    recipe body()
        typography
            color(token(color.muted))
            font_size(14)
            line_height(16)
        end
    end
end

component demo_card(props)
    root
        id(props.id)
        use(demo_theme.card())

        state hover
            style
                bg(token(demo_theme.color.hover))
            end
            paint
                fill(token(demo_theme.color.accent_hover))
            end
        end

        state active
            style
                bg(token(demo_theme.color.active))
            end
        end

        state focus
            style
                bg(token(demo_theme.color.focus))
            end
        end

        state selected
            style
                bg(token(demo_theme.color.selected))
            end
        end

        state disabled
            style
                bg(token(demo_theme.color.disabled))
            end
        end

        el
            part(header)
            layout
                width_grow()
                height_fit()
            end
            slot(header)
                text("Argile DSL Multi-Backend Demo")
                    id("demo_title")
                    use(demo_theme.title())
                    state hover
                        typography
                            color(token(demo_theme.color.accent_hover))
                        end
                    end
                end
            end
        end

        el
            part(body)
            layout
                width_grow()
                height_fit()
                dir(top_to_bottom)
                gap(6)
            end
            children
        end

        el
            part(footer)
            layout
                width_grow()
                height_fit()
            end
            slot(footer)
                text("Keys: F focus | S selected | D disabled | R reset")
                    use(demo_theme.body())
                end
            end
        end
    end
end

-- The main demo scene - returns a Terra Quote directly
local demo_scene = argile
    el
        id("demo_root")
        use(demo_theme.screen())

        demo_card(id = "demo_card")
            fill(header)
                text("Argile DSL Demo")
                    id("demo_card_title")
                    use(demo_theme.title())
                    state hover
                        typography
                            color(token(demo_theme.color.accent_hover))
                        end
                    end
                end
            end

            text("Hover and click the card. Toggle state flags from the backend.")
                id("demo_card_body")
                use(demo_theme.body())
            end

            fill(footer)
                text("Mouse: hover/active | F: focus | S: selected | D: disabled")
                    use(demo_theme.body())
                end
            end
        end
    end
end

-- Portable scene export: Backend-neutral frame API
-- All backends (Love2D, raylib, SDL3) call this function
terra ArgileDemoFrameForContext(ctx: &ui.Context, input: &ui.ArgileFrameInput) : int32
    ui.SetCurrentContext(ctx)
    
    -- Set up text measurement for this frame
    ui.SetMeasureTextFunctionForContext(ctx, demo_measure_text, nil)
    ui.ResetMeasureTextCacheForContext(ctx)
    
    -- Set pointer state from input
    var p: ui.Vector2
    p.x = input.pointer_x
    p.y = input.pointer_y
    ui.SetPointerStateForContext(ctx, p, input.pointer_down)
    
    -- Begin layout with input dimensions
    ui.BeginLayoutForContext(ctx, input.width, input.height)
    
    -- Execute compiled scene (demo_scene is a Terra Quote)
    [demo_scene]
    
    -- Finalize and return command count
    return ui.FinalizeLayoutForContext(ctx)
end

-- Export demo element IDs for state toggling
-- Backends can use these instead of computing hashes
terra ArgileDemoGetIds(ids: &ui.ArgileDemoIds)
    ids.card = ui.GetElementIdFromChars("demo_card", 9)
    ids.title = ui.GetElementIdFromChars("demo_card_title", 15)
    ids.body = ui.GetElementIdFromChars("demo_card_body", 14)
end

return {
    ArgileDemoFrameForContext = ArgileDemoFrameForContext,
    ArgileDemoGetIds = ArgileDemoGetIds,
}
