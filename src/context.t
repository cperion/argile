local ui = require("src.arena")
local array_mod = require("src.array")
local string_mod = require("src.string")
local hash = require("src.hash")
local config = require("src.config")
local layout = require("src.layout")

local RenderCommandArray = array_mod.Array(config.RenderCommand)

local Int32Array = array_mod.Array(int32)
local LayoutElementArray = array_mod.Array(layout.LayoutElement)
local ElementConfigArray = array_mod.Array(config.ElementConfig)
local LayoutConfigArray = array_mod.Array(config.LayoutConfig)
local TextConfigArray = array_mod.Array(config.TextConfig)
local AspectRatioConfigArray = array_mod.Array(config.AspectRatioConfig)
local ImageConfigArray = array_mod.Array(config.ImageConfig)
local FloatingConfigArray = array_mod.Array(config.FloatingConfig)
local ClipConfigArray = array_mod.Array(config.ClipConfig)
local CustomConfigArray = array_mod.Array(config.CustomConfig)
local BorderConfigArray = array_mod.Array(config.BorderConfig)
local SharedConfigArray = array_mod.Array(config.SharedConfig)
local RenderCommandArray = array_mod.Array(config.RenderCommand)
local TextElementDataArray = array_mod.Array(layout.TextElementData)
local WrappedTextLineArray = array_mod.Array(layout.WrappedTextLine)
local StringArray = array_mod.Array(string_mod.String)
local LayoutElementTreeRootArray = array_mod.Array(layout.LayoutElementTreeRoot)
local LayoutElementTreeNodeArray = array_mod.Array(layout.LayoutElementTreeNode)
local ScrollContainerDataArray = array_mod.Array(layout.ScrollContainerDataInternal)

ui.MAXFLOAT = 3.40282346638528859812e+38

ui.Context = struct {
    maxElementCount : int32,
    generation : uint32,
    arenaResetOffset : uint64,
    internalArena : ui.Arena,
    layoutDimensions : config.Dimensions,
    pointerInfo : config.PointerData,
    dynamicElementIndex : uint32,
    layoutElements : LayoutElementArray,
    renderCommands : RenderCommandArray,
    openLayoutElementStack : Int32Array,
    layoutElementChildren : Int32Array,
    layoutElementChildrenBuffer : Int32Array,
    textElementData : TextElementDataArray,
    reusableElementIndexBuffer : Int32Array,
    layoutElementClipElementIds : Int32Array,
    layoutConfigs : LayoutConfigArray,
    elementConfigs : ElementConfigArray,
    textConfigs : TextConfigArray,
    aspectRatioConfigs : AspectRatioConfigArray,
    imageConfigs : ImageConfigArray,
    floatingConfigs : FloatingConfigArray,
    clipConfigs : ClipConfigArray,
    customConfigs : CustomConfigArray,
    borderConfigs : BorderConfigArray,
    sharedConfigs : SharedConfigArray,
    wrappedTextLines : WrappedTextLineArray,
    layoutElementTreeRoots : LayoutElementTreeRootArray,
    layoutElementTreeNodeArray1 : LayoutElementTreeNodeArray,
    layoutElementIdStrings : StringArray,
    scrollContainerDatas : ScrollContainerDataArray,
    maxElementsExceeded : bool
}

local ContextPtr = &ui.Context
ui.currentContextPtr = global(ContextPtr, nil)

terra ui.GetCurrentContext() : &ui.Context
    return ui.currentContextPtr
end

terra ui.SetCurrentContext(ctx: &ui.Context)
    ui.currentContextPtr = ctx
end

terra ui.Context:getOpenLayoutElement() : &layout.LayoutElement
    if self.openLayoutElementStack.length > 0 then
        var idx = self.openLayoutElementStack:getValue(self.openLayoutElementStack.length - 1)
        return self.layoutElements:get(idx)
    end
    return nil
end

terra ui.Context:getParentElementId() : uint32
    if self.openLayoutElementStack.length >= 2 then
        var idx = self.openLayoutElementStack:getValue(self.openLayoutElementStack.length - 2)
        var elem = self.layoutElements:get(idx)
        if elem ~= nil then
            return elem.id
        end
    end
    return 0
end

terra ui.Context:initialize(arena: &ui.Arena, maxElements: int32) : bool
    self.maxElementCount = maxElements
    self.internalArena = @arena
    self.arenaResetOffset = arena.nextAllocation
    self.generation = 0
    self.maxElementsExceeded = false
    self.layoutDimensions.width = 0
    self.layoutDimensions.height = 0
    self.dynamicElementIndex = 0
    
    if not self.layoutElements:allocate(maxElements, arena) then return false end
    if not self.renderCommands:allocate(maxElements, arena) then return false end
    if not self.openLayoutElementStack:allocate(maxElements, arena) then return false end
    if not self.layoutElementChildren:allocate(maxElements * 4, arena) then return false end
    if not self.layoutElementChildrenBuffer:allocate(maxElements * 4, arena) then return false end
    if not self.textElementData:allocate(maxElements, arena) then return false end
    if not self.reusableElementIndexBuffer:allocate(maxElements, arena) then return false end
    if not self.layoutElementClipElementIds:allocate(maxElements, arena) then return false end
    if not self.layoutConfigs:allocate(maxElements, arena) then return false end
    if not self.elementConfigs:allocate(maxElements * 8, arena) then return false end
    if not self.textConfigs:allocate(maxElements, arena) then return false end
    if not self.aspectRatioConfigs:allocate(maxElements, arena) then return false end
    if not self.imageConfigs:allocate(maxElements, arena) then return false end
    if not self.floatingConfigs:allocate(maxElements, arena) then return false end
    if not self.clipConfigs:allocate(maxElements, arena) then return false end
    if not self.customConfigs:allocate(maxElements, arena) then return false end
    if not self.borderConfigs:allocate(maxElements, arena) then return false end
    if not self.sharedConfigs:allocate(maxElements, arena) then return false end
    if not self.wrappedTextLines:allocate(maxElements * 8, arena) then return false end
    if not self.layoutElementTreeRoots:allocate(maxElements, arena) then return false end
    if not self.layoutElementTreeNodeArray1:allocate(maxElements, arena) then return false end
    if not self.layoutElementIdStrings:allocate(maxElements, arena) then return false end
    if not self.scrollContainerDatas:allocate(maxElements, arena) then return false end
    
    return true
