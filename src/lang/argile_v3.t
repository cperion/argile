--[[
    Argile V3 Parser
    
    Entrypoints:
    - argile ... end        (invocation context)
    - theme <name> ... end  (theme declaration)
    - component <name> ... end (component declaration)
]]

local AST = require("src/lang/argile_v3_ast")
local Span = require("src/lang/argile_span")
local Lower = require("src/lang/argile_v3_lower")
local style = require("src/style/core")
local ui = require("src.init")

-- Module-scoped registry for declarations
-- Populated during eager parsing
local v3_registry = {
    components = {},
    themes = {},
}

-- ============================================================================
-- Reserved Keywords
-- ============================================================================

-- These cannot be used as component names
local v3_reserved = {
    -- V2 inherited
    ["el"] = true,
    ["text"] = true,
    ["id"] = true,
    ["layout"] = true,
    ["style"] = true,
    ["typography"] = true,
    ["paint"] = true,
    ["use"] = true,
    ["when"] = true,  -- V2 only, V3 uses 'state'
    
    -- V3 new
    ["theme"] = true,
    ["component"] = true,
    ["variant"] = true,
    ["root"] = true,
    ["part"] = true,
    ["slot"] = true,
    ["fill"] = true,
    ["children"] = true,
    ["state"] = true,
    ["token"] = true,
    ["recipe"] = true,
    ["end"] = true,
}

-- Keywords valid inside node bodies
local v3_body_keywords = {
    ["id"] = true,
    ["part"] = true,
    ["slot"] = true,
    ["children"] = true,
    ["layout"] = true,
    ["style"] = true,
    ["typography"] = true,
    ["paint"] = true,
    ["use"] = true,
    ["state"] = true,
    ["el"] = true,
    ["text"] = true,
}

local layout_dir_values = {
    left_to_right = ui.LEFT_TO_RIGHT,
    top_to_bottom = ui.TOP_TO_BOTTOM,
}

local align_x_values = {
    left = ui.ALIGN_X_LEFT,
    right = ui.ALIGN_X_RIGHT,
    center = ui.ALIGN_X_CENTER,
}

local align_y_values = {
    top = ui.ALIGN_Y_TOP,
    bottom = ui.ALIGN_Y_BOTTOM,
    center = ui.ALIGN_Y_CENTER,
}

local text_wrap_values = {
    words = ui.TEXT_WRAP_WORDS,
    newlines = ui.TEXT_WRAP_NEWLINES,
    none = ui.TEXT_WRAP_NONE,
}

local text_align_values = {
    left = ui.TEXT_ALIGN_LEFT,
    center = ui.TEXT_ALIGN_CENTER,
    right = ui.TEXT_ALIGN_RIGHT,
}

local v3_symbol_values = {}
local function insert_symbol_values(values)
    for k, v in pairs(values) do
        v3_symbol_values[k] = v
    end
end

insert_symbol_values(layout_dir_values)
insert_symbol_values(align_x_values)
insert_symbol_values(align_y_values)
insert_symbol_values(text_wrap_values)
insert_symbol_values(text_align_values)

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- Forward declarations (mutually recursive parsing helpers)
local parse_v3_node_body
local parse_v3_node_decl
local parse_v3_component_invoke
local is_component_invocation

local function matches_word(lex, word)
    if lex:matches(word) then
        return true
    end
    if lex:matches(lex.name) and lex:cur().value == word then
        return true
    end
    return false
end

local function expect_word(lex, word)
    if not matches_word(lex, word) then
        lex:errorexpected(word)
    end
    lex:next()
end

local function consume_separators(lex)
    local consumed = false
    while lex:matches(",") or lex:matches(";") do
        consumed = true
        lex:next()
    end
    return consumed
end

local function parse_v3_content_item(lex, where)
    if matches_word(lex, "el") then
        return parse_v3_node_decl(lex, "el")
    elseif matches_word(lex, "text") then
        return parse_v3_node_decl(lex, "text")
    elseif is_component_invocation and is_component_invocation(lex) then
        return parse_v3_component_invoke(lex)
    end
    lex:error("argile v3: expected el, text, component invocation, or end in " .. where)
end

local function starts_v3_node_body(lex)
    for keyword, _ in pairs(v3_body_keywords) do
        if matches_word(lex, keyword) then
            return true
        end
    end
    return false
