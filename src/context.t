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

local MeasureTextFnType = { string_mod.StringSlice, &config.TextConfig, &opaque } -> config.Dimensions
local QueryScrollOffsetFnType = { uint32, &opaque } -> config.Vector2
ui.measureTextFunction = global(MeasureTextFnType, nil)
ui.measureTextUserData = global(&opaque, nil)
ui.queryScrollOffsetFunction = global(QueryScrollOffsetFnType, nil)
ui.queryScrollOffsetUserData = global(&opaque, nil)

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
    self.layoutElementIdStrings:clear()

    var i: int32 = 0
    while i < self.scrollContainerDatas.length do
        var scrollData = self.scrollContainerDatas:get(i)
        if scrollData ~= nil then
            scrollData.openThisFrame = false
        end
        i = i + 1
    end
    
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
    
    var floatingCfgResult: &config.ElementConfig = nil
    var cfgSearchIdx: int32 = 0
    while cfgSearchIdx < openElem.elementConfigs.length do
        if openElem.elementConfigs.internalArray ~= nil then
            var cfg = &openElem.elementConfigs.internalArray[cfgSearchIdx]
            if cfg.configType == config.CONFIG_FLOATING then
                floatingCfgResult = cfg
                break
            end
        end
        cfgSearchIdx = cfgSearchIdx + 1
    end
    var isFloating = false
    var floatingParentId: uint32 = 0
    var floatingZIndex: int16 = 0
    var floatingClipElementId: uint32 = 0
    if floatingCfgResult ~= nil and floatingCfgResult.config.floatingConfig ~= nil then
        var floatingCfg = floatingCfgResult.config.floatingConfig
        if floatingCfg.attachTo ~= config.ATTACH_NONE then
            isFloating = true
            floatingParentId = floatingCfg.parentId
            floatingZIndex = floatingCfg.zIndex
            if floatingCfg.clipTo == config.CLIP_ATTACHED_PARENT then
                floatingClipElementId = [uint32](self.layoutElementClipElementIds:getValue(self.layoutElements.length - 1))
            end
        end
    end

    var closingIdx = self.openLayoutElementStack:getValue(self.openLayoutElementStack.length - 1)
    self.openLayoutElementStack.length = self.openLayoutElementStack.length - 1
    
    if self.openLayoutElementStack.length > 0 then
        var parent = self:getOpenLayoutElement()
        if parent ~= nil then
            if isFloating then
                parent.floatingChildrenCount = parent.floatingChildrenCount + 1
                if floatingParentId == 0 then
                    floatingParentId = parent.id
                end
            else
                parent.childrenOrTextContent.children.length = parent.childrenOrTextContent.children.length + 1
                self.layoutElementChildrenBuffer:add(closingIdx)
            end
        end
    end

    if isFloating then
        var treeRoot: layout.LayoutElementTreeRoot
        treeRoot.layoutElementIndex = closingIdx
        treeRoot.parentId = floatingParentId
        treeRoot.clipElementId = floatingClipElementId
        treeRoot.zIndex = floatingZIndex
        treeRoot.pointerOffset.x = 0
        treeRoot.pointerOffset.y = 0
        self.layoutElementTreeRoots:add(treeRoot)
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

terra ui.Context:openTextElement(text: config.String, textConfig: &config.TextConfig)
    if self.layoutElements.length >= self.layoutElements.capacity - 1 or self.maxElementsExceeded then
        self.maxElementsExceeded = true
        return
    end
    
    var parentElement = self:getOpenLayoutElement()
    if parentElement == nil then return end
    
    var elem : layout.LayoutElement
    elem.id = hash.HashNumber(parentElement.childrenOrTextContent.children.length + parentElement.floatingChildrenCount, parentElement.id).id
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
    
    self.layoutElementClipElementIds:set(idx, 0)
    self.layoutElementChildrenBuffer:add(idx)
    
    var textData : layout.TextElementData
    textData.text = text
    textData.preferredDimensions.width = 0
    textData.preferredDimensions.height = 0
    textData.wrappedLines.internalArray = nil
    textData.wrappedLines.length = 0
    textData.elementIndex = idx
    
    var textDataPtr = self.textElementData:add(textData)
    
    if added ~= nil then
        added.childrenOrTextContent.textElementData = textDataPtr
        
        if textConfig ~= nil then
            if ui.measureTextFunction ~= nil then
                var slice: string_mod.StringSlice
                slice.length = text.length
                slice.chars = text.chars
                slice.baseChars = text.chars
                textData.preferredDimensions = ui.measureTextFunction(slice, textConfig, ui.measureTextUserData)

                var wrappedLine: layout.WrappedTextLine
                wrappedLine.dimensions = textData.preferredDimensions
                wrappedLine.line = text
                var wrappedLinePtr = self.wrappedTextLines:add(wrappedLine)
                if wrappedLinePtr ~= nil then
                    textData.wrappedLines.internalArray = wrappedLinePtr
                    textData.wrappedLines.length = 1
                end
            end
            @textDataPtr = textData

            var textDimensions: config.Dimensions
            textDimensions.width = textData.preferredDimensions.width
            if textConfig.lineHeight > 0 then
                textDimensions.height = [float](textConfig.lineHeight)
            else
                textDimensions.height = textData.preferredDimensions.height
            end
            added.dimensions = textDimensions
            added.minDimensions.width = textData.preferredDimensions.width
            added.minDimensions.height = textDimensions.height
            
            added.elementConfigs.internalArray = &self.elementConfigs.internalArray[self.elementConfigs.length]
            added.elementConfigs.length = 1
            
            var elemCfg : config.ElementConfig
            elemCfg.configType = config.CONFIG_TEXT
            elemCfg.config.textConfig = textConfig
            self.elementConfigs:add(elemCfg)
        end
        
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
        added.layoutConfig = self:storeLayoutConfig(defaultLayout)
    end
    
    parentElement.childrenOrTextContent.children.length = parentElement.childrenOrTextContent.children.length + 1
