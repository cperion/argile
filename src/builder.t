local ui = require("src.init")

local function value_or(v, default)
    if v == nil then
        return default
    end
    return v
end

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

local function compileBorderConfig(cfg)
    if cfg == nil then return nil end

    local color = cfg.color or {}
    local widthTable = type(cfg.width) == "table" and cfg.width or nil
    local uniformWidth = type(cfg.width) == "number" and cfg.width or cfg.uniformWidth
    if uniformWidth == nil then
        uniformWidth = 0
    end

    local left = value_or(widthTable and widthTable.left, value_or(cfg.left, uniformWidth))
    local right = value_or(widthTable and widthTable.right, value_or(cfg.right, uniformWidth))
    local top = value_or(widthTable and widthTable.top, value_or(cfg.top, uniformWidth))
    local bottom = value_or(widthTable and widthTable.bottom, value_or(cfg.bottom, uniformWidth))
    local betweenChildren = value_or(widthTable and widthTable.betweenChildren, value_or(cfg.betweenChildren, 0))

    return quote
        var b : ui.BorderConfig
        b.color.r = [value_or(color.r, 0.0)]
        b.color.g = [value_or(color.g, 0.0)]
        b.color.b = [value_or(color.b, 0.0)]
        b.color.a = [value_or(color.a, 1.0)]
        b.width.left = [left]
        b.width.right = [right]
        b.width.top = [top]
        b.width.bottom = [bottom]
        b.width.betweenChildren = [betweenChildren]
    in
        b
    end
end

local function compileClipConfig(cfg)
    if cfg == nil then return nil end
    local childOffset = cfg.childOffset or {}
    return quote
        var c : ui.ClipConfig
        c.horizontal = [value_or(cfg.horizontal, false)]
        c.vertical = [value_or(cfg.vertical, false)]
        c.childOffset.x = [value_or(childOffset.x, value_or(cfg.offsetX, 0.0))]
        c.childOffset.y = [value_or(childOffset.y, value_or(cfg.offsetY, 0.0))]
    in
        c
    end
end

local function compileAspectConfig(cfg)
    if cfg == nil then return nil end
    local ratio = value_or(cfg.aspectRatio, value_or(cfg.ratio, 1.0))
    return quote
        var a : ui.AspectRatioConfig
        a.aspectRatio = [ratio]
    in
        a
    end
end

local function compileImageConfig(cfg)
    if cfg == nil then return nil end
    local imageData = value_or(cfg.imageData, cfg.data)
    if imageData ~= nil then
        return quote
            var i : ui.ImageConfig
            i.imageData = [imageData]
        in
            i
        end
    end
    return quote
        var i : ui.ImageConfig
        i.imageData = nil
    in
        i
    end
end

local function compileCustomConfig(cfg)
    if cfg == nil then return nil end
    local customData = value_or(cfg.customData, cfg.data)
    if customData ~= nil then
        return quote
            var c : ui.CustomConfig
            c.customData = [customData]
        in
            c
        end
    end
    return quote
        var c : ui.CustomConfig
        c.customData = nil
    in
        c
    end
end

local function compileFloatingConfig(cfg)
    if cfg == nil then return nil end
    local offset = cfg.offset or {}
    local expand = cfg.expand or {}
    local attachPoints = cfg.attachPoints or {}

    return quote
        var f : ui.FloatingConfig
        f.offset.x = [value_or(offset.x, value_or(cfg.offsetX, 0.0))]
        f.offset.y = [value_or(offset.y, value_or(cfg.offsetY, 0.0))]
        f.expand.width = [value_or(expand.width, value_or(cfg.expandWidth, 0.0))]
        f.expand.height = [value_or(expand.height, value_or(cfg.expandHeight, 0.0))]
        f.parentId = [value_or(cfg.parentId, 0)]
        f.zIndex = [value_or(cfg.zIndex, 0)]
        f.attachPoints.element = [value_or(attachPoints.element, value_or(cfg.elementAttach, ui.ATTACH_LEFT_TOP))]
        f.attachPoints.parent = [value_or(attachPoints.parent, value_or(cfg.parentAttach, ui.ATTACH_LEFT_TOP))]
        f.pointerCaptureMode = [value_or(cfg.pointerCaptureMode, ui.POINTER_CAPTURE)]
        f.attachTo = [value_or(cfg.attachTo, ui.ATTACH_NONE)]
        f.clipTo = [value_or(cfg.clipTo, ui.CLIP_NONE)]
    in
        f
    end
