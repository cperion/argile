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

local attach_point_values = {
    left_top = ui.ATTACH_LEFT_TOP,
    left_center = ui.ATTACH_LEFT_CENTER,
    left_bottom = ui.ATTACH_LEFT_BOTTOM,
    center_top = ui.ATTACH_CENTER_TOP,
    center_center = ui.ATTACH_CENTER_CENTER,
    center_bottom = ui.ATTACH_CENTER_BOTTOM,
    right_top = ui.ATTACH_RIGHT_TOP,
    right_center = ui.ATTACH_RIGHT_CENTER,
    right_bottom = ui.ATTACH_RIGHT_BOTTOM,
}

local pointer_capture_values = {
    capture = ui.POINTER_CAPTURE,
    passthrough = ui.POINTER_PASSTHROUGH,
}

local attach_to_values = {
    none = ui.ATTACH_NONE,
    parent = ui.ATTACH_PARENT,
    element_with_id = ui.ATTACH_ELEMENT_WITH_ID,
    root = ui.ATTACH_ROOT,
}

local clip_to_values = {
    none = ui.CLIP_NONE,
    attached_parent = ui.CLIP_ATTACHED_PARENT,
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
insert_symbol_values(attach_point_values)
insert_symbol_values(pointer_capture_values)
insert_symbol_values(attach_to_values)
insert_symbol_values(clip_to_values)

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

local function ensure_table(tbl, key)
    if type(tbl[key]) ~= "table" then
        tbl[key] = {}
    end
    return tbl[key]
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

local function is_body_keyword(lex)
    return matches_word(lex, "layout")
        or matches_word(lex, "shared")
        or matches_word(lex, "border")
        or matches_word(lex, "clip")
        or matches_word(lex, "aspect")
        or matches_word(lex, "image")
        or matches_word(lex, "custom")
        or matches_word(lex, "floating")
        or matches_word(lex, "textcfg")
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

local function parse_config_ops(lex, keyword)
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

local function apply_shared_op(cfg, op, environment_function)
    local n = op.name
    if n == "color" then
        local color = ensure_table(cfg, "backgroundColor")
        color.r = eval_arg(op, 1, environment_function, 0.0)
        color.g = eval_arg(op, 2, environment_function, 0.0)
        color.b = eval_arg(op, 3, environment_function, 0.0)
        color.a = eval_arg(op, 4, environment_function, 1.0)
    elseif n == "radius" then
        local r = eval_arg(op, 1, environment_function, 0.0)
        cfg.cornerRadius = {
            topLeft = r,
            topRight = r,
            bottomLeft = r,
            bottomRight = r,
        }
    elseif n == "radius4" then
        cfg.cornerRadius = {
            topLeft = eval_arg(op, 1, environment_function, 0.0),
            topRight = eval_arg(op, 2, environment_function, 0.0),
            bottomLeft = eval_arg(op, 3, environment_function, 0.0),
            bottomRight = eval_arg(op, 4, environment_function, 0.0),
        }
    elseif n == "user_data" then
        cfg.userData = eval_arg(op, 1, environment_function, nil)
    else
        error("argile shared: unknown operation '" .. tostring(n) .. "'")
    end
end

local function apply_border_op(cfg, op, environment_function)
    local n = op.name
    if n == "color" then
        local color = ensure_table(cfg, "color")
        color.r = eval_arg(op, 1, environment_function, 0.0)
        color.g = eval_arg(op, 2, environment_function, 0.0)
        color.b = eval_arg(op, 3, environment_function, 0.0)
        color.a = eval_arg(op, 4, environment_function, 1.0)
    elseif n == "width" then
        local w = eval_arg(op, 1, environment_function, 0)
        cfg.width = {
            left = w,
            right = w,
            top = w,
            bottom = w,
            betweenChildren = 0,
        }
    elseif n == "width4" then
        local width = ensure_table(cfg, "width")
        width.left = eval_arg(op, 1, environment_function, 0)
        width.right = eval_arg(op, 2, environment_function, 0)
        width.top = eval_arg(op, 3, environment_function, 0)
        width.bottom = eval_arg(op, 4, environment_function, 0)
    elseif n == "between_children" then
        local width = ensure_table(cfg, "width")
        width.betweenChildren = eval_arg(op, 1, environment_function, 0)
    else
        error("argile border: unknown operation '" .. tostring(n) .. "'")
    end
end

local function apply_clip_op(cfg, op, environment_function)
    local n = op.name
    if n == "horizontal" then
        cfg.horizontal = eval_arg(op, 1, environment_function, false)
    elseif n == "vertical" then
        cfg.vertical = eval_arg(op, 1, environment_function, false)
    elseif n == "offset" then
        cfg.childOffset = {
            x = eval_arg(op, 1, environment_function, 0.0),
            y = eval_arg(op, 2, environment_function, 0.0),
        }
    else
        error("argile clip: unknown operation '" .. tostring(n) .. "'")
    end
end

local function apply_aspect_op(cfg, op, environment_function)
    local n = op.name
    if n == "ratio" then
        cfg.aspectRatio = eval_arg(op, 1, environment_function, 1.0)
    else
        error("argile aspect: unknown operation '" .. tostring(n) .. "'")
    end
end

local function apply_image_op(cfg, op, environment_function)
    local n = op.name
    if n == "data" then
        cfg.imageData = eval_arg(op, 1, environment_function, nil)
    else
        error("argile image: unknown operation '" .. tostring(n) .. "'")
    end
end

local function apply_custom_op(cfg, op, environment_function)
    local n = op.name
    if n == "data" then
        cfg.customData = eval_arg(op, 1, environment_function, nil)
    else
        error("argile custom: unknown operation '" .. tostring(n) .. "'")
    end
end

local function apply_floating_op(cfg, op, environment_function)
    local n = op.name
    if n == "offset" then
        cfg.offset = {
            x = eval_arg(op, 1, environment_function, 0.0),
            y = eval_arg(op, 2, environment_function, 0.0),
        }
    elseif n == "expand" then
        cfg.expand = {
            width = eval_arg(op, 1, environment_function, 0.0),
            height = eval_arg(op, 2, environment_function, 0.0),
        }
    elseif n == "parent_id" then
        cfg.parentId = eval_arg(op, 1, environment_function, 0)
    elseif n == "z_index" then
        cfg.zIndex = eval_arg(op, 1, environment_function, 0)
    elseif n == "element_attach" then
        cfg.elementAttach = coerce_enum(eval_arg(op, 1, environment_function, ui.ATTACH_LEFT_TOP), attach_point_values, ui.ATTACH_LEFT_TOP)
    elseif n == "parent_attach" then
        cfg.parentAttach = coerce_enum(eval_arg(op, 1, environment_function, ui.ATTACH_LEFT_TOP), attach_point_values, ui.ATTACH_LEFT_TOP)
    elseif n == "pointer_capture" then
        cfg.pointerCaptureMode = coerce_enum(eval_arg(op, 1, environment_function, ui.POINTER_CAPTURE), pointer_capture_values, ui.POINTER_CAPTURE)
    elseif n == "attach_to" then
        cfg.attachTo = coerce_enum(eval_arg(op, 1, environment_function, ui.ATTACH_NONE), attach_to_values, ui.ATTACH_NONE)
    elseif n == "clip_to" then
        cfg.clipTo = coerce_enum(eval_arg(op, 1, environment_function, ui.CLIP_NONE), clip_to_values, ui.CLIP_NONE)
    else
        error("argile floating: unknown operation '" .. tostring(n) .. "'")
    end
end

local function apply_textcfg_op(cfg, op, environment_function)
    local n = op.name
    if n == "color" then
        local color = ensure_table(cfg, "textColor")
        color.r = eval_arg(op, 1, environment_function, 0.0)
        color.g = eval_arg(op, 2, environment_function, 0.0)
        color.b = eval_arg(op, 3, environment_function, 0.0)
        color.a = eval_arg(op, 4, environment_function, 1.0)
    elseif n == "font_id" then
        cfg.fontId = eval_arg(op, 1, environment_function, 0)
    elseif n == "font_size" then
        cfg.fontSize = eval_arg(op, 1, environment_function, 16)
    elseif n == "letter_spacing" then
        cfg.letterSpacing = eval_arg(op, 1, environment_function, 0)
    elseif n == "line_height" then
        cfg.lineHeight = eval_arg(op, 1, environment_function, 0)
    elseif n == "wrap" then
        cfg.wrapMode = coerce_enum(eval_arg(op, 1, environment_function, ui.TEXT_WRAP_WORDS), text_wrap_values, ui.TEXT_WRAP_WORDS)
    elseif n == "align" then
        cfg.textAlignment = coerce_enum(eval_arg(op, 1, environment_function, ui.TEXT_ALIGN_LEFT), text_align_values, ui.TEXT_ALIGN_LEFT)
    elseif n == "user_data" then
        cfg.userData = eval_arg(op, 1, environment_function, nil)
    else
        error("argile textcfg: unknown operation '" .. tostring(n) .. "'")
    end
end

local function build_cfg(ops, apply_fn, environment_function)
    local cfg = {}
    for _, op in ipairs(ops) do
        apply_fn(cfg, op, environment_function)
    end
    return cfg
end

local parse_node_builder

local function parse_container_body(lex, allow_textcfg)
    local layout_ops = nil
    local shared_ops = nil
    local border_ops = nil
    local clip_ops = nil
    local aspect_ops = nil
    local image_ops = nil
    local custom_ops = nil
    local floating_ops = nil
    local textcfg_ops = nil
    local child_builders = {}

    while not matches_word(lex, "end") do
        if consume_separators(lex) then
            -- noop
        elseif matches_word(lex, "layout") then
            layout_ops = parse_config_ops(lex, "layout")
        elseif matches_word(lex, "shared") then
            shared_ops = parse_config_ops(lex, "shared")
        elseif matches_word(lex, "border") then
            border_ops = parse_config_ops(lex, "border")
        elseif matches_word(lex, "clip") then
            clip_ops = parse_config_ops(lex, "clip")
        elseif matches_word(lex, "aspect") then
            aspect_ops = parse_config_ops(lex, "aspect")
        elseif matches_word(lex, "image") then
            image_ops = parse_config_ops(lex, "image")
        elseif matches_word(lex, "custom") then
            custom_ops = parse_config_ops(lex, "custom")
        elseif matches_word(lex, "floating") then
            floating_ops = parse_config_ops(lex, "floating")
        elseif matches_word(lex, "textcfg") then
            if not allow_textcfg then
                lex:error("argile: textcfg is only valid inside text nodes")
            end
            textcfg_ops = parse_config_ops(lex, "textcfg")
        elseif matches_word(lex, "el") or matches_word(lex, "text") then
            child_builders[#child_builders + 1] = parse_node_builder(lex)
        else
            lex:error("argile: unexpected token in node body")
        end
        consume_separators(lex)
    end

    expect_word(lex, "end")

    return function(environment_function)
        local node = {}
        if layout_ops then
            node.layout = build_cfg(layout_ops, apply_layout_op, environment_function)
        end
        if shared_ops then
            node.shared = build_cfg(shared_ops, apply_shared_op, environment_function)
        end
        if border_ops then
            node.border = build_cfg(border_ops, apply_border_op, environment_function)
        end
        if clip_ops then
            node.clip = build_cfg(clip_ops, apply_clip_op, environment_function)
        end
        if aspect_ops then
            node.aspect = build_cfg(aspect_ops, apply_aspect_op, environment_function)
        end
        if image_ops then
            node.image = build_cfg(image_ops, apply_image_op, environment_function)
        end
        if custom_ops then
            node.custom = build_cfg(custom_ops, apply_custom_op, environment_function)
        end
        if floating_ops then
            node.floating = build_cfg(floating_ops, apply_floating_op, environment_function)
        end
        if textcfg_ops then
            node.textConfig = build_cfg(textcfg_ops, apply_textcfg_op, environment_function)
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

local function parse_element_builder(lex)
    expect_word(lex, "el")

    local id_value = nil
    if lex:nextif("(") then
        id_value = parse_value_fn(lex, nil)
        lex:expect(")")
    end

    local body_builder = parse_container_body(lex, false)
    return function(environment_function)
        local node = body_builder(environment_function)
        if id_value ~= nil then
            node.id = id_value(environment_function)
        end
        return node
    end
end

local function parse_text_builder(lex)
    expect_word(lex, "text")
    lex:expect("(")
    local text_value = parse_value_fn(lex, nil)
    lex:expect(")")

    local body_builder = nil
    if is_body_keyword(lex) then
        body_builder = parse_container_body(lex, true)
    end

    return function(environment_function)
        local node = body_builder and body_builder(environment_function) or {}
        node.text = text_value(environment_function)
        return node
    end
end

parse_node_builder = function(lex)
    if matches_word(lex, "el") then
        return parse_element_builder(lex)
    elseif matches_word(lex, "text") then
        return parse_text_builder(lex)
    end
    lex:error("argile: expected 'el' or 'text'")
end

local function parse_root_constructor(lex)
    if matches_word(lex, "el") or matches_word(lex, "text") then
        local node_builder = parse_node_builder(lex)
        return function(environment_function)
            return ui.compile(node_builder(environment_function))
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
        "layout",
        "shared",
        "border",
        "clip",
        "aspect",
        "image",
        "custom",
        "floating",
        "textcfg",
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
