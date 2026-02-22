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
local PaintConfigArray = array_mod.Array(config.PaintConfig)
local PaintOpArray = array_mod.Array(config.PaintOp)
local RenderCommandArray = array_mod.Array(config.RenderCommand)
local TextElementDataArray = array_mod.Array(layout.TextElementData)
local WrappedTextLineArray = array_mod.Array(layout.WrappedTextLine)
local StringArray = array_mod.Array(string_mod.String)
local LayoutElementTreeRootArray = array_mod.Array(layout.LayoutElementTreeRoot)
local LayoutElementTreeNodeArray = array_mod.Array(layout.LayoutElementTreeNode)
local ScrollContainerDataArray = array_mod.Array(layout.ScrollContainerDataInternal)
local MeasuredWordArray = array_mod.Array(layout.MeasuredWord)
local MeasureTextCacheItemArray = array_mod.Array(layout.MeasureTextCacheItem)
local UInt32Array = array_mod.Array(uint32)
local BoundingBoxArray = array_mod.Array(config.BoundingBox)
local BoolArray = array_mod.Array(bool)
-- FFI-friendly callback types using out pointers instead of struct-by-value
-- This ensures portability across LuaJIT FFI, Python ctypes, etc.
local MeasureTextFnType = { &string_mod.StringSlice, &config.TextConfig, &opaque, &config.Dimensions } -> int32
local QueryScrollOffsetFnType = { uint32, &opaque, &config.Vector2 } -> int32
local HoverCallbackFnType = { hash.ElementId, &config.PointerData, &opaque } -> {}
local ErrorHandlerFnType = { &config.ErrorData } -> {}
local HoverBinding = struct {
    elementId : uint32,
    callback : HoverCallbackFnType,
    userData : &opaque
}
local HoverBindingArray = array_mod.Array(HoverBinding)
local DecodedElementConfigs = struct {
    text : &config.TextConfig,
    border : &config.BorderConfig,
    floating : &config.FloatingConfig,
    clip : &config.ClipConfig,
    aspect : &config.AspectRatioConfig,
    image : &config.ImageConfig,
    custom : &config.CustomConfig,
    shared : &config.SharedConfig,
    paint : &config.PaintConfig
}

ui.MAXFLOAT = 3.40282346638528859812e+38
ui.ARGILE_API_VERSION = 1

ui.Context = struct {
    maxElementCount : int32,
    maxMeasureTextCacheWordCount : int32,
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
    paintConfigs : PaintConfigArray,
    paintOps : PaintOpArray,
    wrappedTextLines : WrappedTextLineArray,
    layoutElementTreeRoots : LayoutElementTreeRootArray,
    layoutElementTreeNodeArray1 : LayoutElementTreeNodeArray,
    layoutElementIdStrings : StringArray,
    scrollContainerDatas : ScrollContainerDataArray,
    hoverBindings : HoverBindingArray,
    measureTextHashMapInternal : MeasureTextCacheItemArray,
    measureTextHashMapInternalFreeList : Int32Array,
    measureTextHashMap : Int32Array,
    measuredWords : MeasuredWordArray,
    measuredWordsFreeList : Int32Array,
    pointerOverIds : UInt32Array,
    focusedIds : UInt32Array,
    selectedIds : UInt32Array,
    disabledIds : UInt32Array,
    elementIdLookupKeys : UInt32Array,
    elementIdLookupValues : Int32Array,
    elementBoundingBoxes : BoundingBoxArray,
    elementBoundingBoxValid : BoolArray,
    warningTextMeasurementFunctionNotSet : bool,
    warningMaxTextMeasureCacheExceeded : bool,
    warningDuplicateId : bool,
    warningPercentageOverOne : bool,
    warningFloatingParentNotFound : bool,
    maxElementsExceeded : bool,
    -- Portability: per-context measure text function
    measureTextFunction : MeasureTextFnType,
    measureTextUserData : &opaque
}

local ContextPtr = &ui.Context
ui.currentContextPtr = global(ContextPtr, nil)
ui.defaultContextStorage = global(ui.Context)
ui.measureTextFunction = global(MeasureTextFnType, nil)
ui.measureTextUserData = global(&opaque, nil)
ui.queryScrollOffsetFunction = global(QueryScrollOffsetFnType, nil)
ui.queryScrollOffsetUserData = global(&opaque, nil)
ui.errorHandlerFunction = global(ErrorHandlerFnType, nil)
ui.errorHandlerUserData = global(&opaque, nil)
ui.disableCulling = global(bool, false)
ui.debugModeEnabled = global(bool, false)
ui.externalScrollHandlingEnabled = global(bool, false)
ui.defaultMaxElementCount = global(int32, 1024)
ui.defaultMaxMeasureTextWordCacheCount = global(int32, 16384)

terra ui.GetCurrentContext() : &ui.Context
    return ui.currentContextPtr
end

terra ui.SetCurrentContext(ctx: &ui.Context)
    ui.currentContextPtr = ctx
end

terra ui.Initialize(arena: ui.Arena, layoutDimensions: config.Dimensions) : &ui.Context
    var a = arena
    var ctx = &ui.defaultContextStorage
    if not ctx:initialize(&a, ui.defaultMaxElementCount) then
        return nil
    end
    ui.SetCurrentContext(ctx)
    ctx.layoutDimensions = layoutDimensions
    return ctx
end

terra ui.GetApiVersion() : uint32
    return ui.ARGILE_API_VERSION
end

terra ui.GetContextSize() : uint64
    return [uint64](sizeof(ui.Context))
end

terra ui.InitializeContext(ctx: &ui.Context, arena: ui.Arena, maxElements: int32) : bool
    if ctx == nil then
        return false
    end
    var a = arena
    return ctx:initialize(&a, maxElements)
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
    self.maxMeasureTextCacheWordCount = ui.defaultMaxMeasureTextWordCacheCount
    self.internalArena = @arena
    self.arenaResetOffset = arena.nextAllocation
    self.generation = 0
    self.maxElementsExceeded = false
    self.layoutDimensions.width = 0
    self.layoutDimensions.height = 0
    self.dynamicElementIndex = 0
    self.warningTextMeasurementFunctionNotSet = false
    self.warningMaxTextMeasureCacheExceeded = false
    self.warningDuplicateId = false
    self.warningPercentageOverOne = false
    self.warningFloatingParentNotFound = false
    -- Seed new contexts from the current default measure callback so the
    -- legacy global setter still affects subsequently created contexts.
    self.measureTextFunction = ui.measureTextFunction
    self.measureTextUserData = ui.measureTextUserData
    
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
    if not self.paintConfigs:allocate(maxElements, arena) then return false end
    if not self.paintOps:allocate(maxElements * 16, arena) then return false end
    if not self.wrappedTextLines:allocate(maxElements * 8, arena) then return false end
    if not self.layoutElementTreeRoots:allocate(maxElements, arena) then return false end
    if not self.layoutElementTreeNodeArray1:allocate(maxElements, arena) then return false end
    if not self.layoutElementIdStrings:allocate(maxElements, arena) then return false end
    if not self.scrollContainerDatas:allocate(maxElements, arena) then return false end
    if not self.hoverBindings:allocate(maxElements, arena) then return false end
    if not self.measureTextHashMapInternal:allocate(maxElements, arena) then return false end
    if not self.measureTextHashMapInternalFreeList:allocate(maxElements, arena) then return false end
    var hashBuckets = maxElements
    if self.maxMeasureTextCacheWordCount / 32 > hashBuckets then
        hashBuckets = self.maxMeasureTextCacheWordCount / 32
    end
    if hashBuckets < 1 then hashBuckets = 1 end
    if not self.measureTextHashMap:allocate(hashBuckets, arena) then return false end
    if not self.measuredWords:allocate(self.maxMeasureTextCacheWordCount, arena) then return false end
    if not self.measuredWordsFreeList:allocate(self.maxMeasureTextCacheWordCount, arena) then return false end
    if not self.pointerOverIds:allocate(maxElements, arena) then return false end
    if not self.focusedIds:allocate(maxElements, arena) then return false end
    if not self.selectedIds:allocate(maxElements, arena) then return false end
    if not self.disabledIds:allocate(maxElements, arena) then return false end
    if not self.elementIdLookupKeys:allocate(maxElements * 4, arena) then return false end
    if not self.elementIdLookupValues:allocate(maxElements * 4, arena) then return false end
    if not self.elementBoundingBoxes:allocate(maxElements, arena) then return false end
    if not self.elementBoundingBoxValid:allocate(maxElements, arena) then return false end

    self.elementIdLookupKeys.length = self.elementIdLookupKeys.capacity
    self.elementIdLookupValues.length = self.elementIdLookupValues.capacity
    self.elementBoundingBoxValid.length = self.elementBoundingBoxValid.capacity
    self.measureTextHashMap.length = self.measureTextHashMap.capacity
    var i: int32 = 0
    while i < self.elementIdLookupValues.length do
        self.elementIdLookupKeys.internalArray[i] = 0
        self.elementIdLookupValues.internalArray[i] = -1
        i = i + 1
    end
    i = 0
    while i < self.elementBoundingBoxValid.length do
        self.elementBoundingBoxValid.internalArray[i] = false
        i = i + 1
    end
    i = 0
    while i < self.measureTextHashMap.length do
        self.measureTextHashMap.internalArray[i] = 0
        i = i + 1
    end
    self.measureTextHashMapInternal.length = 1
    self.measureTextHashMapInternalFreeList.length = 0
    self.measuredWords.length = 0
    self.measuredWordsFreeList.length = 0
    self.pointerOverIds.length = 0
    self.focusedIds.length = 0
    self.selectedIds.length = 0
    self.disabledIds.length = 0
    
    return true
end

terra ui.Context:resetEphemeral()
    self.internalArena.nextAllocation = self.arenaResetOffset
    self.generation = self.generation + 1
    self.dynamicElementIndex = 0
    self.maxElementsExceeded = false
    self.warningTextMeasurementFunctionNotSet = false
    self.warningMaxTextMeasureCacheExceeded = false
    self.warningDuplicateId = false
    self.warningPercentageOverOne = false
    self.warningFloatingParentNotFound = false
    
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
    self.hoverBindings:clear()

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
    self.paintConfigs:clear()
    self.paintOps:clear()

    var mapIdx: int32 = 0
    while mapIdx < self.elementIdLookupValues.length do
        self.elementIdLookupKeys.internalArray[mapIdx] = 0
        self.elementIdLookupValues.internalArray[mapIdx] = -1
        mapIdx = mapIdx + 1
    end

    var bbIdx: int32 = 0
    while bbIdx < self.elementBoundingBoxValid.length do
        self.elementBoundingBoxValid.internalArray[bbIdx] = false
        bbIdx = bbIdx + 1
    end