end

terra ui.Context:resetEphemeral()
    self.internalArena.nextAllocation = self.arenaResetOffset
    self.generation = self.generation + 1
    self.dynamicElementIndex = 0
    self.maxElementsExceeded = false
    
    self.layoutElements:clear()
    self.renderCommands:clear()
    self.openLayoutElementStack:clear()
    self.layoutElementChildren:clear()
    self.layoutElementChildrenBuffer:clear()
    self.textElementData:clear()
    self.reusableElementIndexBuffer:clear()
    self.layoutElementTreeRoots:clear()
    self.layoutElementTreeNodeArray1:clear()
    self.wrappedTextLines:clear()
    self.scrollContainerDatas:clear()
    self.layoutElementIdStrings:clear()
    
    self.layoutConfigs:clear()
    self.elementConfigs:clear()
    self.textConfigs:clear()
    self.aspectRatioConfigs:clear()
    self.imageConfigs:clear()
    self.floatingConfigs:clear()
    self.clipConfigs:clear()
    self.customConfigs:clear()
    self.borderConfigs:clear()
    self.sharedConfigs:clear()
end

terra ui.Context:storeLayoutConfig(cfg: config.LayoutConfig) : &config.LayoutConfig
    if self.maxElementsExceeded then return nil end
    return self.layoutConfigs:add(cfg)
end

terra ui.Context:storeTextConfig(cfg: config.TextConfig) : &config.TextConfig
    if self.maxElementsExceeded then return nil end
    return self.textConfigs:add(cfg)
end

terra ui.Context:storeSharedConfig(cfg: config.SharedConfig) : &config.SharedConfig
    if self.maxElementsExceeded then return nil end
    return self.sharedConfigs:add(cfg)
end

terra ui.Context:storeFloatingConfig(cfg: config.FloatingConfig) : &config.FloatingConfig
    if self.maxElementsExceeded then return nil end
    return self.floatingConfigs:add(cfg)
end

terra ui.Context:storeClipConfig(cfg: config.ClipConfig) : &config.ClipConfig
    if self.maxElementsExceeded then return nil end
    return self.clipConfigs:add(cfg)
end

terra ui.Context:storeBorderConfig(cfg: config.BorderConfig) : &config.BorderConfig
    if self.maxElementsExceeded then return nil end
    return self.borderConfigs:add(cfg)
end

terra ui.Context:storeImageConfig(cfg: config.ImageConfig) : &config.ImageConfig
    if self.maxElementsExceeded then return nil end
    return self.imageConfigs:add(cfg)
end

terra ui.Context:storeCustomConfig(cfg: config.CustomConfig) : &config.CustomConfig
    if self.maxElementsExceeded then return nil end
    return self.customConfigs:add(cfg)
end

terra ui.Context:storeAspectRatioConfig(cfg: config.AspectRatioConfig) : &config.AspectRatioConfig
    if self.maxElementsExceeded then return nil end
    return self.aspectRatioConfigs:add(cfg)
end

terra ui.Context:attachElementConfig(cfg: config.ElementConfigUnion, cfgType: uint8) : &config.ElementConfig
    if self.maxElementsExceeded then return nil end
    var openElem = self:getOpenLayoutElement()
    if openElem == nil then return nil end
    if openElem.elementConfigs.length == 0 then
        openElem.elementConfigs.internalArray = &self.elementConfigs.internalArray[self.elementConfigs.length]
    end
    openElem.elementConfigs.length = openElem.elementConfigs.length + 1
    var elemCfg : config.ElementConfig
    elemCfg.configType = cfgType
    elemCfg.config = cfg
    return self.elementConfigs:add(elemCfg)
end

terra ui.Context:openElement()
    if self.layoutElements.length >= self.layoutElements.capacity - 1 or self.maxElementsExceeded then
        self.maxElementsExceeded = true
        return
    end
    
    var elem : layout.LayoutElement
    elem.id = 0
    elem.dimensions.width = 0
    elem.dimensions.height = 0
    elem.minDimensions.width = 0
    elem.minDimensions.height = 0
    elem.layoutConfig = nil
    elem.elementConfigs.length = 0
    elem.elementConfigs.internalArray = nil
    elem.childrenOrTextContent.children.elements = nil
    elem.childrenOrTextContent.children.length = 0
    elem.childrenOrTextContent.textElementData = nil
    elem.floatingChildrenCount = 0
    
    var added = self.layoutElements:add(elem)
    var idx = self.layoutElements.length - 1
    self.openLayoutElementStack:add(idx)
    
    var parentId : uint32 = 0
    if self.openLayoutElementStack.length >= 2 then
        var parentIdx = self.openLayoutElementStack:getValue(self.openLayoutElementStack.length - 2)
        var parentElem = self.layoutElements:get(parentIdx)
        if parentElem ~= nil then
            parentId = parentElem.id
        end
    end
    
    var elementId = hash.HashNumber(self.dynamicElementIndex, parentId)
    self.dynamicElementIndex = self.dynamicElementIndex + 1
    if added ~= nil then
        added.id = elementId.id
    end
    
    self.layoutElementClipElementIds:set(idx, 0)
end

terra ui.Context:openElementWithId(elementId: hash.ElementId)
    if self.layoutElements.length >= self.layoutElements.capacity - 1 or self.maxElementsExceeded then
        self.maxElementsExceeded = true
        return
    end
    
    var elem : layout.LayoutElement
    elem.id = elementId.id
    elem.dimensions.width = 0
    elem.dimensions.height = 0
    elem.minDimensions.width = 0
    elem.minDimensions.height = 0
    elem.layoutConfig = nil
    elem.elementConfigs.length = 0
    elem.elementConfigs.internalArray = nil
    elem.childrenOrTextContent.children.elements = nil
    elem.childrenOrTextContent.children.length = 0
    elem.childrenOrTextContent.textElementData = nil
    elem.floatingChildrenCount = 0
    
    self.layoutElements:add(elem)
    var idx = self.layoutElements.length - 1
    self.openLayoutElementStack:add(idx)
    self.layoutElementIdStrings:add(elementId.stringId)
    self.layoutElementClipElementIds:set(idx, 0)
