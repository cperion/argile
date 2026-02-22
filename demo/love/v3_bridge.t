local ui = require("src.builder")
import "src/lang.argile_v3"

terra love_demo_measure_text(text: ui.StringSlice, textCfg: &ui.TextConfig, _userData: &opaque) : ui.Dimensions
    var out: ui.Dimensions
    out.width = [float](text.length * 8)
    if textCfg ~= nil and textCfg.lineHeight > 0 then
        out.height = [float](textCfg.lineHeight)
    else
        out.height = 16.0
    end
    return out
end

theme love_demo_theme
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
        use(love_demo_theme.card())

        state hover
            style
                bg(token(love_demo_theme.color.hover))
            end
            paint
                fill(token(love_demo_theme.color.accent_hover))
            end
        end

        state active
            style
                bg(token(love_demo_theme.color.active))
            end
        end

        state focus
            style
                bg(token(love_demo_theme.color.focus))
            end
        end

        state selected
            style
                bg(token(love_demo_theme.color.selected))
            end
        end

        state disabled
            style
                bg(token(love_demo_theme.color.disabled))
            end
        end

        el
            part(header)
            layout
                width_grow()
                height_fit()
            end
            slot(header)
                text("Argile V3 + Love2D")
                    id("love_v3_demo_title")
                    use(love_demo_theme.title())
                    state hover
                        typography
                            color(token(love_demo_theme.color.accent_hover))
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
                text("Keys: F focus • S selected • D disabled")
                    use(love_demo_theme.body())
                end
            end
        end
    end
end

local v3_demo_scene_node = argile
    el
        id("love_v3_demo_root")
        use(love_demo_theme.screen())

        demo_card(id = "love_v3_demo_card")
            fill(header)
                text("Argile V3 Demo")
                    id("love_v3_demo_title")
                    use(love_demo_theme.title())
                    state hover
                        typography
                            color(token(love_demo_theme.color.accent_hover))
                        end
                    end
                end
            end

            text("Hover and click the card. Toggle state flags from Love2D.")
                id("love_v3_demo_body")
                use(love_demo_theme.body())
            end

            fill(footer)
                text("Mouse: hover/active | F: focus | S: selected | D: disabled")
                    use(love_demo_theme.body())
                end
            end
        end
    end
end

local compiled_v3_demo_scene = ui.compileResolved(v3_demo_scene_node)

terra LoveDemoV3Frame(width: float, height: float, mouseX: float, mouseY: float, pointerDown: bool) : int32
    ui.SetMeasureTextFunction(love_demo_measure_text, nil)
    ui.ResetMeasureTextCache()

    var p: ui.Vector2
    p.x = mouseX
    p.y = mouseY
    ui.SetPointerState(p, pointerDown)

    ui.BeginLayout(width, height)
    [compiled_v3_demo_scene]
    return ui.FinalizeLayout()
end

return {
    LoveDemoV3Frame = LoveDemoV3Frame,
}