end

terra ui.Context:registerElementId(elementId: uint32, elementIndex: int32)
    if elementId == 0 or self.elementIdLookupValues.length <= 0 then return end
    var cap = self.elementIdLookupValues.length
    var slot = [int32](elementId % [uint32](cap))
    var probes: int32 = 0
    while probes < cap do
        var key = self.elementIdLookupKeys.internalArray[slot]
        var value = self.elementIdLookupValues.internalArray[slot]
        if value < 0 then
            self.elementIdLookupKeys.internalArray[slot] = elementId
            self.elementIdLookupValues.internalArray[slot] = elementIndex
            return
        elseif key == elementId then
            if value ~= elementIndex and not self.warningDuplicateId then
                self.warningDuplicateId = true
                ui.ReportError(config.ERROR_TYPE_DUPLICATE_ID,
                    config.String { isStaticallyAllocated = true, length = 78, chars = "Duplicate element ID declared during this layout. IDs must be unique per frame." })
            end
            self.elementIdLookupValues.internalArray[slot] = elementIndex
            return
        end
        slot = slot + 1
        if slot >= cap then
            slot = 0
        end
        probes = probes + 1
    end
end

terra ui.Context:findElementIndexById(elementId: uint32) : int32
    if elementId == 0 or self.elementIdLookupValues.length <= 0 then return -1 end
    var cap = self.elementIdLookupValues.length
    var slot = [int32](elementId % [uint32](cap))
    var probes: int32 = 0
    while probes < cap do
        var value = self.elementIdLookupValues.internalArray[slot]
        if value < 0 then
            return -1
        end
        if self.elementIdLookupKeys.internalArray[slot] == elementId then
            return value
        end
        slot = slot + 1
        if slot >= cap then
            slot = 0
        end
        probes = probes + 1
    end
    return -1
end

terra ui.HashStringContentsWithConfig(text: &config.String, cfg: &config.TextConfig) : uint32
    if text == nil or cfg == nil then return 1 end
    var h: uint32 = 0
    if text.isStaticallyAllocated then
        h = h + [uint32]([uint64](text.chars))
        h = h + (h << 10)
        h = h ^ (h >> 6)
        h = h + [uint32](text.length)
        h = h + (h << 10)
        h = h ^ (h >> 6)
    else
        h = [uint32](hash.HashData([&uint8](text.chars), [uint64](text.length)) % [uint64](4294967295ULL))
    end

    h = h + [uint32](cfg.fontId)
    h = h + (h << 10)
    h = h ^ (h >> 6)

    h = h + [uint32](cfg.fontSize)
    h = h + (h << 10)
    h = h ^ (h >> 6)

    h = h + [uint32](cfg.letterSpacing)
    h = h + (h << 10)
    h = h ^ (h >> 6)

    h = h + (h << 3)
    h = h ^ (h >> 11)
    h = h + (h << 15)
    return h + 1
end

terra ui.Context:addMeasuredWord(word: layout.MeasuredWord, previousWord: &layout.MeasuredWord) : &layout.MeasuredWord
    if previousWord == nil then return nil end
    if self.measuredWordsFreeList.length > 0 then
        var newItemIndex = self.measuredWordsFreeList:getValue(self.measuredWordsFreeList.length - 1)
        self.measuredWordsFreeList.length = self.measuredWordsFreeList.length - 1
        self.measuredWords:set(newItemIndex, word)
        previousWord.next = newItemIndex
        return self.measuredWords:get(newItemIndex)
    else
        previousWord.next = self.measuredWords.length
        return self.measuredWords:add(word)
    end
end

terra ui.Context:measureTextCached(text: &config.String, textCfg: &config.TextConfig) : &layout.MeasureTextCacheItem
    if text == nil or textCfg == nil then return nil end
    var measureTextFn = self.measureTextFunction
    var measureTextUserData = self.measureTextUserData
    if measureTextFn == nil then
        measureTextFn = ui.measureTextFunction
        measureTextUserData = ui.measureTextUserData
    end
    if measureTextFn == nil then
        if not self.warningTextMeasurementFunctionNotSet then
            self.warningTextMeasurementFunctionNotSet = true
            ui.ReportError(config.ERROR_TYPE_TEXT_MEASUREMENT_FUNCTION_NOT_PROVIDED,
                config.String { isStaticallyAllocated = true, length = 136, chars = "MeasureText function is nil. Call SetMeasureTextFunction() with a valid callback before creating text elements." })
        end
        return nil
    end
    if self.measureTextHashMap.length <= 0 then return nil end

    var id = ui.HashStringContentsWithConfig(text, textCfg)
    var hashBucket = [int32](id % [uint32](self.measureTextHashMap.length))
    var elementIndexPrevious: int32 = 0
    var elementIndex = self.measureTextHashMap.internalArray[hashBucket]
    while elementIndex ~= 0 do
        var hashEntry = self.measureTextHashMapInternal:get(elementIndex)
        if hashEntry ~= nil then
            if hashEntry.id == id then
                hashEntry.generation = self.generation
                return hashEntry
            end
            if self.generation - hashEntry.generation > 2 then
                var nextWordIndex = hashEntry.measuredWordsStartIndex
                while nextWordIndex ~= -1 do
                    var measuredWord = self.measuredWords:get(nextWordIndex)
                    self.measuredWordsFreeList:add(nextWordIndex)
                    if measuredWord == nil then
                        nextWordIndex = -1
                    else
                        nextWordIndex = measuredWord.next
                    end
                end

                var nextIndex = hashEntry.nextIndex
                var emptyEntry: layout.MeasureTextCacheItem
                emptyEntry.measuredWordsStartIndex = -1
                self.measureTextHashMapInternal:set(elementIndex, emptyEntry)
                self.measureTextHashMapInternalFreeList:add(elementIndex)
                if elementIndexPrevious == 0 then
                    self.measureTextHashMap.internalArray[hashBucket] = nextIndex
                else
                    var prev = self.measureTextHashMapInternal:get(elementIndexPrevious)
                    if prev ~= nil then
                        prev.nextIndex = nextIndex
                    end
                end
                elementIndex = nextIndex
            else
                elementIndexPrevious = elementIndex
                elementIndex = hashEntry.nextIndex
            end
        else
            break
        end
    end

    var newItemIndex: int32 = 0
    var newCacheItem: layout.MeasureTextCacheItem
    newCacheItem.measuredWordsStartIndex = -1
    newCacheItem.nextIndex = 0
    newCacheItem.id = id
    newCacheItem.generation = self.generation
    newCacheItem.minWidth = 0
    newCacheItem.unwrappedDimensions.width = 0
    newCacheItem.unwrappedDimensions.height = 0
    newCacheItem.containsNewlines = false

    var measured: &layout.MeasureTextCacheItem = nil
    if self.measureTextHashMapInternalFreeList.length > 0 then
        newItemIndex = self.measureTextHashMapInternalFreeList:getValue(self.measureTextHashMapInternalFreeList.length - 1)
        self.measureTextHashMapInternalFreeList.length = self.measureTextHashMapInternalFreeList.length - 1
        self.measureTextHashMapInternal:set(newItemIndex, newCacheItem)
        measured = self.measureTextHashMapInternal:get(newItemIndex)
    else
        if self.measureTextHashMapInternal.length >= self.measureTextHashMapInternal.capacity - 1 then
            if not self.warningMaxTextMeasureCacheExceeded then
                self.warningMaxTextMeasureCacheExceeded = true
                ui.ReportError(config.ERROR_TYPE_ELEMENTS_CAPACITY_EXCEEDED,
                    config.String { isStaticallyAllocated = true, length = 97, chars = "Text cache hash map capacity exceeded. Increase max elements or cache capacity and reinitialize." })
            end
            return nil
        end
        measured = self.measureTextHashMapInternal:add(newCacheItem)
        newItemIndex = self.measureTextHashMapInternal.length - 1
    end
    if measured == nil then return nil end

    var oneChar: config.StringSlice
    oneChar.length = 1
    oneChar.chars = " "
    oneChar.baseChars = " "
    var spaceWidth: float = 0
    var spaceDims: config.Dimensions
    spaceDims.width = 0
    spaceDims.height = 0
    if measureTextFn(&oneChar, textCfg, measureTextUserData, &spaceDims) ~= 0 then
        spaceWidth = spaceDims.width
    end

    var start: int32 = 0
    var e: int32 = 0
    var lineWidth: float = 0
    var measuredWidth: float = 0
    var measuredHeight: float = 0
    var tempWord: layout.MeasuredWord
    tempWord.next = -1
    var previousWord: &layout.MeasuredWord = &tempWord
    while e < text.length do
        if self.measuredWords.length >= self.measuredWords.capacity - 1 then
            if not self.warningMaxTextMeasureCacheExceeded then
                self.warningMaxTextMeasureCacheExceeded = true
                ui.ReportError(config.ERROR_TYPE_TEXT_MEASUREMENT_CAPACITY_EXCEEDED,
                    config.String { isStaticallyAllocated = true, length = 88, chars = "Measured words cache capacity exceeded. Increase max measure text cache word count." })
            end
            return nil
        end
        var current = text.chars[e]
        if current == 32 or current == 10 then
            var length = e - start
            var dimensions: config.Dimensions
            dimensions.width = 0
            dimensions.height = 0
            if length > 0 then
                var s: config.StringSlice
                s.length = length
                s.chars = &text.chars[start]
                s.baseChars = text.chars
                if measureTextFn(&s, textCfg, measureTextUserData, &dimensions) == 0 then
                    dimensions.width = 0
                    dimensions.height = 0
                end
            end
            if dimensions.width > measured.minWidth then
                measured.minWidth = dimensions.width
            end
            if dimensions.height > measuredHeight then
                measuredHeight = dimensions.height
            end
            if current == 32 then
                dimensions.width = dimensions.width + spaceWidth
                var w: layout.MeasuredWord
                w.startOffset = start
                w.length = length + 1
                w.width = dimensions.width
                w.next = -1
                previousWord = self:addMeasuredWord(w, previousWord)
                lineWidth = lineWidth + dimensions.width
            end
            if current == 10 then
                if length > 0 then
                    var w1: layout.MeasuredWord
                    w1.startOffset = start
                    w1.length = length
                    w1.width = dimensions.width
                    w1.next = -1
                    previousWord = self:addMeasuredWord(w1, previousWord)
                end
                var w2: layout.MeasuredWord
                w2.startOffset = e + 1
                w2.length = 0
                w2.width = 0
                w2.next = -1
                previousWord = self:addMeasuredWord(w2, previousWord)
                lineWidth = lineWidth + dimensions.width
                if lineWidth > measuredWidth then
                    measuredWidth = lineWidth
                end
                measured.containsNewlines = true
                lineWidth = 0
            end
            start = e + 1
        end
        e = e + 1
    end

    if e - start > 0 then
        var s: config.StringSlice
        s.length = e - start
        s.chars = &text.chars[start]
        s.baseChars = text.chars
        var dimensions: config.Dimensions
        dimensions.width = 0
        dimensions.height = 0
        if measureTextFn(&s, textCfg, measureTextUserData, &dimensions) == 0 then
            dimensions.width = 0
            dimensions.height = 0
        end
        var w: layout.MeasuredWord
        w.startOffset = start
        w.length = e - start
        w.width = dimensions.width
        w.next = -1
        self:addMeasuredWord(w, previousWord)
        lineWidth = lineWidth + dimensions.width
        if dimensions.height > measuredHeight then
            measuredHeight = dimensions.height
        end
        if dimensions.width > measured.minWidth then
            measured.minWidth = dimensions.width
        end
    end

    if lineWidth > measuredWidth then
        measuredWidth = lineWidth
    end
    measuredWidth = measuredWidth - [float](textCfg.letterSpacing)
    measured.measuredWordsStartIndex = tempWord.next
    measured.unwrappedDimensions.width = measuredWidth
    measured.unwrappedDimensions.height = measuredHeight

    if elementIndexPrevious ~= 0 then
        var prev = self.measureTextHashMapInternal:get(elementIndexPrevious)
        if prev ~= nil then
            prev.nextIndex = newItemIndex
        end
    else
        self.measureTextHashMap.internalArray[hashBucket] = newItemIndex
    end
    return measured
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

