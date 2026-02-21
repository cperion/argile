local ui = require("src.arena")
local config = require("src.config")

ui.WrappedTextLine = struct {
    dimensions : config.Dimensions,
    line : config.String
}

ui.WrappedTextLineSlice = struct {
    internalArray : &ui.WrappedTextLine,
    length : int32
}

ui.TextElementData = struct {
    text : config.String,
    preferredDimensions : config.Dimensions,
    wrappedLines : ui.WrappedTextLineSlice,
    elementIndex : int32
}

ui.LayoutElementChildren = struct {
    elements : &int32,
    length : uint16
}

ui.LayoutElement = struct {
    childrenOrTextContent : struct {
        children : ui.LayoutElementChildren,
        textElementData : &ui.TextElementData
    },
    dimensions : config.Dimensions,
    minDimensions : config.Dimensions,
    layoutConfig : &config.LayoutConfig,
    elementConfigs : struct {
        length : int32,
        internalArray : &config.ElementConfig
    },
    id : uint32,
    floatingChildrenCount : uint16
}

ui.LayoutElementTreeNode = struct {
    layoutElement : &ui.LayoutElement,
    position : config.Vector2,
    nextChildOffset : config.Vector2
}

ui.LayoutElementTreeRoot = struct {
    layoutElementIndex : int32,
    parentId : uint32,
    clipElementId : uint32,
    zIndex : int16,
    pointerOffset : config.Vector2
}

ui.ScrollContainerDataInternal = struct {
    layoutElement : &ui.LayoutElement,
    boundingBox : config.BoundingBox,
    contentSize : config.Dimensions,
    scrollOrigin : config.Vector2,
    pointerOrigin : config.Vector2,
    scrollMomentum : config.Vector2,
    scrollPosition : config.Vector2,
    previousDelta : config.Vector2,
    momentumTime : float,
    elementId : uint32,
    openThisFrame : bool,
    pointerScrollActive : bool
}

ui.MeasuredWord = struct {
    startOffset : int32,
    length : int32,
    width : float,
    next : int32
}

ui.MeasureTextCacheItem = struct {
    measuredWordsStartIndex : int32,
    nextIndex : int32,
    id : uint32,
    generation : uint32,
    minWidth : float,
    unwrappedDimensions : config.Dimensions,
    containsNewlines : bool
}

return ui