end

terra max_f(a: float, b: float) : float
    if a > b then return a end
    return b
end

terra min_f(a: float, b: float) : float
    if a < b then return a end
    return b
end

terra max_i(a: int32, b: int32) : int32
    if a > b then return a end
    return b
end

terra ui.Context:closeElement()
    if self.maxElementsExceeded then return end
    if self.openLayoutElementStack.length == 0 then return end
    
    var openElem = self:getOpenLayoutElement()
    if openElem == nil then return end
    
    var layoutCfg = openElem.layoutConfig
    if layoutCfg == nil then
        var defaultLayout : config.LayoutConfig
        defaultLayout.sizing.width.type = config.SIZING_FIT
        defaultLayout.sizing.width.size.min = 0
        defaultLayout.sizing.width.size.max = ui.MAXFLOAT
        defaultLayout.sizing.width.percent = 0
        defaultLayout.sizing.height.type = config.SIZING_FIT
        defaultLayout.sizing.height.size.min = 0
        defaultLayout.sizing.height.size.max = ui.MAXFLOAT
        defaultLayout.sizing.height.percent = 0
        defaultLayout.padding.left = 0
        defaultLayout.padding.right = 0
        defaultLayout.padding.top = 0
        defaultLayout.padding.bottom = 0
        defaultLayout.childGap = 0
        defaultLayout.childAlignment.x = config.ALIGN_X_LEFT
        defaultLayout.childAlignment.y = config.ALIGN_Y_TOP
        defaultLayout.layoutDirection = config.LEFT_TO_RIGHT
        layoutCfg = self:storeLayoutConfig(defaultLayout)
        openElem.layoutConfig = layoutCfg
    end
    
    var leftRightPadding: float = [float](layoutCfg.padding.left + layoutCfg.padding.right)
    var topBottomPadding: float = [float](layoutCfg.padding.top + layoutCfg.padding.bottom)
    
    openElem.childrenOrTextContent.children.elements = 
        [&int32](&self.layoutElementChildren.internalArray[0]) + self.layoutElementChildren.length
    
    var childCount = openElem.childrenOrTextContent.children.length
    
    if layoutCfg.layoutDirection == config.LEFT_TO_RIGHT then
        openElem.dimensions.width = leftRightPadding
        openElem.dimensions.height = topBottomPadding
        openElem.minDimensions.width = leftRightPadding
        openElem.minDimensions.height = topBottomPadding
        
        for i = 0, childCount do
            var bufIdx = self.layoutElementChildrenBuffer.length - childCount + i
            var childIdx = self.layoutElementChildrenBuffer:getValue(bufIdx)
            var child = self.layoutElements:get(childIdx)
            if child ~= nil then
                openElem.dimensions.width = openElem.dimensions.width + child.dimensions.width
                openElem.dimensions.height = max_f(openElem.dimensions.height, child.dimensions.height + topBottomPadding)
                openElem.minDimensions.width = openElem.minDimensions.width + child.minDimensions.width
                openElem.minDimensions.height = max_f(openElem.minDimensions.height, child.minDimensions.height + topBottomPadding)
            end
            self.layoutElementChildren:add(childIdx)
        end
        
        var childGap: float = [float](max_i(childCount - 1, 0) * layoutCfg.childGap)
        openElem.dimensions.width = openElem.dimensions.width + childGap
        openElem.minDimensions.width = openElem.minDimensions.width + childGap
        
    else
        openElem.dimensions.height = topBottomPadding
        openElem.dimensions.width = leftRightPadding
        openElem.minDimensions.height = topBottomPadding
        openElem.minDimensions.width = leftRightPadding
        
        for i = 0, childCount do
            var bufIdx = self.layoutElementChildrenBuffer.length - childCount + i
            var childIdx = self.layoutElementChildrenBuffer:getValue(bufIdx)
            var child = self.layoutElements:get(childIdx)
            if child ~= nil then
                openElem.dimensions.height = openElem.dimensions.height + child.dimensions.height
                openElem.dimensions.width = max_f(openElem.dimensions.width, child.dimensions.width + leftRightPadding)
                openElem.minDimensions.height = openElem.minDimensions.height + child.minDimensions.height
                openElem.minDimensions.width = max_f(openElem.minDimensions.width, child.minDimensions.width + leftRightPadding)
            end
            self.layoutElementChildren:add(childIdx)
        end
        
        var childGap: float = [float](max_i(childCount - 1, 0) * layoutCfg.childGap)
        openElem.dimensions.height = openElem.dimensions.height + childGap
        openElem.minDimensions.height = openElem.minDimensions.height + childGap
    end
    
    self.layoutElementChildrenBuffer.length = self.layoutElementChildrenBuffer.length - childCount
    
    if layoutCfg.sizing.width.type ~= config.SIZING_PERCENT then
        if layoutCfg.sizing.width.size.max <= 0 then
            layoutCfg.sizing.width.size.max = ui.MAXFLOAT
        end
        openElem.dimensions.width = min_f(max_f(openElem.dimensions.width, layoutCfg.sizing.width.size.min), layoutCfg.sizing.width.size.max)
        openElem.minDimensions.width = min_f(max_f(openElem.minDimensions.width, layoutCfg.sizing.width.size.min), layoutCfg.sizing.width.size.max)
    else
        openElem.dimensions.width = 0
    end
    
    if layoutCfg.sizing.height.type ~= config.SIZING_PERCENT then
        if layoutCfg.sizing.height.size.max <= 0 then
            layoutCfg.sizing.height.size.max = ui.MAXFLOAT
        end
        openElem.dimensions.height = min_f(max_f(openElem.dimensions.height, layoutCfg.sizing.height.size.min), layoutCfg.sizing.height.size.max)
        openElem.minDimensions.height = min_f(max_f(openElem.minDimensions.height, layoutCfg.sizing.height.size.min), layoutCfg.sizing.height.size.max)
    else
        openElem.dimensions.height = 0
    end
    
    var closingIdx = self.openLayoutElementStack:getValue(self.openLayoutElementStack.length - 1)
    self.openLayoutElementStack.length = self.openLayoutElementStack.length - 1
    
    if self.openLayoutElementStack.length > 0 then
        var parent = self:getOpenLayoutElement()
        if parent ~= nil then
            parent.childrenOrTextContent.children.length = parent.childrenOrTextContent.children.length + 1
            self.layoutElementChildrenBuffer:add(closingIdx)
        end
    end