end

terra ui.OpenTextElement(text: config.String, textConfig: &config.TextConfig)
    var ctx = ui.GetCurrentContext()
    if ctx ~= nil then
        ctx:openTextElement(text, textConfig)
    end
end

terra ui.SetMeasureTextFunction(measureTextFunction: MeasureTextFnType, userData: &opaque)
    ui.measureTextFunction = measureTextFunction
    ui.measureTextUserData = userData
end

terra ui.SetQueryScrollOffsetFunction(queryScrollOffsetFunction: QueryScrollOffsetFnType, userData: &opaque)
    ui.queryScrollOffsetFunction = queryScrollOffsetFunction
    ui.queryScrollOffsetUserData = userData
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
    var i: int32 = 0
    while i < elem.elementConfigs.length do
        if elem.elementConfigs.internalArray ~= nil then
            var cfg = &elem.elementConfigs.internalArray[i]
            if cfg.configType == cfgType then
                return true
            end
        end
        i = i + 1
    end
    return false
end

terra ui.FindElementConfigWithType(elem: &layout.LayoutElement, cfgType: uint8) : &config.ElementConfig
    if elem == nil then return nil end
    var i: int32 = 0
    while i < elem.elementConfigs.length do
        if elem.elementConfigs.internalArray ~= nil then
            var cfg = &elem.elementConfigs.internalArray[i]
            if cfg.configType == cfgType then
                return cfg
            end
        end
        i = i + 1
    end
    return nil
end

terra ui.ElementIsOffscreen(ctx: &ui.Context, box: &config.BoundingBox) : bool
    return (box.x > ctx.layoutDimensions.width) or
           (box.y > ctx.layoutDimensions.height) or
           (box.x + box.width < 0) or
           (box.y + box.height < 0)
end

terra ui.GetAttachPosition(box: &config.BoundingBox, attach: uint8) : config.Vector2
    var p: config.Vector2
    if attach == config.ATTACH_LEFT_TOP then
        p.x = box.x
        p.y = box.y
    elseif attach == config.ATTACH_LEFT_CENTER then
        p.x = box.x
        p.y = box.y + box.height / 2.0
    elseif attach == config.ATTACH_LEFT_BOTTOM then
        p.x = box.x
        p.y = box.y + box.height
    elseif attach == config.ATTACH_CENTER_TOP then
        p.x = box.x + box.width / 2.0
        p.y = box.y
    elseif attach == config.ATTACH_CENTER_CENTER then
        p.x = box.x + box.width / 2.0
        p.y = box.y + box.height / 2.0
    elseif attach == config.ATTACH_CENTER_BOTTOM then
        p.x = box.x + box.width / 2.0
        p.y = box.y + box.height
    elseif attach == config.ATTACH_RIGHT_TOP then
        p.x = box.x + box.width
        p.y = box.y
    elseif attach == config.ATTACH_RIGHT_CENTER then
        p.x = box.x + box.width
        p.y = box.y + box.height / 2.0
    else
        p.x = box.x + box.width
        p.y = box.y + box.height
    end
    return p
end

terra ui.Context:findScrollContainerData(elementId: uint32) : &layout.ScrollContainerDataInternal
    var i: int32 = 0
    while i < self.scrollContainerDatas.length do
        var data = self.scrollContainerDatas:get(i)
        if data ~= nil and data.elementId == elementId then
            return data
        end
        i = i + 1
    end
    return nil
end

terra ui.Context:computeContentSize(elem: &layout.LayoutElement, layoutCfg: &config.LayoutConfig) : config.Dimensions
    var contentSize: config.Dimensions
    contentSize.width = 0
    contentSize.height = 0
    if elem == nil or layoutCfg == nil then
        return contentSize
    end
    var childCount = elem.childrenOrTextContent.children.length
    if childCount <= 0 then
        return contentSize
    end
    if layoutCfg.layoutDirection == config.LEFT_TO_RIGHT then
        var i: int32 = 0
        while i < childCount do
            var childIdx = elem.childrenOrTextContent.children.elements[i]
            var child = self.layoutElements:get(childIdx)
            if child ~= nil then
                contentSize.width = contentSize.width + child.dimensions.width
                if child.dimensions.height > contentSize.height then
                    contentSize.height = child.dimensions.height
                end
            end
            i = i + 1
        end
        if childCount > 1 then
            contentSize.width = contentSize.width + [float]([int32](childCount - 1) * layoutCfg.childGap)
        end
    else
        var i: int32 = 0
        while i < childCount do
            var childIdx = elem.childrenOrTextContent.children.elements[i]
            var child = self.layoutElements:get(childIdx)
            if child ~= nil then
                if child.dimensions.width > contentSize.width then
                    contentSize.width = child.dimensions.width
                end
                contentSize.height = contentSize.height + child.dimensions.height
            end
            i = i + 1
        end
        if childCount > 1 then
            contentSize.height = contentSize.height + [float]([int32](childCount - 1) * layoutCfg.childGap)
        end
    end
    return contentSize