terra ui.Context:storePaintConfig(cfg: config.PaintConfig) : &config.PaintConfig
    if self.maxElementsExceeded then return nil end
    var stored = cfg
    if cfg.count > 0 then
        if cfg.ops == nil then return nil end
        var count = [int32](cfg.count)
        if self.paintOps.length + count > self.paintOps.capacity then
            self.maxElementsExceeded = true
            return nil
        end
        var dst = &self.paintOps.internalArray[self.paintOps.length]
        var i: int32 = 0
        while i < count do
            dst[i] = cfg.ops[i]
            i = i + 1
        end
        self.paintOps.length = self.paintOps.length + count
        stored.ops = dst
    end
    return self.paintConfigs:add(stored)
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
        if not self.maxElementsExceeded then
            ui.ReportError(config.ERROR_TYPE_ELEMENTS_CAPACITY_EXCEEDED,
                config.String { isStaticallyAllocated = true, length = 73, chars = "Element capacity exceeded. Increase max element count and reinitialize context." })
        end
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
        self:registerElementId(added.id, idx)
    end
    
    self.layoutElementClipElementIds:set(idx, 0)
end

terra ui.Context:openElementWithId(elementId: hash.ElementId)
    if self.layoutElements.length >= self.layoutElements.capacity - 1 or self.maxElementsExceeded then
        if not self.maxElementsExceeded then
            ui.ReportError(config.ERROR_TYPE_ELEMENTS_CAPACITY_EXCEEDED,
                config.String { isStaticallyAllocated = true, length = 73, chars = "Element capacity exceeded. Increase max element count and reinitialize context." })
        end
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
    self:registerElementId(elementId.id, idx)
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
    var elementHasClipHorizontal = false
    var elementHasClipVertical = false
    var cfgIdx: int32 = 0
    while cfgIdx < openElem.elementConfigs.length do
        if openElem.elementConfigs.internalArray ~= nil then
            var cfg = &openElem.elementConfigs.internalArray[cfgIdx]
            if cfg.configType == config.CONFIG_CLIP and cfg.config.clipConfig ~= nil then
                elementHasClipHorizontal = cfg.config.clipConfig.horizontal
                elementHasClipVertical = cfg.config.clipConfig.vertical
                break
            end
        end
        cfgIdx = cfgIdx + 1
    end
    
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
                if not elementHasClipHorizontal then
                    openElem.minDimensions.width = openElem.minDimensions.width + child.minDimensions.width
                end
                if not elementHasClipVertical then
                    openElem.minDimensions.height = max_f(openElem.minDimensions.height, child.minDimensions.height + topBottomPadding)
                end
            end
            self.layoutElementChildren:add(childIdx)
        end
        
        var childGap: float = [float](max_i(childCount - 1, 0) * layoutCfg.childGap)
        openElem.dimensions.width = openElem.dimensions.width + childGap
        if not elementHasClipHorizontal then
            openElem.minDimensions.width = openElem.minDimensions.width + childGap
        end
        
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
                if not elementHasClipVertical then
                    openElem.minDimensions.height = openElem.minDimensions.height + child.minDimensions.height
                end
                if not elementHasClipHorizontal then
                    openElem.minDimensions.width = max_f(openElem.minDimensions.width, child.minDimensions.width + leftRightPadding)
                end
            end
            self.layoutElementChildren:add(childIdx)
        end
        
        var childGap: float = [float](max_i(childCount - 1, 0) * layoutCfg.childGap)
        openElem.dimensions.height = openElem.dimensions.height + childGap
        if not elementHasClipVertical then
            openElem.minDimensions.height = openElem.minDimensions.height + childGap
        end
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

terra ui.BeginLayoutForContext(ctx: &ui.Context, width: float, height: float)
    if ctx ~= nil then
        ctx:beginLayout(width, height)
    end
end

terra ui.BeginLayout(width: float, height: float)
    ui.BeginLayoutForContext(ui.GetCurrentContext(), width, height)
end

terra ui.OpenElementForContext(ctx: &ui.Context)
    if ctx ~= nil then
        ctx:openElement()
    end
end

terra ui.OpenElement()
    ui.OpenElementForContext(ui.GetCurrentContext())
end

terra ui.OpenElementWithIdForContext(ctx: &ui.Context, elementId: hash.ElementId)
    if ctx ~= nil then
        ctx:openElementWithId(elementId)
    end
end

terra ui.OpenElementWithId(elementId: hash.ElementId)
    ui.OpenElementWithIdForContext(ui.GetCurrentContext(), elementId)
end

terra ui.ConfigureOpenElementBoxForContext(ctx: &ui.Context, width: float, height: float, layoutDirection: config.LayoutDirection, padding: uint16, childGap: uint16, r: float, g: float, b: float, a: float)
    if ctx == nil then return end

    var elem = ctx:getOpenLayoutElement()
    if elem == nil then return end

    var lc: config.LayoutConfig
    lc.sizing.width.type = config.SIZING_FIXED
    lc.sizing.width.size.min = width
    lc.sizing.width.size.max = width
    lc.sizing.width.percent = 0
    lc.sizing.height.type = config.SIZING_FIXED
    lc.sizing.height.size.min = height
    lc.sizing.height.size.max = height
    lc.sizing.height.percent = 0
    lc.padding.left = padding
    lc.padding.right = padding
    lc.padding.top = padding
    lc.padding.bottom = padding
    lc.childGap = childGap
    lc.childAlignment.x = config.ALIGN_X_LEFT
    lc.childAlignment.y = config.ALIGN_Y_TOP
    lc.layoutDirection = layoutDirection
    elem.layoutConfig = ctx:storeLayoutConfig(lc)

    var shared: config.SharedConfig
    shared.backgroundColor.r = r
    shared.backgroundColor.g = g
    shared.backgroundColor.b = b
    shared.backgroundColor.a = a
    shared.cornerRadius.topLeft = 8
    shared.cornerRadius.topRight = 8
    shared.cornerRadius.bottomLeft = 8
    shared.cornerRadius.bottomRight = 8
    shared.userData = nil
    var sharedPtr = ctx:storeSharedConfig(shared)
    if sharedPtr ~= nil then
        var cu: config.ElementConfigUnion
        cu.sharedConfig = sharedPtr
        ctx:attachElementConfig(cu, config.CONFIG_SHARED)
    end
end

terra ui.ConfigureOpenElementBox(width: float, height: float, layoutDirection: config.LayoutDirection, padding: uint16, childGap: uint16, r: float, g: float, b: float, a: float)
    ui.ConfigureOpenElementBoxForContext(ui.GetCurrentContext(), width, height, layoutDirection, padding, childGap, r, g, b, a)
end

terra ui.OpenStyledElementForContext(ctx: &ui.Context, width: float, height: float, layoutDirection: config.LayoutDirection, padding: uint16, childGap: uint16, r: float, g: float, b: float, a: float)
    ui.OpenElementForContext(ctx)
    ui.ConfigureOpenElementBoxForContext(ctx, width, height, layoutDirection, padding, childGap, r, g, b, a)
end

terra ui.OpenStyledElement(width: float, height: float, layoutDirection: config.LayoutDirection, padding: uint16, childGap: uint16, r: float, g: float, b: float, a: float)
    ui.OpenStyledElementForContext(ui.GetCurrentContext(), width, height, layoutDirection, padding, childGap, r, g, b, a)
end

terra ui.CloseElementForContext(ctx: &ui.Context)
    if ctx ~= nil then
        ctx:closeElement()
    end
end

terra ui.CloseElement()
    ui.CloseElementForContext(ui.GetCurrentContext())
end

terra ui.Context:openTextElement(text: config.String, textConfig: &config.TextConfig)
    if self.layoutElements.length >= self.layoutElements.capacity - 1 or self.maxElementsExceeded then
        if not self.maxElementsExceeded then
            ui.ReportError(config.ERROR_TYPE_ELEMENTS_CAPACITY_EXCEEDED,
                config.String { isStaticallyAllocated = true, length = 73, chars = "Element capacity exceeded. Increase max element count and reinitialize context." })
        end
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
        self:registerElementId(added.id, idx)
        var textMinWidth: float = 0
        
        if textConfig ~= nil then
            var measureTextFn = self.measureTextFunction
            var measureTextUserData = self.measureTextUserData
            if measureTextFn == nil then
                measureTextFn = ui.measureTextFunction
                measureTextUserData = ui.measureTextUserData
            end
            if measureTextFn ~= nil then
                var cached = self:measureTextCached(&text, textConfig)
                if cached ~= nil then
                    textData.preferredDimensions = cached.unwrappedDimensions
                    textMinWidth = cached.minWidth
                else
                    var slice: string_mod.StringSlice
                    slice.length = text.length
                    slice.chars = text.chars
                    slice.baseChars = text.chars
                    textData.preferredDimensions.width = 0
                    textData.preferredDimensions.height = 0
                    if measureTextFn(&slice, textConfig, measureTextUserData, &textData.preferredDimensions) ~= 0 then
                        textMinWidth = textData.preferredDimensions.width
                    end
                end

                var wrappedLine: layout.WrappedTextLine
                wrappedLine.dimensions = textData.preferredDimensions
                wrappedLine.line = text
                var wrappedLinePtr = self.wrappedTextLines:add(wrappedLine)
                if wrappedLinePtr ~= nil then
                    textData.wrappedLines.internalArray = wrappedLinePtr
                    textData.wrappedLines.length = 1
                end
            else
                textMinWidth = textData.preferredDimensions.width
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
            added.minDimensions.width = textMinWidth
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

