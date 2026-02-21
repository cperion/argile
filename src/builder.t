local ui = require("src.init")

local function compileLayoutConfig(cfg)
    local widthType = cfg.widthType or ui.SIZING_FIT
    local heightType = cfg.heightType or ui.SIZING_FIT
    local minWidth = cfg.minWidth or 0.0
    local minHeight = cfg.minHeight or 0.0
    local maxWidth = cfg.maxWidth or ui.MAXFLOAT
    local maxHeight = cfg.maxHeight or ui.MAXFLOAT
    local widthPercent = cfg.widthPercent or 0.0
    local heightPercent = cfg.heightPercent or 0.0
    local paddingLeft = cfg.paddingLeft or 0
    local paddingRight = cfg.paddingRight or 0
    local paddingTop = cfg.paddingTop or 0
    local paddingBottom = cfg.paddingBottom or 0
    local childGap = cfg.childGap or 0
    local alignX = cfg.alignX or ui.ALIGN_X_LEFT
    local alignY = cfg.alignY or ui.ALIGN_Y_TOP
    local layoutDir = cfg.layoutDir or ui.LEFT_TO_RIGHT
    
    return quote
        var c : ui.LayoutConfig
        c.sizing.width.type = [widthType]
        c.sizing.width.size.min = [minWidth]
        c.sizing.width.size.max = [maxWidth]
        c.sizing.width.percent = [widthPercent]
        c.sizing.height.type = [heightType]
        c.sizing.height.size.min = [minHeight]
        c.sizing.height.size.max = [maxHeight]
        c.sizing.height.percent = [heightPercent]
        c.padding.left = [paddingLeft]
        c.padding.right = [paddingRight]
        c.padding.top = [paddingTop]
        c.padding.bottom = [paddingBottom]
        c.childGap = [childGap]
        c.childAlignment.x = [alignX]
        c.childAlignment.y = [alignY]
        c.layoutDirection = [layoutDir]
    in
        c
    end
end

local function compileSharedConfig(cfg)
    if cfg == nil then return nil end
    
    local r = cfg.backgroundColor and cfg.backgroundColor.r or 0.0
    local g = cfg.backgroundColor and cfg.backgroundColor.g or 0.0
    local b = cfg.backgroundColor and cfg.backgroundColor.b or 0.0
    local a = cfg.backgroundColor and cfg.backgroundColor.a or 1.0
    local tl = cfg.cornerRadius and cfg.cornerRadius.topLeft or 0.0
    local tr = cfg.cornerRadius and cfg.cornerRadius.topRight or 0.0
    local bl = cfg.cornerRadius and cfg.cornerRadius.bottomLeft or 0.0
    local br = cfg.cornerRadius and cfg.cornerRadius.bottomRight or 0.0
    
    return quote
        var s : ui.SharedConfig
        s.backgroundColor.r = [r]
        s.backgroundColor.g = [g]
        s.backgroundColor.b = [b]
        s.backgroundColor.a = [a]
        s.cornerRadius.topLeft = [tl]
        s.cornerRadius.topRight = [tr]
        s.cornerRadius.bottomLeft = [bl]
        s.cornerRadius.bottomRight = [br]
        s.userData = nil
    in
        s
    end
end

function ui.compile(node)
    local stmts = terralib.newlist()
    
    if node.id then
        if type(node.id) == "string" then
            stmts:insert(quote
                var id_str = ui.String {
                    isStaticallyAllocated = true,
                    length = [#node.id],
                    chars = [node.id]
                }
                var elem_id = ui.GetElementId(id_str)
                ui.OpenElementWithId(elem_id)
            end)
        else
            stmts:insert(quote ui.OpenElement() end)
        end
    else
        stmts:insert(quote ui.OpenElement() end)
    end
    
    if node.layout then
        stmts:insert(quote
            var cfg = ui.GetCurrentContext():storeLayoutConfig([compileLayoutConfig(node.layout)])
            var elem = ui.GetCurrentContext():getOpenLayoutElement()
            if elem ~= nil and cfg ~= nil then
                elem.layoutConfig = cfg
            end
        end)
    end
    
    if node.shared then
        stmts:insert(quote
            var shared_cfg = ui.GetCurrentContext():storeSharedConfig([compileSharedConfig(node.shared)])
            var elem = ui.GetCurrentContext():getOpenLayoutElement()
            if elem ~= nil then
                var cfgUnion : ui.ElementConfigUnion
                cfgUnion.sharedConfig = shared_cfg
                ui.GetCurrentContext():attachElementConfig(cfgUnion, ui.CONFIG_SHARED)
            end
        end)
    end
    
    if node.text then
        local textStr = node.text
        local textConfig = node.textConfig
        
        if textConfig then
            stmts:insert(quote
                var txt : ui.String
                txt.isStaticallyAllocated = true
                txt.length = [#textStr]
                txt.chars = [textStr]
                var txt_cfg : ui.TextConfig
                txt_cfg.userData = nil
                txt_cfg.textColor.r = [textConfig.textColor and textConfig.textColor.r or 0.0]
                txt_cfg.textColor.g = [textConfig.textColor and textConfig.textColor.g or 0.0]
                txt_cfg.textColor.b = [textConfig.textColor and textConfig.textColor.b or 0.0]
                txt_cfg.textColor.a = [textConfig.textColor and textConfig.textColor.a or 1.0]
                txt_cfg.fontId = [textConfig.fontId or 0]
                txt_cfg.fontSize = [textConfig.fontSize or 16]
                txt_cfg.letterSpacing = [textConfig.letterSpacing or 0]
                txt_cfg.lineHeight = [textConfig.lineHeight or 0]
                txt_cfg.wrapMode = [textConfig.wrapMode or ui.TEXT_WRAP_WORDS]
                txt_cfg.textAlignment = [textConfig.textAlignment or ui.TEXT_ALIGN_LEFT]
                var txt_cfg_ptr = ui.GetCurrentContext():storeTextConfig(txt_cfg)
                ui.OpenTextElement(txt, txt_cfg_ptr)
            end)
        else
            stmts:insert(quote
                var txt : ui.String
                txt.isStaticallyAllocated = true
                txt.length = [#textStr]
                txt.chars = [textStr]
                ui.OpenTextElement(txt, nil)
            end)
        end
    elseif node.children then
        for _, child in ipairs(node.children) do
            stmts:insert(ui.compile(child))
        end
    end
    
    stmts:insert(quote ui.CloseElement() end)
    
    return quote [stmts] end
end

-- Generate an exported function that can be called via FFI
function ui.compileFunction(name, node)
    local body = ui.compile(node)
    
    local fn = terra()
        [body]
    end
    fn:setinlined(false)
    
    -- Make it available globally for export
    _G[name] = fn
    
    return fn
end

-- Generate a render function that returns RenderCommandArray via FFI
function ui.compileRenderFunction(name, layoutNode)
    local body = ui.compile(layoutNode)
    
    local RenderCommandArray = ui.Array(ui.RenderCommand)
    
    local fn = terra() : &RenderCommandArray
        ui.BeginLayout(1920.0, 1080.0)
        [body]
        return ui.EndLayout()
    end
    fn:setinlined(false)
    
    _G[name] = fn
    
    return fn
end

return ui