end

local function compileTextConfig(cfg)
    local textColor = cfg.textColor or cfg.color or {}
    local userData = cfg.userData

    if userData ~= nil then
        return quote
            var t : ui.TextConfig
            t.userData = [userData]
            t.textColor.r = [value_or(textColor.r, 0.0)]
            t.textColor.g = [value_or(textColor.g, 0.0)]
            t.textColor.b = [value_or(textColor.b, 0.0)]
            t.textColor.a = [value_or(textColor.a, 1.0)]
            t.fontId = [value_or(cfg.fontId, 0)]
            t.fontSize = [value_or(cfg.fontSize, 16)]
            t.letterSpacing = [value_or(cfg.letterSpacing, 0)]
            t.lineHeight = [value_or(cfg.lineHeight, 0)]
            t.wrapMode = [value_or(cfg.wrapMode, ui.TEXT_WRAP_WORDS)]
            t.textAlignment = [value_or(cfg.textAlignment, ui.TEXT_ALIGN_LEFT)]
        in
            t
        end
    end

    return quote
        var t : ui.TextConfig
        t.userData = nil
        t.textColor.r = [value_or(textColor.r, 0.0)]
        t.textColor.g = [value_or(textColor.g, 0.0)]
        t.textColor.b = [value_or(textColor.b, 0.0)]
        t.textColor.a = [value_or(textColor.a, 1.0)]
        t.fontId = [value_or(cfg.fontId, 0)]
        t.fontSize = [value_or(cfg.fontSize, 16)]
        t.letterSpacing = [value_or(cfg.letterSpacing, 0)]
        t.lineHeight = [value_or(cfg.lineHeight, 0)]
        t.wrapMode = [value_or(cfg.wrapMode, ui.TEXT_WRAP_WORDS)]
        t.textAlignment = [value_or(cfg.textAlignment, ui.TEXT_ALIGN_LEFT)]
    in
        t
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
        stmts:insert(quote ui.SetOpenElementLayoutConfig([compileLayoutConfig(node.layout)]) end)
    end
    
    if node.shared then
        stmts:insert(quote ui.AttachSharedConfig([compileSharedConfig(node.shared)]) end)
    end

    if node.border then
        stmts:insert(quote ui.AttachBorderConfig([compileBorderConfig(node.border)]) end)
    end

    if node.clip then
        stmts:insert(quote ui.AttachClipConfig([compileClipConfig(node.clip)]) end)
    end

    if node.aspect then
        stmts:insert(quote ui.AttachAspectRatioConfig([compileAspectConfig(node.aspect)]) end)
    end

    if node.image then
        stmts:insert(quote ui.AttachImageConfig([compileImageConfig(node.image)]) end)
    end

    if node.custom then
        stmts:insert(quote ui.AttachCustomConfig([compileCustomConfig(node.custom)]) end)
    end

    if node.floating then
        stmts:insert(quote ui.AttachFloatingConfig([compileFloatingConfig(node.floating)]) end)
    end
    
    if node.text then
        local textStr = node.text
        local textConfig = node.textConfig
        if type(textStr) ~= "string" then
            textStr = tostring(textStr)
        end
        
        if textConfig then
            stmts:insert(quote
                var txt_cfg = [compileTextConfig(textConfig)]
                var txt_cfg_ptr = ui.GetCurrentContext():storeTextConfig(txt_cfg)
                ui.OpenTextElementWithLength([textStr], [#textStr], txt_cfg_ptr)
            end)
        else
            stmts:insert(quote
                ui.OpenTextElementWithLength([textStr], [#textStr], nil)
            end)
        end
    end

    if node.children then
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