end

terra ui.Context:beginLayout(width: float, height: float)
    self:resetEphemeral()
    self.layoutDimensions.width = width
    self.layoutDimensions.height = height
    
    var rootId = hash.HashString(string_mod.String { isStaticallyAllocated = true, length = 19, chars = "Clay__RootContainer" }, 0)
    self:openElementWithId(rootId)
    
    var rootLayout : config.LayoutConfig
    rootLayout.sizing.width.type = config.SIZING_FIXED
    rootLayout.sizing.width.size.min = width
    rootLayout.sizing.width.size.max = width
    rootLayout.sizing.height.type = config.SIZING_FIXED
    rootLayout.sizing.height.size.min = height
    rootLayout.sizing.height.size.max = height
    rootLayout.padding.left = 0
    rootLayout.padding.right = 0
    rootLayout.padding.top = 0
    rootLayout.padding.bottom = 0
    rootLayout.childGap = 0
    rootLayout.childAlignment.x = config.ALIGN_X_LEFT
    rootLayout.childAlignment.y = config.ALIGN_Y_TOP
    rootLayout.layoutDirection = config.TOP_TO_BOTTOM
    
    var openElem = self:getOpenLayoutElement()
    if openElem ~= nil then
        openElem.layoutConfig = self:storeLayoutConfig(rootLayout)
        openElem.elementConfigs.internalArray = &self.elementConfigs.internalArray[0]
    end
    
    var treeRoot : layout.LayoutElementTreeRoot
    treeRoot.layoutElementIndex = 0
    treeRoot.parentId = 0
    treeRoot.clipElementId = 0
    treeRoot.zIndex = 0
    treeRoot.pointerOffset.x = 0
    treeRoot.pointerOffset.y = 0
    self.layoutElementTreeRoots:add(treeRoot)
end

terra ui.BeginLayout(width: float, height: float)
    var ctx = ui.GetCurrentContext()
    if ctx ~= nil then
        ctx:beginLayout(width, height)
    end
end

terra ui.OpenElement()
    var ctx = ui.GetCurrentContext()
    if ctx ~= nil then
        ctx:openElement()
    end
end

terra ui.OpenElementWithId(elementId: hash.ElementId)
    var ctx = ui.GetCurrentContext()
    if ctx ~= nil then
        ctx:openElementWithId(elementId)
    end
end

terra ui.CloseElement()
    var ctx = ui.GetCurrentContext()
    if ctx ~= nil then
        ctx:closeElement()
    end
end

ui.EPSILON = 0.01

terra ui.FloatEqual(a: float, b: float) : bool
    var diff = a - b
    return diff < ui.EPSILON and diff > -ui.EPSILON
end

terra ui.clamp(val: float, minVal: float, maxVal: float) : float
    if val < minVal then return minVal end
    if val > maxVal then return maxVal end
    return val
end

terra ui.ElementHasConfig(elem: &layout.LayoutElement, cfgType: uint8) : bool
    if elem == nil then return false end
    for i = 0, elem.elementConfigs.length do
        if elem.elementConfigs.internalArray ~= nil then
            var cfg = &elem.elementConfigs.internalArray[i]
            if cfg.configType == cfgType then
                return true
            end
        end
    end
    return false
end

terra ui.FindElementConfigWithType(elem: &layout.LayoutElement, cfgType: uint8) : &config.ElementConfig
    if elem == nil then return nil end
    for i = 0, elem.elementConfigs.length do
        if elem.elementConfigs.internalArray ~= nil then
            var cfg = &elem.elementConfigs.internalArray[i]
            if cfg.configType == cfgType then
                return cfg
            end
        end
    end
    return nil
end

terra ui.ElementIsOffscreen(ctx: &ui.Context, box: &config.BoundingBox) : bool
    return (box.x > ctx.layoutDimensions.width) or
           (box.y > ctx.layoutDimensions.height) or
           (box.x + box.width < 0) or
           (box.y + box.height < 0)
end

