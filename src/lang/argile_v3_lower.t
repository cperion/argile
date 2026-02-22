--[[
    Argile V3 Lowering
    
    Transforms V3 AST (component invocations, slots, fills) into V2 node trees.
    Handles:
    - Component expansion
    - Slot/fill resolution
    - Children injection
    - Variant validation
    - ID override (invocation overrides template)
    - Metadata preservation (part, component)
]]

local AST = require("src/lang/argile_v3_ast")
local Span = require("src/lang/argile_span")

local M = {}
local build_v2_node

-- ============================================================================
-- Deep Clone
-- ============================================================================

local function deep_clone_node(node)
    if type(node) ~= "table" then
        return node
    end
    
    local clone = {}
    for k, v in pairs(node) do
        if type(v) == "table" then
            if k == "children" or k == "states" or k == "uses" then
                -- Tables that need deep cloning
                if k == "children" then
                    clone[k] = {}
                    for i, child in ipairs(v) do
                        clone[k][i] = deep_clone_node(child)
                    end
                elseif k == "states" then
                    clone[k] = {}
                    for state_name, overlay in pairs(v) do
                        clone[k][state_name] = deep_clone_node(overlay)
                    end
                else
                    clone[k] = {}
                    for i, item in ipairs(v) do
                        clone[k][i] = item
                    end
                end
            else
                clone[k] = deep_clone_node(v)
            end
        else
            clone[k] = v
        end
    end
    return clone
end

-- ============================================================================
-- Variant Validation
-- ============================================================================

local function normalize_value(value)
    if AST.IsKind(value, "Symbol") then
        return value.name
    end
    return value
end

local function eval_expr_fn(expr_fn, env_fn)
    return normalize_value(expr_fn(env_fn))
end

local function build_component_env_fn(component, invoke, parent_env_fn)
    -- Evaluate invocation args in caller environment, then bind them as the
    -- component's param object(s) for template expression evaluation.
    local props = {}
    for arg_name, arg_expr in pairs(invoke.args) do
        props[arg_name] = eval_expr_fn(arg_expr, parent_env_fn)
    end
    
    return function()
        local base = parent_env_fn()
        local env = {}
        if type(base) == "table" then
            for k, v in pairs(base) do
                env[k] = v
            end
        end
        
        if type(component._argile_v3_decl_env) == "table" then
            -- Declaration lexical captures (e.g. theme aliases) behave like a
            -- closure environment for component templates.
            for k, v in pairs(component._argile_v3_decl_env) do
                env[k] = v
            end
        end
        
        if #component.params == 1 then
            env[component.params[1]] = props
        elseif #component.params > 1 then
            for _, param_name in ipairs(component.params) do
                env[param_name] = props[param_name]
            end
        end
        
        return env
    end
end

local function validate_invoke_args(invoke, component, env_fn)
    local declared_variants = {}
    for _, variant in pairs(component.variants) do
        declared_variants[variant.name] = variant.values
    end
    
    local seen_args = {}
    
    for arg_name, arg_expr in pairs(invoke.args) do
        -- Check for duplicates
        if seen_args[arg_name] then
            Span.Raise(invoke._span, "duplicate argument: " .. arg_name)
        end
        seen_args[arg_name] = true
        
        -- Check if it's a variant
        if declared_variants[arg_name] then
            local value = eval_expr_fn(arg_expr, env_fn)
            local valid = false
            for _, valid_value in ipairs(declared_variants[arg_name]) do
                if value == valid_value then
                    valid = true
                    break
                end
            end
            if not valid then
                Span.Raise(invoke._span,
                    "invalid variant value '" .. tostring(value) .. "' for '" .. arg_name .. "'. " ..
                    "Expected one of: " .. table.concat(declared_variants[arg_name], " | "))
            end
        end
        -- Note: Non-variant props are validated at compile time
    end
end

local function resolve_component_decl(invoke, env_fn, registry)
    local component = registry.components[invoke.name]
    if component then
        return component
    end
    
    local env = env_fn and env_fn() or nil
    local handle = env and env[invoke.name] or nil
    if type(handle) == "table" and handle._argile_v3_kind == "component" and handle.decl then
        return handle.decl
    end
    
    Span.Raise(invoke._span, "unknown component: " .. invoke.name)