end

terra ui.Context:applyAspectRatios()
    var i: int32 = 0
    while i < self.layoutElements.length do
        var elem = self.layoutElements:get(i)
        if elem ~= nil then
            var aspectCfgResult = ui.FindElementConfigWithType(elem, config.CONFIG_ASPECT)
            if aspectCfgResult ~= nil and aspectCfgResult.config.aspectRatioConfig ~= nil then
                var ratio = aspectCfgResult.config.aspectRatioConfig.aspectRatio
                if ratio > ui.EPSILON and elem.layoutConfig ~= nil then
                    var width = elem.dimensions.width
                    var height = elem.dimensions.height
                    if width > ui.EPSILON and elem.layoutConfig.sizing.height.type ~= config.SIZING_FIXED then
                        height = width / ratio
                    elseif height > ui.EPSILON and elem.layoutConfig.sizing.width.type ~= config.SIZING_FIXED then
                        width = height * ratio
                    end
                    elem.dimensions.width = width
                    elem.dimensions.height = height
                    elem.minDimensions.width = width
                    elem.minDimensions.height = height
                end
            end
        end
        i = i + 1
    end
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
    self:applyAspectRatios()
    self:sizeContainersAlongAxis(false)
    self:applyAspectRatios()
    
    var sortMax: int32 = self.layoutElementTreeRoots.length - 1
    while sortMax > 0 do
        var i: int32 = 0
        while i < sortMax do
            var current = self.layoutElementTreeRoots:get(i)
            var next = self.layoutElementTreeRoots:get(i + 1)
            if current ~= nil and next ~= nil then
                if next.zIndex < current.zIndex then
                    var temp: layout.LayoutElementTreeRoot = @current
                    @current = @next
                    @next = temp
                end
            end
            i = i + 1
        end
        sortMax = sortMax - 1
    end
    
    self.renderCommands.length = 0
    
    var dfsBuffer = self.layoutElementTreeNodeArray1
    dfsBuffer.length = 0
    
    var rootIndex: int32 = 0
    while rootIndex < self.layoutElementTreeRoots.length do
        var root = self.layoutElementTreeRoots:get(rootIndex)
        
        if root == nil then
            rootIndex = rootIndex + 1
        else
            var rootElement = self.layoutElements:get(root.layoutElementIndex)
            
            if rootElement == nil or rootElement.layoutConfig == nil then
                rootIndex = rootIndex + 1
            else
                dfsBuffer.length = 0
                
                var rootStartX: float = 0
                var rootStartY: float = 0
                var floatingCfgResult = ui.FindElementConfigWithType(rootElement, config.CONFIG_FLOATING)
                if floatingCfgResult ~= nil and floatingCfgResult.config.floatingConfig ~= nil then
                    var floatingCfg = floatingCfgResult.config.floatingConfig
                    if floatingCfg.attachTo ~= config.ATTACH_NONE then
                        var parentBox: config.BoundingBox
                        parentBox.x = 0
                        parentBox.y = 0
                        parentBox.width = self.layoutDimensions.width
                        parentBox.height = self.layoutDimensions.height
                        if floatingCfg.attachTo == config.ATTACH_PARENT or floatingCfg.attachTo == config.ATTACH_ELEMENT_WITH_ID then
                            var parentId = root.parentId
                            if floatingCfg.attachTo == config.ATTACH_ELEMENT_WITH_ID and floatingCfg.parentId ~= 0 then
                                parentId = floatingCfg.parentId
                            end
                            var j: int32 = self.renderCommands.length - 1
                            while j >= 0 do
                                var cmd = self.renderCommands:get(j)
                                if cmd ~= nil and cmd.id == parentId then
                                    parentBox = cmd.boundingBox
                                    break
                                end
                                j = j - 1
                            end
                        end
                        var elementBox: config.BoundingBox
                        elementBox.x = 0
                        elementBox.y = 0
                        elementBox.width = rootElement.dimensions.width
                        elementBox.height = rootElement.dimensions.height
                        var parentAttach = ui.GetAttachPosition(&parentBox, floatingCfg.attachPoints.parent)
                        var elementAttach = ui.GetAttachPosition(&elementBox, floatingCfg.attachPoints.element)
                        rootStartX = parentAttach.x - elementAttach.x + floatingCfg.offset.x
                        rootStartY = parentAttach.y - elementAttach.y + floatingCfg.offset.y
                    end
                end

                var rootNode: layout.LayoutElementTreeNode
                rootNode.layoutElement = rootElement
                rootNode.position.x = rootStartX
                rootNode.position.y = rootStartY
                rootNode.nextChildOffset.x = [float](rootElement.layoutConfig.padding.left)
                rootNode.nextChildOffset.y = [float](rootElement.layoutConfig.padding.top)
                dfsBuffer:add(rootNode)
                
                self.layoutElementClipElementIds:set(0, 0)
                
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
                            var visited = self.layoutElementClipElementIds:getValue(currentIdx) ~= 0
                            
                            if not visited then
                                self.layoutElementClipElementIds:set(currentIdx, 1)
                                
                                var boundingBox: config.BoundingBox
                                boundingBox.x = currentElementTreeNode.position.x
                                boundingBox.y = currentElementTreeNode.position.y
                                boundingBox.width = currentElement.dimensions.width
                                boundingBox.height = currentElement.dimensions.height
                                
                                var sharedCfgResult = ui.FindElementConfigWithType(currentElement, config.CONFIG_SHARED)
                                var emitRectangle = false
                                
                                if sharedCfgResult ~= nil then
                                    var sharedCfg = sharedCfgResult.config.sharedConfig
                                    if sharedCfg ~= nil and sharedCfg.backgroundColor.a > 0 then
                                        emitRectangle = true
                                    end
                                end
                                
                                var offscreen = ui.ElementIsOffscreen(self, &boundingBox)
                                
                                if not offscreen then
                                    var clipCfgResultForScroll = ui.FindElementConfigWithType(currentElement, config.CONFIG_CLIP)
                                    if clipCfgResultForScroll ~= nil and clipCfgResultForScroll.config.clipConfig ~= nil then
                                        var scrollData = self:findScrollContainerData(currentElement.id)
                                        if scrollData == nil then
                                            var newScroll: layout.ScrollContainerDataInternal
                                            newScroll.layoutElement = currentElement
                                            newScroll.boundingBox = boundingBox
                                            newScroll.contentSize = self:computeContentSize(currentElement, layoutCfg)
                                            newScroll.scrollOrigin.x = 0
                                            newScroll.scrollOrigin.y = 0
                                            newScroll.pointerOrigin.x = 0
                                            newScroll.pointerOrigin.y = 0
                                            newScroll.scrollMomentum.x = 0
                                            newScroll.scrollMomentum.y = 0
                                            newScroll.scrollPosition.x = clipCfgResultForScroll.config.clipConfig.childOffset.x
                                            newScroll.scrollPosition.y = clipCfgResultForScroll.config.clipConfig.childOffset.y
                                            newScroll.previousDelta.x = 0
                                            newScroll.previousDelta.y = 0
                                            newScroll.momentumTime = 0
                                            newScroll.elementId = currentElement.id
                                            newScroll.openThisFrame = true
                                            newScroll.pointerScrollActive = false
                                            scrollData = self.scrollContainerDatas:add(newScroll)
                                        end
                                        if scrollData ~= nil then
                                            scrollData.layoutElement = currentElement
                                            scrollData.boundingBox = boundingBox
                                            scrollData.contentSize = self:computeContentSize(currentElement, layoutCfg)
                                            scrollData.openThisFrame = true
                                            if ui.queryScrollOffsetFunction ~= nil then
                                                scrollData.scrollPosition = ui.queryScrollOffsetFunction(currentElement.id, ui.queryScrollOffsetUserData)
                                            end
                                        end
                                    end

                                    var cfgIdx: int32 = 0
                                    while cfgIdx < currentElement.elementConfigs.length do
                                        if currentElement.elementConfigs.internalArray ~= nil then
                                            var elemCfg = &currentElement.elementConfigs.internalArray[cfgIdx]
                                            
                                            if elemCfg.configType == config.CONFIG_CLIP then
                                                var cmd: config.RenderCommand
                                                cmd.boundingBox = boundingBox
                                                cmd.id = currentElement.id
                                                cmd.commandType = config.RENDER_SCISSOR_START
                                                cmd.zIndex = root.zIndex
                                                
                                                if elemCfg.config.clipConfig ~= nil then
                                                    cmd.renderData.clip.horizontal = elemCfg.config.clipConfig.horizontal
                                                    cmd.renderData.clip.vertical = elemCfg.config.clipConfig.vertical
                                                end
                                                
                                                if self.renderCommands.length < self.renderCommands.capacity then
                                                    self.renderCommands:add(cmd)
                                                end
                                                
                                            elseif elemCfg.configType == config.CONFIG_IMAGE then
                                                var cmd: config.RenderCommand
                                                cmd.boundingBox = boundingBox
                                                cmd.id = currentElement.id
                                                cmd.commandType = config.RENDER_IMAGE
                                                cmd.zIndex = root.zIndex
                                                
                                                if elemCfg.config.imageConfig ~= nil then
                                                    cmd.renderData.image.imageData = elemCfg.config.imageConfig.imageData
                                                end
                                                if sharedCfgResult ~= nil and sharedCfgResult.config.sharedConfig ~= nil then
                                                    cmd.renderData.image.backgroundColor = sharedCfgResult.config.sharedConfig.backgroundColor
                                                    cmd.renderData.image.cornerRadius = sharedCfgResult.config.sharedConfig.cornerRadius
                                                end
                                                
                                                if self.renderCommands.length < self.renderCommands.capacity then
                                                    self.renderCommands:add(cmd)
                                                end
                                                emitRectangle = false
                                                
                                            elseif elemCfg.configType == config.CONFIG_CUSTOM then
                                                var cmd: config.RenderCommand
                                                cmd.boundingBox = boundingBox
                                                cmd.id = currentElement.id
                                                cmd.commandType = config.RENDER_CUSTOM
                                                cmd.zIndex = root.zIndex
                                                
                                                if elemCfg.config.customConfig ~= nil then
                                                    cmd.renderData.custom.customData = elemCfg.config.customConfig.customData
                                                end
                                                if sharedCfgResult ~= nil and sharedCfgResult.config.sharedConfig ~= nil then
                                                    cmd.renderData.custom.backgroundColor = sharedCfgResult.config.sharedConfig.backgroundColor
                                                    cmd.renderData.custom.cornerRadius = sharedCfgResult.config.sharedConfig.cornerRadius
                                                end
                                                
                                                if self.renderCommands.length < self.renderCommands.capacity then
                                                    self.renderCommands:add(cmd)
                                                end
                                                emitRectangle = false
                                            end
                                        end
                                        cfgIdx = cfgIdx + 1
                                    end
                                    
                                    if emitRectangle then
                                        var cmd: config.RenderCommand
                                        cmd.boundingBox = boundingBox
                                        cmd.id = currentElement.id
                                        cmd.commandType = config.RENDER_RECTANGLE
                                        cmd.zIndex = root.zIndex
                                        
                                        if sharedCfgResult ~= nil and sharedCfgResult.config.sharedConfig ~= nil then
                                            cmd.renderData.rectangle.backgroundColor = sharedCfgResult.config.sharedConfig.backgroundColor
                                            cmd.renderData.rectangle.cornerRadius = sharedCfgResult.config.sharedConfig.cornerRadius
                                            cmd.userData = sharedCfgResult.config.sharedConfig.userData
                                        end
                                        
                                        if self.renderCommands.length < self.renderCommands.capacity then
                                            self.renderCommands:add(cmd)
                                        end
                                    end
                                    
                                    if ui.ElementHasConfig(currentElement, config.CONFIG_TEXT) then
                                        var textCfgResult = ui.FindElementConfigWithType(currentElement, config.CONFIG_TEXT)
                                        if textCfgResult ~= nil and textCfgResult.config.textConfig ~= nil then
                                            var textCfg = textCfgResult.config.textConfig
                                            var textData = currentElement.childrenOrTextContent.textElementData
                                            
                                            if textData ~= nil then
                                                var naturalLineHeight: float = textData.preferredDimensions.height
                                                var finalLineHeight: float
                                                if textCfg.lineHeight > 0 then
                                                    finalLineHeight = [float](textCfg.lineHeight)
                                                else
                                                    finalLineHeight = naturalLineHeight
                                                end
                                                var lineHeightOffset: float = (finalLineHeight - naturalLineHeight) / 2.0
                                                var yPosition: float = lineHeightOffset
                                                
                                                var lineIndex: int32 = 0
                                                while lineIndex < textData.wrappedLines.length do
                                                    var wrappedLine = &textData.wrappedLines.internalArray[lineIndex]
                                                    if wrappedLine.line.length == 0 then
                                                        yPosition = yPosition + finalLineHeight
                                                    else
                                                        var offset: float = boundingBox.width - wrappedLine.dimensions.width
                                                        if textCfg.textAlignment == config.TEXT_ALIGN_LEFT then
                                                            offset = 0
                                                        elseif textCfg.textAlignment == config.TEXT_ALIGN_CENTER then
                                                            offset = offset / 2.0
                                                        end
                                                        
                                                        var textCmd: config.RenderCommand
                                                        textCmd.boundingBox.x = boundingBox.x + offset
                                                        textCmd.boundingBox.y = boundingBox.y + yPosition
                                                        textCmd.boundingBox.width = wrappedLine.dimensions.width
                                                        textCmd.boundingBox.height = wrappedLine.dimensions.height
                                                        textCmd.renderData.text.stringContents.length = wrappedLine.line.length
                                                        textCmd.renderData.text.stringContents.chars = wrappedLine.line.chars
                                                        textCmd.renderData.text.stringContents.baseChars = textData.text.chars
                                                        textCmd.renderData.text.textColor = textCfg.textColor
                                                        textCmd.renderData.text.fontId = textCfg.fontId
                                                        textCmd.renderData.text.fontSize = textCfg.fontSize
                                                        textCmd.renderData.text.letterSpacing = textCfg.letterSpacing
                                                        textCmd.renderData.text.lineHeight = textCfg.lineHeight
                                                        textCmd.userData = textCfg.userData
                                                        textCmd.id = hash.HashNumber(lineIndex, currentElement.id).id
                                                        textCmd.zIndex = root.zIndex
                                                        textCmd.commandType = config.RENDER_TEXT
                                                        
                                                        if self.renderCommands.length < self.renderCommands.capacity then
                                                            self.renderCommands:add(textCmd)
                                                        end
                                                        
                                                        yPosition = yPosition + finalLineHeight
                                                    end
                                                    lineIndex = lineIndex + 1
                                                end
                                            end
                                        end
                                    end
                                end
                                
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
                                                var clipCfgForChildOffset = ui.FindElementConfigWithType(currentElement, config.CONFIG_CLIP)
                                                if clipCfgForChildOffset ~= nil and clipCfgForChildOffset.config.clipConfig ~= nil then
                                                    var scrollData = self:findScrollContainerData(currentElement.id)
                                                    if scrollData ~= nil then
                                                        scrollOffsetX = scrollData.scrollPosition.x
                                                        scrollOffsetY = scrollData.scrollPosition.y
                                                    else
                                                        scrollOffsetX = clipCfgForChildOffset.config.clipConfig.childOffset.x
                                                        scrollOffsetY = clipCfgForChildOffset.config.clipConfig.childOffset.y
                                                    end
                                                end
                                                
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
                                                self.layoutElementClipElementIds:set(newNodeIndex, 0)
                                                
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
                                    end
                                end
                            else
                                var childCount = currentElement.childrenOrTextContent.children.length
                                
                                if ui.ElementHasConfig(currentElement, config.CONFIG_CLIP) then
                                    if self.renderCommands.length < self.renderCommands.capacity then
                                        var cmd: config.RenderCommand
                                        cmd.id = currentElement.id
                                        cmd.commandType = config.RENDER_SCISSOR_END
                                        self.renderCommands:add(cmd)
                                    end
                                end
                                
                                if ui.ElementHasConfig(currentElement, config.CONFIG_BORDER) then
                                    var borderBoundingBox: config.BoundingBox
                                    borderBoundingBox.x = currentElementTreeNode.position.x
                                    borderBoundingBox.y = currentElementTreeNode.position.y
                                    borderBoundingBox.width = currentElement.dimensions.width
                                    borderBoundingBox.height = currentElement.dimensions.height
                                    
                                    if not ui.ElementIsOffscreen(self, &borderBoundingBox) then
                                        var borderCfgResult = ui.FindElementConfigWithType(currentElement, config.CONFIG_BORDER)
                                        if borderCfgResult ~= nil and borderCfgResult.config.borderConfig ~= nil then
                                            var borderCfg = borderCfgResult.config.borderConfig
                                            
                                            if borderCfg.color.a > 0 then
                                                var borderSharedCfgResult = ui.FindElementConfigWithType(currentElement, config.CONFIG_SHARED)
                                                
                                                var cmd: config.RenderCommand
                                                cmd.boundingBox = borderBoundingBox
                                                cmd.id = currentElement.id
                                                cmd.commandType = config.RENDER_BORDER
                                                cmd.zIndex = root.zIndex
                                                cmd.renderData.border.color = borderCfg.color
                                                cmd.renderData.border.width = borderCfg.width
                                                
                                                if borderSharedCfgResult ~= nil and borderSharedCfgResult.config.sharedConfig ~= nil then
                                                    cmd.renderData.border.cornerRadius = borderSharedCfgResult.config.sharedConfig.cornerRadius
                                                    cmd.userData = borderSharedCfgResult.config.sharedConfig.userData
                                                end
                                                
                                                if self.renderCommands.length < self.renderCommands.capacity then
                                                    self.renderCommands:add(cmd)
                                                end
                                                
                                                if borderCfg.width.betweenChildren > 0 and layoutCfg ~= nil then
                                                    var halfGap: float = [float](layoutCfg.childGap) / 2.0
                                                    var borderOffsetX: float = [float](layoutCfg.padding.left) - halfGap
                                                    var borderOffsetY: float = [float](layoutCfg.padding.top) - halfGap
                                                    
                                                    if layoutCfg.layoutDirection == config.LEFT_TO_RIGHT then
                                                        var i: int32 = 0
                                                        while i < childCount do
                                                            if i > 0 then
                                                                var childIdx = currentElement.childrenOrTextContent.children.elements[i]
                                                                var childElement = self.layoutElements:get(childIdx)
                                                                if childElement ~= nil then
                                                                    var betweenCmd: config.RenderCommand
                                                                    betweenCmd.boundingBox.x = borderBoundingBox.x + borderOffsetX
                                                                    betweenCmd.boundingBox.y = borderBoundingBox.y
                                                                    betweenCmd.boundingBox.width = [float](borderCfg.width.betweenChildren)
                                                                    betweenCmd.boundingBox.height = currentElement.dimensions.height
                                                                    betweenCmd.renderData.rectangle.backgroundColor = borderCfg.color
                                                                    betweenCmd.id = hash.HashNumber(i, currentElement.id).id
                                                                    betweenCmd.commandType = config.RENDER_RECTANGLE
                                                                    betweenCmd.zIndex = root.zIndex
                                                                    
                                                                    if self.renderCommands.length < self.renderCommands.capacity then
                                                                        self.renderCommands:add(betweenCmd)
                                                                    end
                                                                end
                                                            end
                                                            var childIdx = currentElement.childrenOrTextContent.children.elements[i]
                                                            var childElement = self.layoutElements:get(childIdx)
                                                            if childElement ~= nil then
                                                                borderOffsetX = borderOffsetX + childElement.dimensions.width + [float](layoutCfg.childGap)
                                                            end
                                                            i = i + 1
                                                        end
                                                    else
                                                        var i: int32 = 0
                                                        while i < childCount do
                                                            if i > 0 then
                                                                var childIdx = currentElement.childrenOrTextContent.children.elements[i]
                                                                var childElement = self.layoutElements:get(childIdx)
                                                                if childElement ~= nil then
                                                                    var betweenCmd: config.RenderCommand
                                                                    betweenCmd.boundingBox.x = borderBoundingBox.x
                                                                    betweenCmd.boundingBox.y = borderBoundingBox.y + borderOffsetY
                                                                    betweenCmd.boundingBox.width = currentElement.dimensions.width
                                                                    betweenCmd.boundingBox.height = [float](borderCfg.width.betweenChildren)
                                                                    betweenCmd.renderData.rectangle.backgroundColor = borderCfg.color
                                                                    betweenCmd.id = hash.HashNumber(i, currentElement.id).id
                                                                    betweenCmd.commandType = config.RENDER_RECTANGLE
                                                                    betweenCmd.zIndex = root.zIndex
                                                                    
                                                                    if self.renderCommands.length < self.renderCommands.capacity then
                                                                        self.renderCommands:add(betweenCmd)
                                                                    end
                                                                end
                                                            end
                                                            var childIdx = currentElement.childrenOrTextContent.children.elements[i]
                                                            var childElement = self.layoutElements:get(childIdx)
                                                            if childElement ~= nil then
                                                                borderOffsetY = borderOffsetY + childElement.dimensions.height + [float](layoutCfg.childGap)
                                                            end
                                                            i = i + 1
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                                
                                dfsBuffer.length = dfsBuffer.length - 1
                            end
                        end
                    end
                end
            end
            rootIndex = rootIndex + 1
        end
    end
