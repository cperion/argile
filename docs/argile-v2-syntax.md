# Argile V2 Language Syntax Reference

> Language surface for the immediate-mode Terra UI library

## Overview

Argile V2 is a declarative DSL (embedded in Lua/Terra) for constructing immediate-mode UI layouts with zero runtime overhead. The syntax emphasizes **composition over configuration** and **state overlays over structural mutation**.

## Core Concepts

- **Nodes**: Elements (`el`) and text (`text`)
- **Blocks**: `layout`, `style`, `typography`, `paint`
- **Composition**: `use(...)` for style patches
- **States**: `when` for hover/active/focus overlays

---

## Element Declaration

### Basic Element

```lua
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

```lua
argile el("button")
    layout
        width_fixed(120.0)
        height_fixed(40.0)
    end
    style
        bg(ds.colors.primary_500)
        corner_radius(8.0)
    end
end
```

### Text Node

```lua
argile text("Hello, World!")
    typography
        fontSize(16)
        color(ds.colors.text_primary)
    end
end
```

---

## Layout Block

Controls the element's layout model and sizing.

```lua
layout
    width_fixed(100.0)              -- Fixed pixel width
    height_grow(1.0)                -- Grow to fill available space
    direction(left_to_right)        -- Flow direction
    gap(8)                         -- Space between children
    padding(16)                    -- Internal padding
    align_x(center)                -- Horizontal alignment
    align_y(center)                -- Vertical alignment
end
```

---

## Style Block

Visual styling for the element's appearance.

```lua
style
    bg(ds.colors.surface_600)      -- Background color
    corner_radius(8.0)             -- Corner radius (all corners)
    border_width(2)                -- Border thickness
    border_color(ds.colors.border) -- Border color
end
```

---

## Typography Block

Text styling (only valid inside `text` nodes).

```lua
argile text("Label")
    typography
        fontSize(18)
        color(ds.colors.text_primary)
        letterSpacing(0.5)
        lineHeight(1.5)
    end
end
```

---

## Paint Block

Declarative shape drawing layer.

```lua
paint
    fill(ds.colors.surface_600)      -- Solid fill
    round_rect(0, 0, 100, 50, 8)   -- Rounded rectangle
    stroke(2, ds.colors.border)    -- Stroke
    line(0, 25, 100, 25)           -- Line from (0,25) to (100,25)
end
```

---

## Composition: `use(...)`

Apply reusable style patches.

```lua
local button_style = ds.recipes.button

argile el("my_button")
    use(button_style)
    layout
        width_fixed(120.0)
    end
end
```

Multiple patches compose left-to-right (later patches override earlier):

```lua
argile el
    use(ds.recipes.panel)
    use(ds.tokens.elevated)
    style
        bg(ds.colors.custom)  -- Overrides panel background
    end
end
```

---

## State Overlays: `when`

Apply styles conditionally based on element state. Requires string id.

### Hover State (Implemented)

```lua
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

### Other States (Not Yet Implemented)

The following states are parsed but produce compile-time errors:

- `when active` - Not yet implemented
- `when focus` - Not yet implemented
- `when disabled` - Not yet implemented
- `when selected` - Not yet implemented

---

## Complete Example

```lua
local ui = require("src.builder")
local ds = require("src/style/default_theme")
import "src/lang.argile"

-- Define a styled card component
local Card = argile el("card")
    use(ds.recipes.panel)
    layout
        direction(top_to_bottom)
        width_grow(1.0)
        padding(24)
        gap(16)
    end
    style
        bg(ds.colors.surface_700)
        corner_radius(12.0)
    end
    
    -- Card header
    argile el("header")
        layout
            direction(left_to_right)
            gap(12)
        end
        style
            bg(nil)  -- Transparent
        end
        
        argile text("Card Title")
            typography
                fontSize(20)
                color(ds.colors.text_primary)
                bold(true)
            end
        end
    end
    
    -- Card content
    argile el("content")
        layout
            width_grow(1.0)
        end
        style
            bg(nil)
        end
        
        argile text("This is the card content.")
            typography
                fontSize(14)
                color(ds.colors.text_secondary)
            end
        end
    end
    
    -- Action button with hover state
    argile el("action_button")
        layout
            width_fixed(120.0)
            height_fixed(40.0)
            align_x(center)
            align_y(center)
        end
        style
            bg(ds.colors.primary_600)
            corner_radius(8.0)
        end
        when hover
            style
                bg(ds.colors.primary_500)
            end
        end
        
        argile text("Click Me")
            typography
                fontSize(14)
                color(ds.colors.white)
            end
        end
    end
end

-- Compile to Terra
local compiled = ui.compile(Card)
```

---

## Design Principles

1. **Composition First**: Use `use(...)` to build complex UIs from simple parts
2. **Overlay, Don't Mutate**: `when` states modify appearance, not structure
3. **No Silent Failures**: Unsupported features fail at compile-time with clear errors
4. **Zero Runtime Cost**: Everything compiles to flat Terra AST

## Language Surface Summary

```
el(["id"])              -- Element declaration (id optional)
text("content")         -- Text node

layout ... end          -- Layout configuration
style ... end           -- Visual styling
typography ... end      -- Text styling (text nodes only)
paint ... end           -- Shape drawing

use(patch)              -- Apply style patch
when <state> ... end    -- State overlay (requires id)
```