terra ui.Context:sizeContainersAlongAxis(xAxis: bool)
    var bfsBuffer: Int32Array = self.layoutElementChildrenBuffer
    var resizableContainerBuffer: Int32Array = self.openLayoutElementStack
    
    var rootIndex: int32 = 0
    while rootIndex < self.layoutElementTreeRoots.length do
        bfsBuffer.length = 0
        var root = self.layoutElementTreeRoots:get(rootIndex)
        
        if root ~= nil then
            var rootElement = self.layoutElements:get(root.layoutElementIndex)
            
            if rootElement ~= nil then
                bfsBuffer:add(root.layoutElementIndex)
                
                if ui.ElementHasConfig(rootElement, config.CONFIG_FLOATING) then
                    var floatCfgResult = ui.FindElementConfigWithType(rootElement, config.CONFIG_FLOATING)
                    if floatCfgResult ~= nil then
                        var floatCfg = floatCfgResult.config.floatingConfig
                        if floatCfg ~= nil and rootElement.layoutConfig ~= nil then
                            if rootElement.layoutConfig.sizing.width.type == config.SIZING_GROW then
                                rootElement.dimensions.width = self.layoutDimensions.width
                            elseif rootElement.layoutConfig.sizing.width.type == config.SIZING_PERCENT then
                                rootElement.dimensions.width = self.layoutDimensions.width * rootElement.layoutConfig.sizing.width.percent
                            end
                            if rootElement.layoutConfig.sizing.height.type == config.SIZING_GROW then
                                rootElement.dimensions.height = self.layoutDimensions.height
                            elseif rootElement.layoutConfig.sizing.height.type == config.SIZING_PERCENT then
                                rootElement.dimensions.height = self.layoutDimensions.height * rootElement.layoutConfig.sizing.height.percent
                            end
                        end
                    end
                end
                
                if rootElement.layoutConfig ~= nil then
                    if rootElement.layoutConfig.sizing.width.type ~= config.SIZING_PERCENT then
                        rootElement.dimensions.width = ui.clamp(rootElement.dimensions.width, 
                            rootElement.layoutConfig.sizing.width.size.min, 
                            rootElement.layoutConfig.sizing.width.size.max)
                    end
                    if rootElement.layoutConfig.sizing.height.type ~= config.SIZING_PERCENT then
                        rootElement.dimensions.height = ui.clamp(rootElement.dimensions.height, 
                            rootElement.layoutConfig.sizing.height.size.min, 
                            rootElement.layoutConfig.sizing.height.size.max)
                    end
                end
                
                var bfsIdx: int32 = 0
                while bfsIdx < bfsBuffer.length do
                    var parentIndex = bfsBuffer:getValue(bfsIdx)
                    var parent = self.layoutElements:get(parentIndex)
                    
                    if parent ~= nil and parent.layoutConfig ~= nil then
                        var parentStyleConfig = parent.layoutConfig
                        var growContainerCount: int32 = 0
                        var parentSize: float
                        var parentPadding: float
                        
                        if xAxis then
                            parentSize = parent.dimensions.width
                            parentPadding = [float](parent.layoutConfig.padding.left + parent.layoutConfig.padding.right)
                        else
                            parentSize = parent.dimensions.height
                            parentPadding = [float](parent.layoutConfig.padding.top + parent.layoutConfig.padding.bottom)
                        end
                        
                        var innerContentSize: float = 0.0
                        var totalPaddingAndChildGaps: float = parentPadding
                        var sizingAlongAxis: bool = (xAxis and parentStyleConfig.layoutDirection == config.LEFT_TO_RIGHT) or 
                                                     (not xAxis and parentStyleConfig.layoutDirection == config.TOP_TO_BOTTOM)
                        
                        resizableContainerBuffer.length = 0
                        var parentChildGap: float = [float](parentStyleConfig.childGap)
                        
                        var childCount = parent.childrenOrTextContent.children.length
                        var childrenPtr = parent.childrenOrTextContent.children.elements
                        
                        var childOffset: int32 = 0
                        while childOffset < childCount do
                            var childElementIndex = childrenPtr[childOffset]
                            var childElement = self.layoutElements:get(childElementIndex)
                            
                            if childElement ~= nil and childElement.layoutConfig ~= nil then
                                var childSizing: config.SizingAxis
                                var childSize: float
                                
                                if xAxis then
                                    childSizing = childElement.layoutConfig.sizing.width
                                    childSize = childElement.dimensions.width
                                else
                                    childSizing = childElement.layoutConfig.sizing.height
                                    childSize = childElement.dimensions.height
                                end
                                
                                if not ui.ElementHasConfig(childElement, config.CONFIG_TEXT) and 
                                   childElement.childrenOrTextContent.children.length > 0 then
                                    bfsBuffer:add(childElementIndex)
                                end
                                
                                var isResizable = childSizing.type ~= config.SIZING_PERCENT and
                                                  childSizing.type ~= config.SIZING_FIXED
                                
                                if isResizable then
                                    if ui.ElementHasConfig(childElement, config.CONFIG_TEXT) then
                                        var textCfgResult = ui.FindElementConfigWithType(childElement, config.CONFIG_TEXT)
                                        if textCfgResult ~= nil and textCfgResult.config.textConfig ~= nil then
                                            if textCfgResult.config.textConfig.wrapMode ~= config.TEXT_WRAP_WORDS then
                                                isResizable = false
                                            end
                                        end
                                    end
                                end
                                
                                if isResizable then
                                    resizableContainerBuffer:add(childElementIndex)
                                end
                                
                                if sizingAlongAxis then
                                    if childSizing.type ~= config.SIZING_PERCENT then
                                        innerContentSize = innerContentSize + childSize
                                    end
                                    if childSizing.type == config.SIZING_GROW then
                                        growContainerCount = growContainerCount + 1
                                    end
                                    if childOffset > 0 then
                                        innerContentSize = innerContentSize + parentChildGap
                                        totalPaddingAndChildGaps = totalPaddingAndChildGaps + parentChildGap
                                    end
                                else
                                    if childSize > innerContentSize then
                                        innerContentSize = childSize
                                    end
                                end
                            end
                            childOffset = childOffset + 1
                        end
                        
                        childOffset = 0
                        while childOffset < childCount do
                            var childElementIndex = childrenPtr[childOffset]
                            var childElement = self.layoutElements:get(childElementIndex)
                            
                            if childElement ~= nil and childElement.layoutConfig ~= nil then
                                var childSizing: config.SizingAxis
                                
                                if xAxis then
                                    childSizing = childElement.layoutConfig.sizing.width
                                else
                                    childSizing = childElement.layoutConfig.sizing.height
                                end
                                
                                if childSizing.type == config.SIZING_PERCENT then
                                    var childSizePtr: &float
                                    
                                    if xAxis then
                                        childSizePtr = &childElement.dimensions.width
                                    else
                                        childSizePtr = &childElement.dimensions.height
                                    end
                                    
                                    @childSizePtr = (parentSize - totalPaddingAndChildGaps) * childSizing.percent
                                    if sizingAlongAxis then
                                        innerContentSize = innerContentSize + @childSizePtr
                                    end
                                end
                            end
                            childOffset = childOffset + 1
                        end
                        
                        if sizingAlongAxis then
                            var sizeToDistribute: float = parentSize - parentPadding - innerContentSize
                            
                            if sizeToDistribute < 0 then
                                var shouldSkip = false
                                var clipCfgResult = ui.FindElementConfigWithType(parent, config.CONFIG_CLIP)
                                if clipCfgResult ~= nil then
                                    var clipCfg = clipCfgResult.config.clipConfig
                                    if clipCfg ~= nil then
                                        if (xAxis and clipCfg.horizontal) or (not xAxis and clipCfg.vertical) then
                                            shouldSkip = true
                                        end
                                    end
                                end
                                
                                if not shouldSkip then
                                    while sizeToDistribute < -ui.EPSILON and resizableContainerBuffer.length > 0 do
                                        var largest: float = 0.0
                                        var secondLargest: float = 0.0
                                        var widthToAdd: float = sizeToDistribute
                                        
                                        var childIdx: int32 = 0
                                        while childIdx < resizableContainerBuffer.length do
                                            var child = self.layoutElements:get(resizableContainerBuffer:getValue(childIdx))
                                            if child ~= nil then
                                                var cSize: float
                                                
                                                if xAxis then
                                                    cSize = child.dimensions.width
                                                else
                                                    cSize = child.dimensions.height
                                                end
                                                
                                                if not ui.FloatEqual(cSize, largest) then
                                                    if cSize > largest then
                                                        secondLargest = largest
                                                        largest = cSize
                                                    end
                                                    if cSize < largest then
                                                        if cSize > secondLargest then
                                                            secondLargest = cSize
                                                        end
                                                        widthToAdd = secondLargest - largest
                                                    end
                                                end
                                            end
                                            childIdx = childIdx + 1
                                        end
                                        
                                        var fallbackWidth: float = sizeToDistribute / [float](resizableContainerBuffer.length)
                                        if widthToAdd < fallbackWidth then
                                            widthToAdd = fallbackWidth
                                        end
                                        
                                        childIdx = 0
                                        while childIdx < resizableContainerBuffer.length do
                                            var child = self.layoutElements:get(resizableContainerBuffer:getValue(childIdx))
                                            if child ~= nil then
                                                var childSizePtr: &float
                                                var minSize: float
                                                
                                                if xAxis then
                                                    childSizePtr = &child.dimensions.width
                                                    minSize = child.minDimensions.width
                                                else
                                                    childSizePtr = &child.dimensions.height
                                                    minSize = child.minDimensions.height
                                                end
                                                var previousWidth: float = @childSizePtr
                                                
                                                if ui.FloatEqual(@childSizePtr, largest) then
                                                    @childSizePtr = @childSizePtr + widthToAdd
                                                    if @childSizePtr <= minSize then
                                                        @childSizePtr = minSize
                                                        resizableContainerBuffer:removeSwapback(childIdx)
                                                        childIdx = childIdx - 1
                                                    end
                                                    sizeToDistribute = sizeToDistribute - (@childSizePtr - previousWidth)
                                                end
                                            end
                                            childIdx = childIdx + 1
                                        end
                                    end
                                end
                            elseif sizeToDistribute > 0 and growContainerCount > 0 then
                                var growOnlyBuffer: Int32Array = self.reusableElementIndexBuffer
                                growOnlyBuffer.length = 0
                                
                                var childIdx: int32 = 0
                                while childIdx < resizableContainerBuffer.length do
                                    var child = self.layoutElements:get(resizableContainerBuffer:getValue(childIdx))
                                    if child ~= nil and child.layoutConfig ~= nil then
                                        var childSizingType: uint8
                                        
                                        if xAxis then
                                            childSizingType = child.layoutConfig.sizing.width.type
                                        else
                                            childSizingType = child.layoutConfig.sizing.height.type
                                        end
                                        
                                        if childSizingType == config.SIZING_GROW then
                                            growOnlyBuffer:add(resizableContainerBuffer:getValue(childIdx))
                                        end
                                    end
                                    childIdx = childIdx + 1
                                end
                                
                                while sizeToDistribute > ui.EPSILON and growOnlyBuffer.length > 0 do
                                    var smallest: float = ui.MAXFLOAT
                                    var secondSmallest: float = ui.MAXFLOAT
                                    var widthToAdd: float = sizeToDistribute
                                    
                                    childIdx = 0
                                    while childIdx < growOnlyBuffer.length do
                                        var child = self.layoutElements:get(growOnlyBuffer:getValue(childIdx))
                                        if child ~= nil then
                                            var cSize: float
                                            
                                            if xAxis then
                                                cSize = child.dimensions.width
                                            else
                                                cSize = child.dimensions.height
                                            end
                                            
                                            if not ui.FloatEqual(cSize, smallest) then
                                                if cSize < smallest then
                                                    secondSmallest = smallest
                                                    smallest = cSize
                                                end
                                                if cSize > smallest then
                                                    if cSize < secondSmallest then
                                                        secondSmallest = cSize
                                                    end
                                                    widthToAdd = secondSmallest - smallest
                                                end
                                            end
                                        end
                                        childIdx = childIdx + 1
                                    end
                                    
                                    var limitWidth: float = sizeToDistribute / [float](growOnlyBuffer.length)
                                    if widthToAdd > limitWidth then
                                        widthToAdd = limitWidth
                                    end
                                    
                                    childIdx = 0
                                    while childIdx < growOnlyBuffer.length do
                                        var child = self.layoutElements:get(growOnlyBuffer:getValue(childIdx))
                                        if child ~= nil and child.layoutConfig ~= nil then
                                            var childSizePtr: &float
                                            var maxSize: float
                                            
                                            if xAxis then
                                                childSizePtr = &child.dimensions.width
                                                maxSize = child.layoutConfig.sizing.width.size.max
                                            else
                                                childSizePtr = &child.dimensions.height
                                                maxSize = child.layoutConfig.sizing.height.size.max
                                            end
                                            var previousWidth: float = @childSizePtr
                                            
                                            if ui.FloatEqual(@childSizePtr, smallest) then
                                                @childSizePtr = @childSizePtr + widthToAdd
                                                if @childSizePtr >= maxSize then
                                                    @childSizePtr = maxSize
                                                    growOnlyBuffer:removeSwapback(childIdx)
                                                    childIdx = childIdx - 1
                                                end
                                                sizeToDistribute = sizeToDistribute - (@childSizePtr - previousWidth)
                                            end
                                        end
                                        childIdx = childIdx + 1
                                    end
                                end
                            end
                        else
                            var childOffset2: int32 = 0
                            while childOffset2 < resizableContainerBuffer.length do
                                var childElement = self.layoutElements:get(resizableContainerBuffer:getValue(childOffset2))
                                if childElement ~= nil and childElement.layoutConfig ~= nil then
                                    var childSizing: config.SizingAxis
                                    var minSize: float
                                    var childSizePtr: &float
                                    
                                    if xAxis then
                                        childSizing = childElement.layoutConfig.sizing.width
                                        minSize = childElement.minDimensions.width
                                        childSizePtr = &childElement.dimensions.width
                                    else
                                        childSizing = childElement.layoutConfig.sizing.height
                                        minSize = childElement.minDimensions.height
                                        childSizePtr = &childElement.dimensions.height
                                    end
                                    
                                    var maxSize: float = parentSize - parentPadding
                                    
                                    var clipCfgResult = ui.FindElementConfigWithType(parent, config.CONFIG_CLIP)
                                    if clipCfgResult ~= nil then
                                        var clipCfg = clipCfgResult.config.clipConfig
                                        if clipCfg ~= nil then
                                            if (xAxis and clipCfg.horizontal) or (not xAxis and clipCfg.vertical) then
                                                if innerContentSize > maxSize then
                                                    maxSize = innerContentSize
                                                end
                                            end
                                        end
                                    end
                                    
                                    if childSizing.type == config.SIZING_GROW then
                                        if maxSize < childSizing.size.max then
                                            @childSizePtr = maxSize
                                        else
                                            @childSizePtr = childSizing.size.max
                                        end
                                    end
                                    
                                    if @childSizePtr > maxSize then
                                        @childSizePtr = maxSize
                                    end
                                    if @childSizePtr < minSize then
                                        @childSizePtr = minSize
                                    end
                                end
                                childOffset2 = childOffset2 + 1
                            end
                        end
                    end
                    bfsIdx = bfsIdx + 1
                end
            end
        end
        rootIndex = rootIndex + 1
    end