end

terra ui.PointInsideBox(point: config.Vector2, box: config.BoundingBox) : bool
    return point.x >= box.x and point.x <= box.x + box.width and point.y >= box.y and point.y <= box.y + box.height
end

terra ui.SetPointerState(position: config.Vector2, pointerDown: bool)
    var ctx = ui.GetCurrentContext()
    if ctx == nil then return end
    ctx.pointerInfo.position = position
    if pointerDown then
        if ctx.pointerInfo.state == config.POINTER_PRESSED_THIS_FRAME then
            ctx.pointerInfo.state = config.POINTER_PRESSED
        elseif ctx.pointerInfo.state ~= config.POINTER_PRESSED then
            ctx.pointerInfo.state = config.POINTER_PRESSED_THIS_FRAME
        end
    else
        if ctx.pointerInfo.state == config.POINTER_RELEASED_THIS_FRAME then
            ctx.pointerInfo.state = config.POINTER_RELEASED
        elseif ctx.pointerInfo.state ~= config.POINTER_RELEASED then
            ctx.pointerInfo.state = config.POINTER_RELEASED_THIS_FRAME
        end
    end
end

terra ui.UpdateScrollContainers(enableDragScrolling: bool, scrollDelta: config.Vector2, deltaTime: float)
    var ctx = ui.GetCurrentContext()
    if ctx == nil then return end
    var isPointerActive = enableDragScrolling and (ctx.pointerInfo.state == config.POINTER_PRESSED or ctx.pointerInfo.state == config.POINTER_PRESSED_THIS_FRAME)

    var highestPriorityScrollData: &layout.ScrollContainerDataInternal = nil
    var i: int32 = 0
    while i < ctx.scrollContainerDatas.length do
        var scrollData = ctx.scrollContainerDatas:get(i)
        if scrollData == nil or not scrollData.openThisFrame then
            ctx.scrollContainerDatas:removeSwapback(i)
            i = i - 1
        elseif scrollData.layoutElement ~= nil then
            var clipCfgResult = ui.FindElementConfigWithType(scrollData.layoutElement, config.CONFIG_CLIP)
            if clipCfgResult ~= nil and clipCfgResult.config.clipConfig ~= nil then
                var clipCfg = clipCfgResult.config.clipConfig
                var canScrollVertically = clipCfg.vertical and scrollData.contentSize.height > scrollData.layoutElement.dimensions.height
                var canScrollHorizontally = clipCfg.horizontal and scrollData.contentSize.width > scrollData.layoutElement.dimensions.width

                if not isPointerActive and scrollData.pointerScrollActive then
                    if scrollData.momentumTime > ui.EPSILON then
                        scrollData.scrollMomentum.x = (scrollData.scrollPosition.x - scrollData.scrollOrigin.x) / (scrollData.momentumTime * 25.0)
                        scrollData.scrollMomentum.y = (scrollData.scrollPosition.y - scrollData.scrollOrigin.y) / (scrollData.momentumTime * 25.0)
                    end
                    scrollData.pointerScrollActive = false
                    scrollData.pointerOrigin.x = 0
                    scrollData.pointerOrigin.y = 0
                    scrollData.momentumTime = 0
                end

                if not scrollData.pointerScrollActive then
                    scrollData.scrollPosition.x = scrollData.scrollPosition.x + scrollData.scrollMomentum.x
                    scrollData.scrollPosition.y = scrollData.scrollPosition.y + scrollData.scrollMomentum.y
                    scrollData.scrollMomentum.x = scrollData.scrollMomentum.x * (1.0 - deltaTime * 8.0)
                    scrollData.scrollMomentum.y = scrollData.scrollMomentum.y * (1.0 - deltaTime * 8.0)
                    if scrollData.scrollMomentum.x > -0.1 and scrollData.scrollMomentum.x < 0.1 then
                        scrollData.scrollMomentum.x = 0
                    end
                    if scrollData.scrollMomentum.y > -0.1 and scrollData.scrollMomentum.y < 0.1 then
                        scrollData.scrollMomentum.y = 0
                    end
                end

                if ui.PointInsideBox(ctx.pointerInfo.position, scrollData.boundingBox) then
                    highestPriorityScrollData = scrollData
                end

                if canScrollVertically then
                    var minY = -(scrollData.contentSize.height - scrollData.layoutElement.dimensions.height)
                    scrollData.scrollPosition.y = ui.clamp(scrollData.scrollPosition.y, minY, 0)
                end
                if canScrollHorizontally then
                    var minX = -(scrollData.contentSize.width - scrollData.layoutElement.dimensions.width)
                    scrollData.scrollPosition.x = ui.clamp(scrollData.scrollPosition.x, minX, 0)
                end
            end
        end
        i = i + 1
    end

    if highestPriorityScrollData ~= nil and highestPriorityScrollData.layoutElement ~= nil then
        var clipCfgResult = ui.FindElementConfigWithType(highestPriorityScrollData.layoutElement, config.CONFIG_CLIP)
        if clipCfgResult ~= nil and clipCfgResult.config.clipConfig ~= nil then
            var clipCfg = clipCfgResult.config.clipConfig
            var canScrollVertically = clipCfg.vertical and highestPriorityScrollData.contentSize.height > highestPriorityScrollData.layoutElement.dimensions.height
            var canScrollHorizontally = clipCfg.horizontal and highestPriorityScrollData.contentSize.width > highestPriorityScrollData.layoutElement.dimensions.width

            if canScrollVertically then
                highestPriorityScrollData.scrollPosition.y = highestPriorityScrollData.scrollPosition.y + scrollDelta.y * 10.0
            end
            if canScrollHorizontally then
                highestPriorityScrollData.scrollPosition.x = highestPriorityScrollData.scrollPosition.x + scrollDelta.x * 10.0
            end

            if isPointerActive then
                highestPriorityScrollData.scrollMomentum.x = 0
                highestPriorityScrollData.scrollMomentum.y = 0
                if not highestPriorityScrollData.pointerScrollActive then
                    highestPriorityScrollData.pointerOrigin = ctx.pointerInfo.position
                    highestPriorityScrollData.scrollOrigin = highestPriorityScrollData.scrollPosition
                    highestPriorityScrollData.pointerScrollActive = true
                    highestPriorityScrollData.momentumTime = 0
                else
                    if canScrollHorizontally then
                        highestPriorityScrollData.scrollPosition.x = highestPriorityScrollData.scrollOrigin.x + (ctx.pointerInfo.position.x - highestPriorityScrollData.pointerOrigin.x)
                    end
                    if canScrollVertically then
                        highestPriorityScrollData.scrollPosition.y = highestPriorityScrollData.scrollOrigin.y + (ctx.pointerInfo.position.y - highestPriorityScrollData.pointerOrigin.y)
                    end
                    highestPriorityScrollData.momentumTime = highestPriorityScrollData.momentumTime + deltaTime
                end
            end
        end
    end