terra ui.OpenTextElementForContext(ctx: &ui.Context, text: config.String, textConfig: &config.TextConfig)
    if ctx ~= nil then
        ctx:openTextElement(text, textConfig)
    end
end

terra ui.OpenTextElement(text: config.String, textConfig: &config.TextConfig)
    ui.OpenTextElementForContext(ui.GetCurrentContext(), text, textConfig)
end

terra ui.StringFromChars(chars: &int8, length: int32) : config.String
    var s: config.String
    s.isStaticallyAllocated = true
    s.length = length
    s.chars = chars
    return s
end

terra ui.GetElementIdFromChars(chars: &int8, length: int32) : hash.ElementId
    return hash.HashString(ui.StringFromChars(chars, length), 0)
end

terra ui.GetElementIdWithIndexFromChars(chars: &int8, length: int32, index: uint32) : hash.ElementId
    return hash.HashStringWithOffset(ui.StringFromChars(chars, length), index, 0)
end

terra ui.OpenElementWithIdCharsForContext(ctx: &ui.Context, chars: &int8, length: int32)
    ui.OpenElementWithIdForContext(ctx, ui.GetElementIdFromChars(chars, length))
end

terra ui.OpenElementWithIdChars(chars: &int8, length: int32)
    ui.OpenElementWithIdCharsForContext(ui.GetCurrentContext(), chars, length)
end

terra ui.OpenTextElementWithLengthForContext(ctx: &ui.Context, chars: &int8, length: int32, textConfig: &config.TextConfig)
    ui.OpenTextElementForContext(ctx, ui.StringFromChars(chars, length), textConfig)
end

terra ui.OpenTextElementWithLength(chars: &int8, length: int32, textConfig: &config.TextConfig)
    ui.OpenTextElementWithLengthForContext(ui.GetCurrentContext(), chars, length, textConfig)
end

terra ui.SetOpenElementLayoutConfigForContext(ctx: &ui.Context, cfg: config.LayoutConfig) : bool
    if ctx == nil then return false end
    var elem = ctx:getOpenLayoutElement()
    if elem == nil then return false end
    var layoutCfg = ctx:storeLayoutConfig(cfg)
    if layoutCfg == nil then return false end
    elem.layoutConfig = layoutCfg
    return true
end

terra ui.SetOpenElementLayoutConfig(cfg: config.LayoutConfig) : bool
    return ui.SetOpenElementLayoutConfigForContext(ui.GetCurrentContext(), cfg)
end

terra ui.AttachSharedConfigForContext(ctx: &ui.Context, cfg: config.SharedConfig) : bool
    if ctx == nil then return false end
    var sharedCfg = ctx:storeSharedConfig(cfg)
    if sharedCfg == nil then return false end
    var cfgUnion: config.ElementConfigUnion
    cfgUnion.sharedConfig = sharedCfg
    return ctx:attachElementConfig(cfgUnion, config.CONFIG_SHARED) ~= nil
end

terra ui.AttachSharedConfig(cfg: config.SharedConfig) : bool
    return ui.AttachSharedConfigForContext(ui.GetCurrentContext(), cfg)
end

terra ui.AttachBorderConfigForContext(ctx: &ui.Context, cfg: config.BorderConfig) : bool
    if ctx == nil then return false end
    var borderCfg = ctx:storeBorderConfig(cfg)
    if borderCfg == nil then return false end
    var cfgUnion: config.ElementConfigUnion
    cfgUnion.borderConfig = borderCfg
    return ctx:attachElementConfig(cfgUnion, config.CONFIG_BORDER) ~= nil
end

terra ui.AttachBorderConfig(cfg: config.BorderConfig) : bool
    return ui.AttachBorderConfigForContext(ui.GetCurrentContext(), cfg)
end

terra ui.AttachClipConfigForContext(ctx: &ui.Context, cfg: config.ClipConfig) : bool
    if ctx == nil then return false end
    var clipCfg = ctx:storeClipConfig(cfg)
    if clipCfg == nil then return false end
    var cfgUnion: config.ElementConfigUnion
    cfgUnion.clipConfig = clipCfg
    return ctx:attachElementConfig(cfgUnion, config.CONFIG_CLIP) ~= nil
end

terra ui.AttachClipConfig(cfg: config.ClipConfig) : bool
    return ui.AttachClipConfigForContext(ui.GetCurrentContext(), cfg)
end

terra ui.AttachFloatingConfigForContext(ctx: &ui.Context, cfg: config.FloatingConfig) : bool
    if ctx == nil then return false end
    var floatingCfg = ctx:storeFloatingConfig(cfg)
    if floatingCfg == nil then return false end
    var cfgUnion: config.ElementConfigUnion
    cfgUnion.floatingConfig = floatingCfg
    return ctx:attachElementConfig(cfgUnion, config.CONFIG_FLOATING) ~= nil
end

terra ui.AttachFloatingConfig(cfg: config.FloatingConfig) : bool
    return ui.AttachFloatingConfigForContext(ui.GetCurrentContext(), cfg)
end

terra ui.AttachAspectRatioConfigForContext(ctx: &ui.Context, cfg: config.AspectRatioConfig) : bool
    if ctx == nil then return false end
    var aspectCfg = ctx:storeAspectRatioConfig(cfg)
    if aspectCfg == nil then return false end
    var cfgUnion: config.ElementConfigUnion
    cfgUnion.aspectRatioConfig = aspectCfg
    return ctx:attachElementConfig(cfgUnion, config.CONFIG_ASPECT) ~= nil
end

terra ui.AttachAspectRatioConfig(cfg: config.AspectRatioConfig) : bool
    return ui.AttachAspectRatioConfigForContext(ui.GetCurrentContext(), cfg)
end

terra ui.AttachImageConfigForContext(ctx: &ui.Context, cfg: config.ImageConfig) : bool
    if ctx == nil then return false end
    var imageCfg = ctx:storeImageConfig(cfg)
    if imageCfg == nil then return false end
    var cfgUnion: config.ElementConfigUnion
    cfgUnion.imageConfig = imageCfg
    return ctx:attachElementConfig(cfgUnion, config.CONFIG_IMAGE) ~= nil
end

terra ui.AttachImageConfig(cfg: config.ImageConfig) : bool
    return ui.AttachImageConfigForContext(ui.GetCurrentContext(), cfg)
end

terra ui.AttachCustomConfigForContext(ctx: &ui.Context, cfg: config.CustomConfig) : bool
    if ctx == nil then return false end
    var customCfg = ctx:storeCustomConfig(cfg)
    if customCfg == nil then return false end
    var cfgUnion: config.ElementConfigUnion
    cfgUnion.customConfig = customCfg
    return ctx:attachElementConfig(cfgUnion, config.CONFIG_CUSTOM) ~= nil
end

terra ui.AttachCustomConfig(cfg: config.CustomConfig) : bool
    return ui.AttachCustomConfigForContext(ui.GetCurrentContext(), cfg)
end

terra ui.AttachPaintConfigForContext(ctx: &ui.Context, cfg: config.PaintConfig) : bool
    if ctx == nil then return false end
    var paintCfg = ctx:storePaintConfig(cfg)
    if paintCfg == nil then return false end
    var cfgUnion: config.ElementConfigUnion
    cfgUnion.paintConfig = paintCfg
    return ctx:attachElementConfig(cfgUnion, config.CONFIG_PAINT) ~= nil
end

terra ui.AttachPaintConfig(cfg: config.PaintConfig) : bool
    return ui.AttachPaintConfigForContext(ui.GetCurrentContext(), cfg)
end

terra ui.GetElementId(idString: config.String) : hash.ElementId
    return hash.HashString(idString, 0)
end

terra ui.GetElementIdWithIndex(idString: config.String, index: uint32) : hash.ElementId
    return hash.HashStringWithOffset(idString, index, 0)
end

terra ui.SetMeasureTextFunction(measureTextFunction: MeasureTextFnType, userData: &opaque)
    ui.measureTextFunction = measureTextFunction
    ui.measureTextUserData = userData
    var ctx = ui.GetCurrentContext()
    if ctx ~= nil then
        ctx.measureTextFunction = measureTextFunction
        ctx.measureTextUserData = userData
    end
end

terra ui.SetErrorHandler(errorHandlerFunction: ErrorHandlerFnType, userData: &opaque)
    ui.errorHandlerFunction = errorHandlerFunction
    ui.errorHandlerUserData = userData
end

terra ui.ReportError(errorType: uint8, errorText: config.String)
    if ui.errorHandlerFunction ~= nil then
        var d: config.ErrorData
        d.errorType = errorType
        d.errorText = errorText
        d.userData = ui.errorHandlerUserData
        ui.errorHandlerFunction(&d)
    end
end

terra ui.SetQueryScrollOffsetFunction(queryScrollOffsetFunction: QueryScrollOffsetFnType, userData: &opaque)
    ui.queryScrollOffsetFunction = queryScrollOffsetFunction
    ui.queryScrollOffsetUserData = userData
end

terra ui.SetLayoutDimensionsForContext(ctx: &ui.Context, dimensions: config.Dimensions)
    if ctx ~= nil then
        ctx.layoutDimensions = dimensions
    end
end

terra ui.SetLayoutDimensions(dimensions: config.Dimensions)
    ui.SetLayoutDimensionsForContext(ui.GetCurrentContext(), dimensions)
end

terra ui.GetMaxElementCount() : int32
    var ctx = ui.GetCurrentContext()
    if ctx ~= nil then
        return ctx.maxElementCount
    end
    return ui.defaultMaxElementCount
end

terra ui.SetMaxElementCount(maxElementCount: int32)
    var v = maxElementCount
    if v < 1 then v = 1 end
    var ctx = ui.GetCurrentContext()
    if ctx ~= nil then
        ctx.maxElementCount = v
    else
        ui.defaultMaxElementCount = v
        ui.defaultMaxMeasureTextWordCacheCount = v * 2
    end
end

ui.EPSILON = 0.01

terra ui.FloatEqual(a: float, b: float) : bool
    var diff = a - b
    return diff < ui.EPSILON and diff > -ui.EPSILON
end

terra ui.clamp(val: float, minVal: float, maxVal: float) : float
    var out = val
    if out < minVal then
        out = minVal
    end
    if out > maxVal then
        out = maxVal
    end
    return out
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