end

-- ============================================================================
-- Slot/Fill Resolution
-- ============================================================================

local function group_fills_by_slot(fills)
    local grouped = {}
    for _, fill in ipairs(fills) do
        if not grouped[fill.slot_name] then
            grouped[fill.slot_name] = {}
        end
        table.insert(grouped[fill.slot_name], fill)
    end
    return grouped
end

local function resolve_slots(node, fills_by_slot)
    if not AST.IsKind(node, "NodeDecl") then
        return
    end

    -- Check if this node has a slot
    if node.slot_name then
        local fills = fills_by_slot[node.slot_name]
        if fills and #fills > 0 then
            -- Replace fallback with fill content
            node.children = {}
            for _, fill in ipairs(fills) do
                for _, child in ipairs(fill.children) do
                    table.insert(node.children, deep_clone_node(child))
                end
            end
        end
        -- If no fills, keep fallback (already in children)
    end
    
    -- Recurse into children
    for _, child in ipairs(node.children) do
        resolve_slots(child, fills_by_slot)
    end
end

-- ============================================================================
-- Children Resolution
-- ============================================================================

local function find_children_marker(node)
    if not AST.IsKind(node, "NodeDecl") then
        return nil
    end

    -- Depth-first search for children marker
    if node.has_children_marker then
        return node
    end
    
    for _, child in ipairs(node.children) do
        local found = find_children_marker(child)
        if found then
            return found
        end
    end
    
    return nil
end

local function resolve_children(root, body_nodes, invoke_span)
    local marker = find_children_marker(root)
    
    if not marker and #body_nodes > 0 then
        Span.Raise(invoke_span,
            "invocation has content but component has no children marker")
    end
    
    if marker then
        -- Replace marker with body nodes
        marker.has_children_marker = false
        marker.children = {}
        for _, node in ipairs(body_nodes) do
            table.insert(marker.children, deep_clone_node(node))
        end
    end
end

-- ============================================================================
-- Metadata Propagation
-- ============================================================================

local function add_v3_metadata(node, component_name, part_path)
    if not AST.IsKind(node, "NodeDecl") then
        return
    end

    -- Add V3-specific metadata for debugging/introspection
    node._argile_v3_component = component_name
    
    if node.part_name then
        node._argile_v3_part_name = node.part_name
        local new_path = part_path and (part_path .. "." .. node.part_name) or node.part_name
        node._argile_v3_part_path = new_path
        part_path = new_path
    end
    
    -- Recurse
    for _, child in ipairs(node.children) do
        add_v3_metadata(child, component_name, part_path)
    end
end

-- ============================================================================
-- V2 Node Construction
-- ============================================================================

-- Convert V3 operations to V2 format
local function convert_ops_to_v2(ops, env_fn)
    if not ops or #ops == 0 then
        return nil
    end
    
    local result = {}
    for _, op in ipairs(ops) do
        local v2_op = {
            name = op.name,
            args = {},
        }
        for i, arg_fn in ipairs(op.args) do
            v2_op.args[i] = arg_fn(env_fn)
        end
        table.insert(result, v2_op)
    end
    return result
end

-- Convert state overlay to V2 format
local function convert_state_to_v2(overlay, env_fn)
    return {
        style_ops = convert_ops_to_v2(overlay.style_ops, env_fn),
        typography_ops = convert_ops_to_v2(overlay.typography_ops, env_fn),
        paint_ops = convert_ops_to_v2(overlay.paint_ops, env_fn),
    }
end