end

terra ui.GetScrollOffset() : config.Vector2
    var ctx = ui.GetCurrentContext()
    var zero: config.Vector2
    zero.x = 0
    zero.y = 0
    if ctx == nil then
        return zero
    end
    var openElem = ctx:getOpenLayoutElement()
    if openElem == nil then
        return zero
    end
    var scrollData = ctx:findScrollContainerData(openElem.id)
    if scrollData ~= nil then
        return scrollData.scrollPosition
    end
    var clipCfgResult = ui.FindElementConfigWithType(openElem, config.CONFIG_CLIP)
    if clipCfgResult ~= nil and clipCfgResult.config.clipConfig ~= nil then
        return clipCfgResult.config.clipConfig.childOffset
    end
    return zero
end

terra ui.GetScrollContainerData(id: hash.ElementId) : config.ScrollContainerData
    var out: config.ScrollContainerData
    out.scrollPosition = nil
    out.scrollContainerDimensions.width = 0
    out.scrollContainerDimensions.height = 0
    out.contentDimensions.width = 0
    out.contentDimensions.height = 0
    out.config.horizontal = false
    out.config.vertical = false
    out.config.childOffset.x = 0
    out.config.childOffset.y = 0
    out.found = false

    var ctx = ui.GetCurrentContext()
    if ctx == nil then
        return out
    end
    var scrollData = ctx:findScrollContainerData(id.id)
    if scrollData == nil or scrollData.layoutElement == nil then
        return out
    end
    var clipCfgResult = ui.FindElementConfigWithType(scrollData.layoutElement, config.CONFIG_CLIP)
    if clipCfgResult == nil or clipCfgResult.config.clipConfig == nil then
        return out
    end
    out.scrollPosition = &scrollData.scrollPosition
    out.scrollContainerDimensions = scrollData.layoutElement.dimensions
    out.contentDimensions = scrollData.contentSize
    out.config = @clipCfgResult.config.clipConfig
    out.found = true
    return out
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