terra ui.Context:decodeElementConfigs(elem: &layout.LayoutElement) : DecodedElementConfigs
    var out: DecodedElementConfigs
    out.text = nil
    out.border = nil
    out.floating = nil
    out.clip = nil
    out.aspect = nil
    out.image = nil
    out.custom = nil
    out.shared = nil
    out.paint = nil
    if elem == nil or elem.elementConfigs.internalArray == nil then
        return out
    end

    var i: int32 = 0
    while i < elem.elementConfigs.length do
        var c = &elem.elementConfigs.internalArray[i]
        if c.configType == config.CONFIG_TEXT then
            out.text = c.config.textConfig
        elseif c.configType == config.CONFIG_BORDER then
            out.border = c.config.borderConfig
        elseif c.configType == config.CONFIG_FLOATING then
            out.floating = c.config.floatingConfig
        elseif c.configType == config.CONFIG_CLIP then
            out.clip = c.config.clipConfig
        elseif c.configType == config.CONFIG_ASPECT then
            out.aspect = c.config.aspectRatioConfig
        elseif c.configType == config.CONFIG_IMAGE then
            out.image = c.config.imageConfig
        elseif c.configType == config.CONFIG_CUSTOM then
            out.custom = c.config.customConfig
        elseif c.configType == config.CONFIG_SHARED then
            out.shared = c.config.sharedConfig
        elseif c.configType == config.CONFIG_PAINT then
            out.paint = c.config.paintConfig
        end
        i = i + 1
    end
    return out
end

terra ui.ElementIsOffscreen(ctx: &ui.Context, box: &config.BoundingBox) : bool
    return (box.x > ctx.layoutDimensions.width) or
           (box.y > ctx.layoutDimensions.height) or
           (box.x + box.width < 0) or
           (box.y + box.height < 0)
end

terra ui.SetDisableCulling(disable: bool)
    ui.disableCulling = disable
end

terra ui.SetCullingEnabled(enabled: bool)
    ui.disableCulling = not enabled
end

terra ui.SetDebugModeEnabled(enabled: bool)
    ui.debugModeEnabled = enabled
end

terra ui.IsDebugModeEnabled() : bool
    return ui.debugModeEnabled
end

terra ui.SetExternalScrollHandlingEnabled(enabled: bool)
    ui.externalScrollHandlingEnabled = enabled
end

terra ui.MinMemorySize() : uint64
    var ctx = ui.GetCurrentContext()
    var maxElements = ui.defaultMaxElementCount
    if ctx ~= nil and ctx.maxElementCount > 0 then
        maxElements = ctx.maxElementCount
    end
    if maxElements <= 0 then
        maxElements = 1
    end
    var maxMeasureWords = ui.defaultMaxMeasureTextWordCacheCount
    if ctx ~= nil and ctx.maxMeasureTextCacheWordCount > 0 then
        maxMeasureWords = ctx.maxMeasureTextCacheWordCount
    end
    if maxMeasureWords <= 0 then
        maxMeasureWords = 1
    end

    var total: uint64 = 0
    var allocations: int32 = 0

    total = total + uint64(maxElements) * uint64(sizeof(layout.LayoutElement)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(config.RenderCommand)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(int32)); allocations = allocations + 1
    total = total + uint64(maxElements * 4) * uint64(sizeof(int32)); allocations = allocations + 1
    total = total + uint64(maxElements * 4) * uint64(sizeof(int32)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(layout.TextElementData)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(int32)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(int32)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(config.LayoutConfig)); allocations = allocations + 1
    total = total + uint64(maxElements * 8) * uint64(sizeof(config.ElementConfig)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(config.TextConfig)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(config.AspectRatioConfig)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(config.ImageConfig)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(config.FloatingConfig)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(config.ClipConfig)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(config.CustomConfig)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(config.BorderConfig)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(config.SharedConfig)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(config.PaintConfig)); allocations = allocations + 1
    total = total + uint64(maxElements * 16) * uint64(sizeof(config.PaintOp)); allocations = allocations + 1
    total = total + uint64(maxElements * 8) * uint64(sizeof(layout.WrappedTextLine)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(layout.LayoutElementTreeRoot)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(layout.LayoutElementTreeNode)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(string_mod.String)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(layout.ScrollContainerDataInternal)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(layout.MeasureTextCacheItem)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(int32)); allocations = allocations + 1
    var hashBuckets = maxElements
    if maxMeasureWords / 32 > hashBuckets then
        hashBuckets = maxMeasureWords / 32
    end
    if hashBuckets < 1 then hashBuckets = 1 end
    total = total + uint64(hashBuckets) * uint64(sizeof(int32)); allocations = allocations + 1
    total = total + uint64(maxMeasureWords) * uint64(sizeof(layout.MeasuredWord)); allocations = allocations + 1
    total = total + uint64(maxMeasureWords) * uint64(sizeof(int32)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(uint32)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(uint32)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(uint32)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(uint32)); allocations = allocations + 1
    total = total + uint64(maxElements * 4) * uint64(sizeof(uint32)); allocations = allocations + 1
    total = total + uint64(maxElements * 4) * uint64(sizeof(int32)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(config.BoundingBox)); allocations = allocations + 1
    total = total + uint64(maxElements) * uint64(sizeof(bool)); allocations = allocations + 1

    -- arena allocations are 64-byte aligned; reserve worst-case padding per allocation
    total = total + uint64(allocations) * 64 + 128
    return total
end

terra ui.GetMaxMeasureTextCacheWordCount() : int32
    var ctx = ui.GetCurrentContext()
    if ctx ~= nil then
        return ctx.maxMeasureTextCacheWordCount
    end
    return ui.defaultMaxMeasureTextWordCacheCount
end

terra ui.SetMaxMeasureTextCacheWordCount(maxMeasureTextCacheWordCount: int32)
    var v = maxMeasureTextCacheWordCount
    if v < 1 then v = 1 end
    var ctx = ui.GetCurrentContext()
    if ctx ~= nil then
        ctx.maxMeasureTextCacheWordCount = v
    else
        ui.defaultMaxMeasureTextWordCacheCount = v
    end
end

terra ui.ResetMeasureTextCache()
    var ctx = ui.GetCurrentContext()
    if ctx == nil then return end
    ctx.measureTextHashMapInternal.length = 0
    ctx.measureTextHashMapInternalFreeList.length = 0
    ctx.measuredWords.length = 0
    ctx.measuredWordsFreeList.length = 0
    ctx.measureTextHashMap.length = ctx.measureTextHashMap.capacity
    var i: int32 = 0
    while i < ctx.measureTextHashMap.length do
        ctx.measureTextHashMap.internalArray[i] = 0
        i = i + 1
    end
    ctx.measureTextHashMapInternal.length = 1
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

terra ui.Context:applyAspectRatiosVertical()
    var i: int32 = 0
    while i < self.layoutElements.length do
        var elem = self.layoutElements:get(i)
        if elem ~= nil then
            var aspectCfgResult = ui.FindElementConfigWithType(elem, config.CONFIG_ASPECT)
            if aspectCfgResult ~= nil and aspectCfgResult.config.aspectRatioConfig ~= nil then
                var ratio = aspectCfgResult.config.aspectRatioConfig.aspectRatio
                if ratio > ui.EPSILON and elem.layoutConfig ~= nil then
                    elem.dimensions.height = elem.dimensions.width / ratio
                    elem.layoutConfig.sizing.height.size.max = elem.dimensions.height
                end
            end
        end
        i = i + 1
    end
end

terra ui.Context:applyAspectRatiosHorizontal()
    var i: int32 = 0
    while i < self.layoutElements.length do
        var elem = self.layoutElements:get(i)
        if elem ~= nil then
            var aspectCfgResult = ui.FindElementConfigWithType(elem, config.CONFIG_ASPECT)
            if aspectCfgResult ~= nil and aspectCfgResult.config.aspectRatioConfig ~= nil then
                var ratio = aspectCfgResult.config.aspectRatioConfig.aspectRatio
                if ratio > ui.EPSILON and elem.layoutConfig ~= nil then
                    elem.dimensions.width = ratio * elem.dimensions.height
                end
            end
        end
        i = i + 1
    end
end