-- Build V2 node from V3 node
build_v2_node = function(v3_node, env_fn, component_name, registry)
    local v2 = {
        -- Core properties
        id = v3_node.id_expr and v3_node.id_expr(env_fn) or nil,
        text = v3_node.text_expr and v3_node.text_expr(env_fn) or nil,
        
        -- Operations
        layout_ops = convert_ops_to_v2(v3_node.layout_ops, env_fn),
        style_ops = convert_ops_to_v2(v3_node.style_ops, env_fn),
        typography_ops = convert_ops_to_v2(v3_node.typography_ops, env_fn),
        paint_ops = convert_ops_to_v2(v3_node.paint_ops, env_fn),
        
        -- Use patches (evaluate expressions)
        use_patches = {},
        
        -- States
        states = {},
        
        -- Children
        children = {},
        
        -- Metadata
        _argile_v3_component = component_name or v3_node._argile_v3_component,
        _argile_v3_part_name = v3_node._argile_v3_part_name,
        _argile_v3_part_path = v3_node._argile_v3_part_path,
    }
    
    -- Evaluate use expressions
    for _, use_expr in ipairs(v3_node.uses) do
        local patch = use_expr(env_fn)
        if patch then
            table.insert(v2.use_patches, patch)
        end
    end
    
    -- Convert states
    for state_name, overlay in pairs(v3_node.states) do
        v2.states[state_name] = convert_state_to_v2(overlay, env_fn)
    end
    
    -- Convert children
    for _, child in ipairs(v3_node.children) do
        if AST.IsKind(child, "NodeDecl") then
            table.insert(v2.children, build_v2_node(child, env_fn, component_name, registry))
        elseif AST.IsKind(child, "ComponentInvoke") then
            table.insert(v2.children, M.LowerComponentInvoke(child, env_fn, registry))
        else
            Span.Raise(v3_node._span or Span.Synthetic(),
                "unsupported child node in V3 lowering: " .. tostring(child and child._kind))
        end
    end
    
    return v2
end

-- ============================================================================
-- Component Invocation Lowering
-- ============================================================================

function M.LowerComponentInvoke(invoke, env_fn, registry)
    -- 1. Resolve component
    local component = resolve_component_decl(invoke, env_fn, registry)
    
    -- 2. Validate args (including variants)
    validate_invoke_args(invoke, component, env_fn)
    
    -- Build component-local evaluation environment (`props`, etc.)
    local component_env_fn = build_component_env_fn(component, invoke, env_fn)
    
    -- 3. Clone component root tree
    local root = deep_clone_node(component.root)
    
    -- 4. Apply invocation id override (invocation takes precedence)
    if invoke.id_expr then
        root.id_expr = invoke.id_expr
    end
    
    -- 5. Resolve slots with fills
    local fills_by_slot = group_fills_by_slot(invoke.fills)
    resolve_slots(root, fills_by_slot)
    
    -- 6. Validate slot fills
    for slot_name, _ in pairs(fills_by_slot) do
        local found = false
        local function check_slots(node)
            if not AST.IsKind(node, "NodeDecl") then
                return
            end
            if node.slot_name == slot_name then
                found = true
                return
            end
            for _, child in ipairs(node.children) do
                check_slots(child)
            end
        end
        check_slots(root)
        if not found then
            Span.Raise(invoke._span,
                "fill targeting unknown slot '" .. slot_name .. "'")
        end
    end
    
    -- 7. Resolve children with invocation body nodes
    resolve_children(root, invoke.body_nodes, invoke._span)
    
    -- 8. Add metadata
    add_v3_metadata(root, component.name, nil)
    
    -- 9. Build V2 node
    local v2_node = build_v2_node(root, component_env_fn, component.name, registry)
    
    return v2_node
end

-- ============================================================================
-- Main Lowering Entry Point
-- ============================================================================

function M.LowerArgileBody(body_nodes, env_fn, registry)
    -- Lower a list of V3 nodes (invocations and raw nodes)
    local v2_nodes = {}
    
    for _, node in ipairs(body_nodes) do
        if AST.IsKind(node, "ComponentInvoke") then
            table.insert(v2_nodes, M.LowerComponentInvoke(node, env_fn, registry))
        elseif AST.IsKind(node, "NodeDecl") then
            table.insert(v2_nodes, build_v2_node(node, env_fn, nil, registry))
        else
            error("Unknown V3 node type: " .. tostring(node._kind))
        end
    end
    
    return v2_nodes
end

-- ============================================================================
-- Export Functions
-- ============================================================================

return M
