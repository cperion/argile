local ui = {}
local string_mod = require("src.string")
local hash = require("src.hash")

ui.String = string_mod.String
ui.StringSlice = string_mod.StringSlice

-- ============================================
-- ENUMS (as uint8)
-- ============================================

ui.LayoutDirection = uint8
ui.LEFT_TO_RIGHT = 0
ui.TOP_TO_BOTTOM = 1

ui.LayoutAlignmentX = uint8
ui.ALIGN_X_LEFT = 0
ui.ALIGN_X_RIGHT = 1
ui.ALIGN_X_CENTER = 2

ui.LayoutAlignmentY = uint8
ui.ALIGN_Y_TOP = 0
ui.ALIGN_Y_BOTTOM = 1
ui.ALIGN_Y_CENTER = 2

ui.SizingType = uint8
ui.SIZING_FIT = 0
ui.SIZING_GROW = 1
ui.SIZING_PERCENT = 2
ui.SIZING_FIXED = 3

ui.TextWrapMode = uint8
ui.TEXT_WRAP_WORDS = 0
ui.TEXT_WRAP_NEWLINES = 1
ui.TEXT_WRAP_NONE = 2

ui.TextAlignment = uint8
ui.TEXT_ALIGN_LEFT = 0
ui.TEXT_ALIGN_CENTER = 1
ui.TEXT_ALIGN_RIGHT = 2

ui.AttachPoint = uint8
ui.ATTACH_LEFT_TOP = 0
ui.ATTACH_LEFT_CENTER = 1
ui.ATTACH_LEFT_BOTTOM = 2
ui.ATTACH_CENTER_TOP = 3
ui.ATTACH_CENTER_CENTER = 4
ui.ATTACH_CENTER_BOTTOM = 5
ui.ATTACH_RIGHT_TOP = 6
ui.ATTACH_RIGHT_CENTER = 7
ui.ATTACH_RIGHT_BOTTOM = 8

ui.PointerCaptureMode = uint8
ui.POINTER_CAPTURE = 0
ui.POINTER_PASSTHROUGH = 1

ui.AttachToElement = uint8
ui.ATTACH_NONE = 0
ui.ATTACH_PARENT = 1
ui.ATTACH_ELEMENT_WITH_ID = 2
ui.ATTACH_ROOT = 3

ui.ClipToElement = uint8
ui.CLIP_NONE = 0
ui.CLIP_ATTACHED_PARENT = 1

ui.OverflowMode = uint8
ui.OVERFLOW_VISIBLE = 0
ui.OVERFLOW_CLIP = 1
ui.OVERFLOW_SCROLL = 2

ui.RenderCommandType = uint8
ui.RENDER_NONE = 0
ui.RENDER_RECTANGLE = 1
ui.RENDER_BORDER = 2
ui.RENDER_TEXT = 3
ui.RENDER_IMAGE = 4
ui.RENDER_SCISSOR_START = 5
ui.RENDER_SCISSOR_END = 6
ui.RENDER_CUSTOM = 7
ui.RENDER_PAINT = 8

ui.PointerState = uint8
ui.POINTER_PRESSED_THIS_FRAME = 0
ui.POINTER_PRESSED = 1
ui.POINTER_RELEASED_THIS_FRAME = 2
ui.POINTER_RELEASED = 3

ui.ElementConfigType = uint8
ui.CONFIG_NONE = 0
ui.CONFIG_BORDER = 1
ui.CONFIG_FLOATING = 2
ui.CONFIG_CLIP = 3
ui.CONFIG_ASPECT = 4
ui.CONFIG_IMAGE = 5
ui.CONFIG_TEXT = 6
ui.CONFIG_CUSTOM = 7
ui.CONFIG_SHARED = 8
ui.CONFIG_PAINT = 9

ui.ErrorType = uint8
ui.ERROR_TYPE_TEXT_MEASUREMENT_FUNCTION_NOT_PROVIDED = 0
ui.ERROR_TYPE_ARENA_CAPACITY_EXCEEDED = 1
ui.ERROR_TYPE_ELEMENTS_CAPACITY_EXCEEDED = 2
ui.ERROR_TYPE_TEXT_MEASUREMENT_CAPACITY_EXCEEDED = 3
ui.ERROR_TYPE_DUPLICATE_ID = 4
ui.ERROR_TYPE_FLOATING_CONTAINER_PARENT_NOT_FOUND = 5
ui.ERROR_TYPE_PERCENTAGE_OVER_1 = 6
ui.ERROR_TYPE_INTERNAL_ERROR = 7
ui.ERROR_TYPE_UNBALANCED_OPEN_CLOSE = 8

