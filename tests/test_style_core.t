local C = terralib.includecstring[[
    #include <stdio.h>
    #include <stdlib.h>
]]

local style = require("src/style/core")
local theme = require("src/style/default_theme")

local function assert_equal(name, a, b)
    if a ~= b then
        print("FAIL: " .. name .. " - expected " .. tostring(b) .. ", got " .. tostring(a))
        os.exit(1)
    end
end

local function assert_table_equal(name, a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        print("FAIL: " .. name .. " - expected tables")
        os.exit(1)
    end
    for k, v in pairs(b) do
        if a[k] ~= v then
            print("FAIL: " .. name .. " - key " .. tostring(k) .. " expected " .. tostring(v) .. ", got " .. tostring(a[k]))
            os.exit(1)
        end
    end
end

local tests_passed = 0

do
    local p = style.StylePatch:new()
    assert_equal("StylePatch:new creates patch", getmetatable(p), style.StylePatch)
    tests_passed = tests_passed + 1
end

do
    local a = style.StylePatch:new()
    a.shared = { backgroundColor = { r = 1, g = 0, b = 0, a = 1 } }
    
    local b = style.StylePatch:new()
    b.shared = { backgroundColor = { r = 0, g = 1, b = 0, a = 1 } }
    
    local merged = style.merge_patch(a, b)
    assert_equal("merge_patch: last write wins on color", merged.shared.backgroundColor.g, 1)
    tests_passed = tests_passed + 1
end

do
    local a = style.StylePatch:new()
    a.shared = {
        backgroundColor = { r = 1, g = 0, b = 0, a = 1 },
        cornerRadius = { topLeft = 5, topRight = 5, bottomLeft = 5, bottomRight = 5 }
    }
    
    local b = style.StylePatch:new()
    b.shared = { backgroundColor = { r = 0, g = 1, b = 0, a = 1 } }
    
    local merged = style.merge_patch(a, b)
    assert_equal("deep_merge preserves non-overlapping fields", merged.shared.cornerRadius.topLeft, 5)
    tests_passed = tests_passed + 1
end

do
    local a = nil
    local b = style.StylePatch:new()
    b.shared = { backgroundColor = { r = 0, g = 1, b = 0, a = 1 } }
    
    local merged = style.merge_patch(a, b)
    assert_equal("merge_patch handles nil first arg", merged.shared.backgroundColor.g, 1)
    tests_passed = tests_passed + 1
end

do
    local a = style.StylePatch:new()
    a.shared = { backgroundColor = { r = 1, g = 0, b = 0, a = 1 } }
    
    local merged = style.merge_patch(a, nil)
    assert_equal("merge_patch handles nil second arg", merged.shared.backgroundColor.r, 1)
    tests_passed = tests_passed + 1
end

do
    local a = style.StylePatch:new()
    a.shared = { backgroundColor = { r = 1, g = 0, b = 0, a = 1 } }
    
    local b = style.StylePatch:new()
    b.border = { color = { r = 0, g = 0, b = 1, a = 1 }, width = { left = 2, right = 2, top = 2, bottom = 2, betweenChildren = 0 } }
    
    local merged = style.merge_patch(a, b)
    assert_equal("merge_patch combines different config types - shared exists", merged.shared.backgroundColor.r, 1)
    assert_equal("merge_patch combines different config types - border exists", merged.border.color.b, 1)
    tests_passed = tests_passed + 1
end

do
    local a = style.StylePatch:new()
    a.states = {}
    a.states[style.STATE_HOVER] = style.StylePatch:new()
    a.states[style.STATE_HOVER].shared = { backgroundColor = { r = 0.5, g = 0.5, b = 0.5, a = 1 } }
    
    local b = style.StylePatch:new()
    b.states = {}
    b.states[style.STATE_ACTIVE] = style.StylePatch:new()
    b.states[style.STATE_ACTIVE].shared = { backgroundColor = { r = 0.3, g = 0.3, b = 0.3, a = 1 } }
    
    local merged = style.merge_patch(a, b)
    assert_equal("merge_patch combines states - hover preserved", merged.states[style.STATE_HOVER].shared.backgroundColor.r, 0.5)
    assert_equal("merge_patch combines states - active added", merged.states[style.STATE_ACTIVE].shared.backgroundColor.r, 0.3)
    tests_passed = tests_passed + 1
end

do
    local a = style.StylePatch:new()
    a.paint = { style.paint_fill({ r = 1, g = 0, b = 0, a = 1 }) }
    
    local b = style.StylePatch:new()
    b.paint = { style.paint_rect(0, 0, 100, 50) }
    
    local merged = style.merge_patch(a, b)
    assert_equal("merge_patch appends paint ops", #merged.paint, 2)
    assert_equal("merge_patch paint order - first is fill", merged.paint[1].kind, style.PaintOp.FILL)
    assert_equal("merge_patch paint order - second is rect", merged.paint[2].kind, style.PaintOp.RECT)
    tests_passed = tests_passed + 1
end

do
    local patch = style.StylePatch:new()
    patch.shared = { backgroundColor = { r = 1, g = 0, b = 0, a = 1 } }
    
    local clone = patch:clone()
    clone.shared.backgroundColor.r = 0
    
    assert_equal("clone is independent", patch.shared.backgroundColor.r, 1)
    tests_passed = tests_passed + 1
end

do
    local c = style.color(0.5, 0.6, 0.7, 0.8)
    assert_equal("color helper - r", c.r, 0.5)
    assert_equal("color helper - g", c.g, 0.6)
    assert_equal("color helper - b", c.b, 0.7)
    assert_equal("color helper - a", c.a, 0.8)
    tests_passed = tests_passed + 1
end

do
    local r = style.corner_radius(4)
    assert_equal("corner_radius uniform - tl", r.topLeft, 4)
    assert_equal("corner_radius uniform - tr", r.topRight, 4)
    assert_equal("corner_radius uniform - bl", r.bottomLeft, 4)
    assert_equal("corner_radius uniform - br", r.bottomRight, 4)
    tests_passed = tests_passed + 1
end

do
    local r = style.corner_radius(1, 2, 3, 4)
    assert_equal("corner_radius individual - tl", r.topLeft, 1)
    assert_equal("corner_radius individual - tr", r.topRight, 2)
    assert_equal("corner_radius individual - bl", r.bottomLeft, 3)
    assert_equal("corner_radius individual - br", r.bottomRight, 4)
    tests_passed = tests_passed + 1
end

do
    local bw = style.border_width(2)
    assert_equal("border_width uniform - left", bw.left, 2)
    assert_equal("border_width uniform - right", bw.right, 2)
    assert_equal("border_width uniform - top", bw.top, 2)
    assert_equal("border_width uniform - bottom", bw.bottom, 2)
    tests_passed = tests_passed + 1
end

do
    local op = style.paint_fill({ r = 1, g = 1, b = 1, a = 1 })
    assert_equal("paint_fill creates fill op", op.kind, style.PaintOp.FILL)
    tests_passed = tests_passed + 1
end

do
    local op = style.paint_rect(10, 20, 100, 50)
    assert_equal("paint_rect creates rect op", op.kind, style.PaintOp.RECT)
    assert_equal("paint_rect x", op.x, 10)
    assert_equal("paint_rect y", op.y, 20)
    assert_equal("paint_rect w", op.w, 100)
    assert_equal("paint_rect h", op.h, 50)
    tests_passed = tests_passed + 1
end

do
    local panel = theme.panel()
    assert_equal("theme.panel has shared config", panel.shared ~= nil, true)
    assert_equal("theme.panel backgroundColor exists", panel.shared.backgroundColor ~= nil, true)
    tests_passed = tests_passed + 1
end

do
    local button = theme.button({ tone = "primary", size = "md" })
    assert_equal("theme.button has shared config", button.shared ~= nil, true)
    assert_equal("theme.button has hover state", button.states ~= nil and button.states[style.STATE_HOVER] ~= nil, true)
    tests_passed = tests_passed + 1
end

do
    local text_body = theme.text.body()
    assert_equal("theme.text.body has textConfig", text_body.textConfig ~= nil, true)
    assert_equal("theme.text.body textColor exists", text_body.textConfig.textColor ~= nil, true)
    tests_passed = tests_passed + 1
end

do
    local patch = style.StylePatch:new()
    local ops = {
        { name = "bg", args = { { r = 1, g = 0.5, b = 0, a = 1 } } },
        { name = "radius", args = { 8 } },
    }
    local result = style.apply_style_ops(patch, ops)
    assert_equal("apply_style_ops - bg applied", result.shared.backgroundColor.r, 1)
    assert_equal("apply_style_ops - radius applied", result.shared.cornerRadius.topLeft, 8)
    tests_passed = tests_passed + 1
end

do
    local patch = style.StylePatch:new()
    local ops = {
        { name = "color", args = { { r = 1, g = 1, b = 1, a = 1 } } },
        { name = "font_size", args = { 18 } },
    }
    local result = style.apply_typography_ops(patch, ops)
    assert_equal("apply_typography_ops - color applied", result.textConfig.textColor.r, 1)
    assert_equal("apply_typography_ops - font_size applied", result.textConfig.fontSize, 18)
    tests_passed = tests_passed + 1
end

do
    local patch = style.StylePatch:new()
    patch.shared = { backgroundColor = { r = 1, g = 0, b = 0, a = 1 } }
    patch.border = { color = { r = 0, g = 0, b = 1, a = 1 } }
    
    local node = style.resolve_to_node(patch, { id = "test" })
    assert_equal("resolve_to_node preserves id", node.id, "test")
    assert_equal("resolve_to_node maps shared", node.shared.backgroundColor.r, 1)
    assert_equal("resolve_to_node maps border", node.border.color.b, 1)
    tests_passed = tests_passed + 1
end

print("test_style_core: PASS (" .. tests_passed .. " tests)")