terra ui.Context:wrapTextElements()
    var textElementIndex: int32 = 0
    while textElementIndex < self.textElementData.length do
        var textElementData = self.textElementData:get(textElementIndex)
        if textElementData ~= nil then
            var previousWrapped = textElementData.wrappedLines
            textElementData.wrappedLines.length = 0
            if self.wrappedTextLines.length < self.wrappedTextLines.capacity then
                textElementData.wrappedLines.internalArray = &self.wrappedTextLines.internalArray[self.wrappedTextLines.length]
            else
                textElementData.wrappedLines.internalArray = nil
            end
            var containerElement = self.layoutElements:get(textElementData.elementIndex)
            if containerElement ~= nil then
                var textCfgResult = ui.FindElementConfigWithType(containerElement, config.CONFIG_TEXT)
                if textCfgResult ~= nil and textCfgResult.config.textConfig ~= nil then
                    var textCfg = textCfgResult.config.textConfig
                    var measureTextCacheItem = self:measureTextCached(&textElementData.text, textCfg)
                    if measureTextCacheItem ~= nil then
                        var lineWidth: float = 0
                        var lineHeight: float = textElementData.preferredDimensions.height
                        if textCfg.lineHeight > 0 then
                            lineHeight = [float](textCfg.lineHeight)
                        end
                        var lineLengthChars: int32 = 0
                        var lineStartOffset: int32 = 0

                        if (not measureTextCacheItem.containsNewlines) and
                            textElementData.preferredDimensions.width <= containerElement.dimensions.width then
                            if self.wrappedTextLines.length < self.wrappedTextLines.capacity then
                                var single: layout.WrappedTextLine
                                single.dimensions = containerElement.dimensions
                                single.line = textElementData.text
                                self.wrappedTextLines:add(single)
                                textElementData.wrappedLines.length = textElementData.wrappedLines.length + 1
                            end
                        else
                            var oneChar: config.StringSlice
                            oneChar.length = 1
                            oneChar.chars = " "
                            oneChar.baseChars = " "
                            var measureTextFn = self.measureTextFunction
                            var measureTextUserData = self.measureTextUserData
                            if measureTextFn == nil then
                                measureTextFn = ui.measureTextFunction
                                measureTextUserData = ui.measureTextUserData
                            end
                            var spaceWidth: float = 0
                            var spaceDims: config.Dimensions
                            spaceDims.width = 0
                            spaceDims.height = 0
                            if measureTextFn(&oneChar, textCfg, measureTextUserData, &spaceDims) ~= 0 then
                                spaceWidth = spaceDims.width
                            end

                            var wordIndex = measureTextCacheItem.measuredWordsStartIndex
                            while wordIndex ~= -1 do
                                if self.wrappedTextLines.length > self.wrappedTextLines.capacity - 1 then
                                    break
                                end
                                var measuredWord = self.measuredWords:get(wordIndex)
                                if measuredWord == nil then
                                    break
                                end

                                if lineLengthChars == 0 and lineWidth + measuredWord.width > containerElement.dimensions.width then
                                    var line: layout.WrappedTextLine
                                    line.dimensions.width = measuredWord.width
                                    line.dimensions.height = lineHeight
                                    line.line.isStaticallyAllocated = false
                                    line.line.length = measuredWord.length
                                    line.line.chars = &textElementData.text.chars[measuredWord.startOffset]
                                    self.wrappedTextLines:add(line)
                                    textElementData.wrappedLines.length = textElementData.wrappedLines.length + 1
                                    wordIndex = measuredWord.next
                                    lineStartOffset = measuredWord.startOffset + measuredWord.length
                                elseif measuredWord.length == 0 or lineWidth + measuredWord.width > containerElement.dimensions.width then
                                    var charIndex = max_i(lineStartOffset + lineLengthChars - 1, 0)
                                    var finalCharIsSpace = textElementData.text.chars[charIndex] == 32
                                    var trimChars: int32 = 0
                                    if finalCharIsSpace then trimChars = 1 end

                                    var line: layout.WrappedTextLine
                                    line.dimensions.width = lineWidth
                                    if finalCharIsSpace then
                                        line.dimensions.width = line.dimensions.width - spaceWidth
                                    end
                                    line.dimensions.height = lineHeight
                                    line.line.isStaticallyAllocated = false
                                    line.line.length = lineLengthChars - trimChars
                                    line.line.chars = &textElementData.text.chars[lineStartOffset]
                                    self.wrappedTextLines:add(line)
                                    textElementData.wrappedLines.length = textElementData.wrappedLines.length + 1
                                    if lineLengthChars == 0 or measuredWord.length == 0 then
                                        wordIndex = measuredWord.next
                                    end
                                    lineWidth = 0
                                    lineLengthChars = 0
                                    lineStartOffset = measuredWord.startOffset
                                else
                                    lineWidth = lineWidth + measuredWord.width + [float](textCfg.letterSpacing)
                                    lineLengthChars = lineLengthChars + measuredWord.length
                                    wordIndex = measuredWord.next
                                end
                            end

                            if lineLengthChars > 0 and self.wrappedTextLines.length < self.wrappedTextLines.capacity then
                                var line: layout.WrappedTextLine
                                line.dimensions.width = lineWidth - [float](textCfg.letterSpacing)
                                line.dimensions.height = lineHeight
                                line.line.isStaticallyAllocated = false
                                line.line.length = lineLengthChars
                                line.line.chars = &textElementData.text.chars[lineStartOffset]
                                self.wrappedTextLines:add(line)
                                textElementData.wrappedLines.length = textElementData.wrappedLines.length + 1
                            end
                        end

                        containerElement.dimensions.height = lineHeight * [float](textElementData.wrappedLines.length)
                    else
                        -- Preserve pre-populated wrapped lines when no measurement callback is available.
                        textElementData.wrappedLines = previousWrapped
                    end
                end
            end
        end
        textElementIndex = textElementIndex + 1
    end
end