-- ============================================
-- BASIC DATA TYPES
-- ============================================

ui.Dimensions = struct {
    width : float,
    height : float
}

ui.Vector2 = struct {
    x : float,
    y : float
}

ui.Color = struct {
    r : float,
    g : float,
    b : float,
    a : float
}

ui.BoundingBox = struct {
    x : float,
    y : float,
    width : float,
    height : float
}

ui.CornerRadius = struct {
    topLeft : float,
    topRight : float,
    bottomLeft : float,
    bottomRight : float
}

-- ============================================
-- SIZING & LAYOUT
-- ============================================

ui.SizingMinMax = struct {
    min : float,
    max : float
}

ui.SizingAxis = struct {
    size : ui.SizingMinMax,
    percent : float,
    type : ui.SizingType
}

ui.Sizing = struct {
    width : ui.SizingAxis,
    height : ui.SizingAxis
}

ui.Padding = struct {
    left : uint16,
    right : uint16,
    top : uint16,
    bottom : uint16
}

ui.ChildAlignment = struct {
    x : ui.LayoutAlignmentX,
    y : ui.LayoutAlignmentY
}

ui.LayoutConfig = struct {
    sizing : ui.Sizing,
    padding : ui.Padding,
    childGap : uint16,
    childAlignment : ui.ChildAlignment,
    layoutDirection : ui.LayoutDirection
}

-- ============================================
-- ELEMENT CONFIGS
-- ============================================

ui.TextConfig = struct {
    userData : &opaque,
    textColor : ui.Color,
    fontId : uint16,
    fontSize : uint16,
    letterSpacing : uint16,
    lineHeight : uint16,
    wrapMode : ui.TextWrapMode,
    textAlignment : ui.TextAlignment
}

ui.AspectRatioConfig = struct {
    aspectRatio : float
}

ui.ImageConfig = struct {
    imageData : &opaque
}

ui.FloatingAttachPoints = struct {
    element : ui.AttachPoint,
    parent : ui.AttachPoint
}

ui.FloatingConfig = struct {
    offset : ui.Vector2,
    expand : ui.Dimensions,
    parentId : uint32,
    zIndex : int16,
    attachPoints : ui.FloatingAttachPoints,
    pointerCaptureMode : ui.PointerCaptureMode,
    attachTo : ui.AttachToElement,
    clipTo : ui.ClipToElement
}

ui.CustomConfig = struct {
    customData : &opaque
}

ui.ClipConfig = struct {
    horizontal : bool,
    vertical : bool,
    childOffset : ui.Vector2
}

ui.OverflowConfig = struct {
    xMode : ui.OverflowMode,
    yMode : ui.OverflowMode
}

ui.BorderWidth = struct {
    left : uint16,
    right : uint16,
    top : uint16,
    bottom : uint16,
    betweenChildren : uint16
}

ui.BorderConfig = struct {
    color : ui.Color,
    width : ui.BorderWidth
}

ui.SharedConfig = struct {
    backgroundColor : ui.Color,
    cornerRadius : ui.CornerRadius,
    userData : &opaque
}

-- ============================================
-- PAINT OPS
-- ============================================

ui.PaintOpKind = uint8
ui.PAINT_OP_FILL = 0
ui.PAINT_OP_STROKE = 1
ui.PAINT_OP_RECT = 2
ui.PAINT_OP_ROUND_RECT = 3
ui.PAINT_OP_CIRCLE = 4
ui.PAINT_OP_LINE = 5

ui.PaintOp = struct {
    kind : ui.PaintOpKind,
    color : ui.Color,
    x : float,
    y : float,
    w : float,
    h : float,
    r : float,
    x2 : float,
    y2 : float,
    width : uint16
}

ui.PaintConfig = struct {
    ops : &ui.PaintOp,
    count : uint32
}