end

local function read_word_like_name(lex, expected_what)
    if lex:matches(lex.name) then
        return lex:next().value
    end
    for keyword, _ in pairs(v3_reserved) do
        if lex:matches(keyword) then
            lex:next()
            return keyword
        end
    end
    lex:errorexpected(expected_what or "name")
end

-- ============================================================================
-- Expression Value Functions (lazy evaluation)
-- ============================================================================

local function constant_value_fn(value)
    return function(_environment_function)
        return value
    end
end

local function parse_value_fn(lex, value_map)
    if lex:matches(lex.name) then
        local name = lex:cur().value
        local mapped = value_map and value_map[name]
        if mapped ~= nil and (
            lex:lookaheadmatches(")") or
            lex:lookaheadmatches(",") or
            lex:lookaheadmatches(";")
        ) then
            lex:next()
            return constant_value_fn(mapped)
        end
    end

    -- V3 token(...) resolves a dotted token path explicitly. We parse it
    -- ourselves (instead of generic luaexpr) so we can register lexical refs
    -- for Terra language-extension scoping.
    if matches_word(lex, "token") and lex:lookaheadmatches("(") then
        expect_word(lex, "token")
        lex:expect("(")
        local path = {}
        path[#path + 1] = read_word_like_name(lex, "token path component")
        while lex:nextif(".") do
            path[#path + 1] = read_word_like_name(lex, "token path component")
        end
        lex:expect(")")
        if lex.ref then
            lex:ref(path[1])
        end
        return function(environment_function)
            local env = environment_function and environment_function() or nil
            local target = env and env[path[1]] or nil
            if target == nil then
                target = rawget(_G, path[1])
            end
            for i = 2, #path do
                if target == nil then
                    error("argile v3: token path '" .. table.concat(path, ".") .. "' is nil")
                end
                target = target[path[i]]
            end
            if target == nil then
                error("argile v3: token path '" .. table.concat(path, ".") .. "' is nil")
            end
            return target
        end
    end

    local expr = lex:luaexpr()
    return function(environment_function)
        return expr(environment_function())
    end
end

-- V3 component invocation args use named syntax and allow bare symbolic values
-- like `tone = primary` and `size = md`. These are parsed as V3 symbols rather
-- than Lua expressions so they can be validated deterministically in lowering.
local function parse_invoke_arg_value_fn(lex)
    if lex:matches(lex.name) and (lex:lookaheadmatches(",") or lex:lookaheadmatches(")")) then
        local span = Span.SpanFromLexer(lex)
        local name = lex:next().value
        return constant_value_fn(AST.Symbol(name, span))
    end
    return parse_value_fn(lex, nil)
end

local function normalize_runtime_value(value)
    if AST.IsKind(value, "Symbol") then
        return value.name
    end
    return value
end

local function eval_ops_list(ops, env_fn)
    local out = {}
    if not ops then return out end
    for _, op in ipairs(ops) do
        local args = {}
        for i, arg_fn in ipairs(op.args or {}) do
            args[i] = normalize_runtime_value(arg_fn(env_fn))
        end
        out[#out + 1] = { name = op.name, args = args }
    end
    return out
end

local function set_nested_path(root, dotted_path, value)
    local cursor = root
    local parts = {}
    for part in dotted_path:gmatch("[^%.]+") do
        parts[#parts + 1] = part
    end
    for i = 1, #parts - 1 do
        local key = parts[i]
        local nextv = cursor[key]
        if type(nextv) ~= "table" or nextv._argile_v3_kind then
            nextv = {}
            cursor[key] = nextv
        end
        cursor = nextv
    end
    cursor[parts[#parts]] = value
end

local function build_theme_value(decl, decl_env)
    local theme = {
        _argile_v3_kind = "theme",
        _argile_v3_theme_name = decl.name,
        _argile_v3_theme_decl = decl,
    }
    
    decl_env = decl_env or {}
    local decl_env_fn = function() return decl_env end
    for _, token_decl in pairs(decl.tokens or {}) do
        local value = normalize_runtime_value(token_decl.value_expr(decl_env_fn))
        set_nested_path(theme, token_decl.path, value)
    end
    
    local function make_recipe_env_fn(opts)
        return function()
            local env = {}
            for k, v in pairs(decl_env) do
                env[k] = v
            end
            env.opts = opts or {}
            for k, v in pairs(theme) do
                if type(k) == "string" and k:sub(1, 10) ~= "_argile_v3_" then
                    env[k] = v
                end
            end
            return env
        end
    end
    
    for recipe_name, recipe_decl in pairs(decl.recipes or {}) do
        theme[recipe_name] = function(opts)
            opts = opts or {}
            local env_fn = make_recipe_env_fn(opts)
            local patch = style.StylePatch:new()
            for _, block in ipairs(recipe_decl.body or {}) do
                local ops = eval_ops_list(block.ops, env_fn)
                if block.kind == "style" then
                    patch = style.apply_style_ops(patch, ops)
                elseif block.kind == "typography" then
                    patch = style.apply_typography_ops(patch, ops)
                elseif block.kind == "paint" then
                    patch = style.apply_paint_ops(patch, ops)
                elseif block.kind == "layout" then
                    patch = style.apply_layout_ops(patch, ops)
                else
                    error("argile v3: unknown recipe block kind '" .. tostring(block.kind) .. "'")
                end
            end
            return patch
        end
    end
    
    return theme
end

local function build_component_handle(decl, decl_env)
    decl._argile_v3_decl_env = decl_env or {}
    return {
        _argile_v3_kind = "component",
        _argile_v3_component_name = decl.name,
        decl = decl,
    }
end

local function parse_use_expr_fn(lex)
    local path = {}
    path[#path + 1] = read_word_like_name(lex, "use target")
    while lex:nextif(".") do
        path[#path + 1] = read_word_like_name(lex, "use path component")
    end
    
    if lex.ref then
        lex:ref(path[1])
    end
    
    local function resolve_path(environment_function)
        local env = environment_function()
        local target = nil
        if env ~= nil then
            target = env[path[1]]
        end
        if target == nil then
            target = rawget(_G, path[1])
        end
        for i = 2, #path do
            if target == nil then break end
            target = target[path[i]]
        end
        return target
    end
    
    -- use(patch_value)
    if not lex:matches("(") then
        return function(environment_function)
            local target = resolve_path(environment_function)
            if target == nil then
                error("argile v3: use target '" .. table.concat(path, ".") .. "' is nil")
            end
            return target
        end
    end
    
    -- use(theme.recipe(named = args))
    lex:expect("(")
    local args = {}
    if not lex:matches(")") then
        repeat
            local arg_name = read_word_like_name(lex, "recipe argument name")
            if args[arg_name] ~= nil then
                lex:error("argile v3: duplicate recipe argument '" .. arg_name .. "'")
            end
            lex:expect("=")
            args[arg_name] = parse_invoke_arg_value_fn(lex)
        until not lex:nextif(",")
    end
    lex:expect(")")
    
    return function(environment_function)
        local target = resolve_path(environment_function)
        if type(target) ~= "function" then
            error("argile v3: use target '" .. table.concat(path, ".") .. "' is not callable")
        end
        local opts = {}
        for name, arg_fn in pairs(args) do
            opts[name] = normalize_runtime_value(arg_fn(environment_function))
        end
        return target(opts)
    end
end

-- ============================================================================
-- Block Operations Parsing (reused from V2)
-- ============================================================================

local function parse_operation(lex)
    local name = read_word_like_name(lex, "operation name")
    
    local args = {}
    if lex:nextif("(") then
        if not lex:matches(")") then
            repeat
                args[#args + 1] = parse_value_fn(lex, v3_symbol_values)
            until not lex:nextif(",")
        end
        lex:expect(")")
    end
    
    return { name = name, args = args }
end

local function parse_block_ops(lex, keyword)
    expect_word(lex, keyword)
    local ops = {}
    while not matches_word(lex, "end") do
        if not consume_separators(lex) then
            ops[#ops + 1] = parse_operation(lex)
            consume_separators(lex)
        end
    end
    expect_word(lex, "end")
    return ops
end

-- ============================================================================
-- Theme Declaration Parsing
-- ============================================================================

local function parse_v3_token_decl(lex)
    local span = Span.SpanFromLexer(lex)
    expect_word(lex, "token")
    
    -- Parse token path (e.g., color.button.primary.bg)
    local path_parts = {}
    repeat
        table.insert(path_parts, read_word_like_name(lex, "token path component"))
    until not lex:nextif(".")
    
    local path = table.concat(path_parts, ".")
    lex:expect("=")
    local value_expr = parse_value_fn(lex, nil)
    
    return AST.TokenDecl(path, value_expr, span)
end

local function parse_v3_recipe_decl(lex)
    local span = Span.SpanFromLexer(lex)
    expect_word(lex, "recipe")
    
    if not lex:matches(lex.name) then
        lex:errorexpected("recipe name")
    end
    local name = lex:next().value
    
    -- Parse params (optional)
    local params = {}
    if lex:nextif("(") then
        if not lex:matches(")") then
            repeat
                if not lex:matches(lex.name) then
                    lex:errorexpected("param name")
                end
                table.insert(params, lex:next().value)
            until not lex:nextif(",")
        end
        lex:expect(")")
    end
    
    -- Parse body (style, typography, paint blocks)
    local body = {}
    while not matches_word(lex, "end") do
        if matches_word(lex, "style") then
            table.insert(body, { kind = "style", ops = parse_block_ops(lex, "style") })
        elseif matches_word(lex, "typography") then
            table.insert(body, { kind = "typography", ops = parse_block_ops(lex, "typography") })
        elseif matches_word(lex, "paint") then
            table.insert(body, { kind = "paint", ops = parse_block_ops(lex, "paint") })
        elseif matches_word(lex, "layout") then
            table.insert(body, { kind = "layout", ops = parse_block_ops(lex, "layout") })
        else
            lex:error("argile v3: expected style, typography, paint, layout, or end in recipe body")
        end
        consume_separators(lex)
    end
    
    expect_word(lex, "end")
    
    return AST.RecipeDecl(name, params, body, span)
end

local function parse_v3_theme_decl(lex)
    local span = Span.SpanFromLexer(lex)
    expect_word(lex, "theme")
    
    if not lex:matches(lex.name) then
        lex:errorexpected("theme name")
    end
    local name = lex:next().value
    
    -- Check for name collision
    if v3_registry.themes[name] then
        Span.Raise(span, "duplicate theme declaration: " .. name)
    end
    
    local tokens = {}
    local recipes = {}
    
    while not matches_word(lex, "end") do
        if matches_word(lex, "token") then
            local token = parse_v3_token_decl(lex)
            tokens[token.path] = token
        elseif matches_word(lex, "recipe") then
            local recipe = parse_v3_recipe_decl(lex)
            recipes[recipe.name] = recipe
        else
            lex:error("argile v3: expected token, recipe, or end in theme body")
        end
        consume_separators(lex)
    end
    
    expect_word(lex, "end")
    
    local decl = AST.ThemeDecl(name, tokens, recipes, span)
    v3_registry.themes[name] = decl
    
    return decl
end

-- ============================================================================
-- Component Declaration Parsing
-- ============================================================================

local function parse_v3_variant_decl(lex)
    local span = Span.SpanFromLexer(lex)
    expect_word(lex, "variant")
    
    if not lex:matches(lex.name) then
        lex:errorexpected("variant name")
    end
    local name = lex:next().value
    
    lex:expect("=")
    
    -- Parse values: value1 | value2 | value3
    local values = {}
    repeat
        if not lex:matches(lex.name) then
            lex:errorexpected("variant value")
        end
        local value = lex:next().value
        table.insert(values, value)
    until not lex:nextif("|")
    
    return AST.VariantDecl(name, values, span)
end

local function parse_v3_state_block(lex)
    local span = Span.SpanFromLexer(lex)
    expect_word(lex, "state")
    
    if not lex:matches(lex.name) then
        lex:errorexpected("state name")
    end
    local state_name = lex:next().value
    
    -- V3.0 only supports hover
    if state_name ~= "hover" then
        -- Parse but will error at lowering
        -- Actually, let's error here since it's clearer
        lex:error("argile v3: state '" .. state_name .. "' is not yet implemented (only 'hover' is supported)")
    end
    
    local overlay = AST.StateOverlay(state_name, span)
    
    while not matches_word(lex, "end") do
        if matches_word(lex, "style") then
            overlay.style_ops = parse_block_ops(lex, "style")
        elseif matches_word(lex, "typography") then
            overlay.typography_ops = parse_block_ops(lex, "typography")
        elseif matches_word(lex, "paint") then
            overlay.paint_ops = parse_block_ops(lex, "paint")
        else
            lex:error("argile v3: expected style, typography, paint, or end in state block")
        end
        consume_separators(lex)
    end
    
    expect_word(lex, "end")
    
    return overlay
end

parse_v3_node_decl = function(lex, kind)
    local span = Span.SpanFromLexer(lex)
    local node = AST.NodeDecl(kind, span)
    
    if kind == "text" then
        -- Consume "text" keyword
        expect_word(lex, "text")
        lex:expect("(")
        node.text_expr = parse_value_fn(lex, nil)
        lex:expect(")")
    elseif kind == "el" then
        -- Consume "el" keyword
        expect_word(lex, "el")
    end
    
    -- V3 `el` is always a block (`el ... end`), so always parse its body.
    -- `text(...)` may be a leaf or may have a body with directives/blocks.
    if kind == "el" then
        parse_v3_node_body(lex, node)
    elseif starts_v3_node_body(lex) then
        parse_v3_node_body(lex, node)
    end
    
    return node
end

parse_v3_node_body = function(lex, node)
    -- Parse directives and blocks
    while not matches_word(lex, "end") do
        if consume_separators(lex) then
            -- noop
        elseif matches_word(lex, "id") then
            if node.id_expr then
                lex:error("argile v3: duplicate id(...) directive")
            end
            expect_word(lex, "id")
            lex:expect("(")
            node.id_expr = parse_value_fn(lex, nil)
            lex:expect(")")
        elseif matches_word(lex, "part") then
            if node.part_name then
                lex:error("argile v3: duplicate part(...) directive")
            end
            expect_word(lex, "part")
            lex:expect("(")
            if not lex:matches(lex.name) then
                lex:errorexpected("part name")
            end
            node.part_name = lex:next().value
            lex:expect(")")
        elseif matches_word(lex, "slot") then
            if node.slot_name then
                lex:error("argile v3: duplicate slot declaration on same node")
            end
            if node.has_children_marker then
                lex:error("argile v3: cannot have both slot and children on same node")
            end
            expect_word(lex, "slot")
            lex:expect("(")
            if not lex:matches(lex.name) then
                lex:errorexpected("slot name")
            end
            node.slot_name = lex:next().value
            lex:expect(")")
            
            -- Parse fallback content
            while not matches_word(lex, "end") do
                table.insert(node.children, parse_v3_content_item(lex, "slot fallback"))
                consume_separators(lex)
            end
            expect_word(lex, "end")
        elseif matches_word(lex, "children") then
            if node.has_children_marker then
                lex:error("argile v3: duplicate children marker")
            end
            if node.slot_name then
                lex:error("argile v3: cannot have both slot and children on same node")
            end
            expect_word(lex, "children")
            node.has_children_marker = true
        elseif matches_word(lex, "layout") then
            if #node.layout_ops > 0 then
                lex:error("argile v3: duplicate layout block")
            end
            node.layout_ops = parse_block_ops(lex, "layout")
        elseif matches_word(lex, "style") then
            local ops = parse_block_ops(lex, "style")
            for _, op in ipairs(ops) do
                table.insert(node.style_ops, op)
            end
        elseif matches_word(lex, "typography") then
            local ops = parse_block_ops(lex, "typography")
            for _, op in ipairs(ops) do
                table.insert(node.typography_ops, op)
            end
        elseif matches_word(lex, "paint") then
            local ops = parse_block_ops(lex, "paint")
            for _, op in ipairs(ops) do
                table.insert(node.paint_ops, op)
            end
        elseif matches_word(lex, "use") then
            expect_word(lex, "use")
            lex:expect("(")
            local use_expr = parse_use_expr_fn(lex)
            lex:expect(")")
            table.insert(node.uses, use_expr)
        elseif matches_word(lex, "state") then
            local overlay = parse_v3_state_block(lex)
            if node.states[overlay.name] then
                lex:error("argile v3: duplicate state '" .. overlay.name .. "'")
            end
            node.states[overlay.name] = overlay
        elseif matches_word(lex, "el") then
            table.insert(node.children, parse_v3_node_decl(lex, "el"))
        elseif matches_word(lex, "text") then
            table.insert(node.children, parse_v3_node_decl(lex, "text"))
        elseif is_component_invocation(lex) then
            table.insert(node.children, parse_v3_component_invoke(lex))
        else
            lex:error("argile v3: unexpected token in node body")
        end
        consume_separators(lex)
    end
    
    expect_word(lex, "end")
end

local function parse_v3_root_block(lex)
    local span = Span.SpanFromLexer(lex)
    expect_word(lex, "root")
    
    -- Root is the implicit root element node
    -- It uses node-body grammar (id, layout, style, state, slot, children, el, text, etc.)
    local node = AST.NodeDecl("el", span)
    
    -- Parse node body directives
    parse_v3_node_body(lex, node)
    
    return node
end

local function parse_v3_component_decl(lex)
    local span = Span.SpanFromLexer(lex)
    expect_word(lex, "component")
    
    if not lex:matches(lex.name) then
        lex:errorexpected("component name")
    end
    local name = lex:next().value
    
    -- Check for name collision
    if v3_reserved[name] then
        Span.Raise(span, "component name cannot be reserved keyword: " .. name)
    end
    if v3_registry.components[name] then
        Span.Raise(span, "duplicate component declaration: " .. name)
    end
    
    -- Parse params
    lex:expect("(")
    local params = {}
    if not lex:matches(")") then
        repeat
            if not lex:matches(lex.name) then
                lex:errorexpected("param name")
            end
            table.insert(params, lex:next().value)
        until not lex:nextif(",")
    end
    lex:expect(")")
    
    -- Parse body
    local variants = {}
    local root = nil
    
    while not matches_word(lex, "end") do
        if matches_word(lex, "variant") then
            local variant = parse_v3_variant_decl(lex)
            if variants[variant.name] then
                lex:error("argile v3: duplicate variant '" .. variant.name .. "'")
            end
            variants[variant.name] = variant
        elseif matches_word(lex, "root") then
            if root then
                lex:error("argile v3: duplicate root block (only one allowed per component)")
            end
            root = parse_v3_root_block(lex)
        else
            lex:error("argile v3: expected variant, root, or end in component body")
        end
        consume_separators(lex)
    end
    
    expect_word(lex, "end")
    
    if not root then
        Span.Raise(span, "component must have exactly one root block")
    end
    
    local decl = AST.ComponentDecl(name, params, variants, root, span)
    v3_registry.components[name] = decl
    
    return decl
end

-- ============================================================================
-- Component Invocation Parsing
-- ============================================================================

local function parse_v3_fill_decl(lex)
    local span = Span.SpanFromLexer(lex)
    expect_word(lex, "fill")
    lex:expect("(")
    if not lex:matches(lex.name) then
        lex:errorexpected("slot name")
    end
    local slot_name = lex:next().value
    lex:expect(")")
    
    local children = {}
    while not matches_word(lex, "end") do
        table.insert(children, parse_v3_content_item(lex, "fill body"))
        consume_separators(lex)
    end
    
    expect_word(lex, "end")
    
    return AST.FillDecl(slot_name, children, span)
end

local function parse_v3_invoke_body(lex, invoke)
    while not matches_word(lex, "end") do
        if consume_separators(lex) then
            -- noop
        elseif matches_word(lex, "id") then
            if invoke.id_expr then
                lex:error("argile v3: duplicate id(...) in invocation body")
            end
            expect_word(lex, "id")
            lex:expect("(")
            invoke.id_expr = parse_value_fn(lex, nil)
            lex:expect(")")
        elseif matches_word(lex, "fill") then
            table.insert(invoke.fills, parse_v3_fill_decl(lex))
        else
            table.insert(invoke.body_nodes, parse_v3_content_item(lex, "invocation body"))
        end
        consume_separators(lex)
    end
    
    expect_word(lex, "end")
end

parse_v3_component_invoke = function(lex)
    local span = Span.SpanFromLexer(lex)
    
    if not lex:matches(lex.name) then
        lex:errorexpected("component name")
    end
    local name = lex:next().value
    if lex.ref then
        lex:ref(name)
    end
    
    lex:expect("(")
    
    -- Parse named args: name = value, name2 = value2
    local args = {}
    if not lex:matches(")") then
        repeat
            local arg_name = read_word_like_name(lex, "argument name")
            if args[arg_name] ~= nil then
                lex:error("argile v3: duplicate argument '" .. arg_name .. "'")
            end
            lex:expect("=")
            args[arg_name] = parse_invoke_arg_value_fn(lex)
        until not lex:nextif(",")
    end
    
    lex:expect(")")
    
    local invoke = AST.ComponentInvoke(name, args, span)
    
    -- Parse invocation body
    parse_v3_invoke_body(lex, invoke)
    
    return invoke
end

-- ============================================================================
-- Top-Level Parsing Entrypoints
-- ============================================================================

-- Check if current token starts a component invocation
is_component_invocation = function(lex)
    if not lex:matches(lex.name) then
        return false
    end
    local name = lex:cur().value
    
    -- Not an invocation if it's a reserved keyword
    if v3_reserved[name] then
        return false
    end
    
    -- Must be followed by (
    return lex:lookaheadmatches("(")
end

-- Inside argile ... end: parse mixed content
local function parse_argile_body(lex)
    local body_nodes = {}
    
    while not matches_word(lex, "end") do
        table.insert(body_nodes, parse_v3_content_item(lex, "argile body"))
        consume_separators(lex)
    end
    
    expect_word(lex, "end")
    return body_nodes
end

-- ============================================================================
-- Language Extension Entrypoints
-- ============================================================================

-- Clear registry for fresh parse (called at module load)
-- In practice, declarations persist within a module
local function clear_registry()
    v3_registry.components = {}
    v3_registry.themes = {}
end

local language = {
    name = "argile_v3",
    entrypoints = { "argile", "theme", "component" },
    keywords = {
        "argile", "theme", "component", "variant", "root", "part",
        "slot", "fill", "children", "state", "token", "recipe",
        "el", "text", "id", "layout", "style", "typography", "paint", "use",
        "when", -- V2 compatibility, V3 uses 'state'
    },
    
    -- argile ... end (expression form)
    expression = function(self, lex)
        lex:expect("argile")
        local body = parse_argile_body(lex)
        
        -- Return builder that lowers V3 to V2 at compile time
        return function(environment_function)
            local v2_nodes = Lower.LowerArgileBody(body, environment_function, v3_registry)
            -- Return first node for single-node body
            if #v2_nodes == 1 then
                return v2_nodes[1]
            else
                return v2_nodes
            end
        end
    end,
    
    -- theme <name> ... end (statement form)
    statement = function(self, lex)
        if matches_word(lex, "theme") then
            local decl = parse_v3_theme_decl(lex)
            return function(env_fn)
                local captured = env_fn and env_fn() or {}
                return build_theme_value(decl, captured)
            end, { decl.name }
        elseif matches_word(lex, "component") then
            local decl = parse_v3_component_decl(lex)
            return function(env_fn)
                local captured = env_fn and env_fn() or {}
                return build_component_handle(decl, captured)
            end, { decl.name }
        elseif matches_word(lex, "argile") then
            lex:expect("argile")
            local body = parse_argile_body(lex)
            -- Return constructor that lowers V3 to V2
            return function(environment_function)
                local v2_nodes = Lower.LowerArgileBody(body, environment_function, v3_registry)
                if #v2_nodes == 1 then
                    return v2_nodes[1]
                else
                    return v2_nodes
                end
            end
        else
            lex:errorexpected("theme, component, or argile")
        end
    end,
    
    -- local theme ... end, local component ... end, local argile ... end
    localstatement = function(self, lex)
        if matches_word(lex, "theme") then
            local decl = parse_v3_theme_decl(lex)
            return function(env_fn)
                local captured = env_fn and env_fn() or {}
                return build_theme_value(decl, captured)
            end, { decl.name }
        elseif matches_word(lex, "component") then
            local decl = parse_v3_component_decl(lex)
            return function(env_fn)
                local captured = env_fn and env_fn() or {}
                return build_component_handle(decl, captured)
            end, { decl.name }
        elseif matches_word(lex, "argile") then
            lex:expect("argile")
            local body = parse_argile_body(lex)
            return function(environment_function)
                local v2_nodes = Lower.LowerArgileBody(body, environment_function, v3_registry)
                if #v2_nodes == 1 then
                    return v2_nodes[1]
                else
                    return v2_nodes
                end
            end
        else
            lex:errorexpected("theme, component, or argile")
        end
    end,
}

-- Export registry for lowering module
language.registry = v3_registry

return language
