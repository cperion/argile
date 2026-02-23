--[[
    Argile DSL Parser
    
    Entrypoints:
    - argile ... end        (invocation context)
    - theme <name> ... end  (theme declaration)
    - component <name> ... end (component declaration)
]]

local AST = require("src/lang/ast")
local Span = require("src/lang/argile_span")
local DslCompiler = require("src/dsl_compiler")
local DslRegistry = require("src/dsl_registry")
local ui = require("src.init")

-- Module-scoped registry for declarations
-- Populated during eager parsing
local dsl_registry = DslRegistry.Create()

-- ============================================================================
-- Reserved Keywords
-- ============================================================================

-- These cannot be used as component names
local dsl_reserved = {
    -- V2 inherited
    ["el"] = true,
    ["text"] = true,
    ["id"] = true,
    ["layout"] = true,
    ["style"] = true,
    ["typography"] = true,
    ["paint"] = true,
    ["use"] = true,
    ["when"] = true,  -- V2 only, DSL uses 'state'
    
    -- DSL new
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
local dsl_body_keywords = {
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

local dsl_valid_states = {
    hover = true,
    active = true,
    disabled = true,
    focus = true,
    selected = true,
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

local dsl_symbol_values = {}
local function insert_symbol_values(values)
    for k, v in pairs(values) do
        dsl_symbol_values[k] = v
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
local parse_dsl_node_body
local parse_dsl_node_decl
local parse_dsl_component_invoke
local is_component_invocation
local validate_component_template

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

local function parse_dsl_content_item(lex, where)
    if matches_word(lex, "el") then
        return parse_dsl_node_decl(lex, "el")
    elseif matches_word(lex, "text") then
        return parse_dsl_node_decl(lex, "text")
    elseif lex:matches("[") then
        -- [expression] splice: inject a pre-built V2 subtree
        local span = Span.SpanFromLexer(lex)
        lex:expect("[")
        local expr = lex:luaexpr()
        lex:expect("]")
        return AST.Splice(function(environment_function)
            return expr(environment_function())
        end, span)
    elseif is_component_invocation and is_component_invocation(lex) then
        return parse_dsl_component_invoke(lex)
    end
    lex:error("argile: expected el, text, [splice], component invocation, or end in " .. where)
end

local function starts_v3_node_body(lex)
    for keyword, _ in pairs(dsl_body_keywords) do
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
    for keyword, _ in pairs(dsl_reserved) do
        if lex:matches(keyword) then
            lex:next()
            return keyword
        end
    end
    lex:errorexpected(expected_what or "name")
end

-- ============================================================================
-- Expression Value Parsing (AST expressions)
-- ============================================================================

local function parse_value_fn(lex, value_map)
    local span = Span.SpanFromLexer(lex)
    if lex:matches(lex.name) then
        local name = lex:cur().value
        local mapped = value_map and value_map[name]
        if mapped ~= nil and (
            lex:lookaheadmatches(")") or
            lex:lookaheadmatches(",") or
            lex:lookaheadmatches(";")
        ) then
            lex:next()
            return AST.LiteralExpr(mapped, span)
        end
    end

    -- DSL token(...) resolves a dotted token path explicitly. We parse it
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
        return AST.TokenRefExpr(path, span)
    end

    local expr = lex:luaexpr()
    return AST.LuaExpr(expr, span)
end

-- DSL component invocation args use named syntax and allow bare symbolic values
-- like `tone = primary` and `size = md`. These are parsed as DSL symbols rather
-- than Lua expressions so they can be validated deterministically in lowering.
--
-- For non-variant args (e.g. `theme = dark` where `dark` is a Lua variable),
-- the bare name is still parsed as a Symbol but we also call lex:ref(name)
-- to ensure the name is captured in the lexical environment. The lowering
-- phase resolves non-variant Symbols from the environment.
local function parse_invoke_arg_value_fn(lex)
    if lex:matches(lex.name) and (lex:lookaheadmatches(",") or lex:lookaheadmatches(")")) then
        local span = Span.SpanFromLexer(lex)
        local name = lex:next().value
        -- Register the name for lexical environment capture so that
        -- non-variant args can be resolved from the caller's scope.
        if lex.ref then
            lex:ref(name)
        end
        return AST.Symbol(name, span)
    end
    return parse_value_fn(lex, nil)
end

local function parse_use_expr_fn(lex)
    local span = Span.SpanFromLexer(lex)
    -- use() accepts either:
    --   1. A dotted path to a pre-computed StylePatch value: use(my_patch)
    --   2. A dotted path + named-arg recipe call: use(theme.recipe(name = val))
    --   3. A general Lua expression: use(recipes.button(dark, { tone = "primary" }))
    --
    -- We try the DSL-specific grammar first (path + optional named-arg call).
    -- If the grammar doesn't fit (e.g. positional args), we fall back to
    -- parsing the entire content as a generic Lua expression.

    -- Check if it starts with a name (could be a DSL path or a Lua expr)
    if not lex:matches(lex.name) then
        -- Starts with something other than a name — must be a Lua expression
        local expr_span = Span.SpanFromLexer(lex)
        local expr = lex:luaexpr()
        return AST.LuaExpr(expr, expr_span)
    end

    -- Try to parse a dotted path
    local path = {}
    path[#path + 1] = read_word_like_name(lex, "use target")
    while lex:nextif(".") do
        path[#path + 1] = read_word_like_name(lex, "use path component")
    end
    
    if lex.ref then
        lex:ref(path[1])
    end

    local callee_expr = AST.PathRefExpr(path, span)
    
    -- use(patch_value) — no call, just a path to a pre-computed value
    if not lex:matches("(") then
        return callee_expr
    end
    
    -- Peek ahead: is this a named-arg recipe call `recipe(name = ...)` or
    -- a generic Lua function call `recipe(expr, ...)`?
    -- Named-arg form requires: "(" <name> "=" ...
    -- We check lookahead to distinguish the two cases.
    local is_named_arg_call = false
    if lex:matches("(") then
        -- Look for pattern: ( name =
        -- lex:cur() is "(", lookahead is the next token
        -- We can't easily double-lookahead, so check if after "(" comes
        -- a name token. If so, speculatively check for "=".
        -- Save state: unfortunately Terra lexer doesn't support save/restore,
        -- so we check the common patterns:
        --   - "(" ")" -> call with no args (could be either)
        --   - "(" <name> "=" -> named arg call
        --   - "(" <name> "," -> positional arg call  
        --   - "(" <name> ")" -> single positional arg or named with no =
        --   - anything else -> generic Lua expression
        --
        -- Actually, the simplest approach: named-arg requires the pattern
        -- name "=", so we check if lookahead is a name and the token after
        -- is "=". Terra lexer only supports single lookahead, so we need a
        -- different strategy.
        --
        -- Practical heuristic: if the next token after "(" is ")" it's a
        -- no-arg call. If it's <name> followed by "=", it's named-arg.
        -- Otherwise, fall back to generic Lua expression for the entire call.
        --
        -- Since we already consumed the path tokens, we'll reconstruct the
        -- full expression as a Lua function call using the resolved path.
        
        -- For empty calls and named-arg calls, use DSL grammar
        -- For everything else, evaluate as path(...) using a Lua expression parse
        if lex:lookaheadmatches(")") then
            -- recipe() — no args
            is_named_arg_call = true
        else
            -- We need to check: after "(", is there a <name> followed by "="?
            -- Terra lexer limitation: only 1-token lookahead.
            -- We'll consume "(" and check the pattern.
            -- If it's named-arg, proceed. If not, parse the rest as Lua exprs.
            
            -- Don't consume yet — we'll handle below
            is_named_arg_call = false  -- assume generic, override if named-arg detected
        end
    end
    
    -- Strategy: consume "(" and look at what follows
    lex:expect("(")
    
    -- Empty call: recipe()
    if lex:matches(")") then
        lex:expect(")")
        return AST.CallExpr(callee_expr, "named", span)
    end
    
    -- Check for named-arg pattern: <name> "="
    if lex:matches(lex.name) and lex:lookaheadmatches("=") then
        -- Named-arg recipe call: use(path.recipe(name = val, ...))
        local args = {}
        repeat
            local arg_name = read_word_like_name(lex, "recipe argument name")
            if args[arg_name] ~= nil then
                lex:error("argile: duplicate recipe argument '" .. arg_name .. "'")
            end
            lex:expect("=")
            args[arg_name] = parse_invoke_arg_value_fn(lex)
        until not lex:nextif(",")
        lex:expect(")")

        local call = AST.CallExpr(callee_expr, "named", span)
        call.named_args = args
        return call
    end
    
    -- Generic positional-arg call: use(path.fn(expr1, expr2, ...))
    -- We've already consumed "(" and the first token is not <name> "=".
    -- Parse positional arguments as Lua expressions.
    local pos_args = {}
    repeat
        local expr_span = Span.SpanFromLexer(lex)
        local expr = lex:luaexpr()
        expr = AST.LuaExpr(expr, expr_span)
        pos_args[#pos_args + 1] = expr
    until not lex:nextif(",")
    lex:expect(")")

    local call = AST.CallExpr(callee_expr, "positional", span)
    call.pos_args = pos_args
    return call
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
                args[#args + 1] = parse_value_fn(lex, dsl_symbol_values)
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

local function parse_dsl_token_decl(lex)
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

local function parse_dsl_recipe_decl(lex)
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
            lex:error("argile: expected style, typography, paint, layout, or end in recipe body")
        end
        consume_separators(lex)
    end
    
    expect_word(lex, "end")
    
    return AST.RecipeDecl(name, params, body, span)
end

local function parse_dsl_theme_decl(lex)
    local span = Span.SpanFromLexer(lex)
    expect_word(lex, "theme")
    
    if not lex:matches(lex.name) then
        lex:errorexpected("theme name")
    end
    local name = lex:next().value
    
    -- Check for name collision
    if dsl_registry.themes[name] then
        Span.Raise(span, "duplicate theme declaration: " .. name)
    end
    
    local tokens = {}
    local recipes = {}
    
    while not matches_word(lex, "end") do
        if matches_word(lex, "token") then
            local token = parse_dsl_token_decl(lex)
            tokens[token.path] = token
        elseif matches_word(lex, "recipe") then
            local recipe = parse_dsl_recipe_decl(lex)
            recipes[recipe.name] = recipe
        else
            lex:error("argile: expected token, recipe, or end in theme body")
        end
        consume_separators(lex)
    end
    
    expect_word(lex, "end")
    
    local decl = AST.ThemeDecl(name, tokens, recipes, span)
    dsl_registry.themes[name] = decl
    
    return decl
end

-- ============================================================================
-- Component Declaration Parsing
-- ============================================================================

local function parse_dsl_variant_decl(lex)
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

local function parse_dsl_state_block(lex)
    local span = Span.SpanFromLexer(lex)
    expect_word(lex, "state")
    
    if not lex:matches(lex.name) then
        lex:errorexpected("state name")
    end
    local state_name = lex:next().value
    
    if not dsl_valid_states[state_name] then
        lex:error("argile: unknown state '" .. tostring(state_name) .. "'")
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
            lex:error("argile: expected style, typography, paint, or end in state block")
        end
        consume_separators(lex)
    end
    
    expect_word(lex, "end")
    
    return overlay
end

parse_dsl_node_decl = function(lex, kind)
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
    
    -- DSL `el` is always a block (`el ... end`), so always parse its body.
    -- `text(...)` may be a leaf or may have a body with directives/blocks.
    if kind == "el" then
        parse_dsl_node_body(lex, node)
    elseif starts_v3_node_body(lex) then
        parse_dsl_node_body(lex, node)
    end
    
    return node
end

parse_dsl_node_body = function(lex, node)
    -- Parse directives and blocks
    while not matches_word(lex, "end") do
        if consume_separators(lex) then
            -- noop
        elseif matches_word(lex, "id") then
            if node.id_expr then
                lex:error("argile: duplicate id(...) directive")
            end
            expect_word(lex, "id")
            lex:expect("(")
            node.id_expr = parse_value_fn(lex, nil)
            lex:expect(")")
        elseif matches_word(lex, "part") then
            if node.part_name then
                lex:error("argile: duplicate part(...) directive")
            end
            expect_word(lex, "part")
            lex:expect("(")
            node.part_name = read_word_like_name(lex, "part name")
            lex:expect(")")
        elseif matches_word(lex, "slot") then
            if node.slot_name then
                lex:error("argile: duplicate slot declaration on same node")
            end
            if node.has_children_marker then
                lex:error("argile: cannot have both slot and children on same node")
            end
            expect_word(lex, "slot")
            lex:expect("(")
            node.slot_name = read_word_like_name(lex, "slot name")
            lex:expect(")")
            
            -- Parse fallback content
            while not matches_word(lex, "end") do
                table.insert(node.children, parse_dsl_content_item(lex, "slot fallback"))
                consume_separators(lex)
            end
            expect_word(lex, "end")
        elseif matches_word(lex, "children") then
            if node.has_children_marker then
                lex:error("argile: duplicate children marker")
            end
            if node.slot_name then
                lex:error("argile: cannot have both slot and children on same node")
            end
            expect_word(lex, "children")
            node.has_children_marker = true
        elseif matches_word(lex, "layout") then
            if #node.layout_ops > 0 then
                lex:error("argile: duplicate layout block")
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
            local overlay = parse_dsl_state_block(lex)
            if node.states[overlay.name] then
                lex:error("argile: duplicate state '" .. overlay.name .. "'")
            end
            node.states[overlay.name] = overlay
        elseif matches_word(lex, "el") then
            table.insert(node.children, parse_dsl_node_decl(lex, "el"))
        elseif matches_word(lex, "text") then
            table.insert(node.children, parse_dsl_node_decl(lex, "text"))
        elseif lex:matches("[") then
            -- [expression] splice: inject pre-built V2 subtree(s)
            local span = Span.SpanFromLexer(lex)
            lex:expect("[")
            local expr = lex:luaexpr()
            lex:expect("]")
            table.insert(node.children, AST.Splice(function(environment_function)
                return expr(environment_function())
            end, span))
        elseif is_component_invocation(lex) then
            table.insert(node.children, parse_dsl_component_invoke(lex))
        else
            lex:error("argile: unexpected token in node body")
        end
        consume_separators(lex)
    end
    
    expect_word(lex, "end")
end

local function parse_dsl_root_block(lex)
    local span = Span.SpanFromLexer(lex)
    expect_word(lex, "root")
    
    -- Root is the implicit root element node
    -- It uses node-body grammar (id, layout, style, state, slot, children, el, text, etc.)
    local node = AST.NodeDecl("el", span)
    
    -- Parse node body directives
    parse_dsl_node_body(lex, node)
    
    return node
end

validate_component_template = function(component_name, root_node)
    local seen_slots = {}

    local function visit(node)
        if not AST.IsKind(node, "NodeDecl") then
            return
        end

        if node.part_name == "root" then
            Span.Raise(node._span, "part name 'root' is reserved (implicit component root path) in component '" .. component_name .. "'")
        end

        if node.slot_name then
            if seen_slots[node.slot_name] ~= nil then
                Span.Raise(node._span, "duplicate slot '" .. node.slot_name .. "' in component '" .. component_name .. "' (slot names must be unique per component)")
            end
            seen_slots[node.slot_name] = true
        end

        local sibling_parts = {}
        for _, child in ipairs(node.children or {}) do
            if AST.IsKind(child, "NodeDecl") and child.part_name ~= nil then
                if child.part_name == "root" then
                    Span.Raise(child._span, "part name 'root' is reserved (implicit component root path) in component '" .. component_name .. "'")
                end
                if sibling_parts[child.part_name] then
                    Span.Raise(child._span, "duplicate sibling part '" .. child.part_name .. "' in component '" .. component_name .. "'")
                end
                sibling_parts[child.part_name] = true
            end
        end

        for _, child in ipairs(node.children or {}) do
            if AST.IsKind(child, "NodeDecl") then
                visit(child)
            end
        end
    end

    visit(root_node)
end

local function parse_dsl_component_decl(lex)
    local span = Span.SpanFromLexer(lex)
    expect_word(lex, "component")
    
    if not lex:matches(lex.name) then
        lex:errorexpected("component name")
    end
    local name = lex:next().value
    
    -- Check for name collision
    if dsl_reserved[name] then
        Span.Raise(span, "component name cannot be reserved keyword: " .. name)
    end
    if dsl_registry.components[name] then
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
            local variant = parse_dsl_variant_decl(lex)
            if variants[variant.name] then
                lex:error("argile: duplicate variant '" .. variant.name .. "'")
            end
            variants[variant.name] = variant
        elseif matches_word(lex, "root") then
            if root then
                lex:error("argile: duplicate root block (only one allowed per component)")
            end
            root = parse_dsl_root_block(lex)
        else
            lex:error("argile: expected variant, root, or end in component body")
        end
        consume_separators(lex)
    end
    
    expect_word(lex, "end")
    
    if not root then
        Span.Raise(span, "component must have exactly one root block")
    end

    validate_component_template(name, root)
    
    local decl = AST.ComponentDecl(name, params, variants, root, span)
    dsl_registry.components[name] = decl
    
    return decl
end

-- ============================================================================
-- Component Invocation Parsing
-- ============================================================================

local function parse_dsl_fill_decl(lex)
    local span = Span.SpanFromLexer(lex)
    expect_word(lex, "fill")
    lex:expect("(")
    local slot_name = read_word_like_name(lex, "slot name")
    lex:expect(")")
    
    local children = {}
    while not matches_word(lex, "end") do
        table.insert(children, parse_dsl_content_item(lex, "fill body"))
        consume_separators(lex)
    end
    
    expect_word(lex, "end")
    
    return AST.FillDecl(slot_name, children, span)
end

local function parse_dsl_invoke_body(lex, invoke)
    while not matches_word(lex, "end") do
        if consume_separators(lex) then
            -- noop
        elseif matches_word(lex, "id") then
            if invoke.id_expr then
                lex:error("argile: duplicate id(...) in invocation body")
            end
            expect_word(lex, "id")
            lex:expect("(")
            invoke.id_expr = parse_value_fn(lex, nil)
            lex:expect(")")
        elseif matches_word(lex, "fill") then
            table.insert(invoke.fills, parse_dsl_fill_decl(lex))
        else
            table.insert(invoke.body_nodes, parse_dsl_content_item(lex, "invocation body"))
        end
        consume_separators(lex)
    end
    
    expect_word(lex, "end")
end

parse_dsl_component_invoke = function(lex)
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
                lex:error("argile: duplicate argument '" .. arg_name .. "'")
            end
            lex:expect("=")
            args[arg_name] = parse_invoke_arg_value_fn(lex)
        until not lex:nextif(",")
    end
    
    lex:expect(")")
    
    local invoke = AST.ComponentInvoke(name, args, span)
    
    -- Parse invocation body
    parse_dsl_invoke_body(lex, invoke)
    
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
    if dsl_reserved[name] then
        return false
    end
    
    -- Must be followed by (
    return lex:lookaheadmatches("(")
end

-- Inside argile ... end: parse mixed content
local function parse_argile_body(lex)
    local body_nodes = {}
    
    while not matches_word(lex, "end") do
        table.insert(body_nodes, parse_dsl_content_item(lex, "argile body"))
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
    DslRegistry.Clear(dsl_registry)
end

local language = {
    name = "argile",
    entrypoints = { "argile", "theme", "component" },
    keywords = {
        "argile", "theme", "component", "variant", "root", "part",
        "slot", "fill", "children", "state", "token", "recipe",
        "el", "text", "id", "layout", "style", "typography", "paint", "use",
        "when", -- V2 compatibility, DSL uses 'state'
    },
    
    -- argile ... end (expression form)
    expression = function(self, lex)
        lex:expect("argile")
        local body = parse_argile_body(lex)
        
        return function(environment_function)
            return DslCompiler.compileAstBody(body, environment_function, dsl_registry)
        end
    end,
    
    -- theme <name> ... end (statement form)
    statement = function(self, lex)
        if matches_word(lex, "theme") then
            local decl = parse_dsl_theme_decl(lex)
            return function(env_fn)
                local captured = env_fn and env_fn() or {}
                return DslRegistry.BuildThemeValue(decl, captured)
            end, { decl.name }
        elseif matches_word(lex, "component") then
            local decl = parse_dsl_component_decl(lex)
            return function(env_fn)
                local captured = env_fn and env_fn() or {}
                return DslRegistry.BuildComponentHandle(decl, captured)
            end, { decl.name }
        elseif matches_word(lex, "argile") then
            lex:expect("argile")
            local body = parse_argile_body(lex)
            return function(environment_function)
                return DslCompiler.compileAstBody(body, environment_function, dsl_registry)
            end
        else
            lex:errorexpected("theme, component, or argile")
        end
    end,
    
    -- local theme ... end, local component ... end, local argile ... end
    localstatement = function(self, lex)
        if matches_word(lex, "theme") then
            local decl = parse_dsl_theme_decl(lex)
            return function(env_fn)
                local captured = env_fn and env_fn() or {}
                return DslRegistry.BuildThemeValue(decl, captured)
            end, { decl.name }
        elseif matches_word(lex, "component") then
            local decl = parse_dsl_component_decl(lex)
            return function(env_fn)
                local captured = env_fn and env_fn() or {}
                return DslRegistry.BuildComponentHandle(decl, captured)
            end, { decl.name }
        elseif matches_word(lex, "argile") then
            lex:expect("argile")
            local body = parse_argile_body(lex)
            return function(environment_function)
                return DslCompiler.compileAstBody(body, environment_function, dsl_registry)
            end
        else
            lex:errorexpected("theme, component, or argile")
        end
    end,
}

language.registry = dsl_registry

return language
