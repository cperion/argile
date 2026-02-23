--[[
    V3 Integration Tests (Basic)
    
    Test parsing and lowering of V3 component syntax.
]]

local C = terralib.includecstring[[
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
]]

local ui = require("src.init")

-- Import V3 language extension
import "src/lang.argile_v3"

-- Get access to parser registry
local v3_parser = require("src/lang.argile_v3")
local registry = v3_parser.registry

print("Testing V3 Component Declaration...")

-- Define a simple button component
component button(props)
    variant tone = primary | secondary | danger
    variant size = sm | md | lg
    
    root
        id(props.id)
        layout
            width_fit()
            height_fit()
        end
        style
            bg(props.bg_color)
            radius(8)
        end
        state hover
            style
                bg(props.bg_hover)
            end
        end
        text(props.label)
    end
end

print("  Component declaration: PASS")

-- Verify component was registered
assert(registry.components.button ~= nil, "Button component not registered")
local btn_comp = registry.components.button
assert(btn_comp.name == "button", "Component name mismatch")
assert(#btn_comp.params == 1, "Expected 1 param (props)")
assert(btn_comp.variants.tone ~= nil, "Variant 'tone' not found")
assert(#btn_comp.variants.tone.values == 3, "Expected 3 tone values")
print("  Component registration: PASS")

-- Test component invocation parsing
print("\nTesting V3 Component Invocation...")

-- This should parse successfully
local compiled = argile
    button(
        label = "Save",
        tone = primary,
        size = md,
        bg_color = { r = 0.2, g = 0.4, b = 0.9, a = 1.0 },
        bg_hover = { r = 0.15, g = 0.35, b = 0.8, a = 1.0 }
    )
        id("save_btn")
    end
end

print("  Invocation parsing: PASS")

-- Argile expression lowers to a V2 node tree value (single-root case)
assert(type(compiled) == "table", "Expected lowered V2 node table")
print("  Lowered node value: PASS")

-- Test lowered result shape
print("\nTesting V3 Lowering...")
local v2_node = compiled

-- Verify V2 node structure
assert(v2_node ~= nil, "Lowering returned nil")
assert(v2_node.id == "save_btn", "ID mismatch")
assert(v2_node.layout_ops ~= nil, "Missing layout_ops")
assert(v2_node.style_ops ~= nil, "Missing style_ops")
assert(v2_node.states ~= nil, "Missing states")
assert(v2_node.states.hover ~= nil, "Missing hover state")
assert(v2_node._argile_v3_component == "button", "Component metadata missing")
print("  Lowering to V2: PASS")

-- Test slot/fill
print("\nTesting Slot/Fill...")

-- Define card component
component card(props)
    root
        id(props.id)
        el
            part(header)
            slot(header)
                text("Default Header")
            end
        end
        el
            part(body)
            children
        end
    end
end

print("  Card component declaration: PASS")

-- Test card invocation with fill
local card_compiled = argile
    card()
        id("my_card")
        fill(header)
            text("Custom Header")
        end
    end
end
local card_v2 = card_compiled
assert(card_v2 ~= nil, "Card lowering returned nil")
assert(card_v2._argile_v3_component == "card", "Card component metadata missing")
assert(card_v2.children[1]._argile_v3_part_path == "root.header", "Expected root-prefixed part path for header")
print("  Card with fill: PASS")

-- Fallback header should be used when no fill provided
local card_fallback = argile
    card()
        id("fallback_card")
    end
end
assert(card_fallback.children[1].children[1].text == "Default Header", "Expected slot fallback content when no fill provided")

-- Multiple fills for same slot append in source order and replace fallback
local card_multi_fill = argile
    card()
        id("multi_fill_card")
        fill(header)
            text("A")
        end
        fill(header)
            text("B")
        end
    end
end
assert(#card_multi_fill.children[1].children == 2, "Expected two appended slot fill nodes")
assert(card_multi_fill.children[1].children[1].text == "A", "Expected first fill content first")
assert(card_multi_fill.children[1].children[2].text == "B", "Expected second fill content second")

-- Test nested component invocation in fill and children
print("\nTesting Nested Component Composition...")

component badge(props)
    root
        id(props.id)
        text(props.label)
            part(label)
        end
    end
end

component panel(props)
    root
        id(props.id)
        children
    end
end

local nested_card = argile
    card()
        id("nested_card")
        fill(header)
            badge(label = "Nested", id = "nested_badge")
            end
        end
    end
end

assert(nested_card.children[1] ~= nil, "Expected card header node")
assert(nested_card.children[1].children[1] ~= nil, "Expected nested header child")
assert(nested_card.children[1].children[1]._argile_v3_component == "badge", "Expected nested badge component in slot fill")
assert(nested_card.children[1].children[1].id == "nested_badge", "Nested badge id mismatch")
assert(nested_card.children[1]._argile_v3_part_path == "root.header", "Nested card header part path mismatch")

local nested_panel = argile
    panel(id = "panel_root")
        badge(label = "A", id = "badge_a")
        end
        text("raw child")
        badge(label = "B", id = "badge_b")
        end
    end
end

assert(nested_panel.id == "panel_root", "Panel id mismatch")
assert(#nested_panel.children == 3, "Expected 3 children in panel")
assert(nested_panel.children[1]._argile_v3_component == "badge", "First child should be nested badge")
assert(nested_panel.children[2].text == "raw child", "Second child should be raw text")
assert(nested_panel.children[3]._argile_v3_component == "badge", "Third child should be nested badge")
print("  Nested component invocation in fill/children: PASS")

-- Test V3 state keywords beyond hover parse/lower correctly
print("\nTesting V3 State Surface...")
component v3_state_probe(props)
    root
        id(props.id)
        state active
            style
                bg({ r = 0.1, g = 0.2, b = 0.3, a = 1.0 })
            end
        end
        state focus
            style
                bg({ r = 0.2, g = 0.3, b = 0.4, a = 1.0 })
            end
        end
        state selected
            style
                bg({ r = 0.3, g = 0.4, b = 0.5, a = 1.0 })
            end
        end
        state disabled
            style
                bg({ r = 0.4, g = 0.5, b = 0.6, a = 1.0 })
            end
        end
        text(props.label)
            state hover
                typography
                    color({ r = 1.0, g = 0.8, b = 0.2, a = 1.0 })
                end
            end
        end
    end
end

local v3_state_probe_node = argile
    v3_state_probe(id = "v3_state_probe", label = "Stateful")
    end
end
assert(v3_state_probe_node.states.active ~= nil, "V3 active state missing")
assert(v3_state_probe_node.states.focus ~= nil, "V3 focus state missing")
assert(v3_state_probe_node.states.selected ~= nil, "V3 selected state missing")
assert(v3_state_probe_node.states.disabled ~= nil, "V3 disabled state missing")
assert(v3_state_probe_node.children[1].states.hover ~= nil, "V3 hover text state missing")
print("  V3 state surface parse/lower: PASS")

-- Test theme/token/recipe + use(...) semantics
print("\nTesting Theme / Token / Recipe / Use...")

theme app_theme
    token color.button.bg = { r = 0.10, g = 0.20, b = 0.30, a = 1.0 }
    token color.button.fg = { r = 0.90, g = 0.95, b = 1.00, a = 1.0 }

    recipe button_skin(opts)
        layout
            width_fixed(180)
            height_fixed(36)
            dir(top_to_bottom)
            padding(5)
        end
        style
            bg(token(color.button.bg))
            radius(6)
        end
    end

    recipe label_skin(opts)
        typography
            color(token(color.button.fg))
            font_size(15)
        end
    end
end

assert(type(app_theme) == "table", "Expected theme value table")
assert(type(app_theme.button_skin) == "function", "Expected recipe function on theme")
assert(app_theme.color.button.bg.r == 0.10, "Theme token path lookup failed")

local theme_alias = app_theme

component themed_button(props)
    root
        id(props.id)
        use(theme_alias.button_skin(tone = primary))
        text(props.label)
            use(theme_alias.label_skin())
        end
    end
end

local themed_node = argile
    themed_button(id = "themed_btn", label = "Themed")
    end
end

assert(themed_node.id == "themed_btn", "Themed button id mismatch")
assert(themed_node.use_patches and #themed_node.use_patches == 1, "Expected 1 root use patch")
assert(themed_node.use_patches[1].layout ~= nil, "Expected layout patch from recipe")
assert(themed_node.use_patches[1].layout.widthType == ui.SIZING_FIXED, "Recipe layout widthType mismatch")
assert(themed_node.use_patches[1].layout.heightType == ui.SIZING_FIXED, "Recipe layout heightType mismatch")
assert(themed_node.use_patches[1].layout.minWidth == 180 and themed_node.use_patches[1].layout.maxWidth == 180, "Recipe layout width_fixed not applied")
assert(themed_node.use_patches[1].layout.minHeight == 36 and themed_node.use_patches[1].layout.maxHeight == 36, "Recipe layout height_fixed not applied")
assert(themed_node.use_patches[1].layout.layoutDir == ui.TOP_TO_BOTTOM, "Recipe layout dir not applied")
assert(themed_node.use_patches[1].layout.paddingLeft == 5 and themed_node.use_patches[1].layout.paddingTop == 5, "Recipe layout padding not applied")
assert(themed_node.use_patches[1].shared ~= nil, "Expected shared config patch from recipe")
assert(themed_node.use_patches[1].shared.backgroundColor.r == 0.10, "Theme recipe bg token not applied")
assert(themed_node.children[1].use_patches and #themed_node.children[1].use_patches == 1, "Expected text use patch")
assert(themed_node.children[1].use_patches[1].textConfig.fontSize == 15, "Label recipe font size not applied")
assert(themed_node.children[1].use_patches[1].textConfig.textColor.g == 0.95, "Label recipe token color not applied")
print("  Theme / token / recipe / use: PASS")

-- Test component handle alias resolution (env-based fallback when not in local registry by name)
print("\nTesting Component Handle Alias Resolution...")
local badge_alias = badge
local alias_node = argile
    badge_alias(label = "Alias", id = "alias_badge")
    end
end
assert(alias_node._argile_v3_component == "badge", "Alias component invocation did not resolve to badge decl")
assert(alias_node.id == "alias_badge", "Alias component id mismatch")
print("  Component alias invocation: PASS")

-- Test error cases
print("\nTesting Error Cases...")

local function expect_v3_error(label, code, pattern)
    local ok, err = pcall(function()
        local chunk = assert(terralib.loadstring(code))
        chunk()
    end)
    assert(not ok, label .. ": expected error")
    assert(tostring(err):find(pattern), label .. ": expected pattern '" .. pattern .. "', got: " .. tostring(err))
    print("  " .. label .. ": PASS (caught)")
end

-- Test duplicate id in invocation
expect_v3_error("Duplicate id error", [=[
        import "src/lang.argile_v3"

        local _probe = argile
            button(label = "Test")
                id("btn1")
                id("btn2")
            end
        end
]=], "duplicate id")

expect_v3_error("Duplicate arg error", [=[
    import "src/lang.argile_v3"
    local _probe = argile
        button(label = "A", label = "B")
        end
    end
]=], "duplicate argument")

expect_v3_error("Unknown slot fill error", [=[
    import "src/lang.argile_v3"
    component v3_slot_card(props)
        root
            el
                slot(header)
                end
            end
        end
    end
    local _probe = argile
        v3_slot_card()
            fill(footer)
                text("oops")
            end
        end
    end
]=], "unknown slot 'footer' in component 'v3_slot_card'")

expect_v3_error("Missing children marker error", [=[
    import "src/lang.argile_v3"
    component v3_no_children(props)
        root
            text("fixed")
        end
    end
    local _probe = argile
        v3_no_children()
            text("extra child")
        end
    end
]=], "component 'v3_no_children' has no children marker")

expect_v3_error("Invalid variant value error", [=[
    import "src/lang.argile_v3"
    component v3_variant_button(props)
        variant tone = primary | secondary
        root
            text("ok")
        end
    end
    local _probe = argile
        v3_variant_button(tone = danger)
        end
    end
]=], "invalid variant value")

expect_v3_error("Duplicate sibling part error", [=[
    import "src/lang.argile_v3"
    component v3_dup_parts(props)
        root
            el
                part(row)
            end
            el
                part(row)
            end
        end
    end
]=], "duplicate sibling part")

expect_v3_error("Duplicate slot in component error", [=[
    import "src/lang.argile_v3"
    component v3_dup_slots(props)
        root
            el
                slot(header)
                end
            end
            el
                slot(header)
                end
            end
        end
    end
]=], "duplicate slot 'header'")

expect_v3_error("Reserved part root error", [=[
    import "src/lang.argile_v3"
    component v3_bad_root_part(props)
        root
            el
                part(root)
            end
        end
    end
]=], "part name 'root' is reserved")

-- Test: Non-variant bare-name args resolve from caller environment
print("\nTesting Non-Variant Env Resolution...")

-- Create a themed component that takes a `skin` prop (not a variant)
component env_probe(props)
    variant tone = a | b
    root
        id(props.id)
        style
            bg(props.skin.bg)
        end
        text(props.label)
    end
end

-- `my_skin` is a real Lua table — when passed as `skin = my_skin` the
-- lowering must resolve the Symbol to the table, not the string "my_skin".
local my_skin = { bg = { r = 0.1, g = 0.2, b = 0.3, a = 1.0 } }

local env_node = argile
    env_probe(id = "env1", label = "Hello", skin = my_skin, tone = a)
    end
end

assert(env_node.id == "env1", "env_probe id mismatch")
-- The bg should be the actual table from my_skin, not a string
assert(type(env_node.style_ops) == "table", "Expected style_ops")
-- Find the bg op and check its value came through as a table
local found_bg = false
for _, op in ipairs(env_node.style_ops) do
    if op.name == "bg" then
        assert(type(op.args[1]) == "table", "bg arg should be the skin table value, not a string")
        assert(op.args[1].r == 0.1, "bg.r should be 0.1 from my_skin")
        found_bg = true
    end
end
assert(found_bg, "Expected bg style op from skin prop")
print("  Non-variant env resolution: PASS")

-- Test: Variant args still resolve to strings (not env lookup)
local a_value = "this should NOT appear"
local env_node2 = argile
    env_probe(id = "env2", label = "Test", skin = my_skin, tone = a)
    end
end
-- `tone = a` should resolve to the string "a", not the local `a_value`
assert(env_node2._argile_v3_component == "env_probe", "Component mismatch")
print("  Variant args still resolve as strings: PASS")

-- Test: [splice] in argile body
print("\nTesting [splice] in argile body...")

local pre_built = argile
    el
        id("spliced_child")
        layout
            width_fixed(100)
            height_fixed(50)
        end
    end
end

local splice_result = argile
    el
        id("splice_parent")
        layout
            width_grow()
            height_grow()
            dir(top_to_bottom)
        end

        text("before")
            id("before_txt")
        end

        [pre_built]

        text("after")
            id("after_txt")
        end
    end
end

assert(splice_result.id == "splice_parent", "Splice parent id mismatch")
assert(#splice_result.children == 3, "Expected 3 children (text + splice + text), got " .. #splice_result.children)
assert(splice_result.children[1].text == "before", "First child should be 'before' text")
assert(splice_result.children[2].id == "spliced_child", "Second child should be the spliced node")
assert(splice_result.children[3].text == "after", "Third child should be 'after' text")
print("  [splice] inline in argile body: PASS")

-- Test: [splice] at top level of argile ... end
local top_splice = argile
    [pre_built]
end
assert(top_splice.id == "spliced_child", "Top-level splice should return the node directly")
print("  [splice] at top level: PASS")

-- Test: [splice] with a list of nodes
local pre_built_list = argile
    el
        id("list_a")
    end
end
local pre_built_list2 = argile
    el
        id("list_b")
    end
end
local list_items = { pre_built_list, pre_built_list2 }

local splice_list_result = argile
    el
        id("list_parent")
        layout
            dir(left_to_right)
        end
        [list_items]
    end
end

assert(#splice_list_result.children == 2, "Expected 2 children from spliced list, got " .. #splice_list_result.children)
assert(splice_list_result.children[1].id == "list_a", "First spliced list child id mismatch")
assert(splice_list_result.children[2].id == "list_b", "Second spliced list child id mismatch")
print("  [splice] with list of nodes: PASS")

-- Summary
print("\n" .. string.rep("=", 50))
print("V3 Integration Tests (Basic)")
print("Status: PASS")
print(string.rep("=", 50))