terra ui.Context:propagateHeightChangesToParents()
    var dfsBuffer = self.layoutElementTreeNodeArray1
    dfsBuffer.length = 0
    var i: int32 = 0
    while i < self.layoutElementTreeRoots.length do
        var root = self.layoutElementTreeRoots:get(i)
        if root ~= nil then
            var node: layout.LayoutElementTreeNode
            node.layoutElement = self.layoutElements:get(root.layoutElementIndex)
            node.position.x = 0
            node.position.y = 0
            node.nextChildOffset.x = 0
            node.nextChildOffset.y = 0
            dfsBuffer:add(node)
            self.layoutElementClipElementIds:set(dfsBuffer.length - 1, 0)
        end
        i = i + 1
    end

    while dfsBuffer.length > 0 do
        var idx = dfsBuffer.length - 1
        var currentNode = dfsBuffer:get(idx)
        if currentNode == nil or currentNode.layoutElement == nil then
            dfsBuffer.length = dfsBuffer.length - 1
        else
            var currentElement = currentNode.layoutElement
            var visited = self.layoutElementClipElementIds:getValue(idx) ~= 0
            if not visited then
                self.layoutElementClipElementIds:set(idx, 1)
                if ui.ElementHasConfig(currentElement, config.CONFIG_TEXT) or currentElement.childrenOrTextContent.children.length == 0 then
                    dfsBuffer.length = dfsBuffer.length - 1
                else
                    var c: int32 = 0
                    while c < currentElement.childrenOrTextContent.children.length do
                        var child = self.layoutElements:get(currentElement.childrenOrTextContent.children.elements[c])
                        if child ~= nil then
                            var childNode: layout.LayoutElementTreeNode
                            childNode.layoutElement = child
                            childNode.position.x = 0
                            childNode.position.y = 0
                            childNode.nextChildOffset.x = 0
                            childNode.nextChildOffset.y = 0
                            dfsBuffer:add(childNode)
                            self.layoutElementClipElementIds:set(dfsBuffer.length - 1, 0)
                        end
                        c = c + 1
                    end
                end
            else
                dfsBuffer.length = dfsBuffer.length - 1
                var layoutCfg = currentElement.layoutConfig
                if layoutCfg ~= nil then
                    if layoutCfg.layoutDirection == config.LEFT_TO_RIGHT then
                        var j: int32 = 0
                        while j < currentElement.childrenOrTextContent.children.length do
                            var childElement = self.layoutElements:get(currentElement.childrenOrTextContent.children.elements[j])
                            if childElement ~= nil then
                                var childHeightWithPadding = childElement.dimensions.height + [float](layoutCfg.padding.top + layoutCfg.padding.bottom)
                                if childHeightWithPadding < currentElement.dimensions.height then
                                    childHeightWithPadding = currentElement.dimensions.height
                                end
                                currentElement.dimensions.height = ui.clamp(childHeightWithPadding, layoutCfg.sizing.height.size.min, layoutCfg.sizing.height.size.max)
                            end
                            j = j + 1
                        end
                    elseif layoutCfg.layoutDirection == config.TOP_TO_BOTTOM then
                        var contentHeight: float = [float](layoutCfg.padding.top + layoutCfg.padding.bottom)
                        var j: int32 = 0
                        while j < currentElement.childrenOrTextContent.children.length do
                            var childElement = self.layoutElements:get(currentElement.childrenOrTextContent.children.elements[j])
                            if childElement ~= nil then
                                contentHeight = contentHeight + childElement.dimensions.height
                            end
                            j = j + 1
                        end
                        contentHeight = contentHeight + [float](max_i(currentElement.childrenOrTextContent.children.length - 1, 0) * layoutCfg.childGap)
                        currentElement.dimensions.height = ui.clamp(contentHeight, layoutCfg.sizing.height.size.min, layoutCfg.sizing.height.size.max)
                    end
                end
            end
        end
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
                                if rootElement.layoutConfig.sizing.width.percent > 1.0 and not self.warningPercentageOverOne then
                                    self.warningPercentageOverOne = true
                                    ui.ReportError(config.ERROR_TYPE_PERCENTAGE_OVER_1,
                                        config.String { isStaticallyAllocated = true, length = 72, chars = "Sizing percent value over 1.0 detected. Percent values are expected in [0,1]." })
                                end
                                rootElement.dimensions.width = self.layoutDimensions.width * rootElement.layoutConfig.sizing.width.percent
                            end
                            if rootElement.layoutConfig.sizing.height.type == config.SIZING_GROW then
                                rootElement.dimensions.height = self.layoutDimensions.height
                            elseif rootElement.layoutConfig.sizing.height.type == config.SIZING_PERCENT then
                                if rootElement.layoutConfig.sizing.height.percent > 1.0 and not self.warningPercentageOverOne then
                                    self.warningPercentageOverOne = true
                                    ui.ReportError(config.ERROR_TYPE_PERCENTAGE_OVER_1,
                                        config.String { isStaticallyAllocated = true, length = 72, chars = "Sizing percent value over 1.0 detected. Percent values are expected in [0,1]." })
                                end
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
                                    if childSizing.percent > 1.0 and not self.warningPercentageOverOne then
                                        self.warningPercentageOverOne = true
                                        ui.ReportError(config.ERROR_TYPE_PERCENTAGE_OVER_1,
                                            config.String { isStaticallyAllocated = true, length = 72, chars = "Sizing percent value over 1.0 detected. Percent values are expected in [0,1]." })
                                    end
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
    self:wrapTextElements()
    self:applyAspectRatiosVertical()
    self:propagateHeightChangesToParents()
    self:sizeContainersAlongAxis(false)
    self:applyAspectRatiosHorizontal()
    
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
    -- Preserve previous-frame hover ids through BeginLayout so DSL/runtime code can
    -- query hover state while emitting the next frame. Recompute the hover set here.
    self.pointerOverIds:clear()
    
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
                var rootDecoded = self:decodeElementConfigs(rootElement)
                if rootDecoded.floating ~= nil then
                    var floatingCfg = rootDecoded.floating
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
                            var foundParent = false
                            var j: int32 = self.renderCommands.length - 1
                            while j >= 0 do
                                var cmd = self.renderCommands:get(j)
                                if cmd ~= nil and cmd.id == parentId then
                                    parentBox = cmd.boundingBox
                                    foundParent = true
                                    break
                                end
                                j = j - 1
                            end
                            if not foundParent and floatingCfg.attachTo == config.ATTACH_ELEMENT_WITH_ID and not self.warningFloatingParentNotFound then
                                self.warningFloatingParentNotFound = true
                                ui.ReportError(config.ERROR_TYPE_FLOATING_CONTAINER_PARENT_NOT_FOUND,
                                    config.String { isStaticallyAllocated = true, length = 92, chars = "Floating element parentId not found. Ensure parent exists and is declared before this floating element." })
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
                            var decoded = self:decodeElementConfigs(currentElement)
                            var visited = self.layoutElementClipElementIds:getValue(currentIdx) ~= 0
                            
                            if not visited then
                                self.layoutElementClipElementIds:set(currentIdx, 1)
                                
                                var boundingBox: config.BoundingBox
                                boundingBox.x = currentElementTreeNode.position.x
                                boundingBox.y = currentElementTreeNode.position.y
                                boundingBox.width = currentElement.dimensions.width
                                boundingBox.height = currentElement.dimensions.height

                                var currentElementIndex = self:findElementIndexById(currentElement.id)
                                if currentElementIndex >= 0 and currentElementIndex < self.elementBoundingBoxes.capacity then
                                    self.elementBoundingBoxes.internalArray[currentElementIndex] = boundingBox
                                    self.elementBoundingBoxValid.internalArray[currentElementIndex] = true
                                end

                                if ui.PointInsideBox(self.pointerInfo.position, boundingBox) then
                                    if self.pointerOverIds.length < self.pointerOverIds.capacity then
                                        self.pointerOverIds:add(currentElement.id)
                                    end
                                end
                                
                                var emitRectangle = false
                                if decoded.shared ~= nil and decoded.shared.backgroundColor.a > 0 then
                                    emitRectangle = true
                                end
                                
                                var offscreen = (not ui.disableCulling) and ui.ElementIsOffscreen(self, &boundingBox)
                                
                                if not offscreen then
                                    if decoded.clip ~= nil then
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
                                            newScroll.scrollPosition.x = decoded.clip.childOffset.x
                                            newScroll.scrollPosition.y = decoded.clip.childOffset.y
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
                                                var outOffset: config.Vector2
                                                outOffset.x = 0
                                                outOffset.y = 0
                                                if ui.queryScrollOffsetFunction(currentElement.id, ui.queryScrollOffsetUserData, &outOffset) ~= 0 then
                                                    scrollData.scrollPosition = outOffset
                                                else
                                                    scrollData.scrollPosition = decoded.clip.childOffset
                                                end
                                            else
                                                scrollData.scrollPosition = decoded.clip.childOffset
                                            end
                                        end
                                    end

                                    if decoded.clip ~= nil then
                                        var cmd: config.RenderCommand
                                        cmd.boundingBox = boundingBox
                                        cmd.id = currentElement.id
                                        cmd.commandType = config.RENDER_SCISSOR_START
                                        cmd.zIndex = root.zIndex
                                        cmd.renderData.clip.horizontal = decoded.clip.horizontal
                                        cmd.renderData.clip.vertical = decoded.clip.vertical
                                        if self.renderCommands.length < self.renderCommands.capacity then
                                            self.renderCommands:add(cmd)
                                        end
                                    end

                                    if decoded.image ~= nil then
                                        var cmd: config.RenderCommand
                                        cmd.boundingBox = boundingBox
                                        cmd.id = currentElement.id
                                        cmd.commandType = config.RENDER_IMAGE
                                        cmd.zIndex = root.zIndex
                                        cmd.renderData.image.imageData = decoded.image.imageData
                                        if decoded.shared ~= nil then
                                            cmd.renderData.image.backgroundColor = decoded.shared.backgroundColor
                                            cmd.renderData.image.cornerRadius = decoded.shared.cornerRadius
                                        end
                                        if self.renderCommands.length < self.renderCommands.capacity then
                                            self.renderCommands:add(cmd)
                                        end
                                        emitRectangle = false
                                    end

                                    if decoded.custom ~= nil then
                                        var cmd: config.RenderCommand
                                        cmd.boundingBox = boundingBox
                                        cmd.id = currentElement.id
                                        cmd.commandType = config.RENDER_CUSTOM
                                        cmd.zIndex = root.zIndex
                                        cmd.renderData.custom.customData = decoded.custom.customData
                                        if decoded.shared ~= nil then
                                            cmd.renderData.custom.backgroundColor = decoded.shared.backgroundColor
                                            cmd.renderData.custom.cornerRadius = decoded.shared.cornerRadius
                                        end
                                        if self.renderCommands.length < self.renderCommands.capacity then
                                            self.renderCommands:add(cmd)
                                        end
                                        emitRectangle = false
                                    end

                                    if emitRectangle then
                                        var cmd: config.RenderCommand
                                        cmd.boundingBox = boundingBox
                                        cmd.id = currentElement.id
                                        cmd.commandType = config.RENDER_RECTANGLE
                                        cmd.zIndex = root.zIndex
                                        
                                        if decoded.shared ~= nil then
                                            cmd.renderData.rectangle.backgroundColor = decoded.shared.backgroundColor
                                            cmd.renderData.rectangle.cornerRadius = decoded.shared.cornerRadius
                                            cmd.userData = decoded.shared.userData
                                        end
                                        
                                        if self.renderCommands.length < self.renderCommands.capacity then
                                            self.renderCommands:add(cmd)
                                        end
                                    end

                                    if decoded.paint ~= nil then
                                        var cmd: config.RenderCommand
                                        cmd.boundingBox = boundingBox
                                        cmd.id = currentElement.id
                                        cmd.commandType = config.RENDER_PAINT
                                        cmd.zIndex = root.zIndex
                                        cmd.renderData.paint.ops = decoded.paint.ops
                                        cmd.renderData.paint.count = decoded.paint.count
                                        if self.renderCommands.length < self.renderCommands.capacity then
                                            self.renderCommands:add(cmd)
                                        end
                                    end
                                    
                                    if decoded.text ~= nil then
                                            var textCfg = decoded.text
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
                                
                                if decoded.text == nil then
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
                                
                                if decoded.text == nil then
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
                                                childNode.position.x = 0
                                                childNode.position.y = 0
                                                childNode.nextChildOffset.x = [float](childElement.layoutConfig.padding.left)
                                                childNode.nextChildOffset.y = [float](childElement.layoutConfig.padding.top)
                                                
                                                var scrollOffsetX: float = 0
                                                var scrollOffsetY: float = 0
                                                if decoded.clip ~= nil then
                                                    if not ui.externalScrollHandlingEnabled then
                                                        scrollOffsetX = decoded.clip.childOffset.x
                                                        scrollOffsetY = decoded.clip.childOffset.y
                                                    end
                                                end
                                                
                                                if layoutCfg.layoutDirection == config.LEFT_TO_RIGHT then
                                                    var whiteSpaceAroundChild: float = currentElement.dimensions.height - 
                                                        [float](layoutCfg.padding.top + layoutCfg.padding.bottom) - 
                                                        childElement.dimensions.height

                                                    if layoutCfg.childAlignment.y == config.ALIGN_Y_CENTER then
                                                        childNode.nextChildOffset.y = childNode.nextChildOffset.y + whiteSpaceAroundChild / 2.0
                                                    elseif layoutCfg.childAlignment.y == config.ALIGN_Y_BOTTOM then
                                                        childNode.nextChildOffset.y = childNode.nextChildOffset.y + whiteSpaceAroundChild
                                                    end
                                                else
                                                    var whiteSpaceAroundChild: float = currentElement.dimensions.width - 
                                                        [float](layoutCfg.padding.left + layoutCfg.padding.right) - 
                                                        childElement.dimensions.width

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
                                
                                if decoded.clip ~= nil then
                                    if self.renderCommands.length < self.renderCommands.capacity then
                                        var cmd: config.RenderCommand
                                        cmd.id = currentElement.id
                                        cmd.commandType = config.RENDER_SCISSOR_END
                                        self.renderCommands:add(cmd)
                                    end
                                end
                                
                                if decoded.border ~= nil then
                                    var borderBoundingBox: config.BoundingBox
                                    borderBoundingBox.x = currentElementTreeNode.position.x
                                    borderBoundingBox.y = currentElementTreeNode.position.y
                                    borderBoundingBox.width = currentElement.dimensions.width
                                    borderBoundingBox.height = currentElement.dimensions.height
                                    
                                    if not ui.ElementIsOffscreen(self, &borderBoundingBox) then
                                        var borderCfg = decoded.border
                                        if borderCfg.color.a > 0 then
                                                
                                                var cmd: config.RenderCommand
                                                cmd.boundingBox = borderBoundingBox
                                                cmd.id = currentElement.id
                                                cmd.commandType = config.RENDER_BORDER
                                                cmd.zIndex = root.zIndex
                                                cmd.renderData.border.color = borderCfg.color
                                                cmd.renderData.border.width = borderCfg.width
                                                
                                                if decoded.shared ~= nil then
                                                    cmd.renderData.border.cornerRadius = decoded.shared.cornerRadius
                                                    cmd.userData = decoded.shared.userData
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

terra ui.SetPointerStateForContext(ctx: &ui.Context, position: config.Vector2, pointerDown: bool)
    if ctx == nil then return end
    ctx.pointerInfo.position = position

    ctx.pointerOverIds.length = 0
    var dfsBuffer = ctx.reusableElementIndexBuffer
    var rootIndex: int32 = ctx.layoutElementTreeRoots.length - 1
    while rootIndex >= 0 do
        var root = ctx.layoutElementTreeRoots:get(rootIndex)
        var foundInRoot = false
        dfsBuffer.length = 0
        if root ~= nil then
            dfsBuffer:add(root.layoutElementIndex)
        end
        while dfsBuffer.length > 0 do
            var elemIndex = dfsBuffer:getValue(dfsBuffer.length - 1)
            dfsBuffer.length = dfsBuffer.length - 1
            var elem = ctx.layoutElements:get(elemIndex)
            if elem ~= nil then
                var mapIndex = ctx:findElementIndexById(elem.id)
                if mapIndex >= 0 and mapIndex < ctx.elementBoundingBoxes.capacity and ctx.elementBoundingBoxValid.internalArray[mapIndex] then
                    var box = ctx.elementBoundingBoxes.internalArray[mapIndex]
                    var inside = ui.PointInsideBox(position, box)
                    if inside and not ui.externalScrollHandlingEnabled then
                        var clipElementId = ctx.layoutElementClipElementIds:getValue(elemIndex)
                        if clipElementId ~= 0 then
                            var clipMapIndex = ctx:findElementIndexById([uint32](clipElementId))
                            if clipMapIndex >= 0 and clipMapIndex < ctx.elementBoundingBoxes.capacity and ctx.elementBoundingBoxValid.internalArray[clipMapIndex] then
                                var clipBox = ctx.elementBoundingBoxes.internalArray[clipMapIndex]
                                if not ui.PointInsideBox(position, clipBox) then
                                    inside = false
                                end
                            end
                        end
                    end
                    if inside then
                        if ctx.pointerOverIds.length < ctx.pointerOverIds.capacity then
                            ctx.pointerOverIds:add(elem.id)
                        end
                        foundInRoot = true
                        var h: int32 = 0
                        while h < ctx.hoverBindings.length do
                            var hb = ctx.hoverBindings:get(h)
                            if hb ~= nil and hb.callback ~= nil and hb.elementId == elem.id then
                                var id: hash.ElementId
                                id.id = hb.elementId
                                id.offset = 0
                                id.baseId = hb.elementId
                                id.stringId.isStaticallyAllocated = false
                                id.stringId.length = 0
                                id.stringId.chars = nil
                                hb.callback(id, &ctx.pointerInfo, hb.userData)
                            end
                            h = h + 1
                        end
                    end
                end

                if not ui.ElementHasConfig(elem, config.CONFIG_TEXT) then
                    var childIndex: int32 = [int32](elem.childrenOrTextContent.children.length) - 1
                    while childIndex >= 0 do
                        var childElemIndex = elem.childrenOrTextContent.children.elements[childIndex]
                        dfsBuffer:add(childElemIndex)
                        childIndex = childIndex - 1
                    end
                end
            end
        end

        if foundInRoot and root ~= nil then
            var rootElem = ctx.layoutElements:get(root.layoutElementIndex)
            if rootElem ~= nil and ui.ElementHasConfig(rootElem, config.CONFIG_FLOATING) then
                var floatingCfg = ui.FindElementConfigWithType(rootElem, config.CONFIG_FLOATING)
                if floatingCfg ~= nil and floatingCfg.config.floatingConfig ~= nil then
                    if floatingCfg.config.floatingConfig.pointerCaptureMode == config.POINTER_CAPTURE then
                        break
                    end
                end
            end
        end
        rootIndex = rootIndex - 1
    end

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

