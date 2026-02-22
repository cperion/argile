local ui = require("src.builder")

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

local symbol_values = {}
local function insert_symbol_values(values)
    for k, v in pairs(values) do
        symbol_values[k] = v
    end
end

insert_symbol_values(layout_dir_values)
insert_symbol_values(align_x_values)
insert_symbol_values(align_y_values)
insert_symbol_values(text_wrap_values)
insert_symbol_values(text_align_values)

local valid_states = {
    hover = true,
    active = true,
    disabled = true,
    focus = true,
    selected = true,
}

local function coerce_enum(value, map, fallback)
    if value == nil then
        return fallback
    end
    if map[value] ~= nil then
        return map[value]
    end
    if type(value) == "string" then
        local key = value:lower():gsub("%s+", "_")
        if map[key] ~= nil then
            return map[key]
        end
    end
    return value
end

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

local function is_v2_body_keyword(lex)
    return matches_word(lex, "layout")
        or matches_word(lex, "id")
        or matches_word(lex, "use")
        or matches_word(lex, "style")
        or matches_word(lex, "typography")
        or matches_word(lex, "paint")
        or matches_word(lex, "when")
        or matches_word(lex, "el")
        or matches_word(lex, "text")
end

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

    local expr = lex:luaexpr()
    return function(environment_function)
        return expr(environment_function())
    end
end