-- ============================================
-- RENDER DATA
-- ============================================

ui.TextRenderData = struct {
    stringContents : ui.StringSlice,
    textColor : ui.Color,
    fontId : uint16,
    fontSize : uint16,
    letterSpacing : uint16,
    lineHeight : uint16
}

ui.RectangleRenderData = struct {
    backgroundColor : ui.Color,
    cornerRadius : ui.CornerRadius
}

ui.ImageRenderData = struct {
    backgroundColor : ui.Color,
    cornerRadius : ui.CornerRadius,
    imageData : &opaque
}

ui.CustomRenderData = struct {
    backgroundColor : ui.Color,
    cornerRadius : ui.CornerRadius,
    customData : &opaque
}

ui.ClipRenderData = struct {
    horizontal : bool,
    vertical : bool
}

ui.BorderRenderData = struct {
    color : ui.Color,
    cornerRadius : ui.CornerRadius,
    width : ui.BorderWidth
}

ui.PaintRenderData = struct {
    ops : &ui.PaintOp,
    count : uint32
}

ui.RenderData = struct {
    rectangle : ui.RectangleRenderData,
    text : ui.TextRenderData,
    image : ui.ImageRenderData,
    custom : ui.CustomRenderData,
    border : ui.BorderRenderData,
    clip : ui.ClipRenderData,
    paint : ui.PaintRenderData
}

ui.RenderCommand = struct {
    boundingBox : ui.BoundingBox,
    renderData : ui.RenderData,
    userData : &opaque,
    id : uint32,
    zIndex : int16,
    commandType : ui.RenderCommandType
}

-- ============================================
-- MISC DATA STRUCTURES
-- ============================================

ui.ScrollContainerData = struct {
    scrollPosition : &ui.Vector2,
    scrollContainerDimensions : ui.Dimensions,
    contentDimensions : ui.Dimensions,
    config : ui.ClipConfig,
    found : bool
}

ui.ElementData = struct {
    boundingBox : ui.BoundingBox,
    found : bool
}

ui.PointerData = struct {
    position : ui.Vector2,
    state : ui.PointerState
}

ui.ErrorData = struct {
    errorType : ui.ErrorType,
    errorText : ui.String,
    userData : &opaque
}

-- ============================================
-- ELEMENT CONFIG UNION
-- ============================================

ui.ElementConfigUnion = struct {
    textConfig : &ui.TextConfig,
    aspectRatioConfig : &ui.AspectRatioConfig,
    imageConfig : &ui.ImageConfig,
    floatingConfig : &ui.FloatingConfig,
    customConfig : &ui.CustomConfig,
    clipConfig : &ui.ClipConfig,
    borderConfig : &ui.BorderConfig,
    sharedConfig : &ui.SharedConfig,
    paintConfig : &ui.PaintConfig
}

ui.ElementConfig = struct {
    configType : ui.ElementConfigType,
    config : ui.ElementConfigUnion
}

-- CAPI/Terra helper bundle mirroring the set of configs DSL can attach to a node.
-- All fields are optional pointers; nil means "do not attach".
ui.NodeBuildConfigBundle = struct {
    layoutConfig : &ui.LayoutConfig,
    sharedConfig : &ui.SharedConfig,
    borderConfig : &ui.BorderConfig,
    clipConfig : &ui.ClipConfig,
    floatingConfig : &ui.FloatingConfig,
    aspectRatioConfig : &ui.AspectRatioConfig,
    imageConfig : &ui.ImageConfig,
    customConfig : &ui.CustomConfig,
    paintConfig : &ui.PaintConfig
}

-- ============================================
-- PORTABILITY: Backend-Neutral Frame Input
-- ============================================

ui.ArgileFrameInput = struct {
    width : float,
    height : float,
    pointer_x : float,
    pointer_y : float,
    pointer_down : bool,
    pointer_pressed : bool,
    pointer_released : bool,
    scroll_delta_x : float,
    scroll_delta_y : float,
    delta_time : float
}

ui.ArgileFrameStateFlags = struct {
    focused : bool,
    selected : bool,
    disabled : bool
}

ui.ArgileDemoIds = struct {
    card : hash.ElementId,
    title : hash.ElementId,
    body : hash.ElementId
}

return ui