terra ui.SetPointerState(position: config.Vector2, pointerDown: bool)
    ui.SetPointerStateForContext(ui.GetCurrentContext(), position, pointerDown)
end

terra ui.Hovered() : bool
    var ctx = ui.GetCurrentContext()
    if ctx == nil then return false end
    return ctx.pointerOverIds.length > 0
end

terra ui.PointerOver(id: hash.ElementId) : bool
    var ctx = ui.GetCurrentContext()
    if ctx == nil then return false end
    var i: int32 = 0
    while i < ctx.pointerOverIds.length do
        if ctx.pointerOverIds:getValue(i) == id.id then
            return true
        end
        i = i + 1
    end
    return false
end

local terra containsId(array: &UInt32Array, id: uint32) : bool
    if array == nil or id == 0 then return false end
    var i: int32 = 0
    while i < array.length do
        if array:getValue(i) == id then
            return true
        end
        i = i + 1
    end
    return false
end

local terra setIdEnabled(array: &UInt32Array, id: uint32, enabled: bool)
    if array == nil or id == 0 then return end
    var i: int32 = 0
    while i < array.length do
        if array:getValue(i) == id then
            if not enabled then
                array:removeSwapback(i)
            end
            return
        end
        i = i + 1
    end
    if enabled and array.length < array.capacity then
        array:add(id)
    end
end

terra ui.PointerDown() : bool
    var ctx = ui.GetCurrentContext()
    if ctx == nil then return false end
    return ctx.pointerInfo.state == config.POINTER_PRESSED or
           ctx.pointerInfo.state == config.POINTER_PRESSED_THIS_FRAME
end

terra ui.ElementActive(id: hash.ElementId) : bool
    return ui.PointerOver(id) and ui.PointerDown()
end

terra ui.ElementFocused(id: hash.ElementId) : bool
    var ctx = ui.GetCurrentContext()
    if ctx == nil then return false end
    return containsId(&ctx.focusedIds, id.id)
end

terra ui.ElementSelected(id: hash.ElementId) : bool
    var ctx = ui.GetCurrentContext()
    if ctx == nil then return false end
    return containsId(&ctx.selectedIds, id.id)
end

terra ui.ElementDisabled(id: hash.ElementId) : bool
    var ctx = ui.GetCurrentContext()
    if ctx == nil then return false end
    return containsId(&ctx.disabledIds, id.id)
end

terra ui.SetElementFocusedForContext(ctx: &ui.Context, id: hash.ElementId, enabled: bool)
    if ctx == nil then return end
    setIdEnabled(&ctx.focusedIds, id.id, enabled)
end

terra ui.SetElementFocused(id: hash.ElementId, enabled: bool)
    ui.SetElementFocusedForContext(ui.GetCurrentContext(), id, enabled)
end

terra ui.SetElementSelectedForContext(ctx: &ui.Context, id: hash.ElementId, enabled: bool)
    if ctx == nil then return end
    setIdEnabled(&ctx.selectedIds, id.id, enabled)
end

terra ui.SetElementSelected(id: hash.ElementId, enabled: bool)
    ui.SetElementSelectedForContext(ui.GetCurrentContext(), id, enabled)
end

terra ui.SetElementDisabledForContext(ctx: &ui.Context, id: hash.ElementId, enabled: bool)
    if ctx == nil then return end
    setIdEnabled(&ctx.disabledIds, id.id, enabled)
end

terra ui.SetElementDisabled(id: hash.ElementId, enabled: bool)
    ui.SetElementDisabledForContext(ui.GetCurrentContext(), id, enabled)
end

terra ui.OnHoverCurrent(callback: HoverCallbackFnType, userData: &opaque)
    var ctx = ui.GetCurrentContext()
    if ctx == nil or callback == nil then return end
    var openElem = ctx:getOpenLayoutElement()
    if openElem == nil then return end
    var i: int32 = 0
    while i < ctx.hoverBindings.length do
        var hb = ctx.hoverBindings:get(i)
        if hb ~= nil and hb.elementId == openElem.id then
            hb.callback = callback
            hb.userData = userData
            return
        end
        i = i + 1
    end
    if ctx.hoverBindings.length < ctx.hoverBindings.capacity then
        var hb: HoverBinding
        hb.elementId = openElem.id
        hb.callback = callback
        hb.userData = userData
        ctx.hoverBindings:add(hb)
    end
end

terra ui.OnHover(id: hash.ElementId, callback: HoverCallbackFnType, userData: &opaque)
    if callback == nil then return end
    if ui.PointerOver(id) then
        var ctx = ui.GetCurrentContext()
        if ctx ~= nil then
            callback(id, &ctx.pointerInfo, userData)
        else
            var p: config.PointerData
            p.position.x = 0
            p.position.y = 0
            p.state = config.POINTER_RELEASED
            callback(id, &p, userData)
        end
    end
end

terra ui.UpdateScrollContainersForContext(ctx: &ui.Context, enableDragScrolling: bool, scrollDelta: config.Vector2, deltaTime: float)
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

    i = 0
    while i < ctx.scrollContainerDatas.length do
        var scrollData = ctx.scrollContainerDatas:get(i)
        if scrollData ~= nil and scrollData.layoutElement ~= nil then
            var clipCfgResult = ui.FindElementConfigWithType(scrollData.layoutElement, config.CONFIG_CLIP)
            if clipCfgResult ~= nil and clipCfgResult.config.clipConfig ~= nil then
                clipCfgResult.config.clipConfig.childOffset = scrollData.scrollPosition
            end
        end
        i = i + 1
    end
end

terra ui.UpdateScrollContainers(enableDragScrolling: bool, scrollDelta: config.Vector2, deltaTime: float)
    ui.UpdateScrollContainersForContext(ui.GetCurrentContext(), enableDragScrolling, scrollDelta, deltaTime)
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

terra ui.GetElementData(id: hash.ElementId) : config.ElementData
    var out: config.ElementData
    out.boundingBox.x = 0
    out.boundingBox.y = 0
    out.boundingBox.width = 0
    out.boundingBox.height = 0
    out.found = false

    var ctx = ui.GetCurrentContext()
    if ctx == nil then
        return out
    end

    var idx = ctx:findElementIndexById(id.id)
    if idx < 0 or idx >= ctx.elementBoundingBoxes.capacity then
        return out
    end

    if not ctx.elementBoundingBoxValid.internalArray[idx] then
        return out
    end

    out.boundingBox = ctx.elementBoundingBoxes.internalArray[idx]
    out.found = true
    return out
end

terra ui.Context:endLayout()
    self:closeElement()
    if self.openLayoutElementStack.length > 0 then
        ui.ReportError(config.ERROR_TYPE_UNBALANCED_OPEN_CLOSE,
            config.String { isStaticallyAllocated = true, length = 111, chars = "Unbalanced OpenElement/CloseElement calls. There were still open layout elements when EndLayout executed." })
    end
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

terra ui.FinalizeLayoutForContext(ctx: &ui.Context) : int32
    if ctx == nil then
        return 0
    end
    var cmds = ctx:endLayout()
    if cmds == nil then
        return 0
    end
    return cmds.length
end

terra ui.FinalizeLayout() : int32
    return ui.FinalizeLayoutForContext(ui.GetCurrentContext())
end

terra ui.GetRenderCommandCountForContext(ctx: &ui.Context) : int32
    if ctx == nil then
        return 0
    end
    return ctx.renderCommands.length
end

terra ui.GetRenderCommandCount() : int32
    return ui.GetRenderCommandCountForContext(ui.GetCurrentContext())
end

terra ui.GetRenderCommandBufferForContext(ctx: &ui.Context) : &config.RenderCommand
    if ctx == nil then
        return nil
    end
    if ctx.renderCommands.length <= 0 then
        return nil
    end
    return ctx.renderCommands.internalArray
end

terra ui.GetRenderCommandBuffer() : &config.RenderCommand
    return ui.GetRenderCommandBufferForContext(ui.GetCurrentContext())
end

terra ui.GetRenderCommandAtForContext(ctx: &ui.Context, index: int32) : config.RenderCommand
    var out: config.RenderCommand
    out.boundingBox.x = 0
    out.boundingBox.y = 0
    out.boundingBox.width = 0
    out.boundingBox.height = 0
    out.commandType = config.RENDER_NONE

    if ctx == nil then
        return out
    end
    if index < 0 or index >= ctx.renderCommands.length then
        return out
    end
    return ctx.renderCommands.internalArray[index]
end

terra ui.GetRenderCommandAt(index: int32) : config.RenderCommand
    return ui.GetRenderCommandAtForContext(ui.GetCurrentContext(), index)
end

-- ============================================
-- PORTABILITY: ForContext Text Measurement APIs
-- ============================================

terra ui.SetMeasureTextFunctionForContext(ctx: &ui.Context, measureTextFunction: MeasureTextFnType, userData: &opaque)
    if ctx == nil then return end
    ctx.measureTextFunction = measureTextFunction
    ctx.measureTextUserData = userData
end

terra ui.ResetMeasureTextCacheForContext(ctx: &ui.Context)
    if ctx == nil then return end
    ctx.measureTextHashMapInternal.length = 0
    ctx.measureTextHashMapInternalFreeList.length = 0
    ctx.measuredWords.length = 0
    ctx.measuredWordsFreeList.length = 0
    ctx.measureTextHashMap.length = ctx.measureTextHashMap.capacity
    var i: int32 = 0
    while i < ctx.measureTextHashMap.length do
        ctx.measureTextHashMap.internalArray[i] = 0
        i = i + 1
    end
    ctx.measureTextHashMapInternal.length = 1
end

return ui
