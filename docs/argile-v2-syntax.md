# Argile V2 Language Syntax Reference

> Language surface for the immediate-mode Terra UI library

## Overview

Argile V2 is a declarative DSL (embedded in Lua/Terra) for constructing immediate-mode UI layouts with zero runtime overhead. The syntax emphasizes **composition over configuration** and **state overlays over structural mutation**.

## Core Concepts

- **Nodes**: Elements (`el`) and text (`text`)
- **Blocks**: `layout`, `style`, `typography`, `paint`
- **Composition**: `use(...)` for style patches
- **States**: `when` overlays (`hover` implemented; others currently error)

---

## Element Declaration

### Basic Element

```terra
argile el
    layout
        width_fixed(100.0)
        height_fixed(50.0)
    end
    style
        bg(ds.colors.surface_600)
    end
end
```

### Element with ID

```terra
argile el("button")
    layout
        width_fixed(120.0)
        height_fixed(40.0)
    end
    style
        bg(ds.colors.primary_500)
        radius(8.0)
    end
end
```

### Text Node

```terra
argile text("Hello, World!")
    typography
        font_size(16)
        color(ds.colors.fg_default)
    end
end
```

---

## Layout Block

Controls the element's layout model and sizing.

```terra
layout
    width_fixed(100.0)              -- Fixed pixel width
    height_grow                     -- Grow to fill available space
    dir(left_to_right)              -- Flow direction
    gap(8)                          -- Space between children
    padding(16)                     -- Internal padding
    align_x(center)                 -- Horizontal alignment
    align_y(center)                 -- Vertical alignment
end
```

---

## Style Block

Visual styling for the element's appearance.

```terra
style
    bg(ds.colors.surface_600)      -- Background color
    radius(8.0)                    -- Corner radius (all corners)
    border_width(2)                -- Border thickness
    border_color(ds.colors.border_default) -- Border color
end
```

---

## Typography Block

Text styling (only valid inside `text` nodes).

```terra
argile text("Label")
    typography
        font_size(18)
        color(ds.colors.fg_default)
        letter_spacing(1)
        line_height(24)
    end
end
```

---

## Paint Block

Declarative shape drawing layer.

```terra
paint
    fill(ds.colors.surface_600)      -- Solid fill
    round_rect(0, 0, 100, 50, 8)     -- Rounded rectangle
    stroke(ds.colors.border_muted, 2) -- Stroke(color, width)
    line(0, 25, 100, 25)             -- Line from (0,25) to (100,25)
end
```

---

## Composition: `use(...)`

Apply reusable style patches.

```terra
local button_style = ds.button()

argile el("my_button")
    use(button_style)
    layout
        width_fixed(120.0)
    end
end
```

Multiple patches compose left-to-right (later patches override earlier):

```terra
argile el
    use(ds.panel())
    use({
        border = { color = ds.colors.border_muted }
    })
    style
        bg(ds.colors.primary_700)  -- Overrides panel background
    end
end
```

---

## State Overlays: `when`

Apply styles conditionally based on element state.

Current V2 runtime support:

- `hover` overlays are implemented and require a string id
- other parsed states currently fail with clear compile-time errors

### Hover State (Implemented for `style` and `paint` overlays)

```terra
argile el("hover_button")
    layout
        width_fixed(120.0)
        height_fixed(40.0)
    end
    style
        bg(ds.colors.surface_500)
    end
    when hover
        style
            bg(ds.colors.primary_500)
        end
    end
end
```

Current limitation:

- `when hover` with `typography` overlays is not yet implemented and fails with a clear compile-time error.

### Other States (Not Yet Implemented)

The following states are parsed but produce compile-time errors:

- `when active` - Not yet implemented
- `when focus` - Not yet implemented
- `when disabled` - Not yet implemented
- `when selected` - Not yet implemented

---

## Complete Example

```terra
local ui = require("src.builder")
local ds = require("src/style/default_theme")
import "src/lang.argile"

local compiled_card = argile el("card")
    use(ds.panel())
    layout
        dir(top_to_bottom)
        width_grow
        padding(24)
        gap(16)
    end
    style
        bg(ds.colors.surface_700)
        radius(12.0)
    end
    
    -- Card header
    el("header")
        layout
            dir(left_to_right)
            gap(12)
        end
        style
            bg(ds.colors.transparent)
        end
        
        text("Card Title")
            typography
                font_size(ds.font_sizes.xl)
                color(ds.colors.white)
            end
        end
    end
    
    -- Card content
    el("content")
        layout
            width_grow
        end
        style
            bg(ds.colors.transparent)
        end
        
        text("This is the card content.")
            typography
                font_size(ds.font_sizes.md)
                color(ds.colors.fg_subtle)
            end
        end
    end
    
    -- Action button with hover state
    el("action_button")
        layout
            width_fixed(120.0)
            height_fixed(40.0)
            align_x(center)
            align_y(center)
        end
        style
            bg(ds.colors.primary_600)
            radius(8.0)
        end
        when hover
            style
                bg(ds.colors.primary_500)
            end
        end
        
        text("Click Me")
            typography
                font_size(ds.font_sizes.md)
                color(ds.colors.white)
            end
        end
    end
end

-- `compiled_card` is already a Terra quote emitted by the language extension
```

---

## Design Principles

1. **Composition First**: Use `use(...)` to build complex UIs from simple parts
2. **Overlay, Don't Mutate**: `when` states modify appearance, not structure
3. **No Silent Failures**: Unsupported features fail at compile-time with clear errors
4. **Zero Runtime Cost**: Everything compiles to flat Terra AST

## Language Surface Summary

```text
el                      -- Element declaration (no id)
el("id")                -- Element declaration (string id)
text("content")         -- Text node

layout ... end          -- Layout configuration
style ... end           -- Visual styling
typography ... end      -- Text styling (text nodes only)
paint ... end           -- Shape drawing

use(patch)              -- Apply style patch / recipe result
when <state> ... end    -- State overlay (hover implemented; hover requires string id)
```