local function parse_call_args(lex)
    local args = {}
    if not lex:nextif("(") then
        return args
    end
    if not lex:matches(")") then
        repeat
            args[#args + 1] = parse_value_fn(lex, symbol_values)
        until not lex:nextif(",")
    end
    lex:expect(")")
    return args
end

local function parse_operation(lex)
    if not lex:matches(lex.name) then
        lex:errorexpected("operation name")
    end
    local name = lex:next().value
    return { name = name, args = parse_call_args(lex) }
end

local function eval_arg(op, index, environment_function, fallback)
    local fn = op.args[index]
    if fn == nil then
        return fallback
    end
    local value = fn(environment_function)
    if value == nil then
        return fallback
    end
    return value
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

local function apply_layout_op(cfg, op, environment_function)
    local n = op.name
    if n == "width_fit" then
        cfg.widthType = ui.SIZING_FIT
    elseif n == "width_grow" then
        cfg.widthType = ui.SIZING_GROW
    elseif n == "width_fixed" then
        local v = eval_arg(op, 1, environment_function, 0.0)
        local vmax = eval_arg(op, 2, environment_function, v)
        cfg.widthType = ui.SIZING_FIXED
        cfg.minWidth = v
        cfg.maxWidth = vmax
    elseif n == "width_percent" then
        cfg.widthType = ui.SIZING_PERCENT
        cfg.widthPercent = eval_arg(op, 1, environment_function, 0.0)
    elseif n == "height_fit" then
        cfg.heightType = ui.SIZING_FIT
    elseif n == "height_grow" then
        cfg.heightType = ui.SIZING_GROW
    elseif n == "height_fixed" then
        local v = eval_arg(op, 1, environment_function, 0.0)
        local vmax = eval_arg(op, 2, environment_function, v)
        cfg.heightType = ui.SIZING_FIXED
        cfg.minHeight = v
        cfg.maxHeight = vmax
    elseif n == "height_percent" then
        cfg.heightType = ui.SIZING_PERCENT
        cfg.heightPercent = eval_arg(op, 1, environment_function, 0.0)
    elseif n == "min_width" then
        cfg.minWidth = eval_arg(op, 1, environment_function, 0.0)
    elseif n == "max_width" then
        cfg.maxWidth = eval_arg(op, 1, environment_function, ui.MAXFLOAT)
    elseif n == "min_height" then
        cfg.minHeight = eval_arg(op, 1, environment_function, 0.0)
    elseif n == "max_height" then
        cfg.maxHeight = eval_arg(op, 1, environment_function, ui.MAXFLOAT)
    elseif n == "padding" then
        local p = eval_arg(op, 1, environment_function, 0)
        cfg.paddingLeft = p
        cfg.paddingRight = p
        cfg.paddingTop = p
        cfg.paddingBottom = p
    elseif n == "padding4" then
        cfg.paddingLeft = eval_arg(op, 1, environment_function, 0)
        cfg.paddingRight = eval_arg(op, 2, environment_function, 0)
        cfg.paddingTop = eval_arg(op, 3, environment_function, 0)
        cfg.paddingBottom = eval_arg(op, 4, environment_function, 0)
    elseif n == "gap" then
        cfg.childGap = eval_arg(op, 1, environment_function, 0)
    elseif n == "dir" then
        cfg.layoutDir = coerce_enum(eval_arg(op, 1, environment_function, ui.LEFT_TO_RIGHT), layout_dir_values, ui.LEFT_TO_RIGHT)
    elseif n == "align_x" then
        cfg.alignX = coerce_enum(eval_arg(op, 1, environment_function, ui.ALIGN_X_LEFT), align_x_values, ui.ALIGN_X_LEFT)
    elseif n == "align_y" then
        cfg.alignY = coerce_enum(eval_arg(op, 1, environment_function, ui.ALIGN_Y_TOP), align_y_values, ui.ALIGN_Y_TOP)
    else
        error("argile layout: unknown operation '" .. tostring(n) .. "'")
    end
end

local function build_layout_cfg(ops, environment_function)
    local cfg = {}
    for _, op in ipairs(ops) do
        apply_layout_op(cfg, op, environment_function)
    end
    return cfg
end

local function eval_ops_list(op_blocks, environment_function)
    if #op_blocks == 0 then
        return nil
    end

    local out = {}
    for _, ops in ipairs(op_blocks) do
        for _, op in ipairs(ops) do
            local args = {}
            if op.args then
                for i, arg_fn in ipairs(op.args) do
                    args[i] = arg_fn(environment_function)
                end
            end
            table.insert(out, { name = op.name, args = args })
        end
    end
    return out
end

local parse_v2_node_builder
local parse_v2_state_block

local function parse_v2_container_body(lex, is_text_node)
    local id_value = nil
    local layout_ops = nil
    local use_patches = {}
    local style_ops_list = {}
    local typography_ops_list = {}
    local paint_ops_list = {}
    local state_builders = {}
    local child_builders = {}

    while not matches_word(lex, "end") do
        if consume_separators(lex) then
            -- noop
        elseif matches_word(lex, "id") then
            if id_value ~= nil then
                lex:error("argile: duplicate id(...) directive")
            end
            expect_word(lex, "id")
            lex:expect("(")
            id_value = parse_value_fn(lex, nil)
            lex:expect(")")
        elseif matches_word(lex, "layout") then
            if layout_ops ~= nil then
                lex:error("argile: duplicate layout block (only one layout block is allowed per node)")
            end
            layout_ops = parse_block_ops(lex, "layout")
        elseif matches_word(lex, "use") then
            expect_word(lex, "use")
            lex:expect("(")
            local patch_expr = lex:luaexpr()
            lex:expect(")")
            table.insert(use_patches, patch_expr)
        elseif matches_word(lex, "style") then
            local ops = parse_block_ops(lex, "style")
            table.insert(style_ops_list, ops)
        elseif matches_word(lex, "typography") then
            if not is_text_node then
                lex:error("argile: typography is only valid inside text nodes")
            end
            local ops = parse_block_ops(lex, "typography")
            table.insert(typography_ops_list, ops)
        elseif matches_word(lex, "paint") then
            local ops = parse_block_ops(lex, "paint")
            table.insert(paint_ops_list, ops)
        elseif matches_word(lex, "when") then
            local state_name, state_builder = parse_v2_state_block(lex, is_text_node)
            if state_builders[state_name] ~= nil then
                lex:error("argile: duplicate when block for state '" .. state_name .. "'")
            end
            state_builders[state_name] = state_builder
        elseif matches_word(lex, "el") or matches_word(lex, "text") then
            child_builders[#child_builders + 1] = parse_v2_node_builder(lex)
        else
            lex:error("argile: unexpected token in node body")
        end
        consume_separators(lex)
    end

    expect_word(lex, "end")

    return function(environment_function)
        local node = {}

        if id_value ~= nil then
            node.id = id_value(environment_function)
        end
        
        if layout_ops then
            node.layout = build_layout_cfg(layout_ops, environment_function)
        end
        
        if #use_patches > 0 then
            node.use_patches = {}
            for _, expr in ipairs(use_patches) do
                local patch = expr(environment_function())
                if patch ~= nil then
                    table.insert(node.use_patches, patch)
                end
            end
        end
        
        node.style_ops = eval_ops_list(style_ops_list, environment_function)
        node.typography_ops = eval_ops_list(typography_ops_list, environment_function)
        node.paint_ops = eval_ops_list(paint_ops_list, environment_function)
        
        local has_state = false
        for _ in pairs(state_builders) do
            has_state = true
            break
        end
        if has_state then
            node.states = {}
            for state_name, builder in pairs(state_builders) do
                node.states[state_name] = builder(environment_function)
            end
        end
        
        if #child_builders > 0 then
            node.children = {}
            for _, builder in ipairs(child_builders) do
                node.children[#node.children + 1] = builder(environment_function)
            end
        end
        
        return node
    end
end

parse_v2_state_block = function(lex, is_text_node)
    expect_word(lex, "when")
    
    if not lex:matches(lex.name) then
        lex:errorexpected("state name")
    end
    local state_name = lex:next().value
    
    if not valid_states[state_name] then
        lex:error("argile: invalid state '" .. state_name .. "'. Valid states: hover, active, disabled, focus, selected")
    end
    
    local use_patches = {}
    local style_ops_list = {}
    local typography_ops_list = {}
    local paint_ops_list = {}

    while not matches_word(lex, "end") do
        if consume_separators(lex) then
            -- noop
        elseif matches_word(lex, "use") then
            expect_word(lex, "use")
            lex:expect("(")
            local patch_expr = lex:luaexpr()
            lex:expect(")")
            table.insert(use_patches, patch_expr)
        elseif matches_word(lex, "style") then
            local ops = parse_block_ops(lex, "style")
            table.insert(style_ops_list, ops)
        elseif matches_word(lex, "typography") then
            if not is_text_node then
                lex:error("argile: typography is only valid inside text nodes")
            end
            local ops = parse_block_ops(lex, "typography")
            table.insert(typography_ops_list, ops)
        elseif matches_word(lex, "paint") then
            local ops = parse_block_ops(lex, "paint")
            table.insert(paint_ops_list, ops)
        else
            lex:error("argile: unexpected token in when block (only use, style, typography, paint allowed)")
        end
        consume_separators(lex)
    end

    expect_word(lex, "end")

    local builder = function(environment_function)
        local node = {}
        
        if #use_patches > 0 then
            node.use_patches = {}
            for _, expr in ipairs(use_patches) do
                local patch = expr(environment_function())
                if patch ~= nil then
                    table.insert(node.use_patches, patch)
                end
            end
        end
        
        node.style_ops = eval_ops_list(style_ops_list, environment_function)
        node.typography_ops = eval_ops_list(typography_ops_list, environment_function)
        node.paint_ops = eval_ops_list(paint_ops_list, environment_function)
        
        return node
    end

    return state_name, builder
end

local function parse_v2_element_builder(lex)
    expect_word(lex, "el")
    if lex:matches("(") then
        lex:error("argile: el(...) was removed; use id(...) inside the el body")
    end

    local body_builder = parse_v2_container_body(lex, false)
    return function(environment_function)
        return body_builder(environment_function)
    end
end

local function parse_v2_text_builder(lex)
    expect_word(lex, "text")
    lex:expect("(")
    local text_value = parse_value_fn(lex, nil)
    lex:expect(")")

    local body_builder = nil
    if is_v2_body_keyword(lex) then
        body_builder = parse_v2_container_body(lex, true)
    end

    return function(environment_function)
        local node = body_builder and body_builder(environment_function) or {}
        node.text = text_value(environment_function)
        return node
    end
end

parse_v2_node_builder = function(lex)
    if matches_word(lex, "el") then
        return parse_v2_element_builder(lex)
    elseif matches_word(lex, "text") then
        return parse_v2_text_builder(lex)
    end
    lex:error("argile: expected 'el' or 'text'")
end

local function parse_root_constructor(lex)
    if matches_word(lex, "el") or matches_word(lex, "text") then
        local node_builder = parse_v2_node_builder(lex)
        return function(environment_function)
            return ui.compileResolved(node_builder(environment_function))
        end
    end
    lex:error("argile: expected root node 'el' or 'text'")
end

local function parse_named_layout_assignment(lex)
    local name = lex:expect(lex.name).value
    lex:expect("=")
    return parse_root_constructor(lex), { name }
end

local language = {
    name = "argile";
    entrypoints = { "argile" };
    keywords = {
        "el",
        "text",
        "id",
        "layout",
        "use",
        "style",
        "typography",
        "paint",
        "when",
    };
    expression = function(self, lex)
        lex:expect("argile")
        return parse_root_constructor(lex)
    end;
    statement = function(self, lex)
        lex:expect("argile")
        return parse_named_layout_assignment(lex)
    end;
    localstatement = function(self, lex)
        lex:expect("argile")
        return parse_named_layout_assignment(lex)
    end;
}

return language