end

terra ui.Context:calculateFinalLayout()
    self:sizeContainersAlongAxis(true)
    self:sizeContainersAlongAxis(false)
    
    self.renderCommands.length = 0
    
    var dfsBuffer = self.layoutElementTreeNodeArray1
    dfsBuffer.length = 0
    
    var rootIndex: int32 = 0
    while rootIndex < self.layoutElementTreeRoots.length do
        var root = self.layoutElementTreeRoots:get(rootIndex)
        
        if root ~= nil then
            var rootElement = self.layoutElements:get(root.layoutElementIndex)
            
            if rootElement ~= nil and rootElement.layoutConfig ~= nil then
                dfsBuffer.length = 0
                
                var rootNode: layout.LayoutElementTreeNode
                rootNode.layoutElement = rootElement
                rootNode.position.x = 0
                rootNode.position.y = 0
                rootNode.nextChildOffset.x = [float](rootElement.layoutConfig.padding.left)
                rootNode.nextChildOffset.y = [float](rootElement.layoutConfig.padding.top)
                dfsBuffer:add(rootNode)
                
                while dfsBuffer.length > 0 do
                    var currentIdx = dfsBuffer.length - 1
                    var currentElementTreeNode = dfsBuffer:get(currentIdx)
                    
                    if currentElementTreeNode == nil then
                        dfsBuffer.length = dfsBuffer.length - 1
                    else
                        var currentElement = currentElementTreeNode.layoutElement
                        
                        if currentElement == nil or currentElement.layoutConfig == nil then
                            dfsBuffer.length = dfsBuffer.length - 1
                        else
                            var layoutCfg = currentElement.layoutConfig
                            
                            if not ui.ElementHasConfig(currentElement, config.CONFIG_TEXT) then
                                var childCount = currentElement.childrenOrTextContent.children.length
                                if childCount > 0 then
                                    var contentSize: config.Dimensions
                                    contentSize.width = 0
                                    contentSize.height = 0
                                    
                                    if layoutCfg.layoutDirection == config.LEFT_TO_RIGHT then
                                        var i: int32 = 0
                                        while i < childCount do
                                            var childIdx = currentElement.childrenOrTextContent.children.elements[i]
                                            var childElement = self.layoutElements:get(childIdx)
                                            if childElement ~= nil then
                                                contentSize.width = contentSize.width + childElement.dimensions.width
                                                if childElement.dimensions.height > contentSize.height then
                                                    contentSize.height = childElement.dimensions.height
                                                end
                                            end
                                            i = i + 1
                                        end
                                        contentSize.width = contentSize.width + [float]([int32](childCount - 1) * layoutCfg.childGap)
                                    else
                                        var i: int32 = 0
                                        while i < childCount do
                                            var childIdx = currentElement.childrenOrTextContent.children.elements[i]
                                            var childElement = self.layoutElements:get(childIdx)
                                            if childElement ~= nil then
                                                if childElement.dimensions.width > contentSize.width then
                                                    contentSize.width = childElement.dimensions.width
                                                end
                                                contentSize.height = contentSize.height + childElement.dimensions.height
                                            end
                                            i = i + 1
                                        end
                                        contentSize.height = contentSize.height + [float]([int32](childCount - 1) * layoutCfg.childGap)
                                    end
                                    
                                    var paddingH: float = [float](layoutCfg.padding.left + layoutCfg.padding.right)
                                    var paddingV: float = [float](layoutCfg.padding.top + layoutCfg.padding.bottom)
                                    
                                    if layoutCfg.layoutDirection == config.LEFT_TO_RIGHT then
                                        var extraSpace: float = currentElement.dimensions.width - paddingH - contentSize.width
                                        if extraSpace < 0 then extraSpace = 0 end
                                        if layoutCfg.childAlignment.x == config.ALIGN_X_CENTER then
                                            currentElementTreeNode.nextChildOffset.x = currentElementTreeNode.nextChildOffset.x + extraSpace / 2.0
                                        elseif layoutCfg.childAlignment.x == config.ALIGN_X_RIGHT then
                                            currentElementTreeNode.nextChildOffset.x = currentElementTreeNode.nextChildOffset.x + extraSpace
                                        end
                                    else
                                        var extraSpace: float = currentElement.dimensions.height - paddingV - contentSize.height
                                        if extraSpace < 0 then extraSpace = 0 end
                                        if layoutCfg.childAlignment.y == config.ALIGN_Y_CENTER then
                                            currentElementTreeNode.nextChildOffset.y = currentElementTreeNode.nextChildOffset.y + extraSpace / 2.0
                                        elseif layoutCfg.childAlignment.y == config.ALIGN_Y_BOTTOM then
                                            currentElementTreeNode.nextChildOffset.y = currentElementTreeNode.nextChildOffset.y + extraSpace
                                        end
                                    end
                                end
                            end
                            
                            var addedChildren = false
                            if not ui.ElementHasConfig(currentElement, config.CONFIG_TEXT) then
                                var childCount = currentElement.childrenOrTextContent.children.length
                                if childCount > 0 then
                                    dfsBuffer.length = dfsBuffer.length + childCount
                                    
                                    var i: int32 = 0
                                    while i < childCount do
                                        var childIdx = currentElement.childrenOrTextContent.children.elements[i]
                                        var childElement = self.layoutElements:get(childIdx)
                                        if childElement ~= nil and childElement.layoutConfig ~= nil then
                                            var childNode: layout.LayoutElementTreeNode
                                            childNode.layoutElement = childElement
                                            
                                            var scrollOffsetX: float = 0
                                            var scrollOffsetY: float = 0
                                            
                                            if layoutCfg.layoutDirection == config.LEFT_TO_RIGHT then
                                                var whiteSpaceAroundChild: float = currentElement.dimensions.height - 
                                                    [float](layoutCfg.padding.top + layoutCfg.padding.bottom) - 
                                                    childElement.dimensions.height
                                                
                                                childNode.nextChildOffset.y = [float](childElement.layoutConfig.padding.top)
                                                
                                                if layoutCfg.childAlignment.y == config.ALIGN_Y_CENTER then
                                                    childNode.nextChildOffset.y = childNode.nextChildOffset.y + whiteSpaceAroundChild / 2.0
                                                elseif layoutCfg.childAlignment.y == config.ALIGN_Y_BOTTOM then
                                                    childNode.nextChildOffset.y = childNode.nextChildOffset.y + whiteSpaceAroundChild
                                                end
                                            else
                                                var whiteSpaceAroundChild: float = currentElement.dimensions.width - 
                                                    [float](layoutCfg.padding.left + layoutCfg.padding.right) - 
                                                    childElement.dimensions.width
                                                
                                                childNode.nextChildOffset.x = [float](childElement.layoutConfig.padding.left)
                                                
                                                if layoutCfg.childAlignment.x == config.ALIGN_X_CENTER then
                                                    childNode.nextChildOffset.x = childNode.nextChildOffset.x + whiteSpaceAroundChild / 2.0
                                                elseif layoutCfg.childAlignment.x == config.ALIGN_X_RIGHT then
                                                    childNode.nextChildOffset.x = childNode.nextChildOffset.x + whiteSpaceAroundChild
                                                end
                                            end
                                            
                                            childNode.position.x = currentElementTreeNode.position.x + 
                                                currentElementTreeNode.nextChildOffset.x + scrollOffsetX
                                            childNode.position.y = currentElementTreeNode.position.y + 
                                                currentElementTreeNode.nextChildOffset.y + scrollOffsetY
                                            
                                            var newNodeIndex = dfsBuffer.length - 1 - i
                                            dfsBuffer:set(newNodeIndex, childNode)
                                            
                                            if layoutCfg.layoutDirection == config.LEFT_TO_RIGHT then
                                                currentElementTreeNode.nextChildOffset.x = currentElementTreeNode.nextChildOffset.x + 
                                                    childElement.dimensions.width + [float](layoutCfg.childGap)
                                            else
                                                currentElementTreeNode.nextChildOffset.y = currentElementTreeNode.nextChildOffset.y + 
                                                    childElement.dimensions.height + [float](layoutCfg.childGap)
                                            end
                                        end
                                        i = i + 1
                                    end
                                    addedChildren = true
                                end
                            end
                            
                            if addedChildren then
                                -- Remove the current parent node after pushing children.
                                -- Otherwise the same node is revisited forever.
                                var topNode = dfsBuffer:get(dfsBuffer.length - 1)
                                if topNode ~= nil then
                                    dfsBuffer:set(currentIdx, @topNode)
                                end
                                dfsBuffer.length = dfsBuffer.length - 1
                            end
                            
                            if not addedChildren then
                                var boundingBox: config.BoundingBox
                                boundingBox.x = currentElementTreeNode.position.x
                                boundingBox.y = currentElementTreeNode.position.y
                                boundingBox.width = currentElement.dimensions.width
                                boundingBox.height = currentElement.dimensions.height
                                
                                if not ui.ElementIsOffscreen(self, &boundingBox) then
                                    var sharedCfgResult = ui.FindElementConfigWithType(currentElement, config.CONFIG_SHARED)
                                    var emitRectangle = false
                                    
                                    if sharedCfgResult ~= nil then
                                        var sharedCfg = sharedCfgResult.config.sharedConfig
                                        if sharedCfg ~= nil and sharedCfg.backgroundColor.a > 0 then
                                            emitRectangle = true
                                        end
                                    end
                                    
                                    if emitRectangle then
                                        var cmd: config.RenderCommand
                                        cmd.boundingBox = boundingBox
                                        cmd.id = currentElement.id
                                        cmd.commandType = config.RENDER_RECTANGLE
                                        
                                        if sharedCfgResult ~= nil and sharedCfgResult.config.sharedConfig ~= nil then
                                            cmd.renderData.rectangle.backgroundColor = sharedCfgResult.config.sharedConfig.backgroundColor
                                            cmd.renderData.rectangle.cornerRadius = sharedCfgResult.config.sharedConfig.cornerRadius
                                        end
                                        
                                        if self.renderCommands.length < self.renderCommands.capacity then
                                            self.renderCommands:add(cmd)
                                        end
                                    end
                                end
                                
                                dfsBuffer.length = dfsBuffer.length - 1
                            end
                        end
                    end
                end
            end
        end
        rootIndex = rootIndex + 1
    end
end

terra ui.Context:endLayout()
    self:closeElement()
    self:calculateFinalLayout()
    return &self.renderCommands
end

terra ui.EndLayout() : &RenderCommandArray
    var ctx = ui.GetCurrentContext()
    if ctx ~= nil then
        return ctx:endLayout()
    end
    return nil
end

return ui
