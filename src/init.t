local ui = {}

local arena = require("src.arena")
local array = require("src.array")
local string_mod = require("src.string")
local hash = require("src.hash")
local config = require("src.config")
local layout = require("src.layout")
local context = require("src.context")

ui.Arena = arena.Arena
ui.CreateArenaWithCapacityAndMemory = arena.CreateArenaWithCapacityAndMemory
ui.Array = array.Array
ui.Slice = array.Slice
ui.String = string_mod.String
ui.StringSlice = string_mod.StringSlice
ui.ElementId = hash.ElementId
ui.HashData = hash.HashData
ui.HashNumber = hash.HashNumber
ui.HashString = hash.HashString
ui.HashStringWithOffset = hash.HashStringWithOffset

ui.LayoutDirection = config.LayoutDirection
ui.LEFT_TO_RIGHT = config.LEFT_TO_RIGHT
ui.TOP_TO_BOTTOM = config.TOP_TO_BOTTOM

ui.LayoutAlignmentX = config.LayoutAlignmentX
ui.ALIGN_X_LEFT = config.ALIGN_X_LEFT
ui.ALIGN_X_RIGHT = config.ALIGN_X_RIGHT
ui.ALIGN_X_CENTER = config.ALIGN_X_CENTER

ui.LayoutAlignmentY = config.LayoutAlignmentY
ui.ALIGN_Y_TOP = config.ALIGN_Y_TOP
ui.ALIGN_Y_BOTTOM = config.ALIGN_Y_BOTTOM
ui.ALIGN_Y_CENTER = config.ALIGN_Y_CENTER

ui.SizingType = config.SizingType
ui.SIZING_FIT = config.SIZING_FIT
ui.SIZING_GROW = config.SIZING_GROW
ui.SIZING_PERCENT = config.SIZING_PERCENT
ui.SIZING_FIXED = config.SIZING_FIXED

ui.TextWrapMode = config.TextWrapMode
ui.TEXT_WRAP_WORDS = config.TEXT_WRAP_WORDS
ui.TEXT_WRAP_NEWLINES = config.TEXT_WRAP_NEWLINES
ui.TEXT_WRAP_NONE = config.TEXT_WRAP_NONE

ui.TextAlignment = config.TextAlignment
ui.TEXT_ALIGN_LEFT = config.TEXT_ALIGN_LEFT
ui.TEXT_ALIGN_CENTER = config.TEXT_ALIGN_CENTER
ui.TEXT_ALIGN_RIGHT = config.TEXT_ALIGN_RIGHT

ui.AttachPoint = config.AttachPoint
ui.ATTACH_LEFT_TOP = config.ATTACH_LEFT_TOP
ui.ATTACH_LEFT_CENTER = config.ATTACH_LEFT_CENTER
ui.ATTACH_LEFT_BOTTOM = config.ATTACH_LEFT_BOTTOM
ui.ATTACH_CENTER_TOP = config.ATTACH_CENTER_TOP
ui.ATTACH_CENTER_CENTER = config.ATTACH_CENTER_CENTER
ui.ATTACH_CENTER_BOTTOM = config.ATTACH_CENTER_BOTTOM
ui.ATTACH_RIGHT_TOP = config.ATTACH_RIGHT_TOP
ui.ATTACH_RIGHT_CENTER = config.ATTACH_RIGHT_CENTER
ui.ATTACH_RIGHT_BOTTOM = config.ATTACH_RIGHT_BOTTOM

ui.PointerCaptureMode = config.PointerCaptureMode
ui.POINTER_CAPTURE = config.POINTER_CAPTURE
ui.POINTER_PASSTHROUGH = config.POINTER_PASSTHROUGH

ui.AttachToElement = config.AttachToElement
ui.ATTACH_NONE = config.ATTACH_NONE
ui.ATTACH_PARENT = config.ATTACH_PARENT
ui.ATTACH_ELEMENT_WITH_ID = config.ATTACH_ELEMENT_WITH_ID
ui.ATTACH_ROOT = config.ATTACH_ROOT

ui.ClipToElement = config.ClipToElement
ui.CLIP_NONE = config.CLIP_NONE
ui.CLIP_ATTACHED_PARENT = config.CLIP_ATTACHED_PARENT

ui.OverflowMode = config.OverflowMode
ui.OVERFLOW_VISIBLE = config.OVERFLOW_VISIBLE
ui.OVERFLOW_CLIP = config.OVERFLOW_CLIP
ui.OVERFLOW_SCROLL = config.OVERFLOW_SCROLL

ui.RenderCommandType = config.RenderCommandType
ui.RENDER_NONE = config.RENDER_NONE
ui.RENDER_RECTANGLE = config.RENDER_RECTANGLE
ui.RENDER_BORDER = config.RENDER_BORDER
ui.RENDER_TEXT = config.RENDER_TEXT
ui.RENDER_IMAGE = config.RENDER_IMAGE
ui.RENDER_SCISSOR_START = config.RENDER_SCISSOR_START
ui.RENDER_SCISSOR_END = config.RENDER_SCISSOR_END
ui.RENDER_CUSTOM = config.RENDER_CUSTOM
ui.RENDER_PAINT = config.RENDER_PAINT

ui.PointerState = config.PointerState
ui.POINTER_PRESSED_THIS_FRAME = config.POINTER_PRESSED_THIS_FRAME
ui.POINTER_PRESSED = config.POINTER_PRESSED
ui.POINTER_RELEASED_THIS_FRAME = config.POINTER_RELEASED_THIS_FRAME
ui.POINTER_RELEASED = config.POINTER_RELEASED

ui.ElementConfigType = config.ElementConfigType
ui.CONFIG_NONE = config.CONFIG_NONE
ui.CONFIG_BORDER = config.CONFIG_BORDER
ui.CONFIG_FLOATING = config.CONFIG_FLOATING
ui.CONFIG_CLIP = config.CONFIG_CLIP
ui.CONFIG_ASPECT = config.CONFIG_ASPECT
ui.CONFIG_IMAGE = config.CONFIG_IMAGE
ui.CONFIG_TEXT = config.CONFIG_TEXT
ui.CONFIG_CUSTOM = config.CONFIG_CUSTOM
ui.CONFIG_SHARED = config.CONFIG_SHARED
ui.CONFIG_PAINT = config.CONFIG_PAINT

ui.ErrorType = config.ErrorType
ui.ERROR_TYPE_TEXT_MEASUREMENT_FUNCTION_NOT_PROVIDED = config.ERROR_TYPE_TEXT_MEASUREMENT_FUNCTION_NOT_PROVIDED
ui.ERROR_TYPE_ARENA_CAPACITY_EXCEEDED = config.ERROR_TYPE_ARENA_CAPACITY_EXCEEDED
ui.ERROR_TYPE_ELEMENTS_CAPACITY_EXCEEDED = config.ERROR_TYPE_ELEMENTS_CAPACITY_EXCEEDED
ui.ERROR_TYPE_TEXT_MEASUREMENT_CAPACITY_EXCEEDED = config.ERROR_TYPE_TEXT_MEASUREMENT_CAPACITY_EXCEEDED
ui.ERROR_TYPE_DUPLICATE_ID = config.ERROR_TYPE_DUPLICATE_ID
ui.ERROR_TYPE_FLOATING_CONTAINER_PARENT_NOT_FOUND = config.ERROR_TYPE_FLOATING_CONTAINER_PARENT_NOT_FOUND
ui.ERROR_TYPE_PERCENTAGE_OVER_1 = config.ERROR_TYPE_PERCENTAGE_OVER_1
ui.ERROR_TYPE_INTERNAL_ERROR = config.ERROR_TYPE_INTERNAL_ERROR
ui.ERROR_TYPE_UNBALANCED_OPEN_CLOSE = config.ERROR_TYPE_UNBALANCED_OPEN_CLOSE

ui.Dimensions = config.Dimensions
ui.Vector2 = config.Vector2
ui.Color = config.Color
ui.BoundingBox = config.BoundingBox
ui.CornerRadius = config.CornerRadius
ui.SizingMinMax = config.SizingMinMax
ui.SizingAxis = config.SizingAxis
ui.Sizing = config.Sizing
ui.Padding = config.Padding
ui.ChildAlignment = config.ChildAlignment
ui.LayoutConfig = config.LayoutConfig
ui.TextConfig = config.TextConfig
ui.AspectRatioConfig = config.AspectRatioConfig
ui.ImageConfig = config.ImageConfig
ui.FloatingAttachPoints = config.FloatingAttachPoints
ui.FloatingConfig = config.FloatingConfig
ui.CustomConfig = config.CustomConfig
ui.ClipConfig = config.ClipConfig
ui.OverflowConfig = config.OverflowConfig
ui.BorderWidth = config.BorderWidth
ui.BorderConfig = config.BorderConfig
ui.SharedConfig = config.SharedConfig
ui.PaintOpKind = config.PaintOpKind
ui.PAINT_OP_FILL = config.PAINT_OP_FILL
ui.PAINT_OP_STROKE = config.PAINT_OP_STROKE
ui.PAINT_OP_RECT = config.PAINT_OP_RECT
ui.PAINT_OP_ROUND_RECT = config.PAINT_OP_ROUND_RECT
ui.PAINT_OP_CIRCLE = config.PAINT_OP_CIRCLE
ui.PAINT_OP_LINE = config.PAINT_OP_LINE
ui.PaintOp = config.PaintOp
ui.PaintConfig = config.PaintConfig
ui.PaintRenderData = config.PaintRenderData
ui.TextRenderData = config.TextRenderData
ui.RectangleRenderData = config.RectangleRenderData
ui.ImageRenderData = config.ImageRenderData
ui.CustomRenderData = config.CustomRenderData
ui.ClipRenderData = config.ClipRenderData
ui.BorderRenderData = config.BorderRenderData
ui.RenderData = config.RenderData
ui.RenderCommand = config.RenderCommand
ui.ScrollContainerData = config.ScrollContainerData
ui.ElementData = config.ElementData
ui.PointerData = config.PointerData
ui.ErrorData = config.ErrorData
ui.ElementConfigUnion = config.ElementConfigUnion
ui.ElementConfig = config.ElementConfig
ui.ElementDescFlags = config.ElementDescFlags
ui.DESC_HAS_LAYOUT = config.DESC_HAS_LAYOUT
ui.DESC_HAS_SHARED = config.DESC_HAS_SHARED
ui.DESC_HAS_BORDER = config.DESC_HAS_BORDER
ui.DESC_HAS_CLIP = config.DESC_HAS_CLIP
ui.DESC_HAS_FLOATING = config.DESC_HAS_FLOATING
ui.DESC_HAS_ASPECT = config.DESC_HAS_ASPECT
ui.DESC_HAS_IMAGE = config.DESC_HAS_IMAGE
ui.DESC_HAS_CUSTOM = config.DESC_HAS_CUSTOM
ui.DESC_HAS_PAINT = config.DESC_HAS_PAINT
ui.ElementDesc = config.ElementDesc

-- Portability: Backend-neutral frame input structs
ui.ArgileFrameInput = config.ArgileFrameInput
ui.ArgileFrameStateFlags = config.ArgileFrameStateFlags
ui.ArgileDemoIds = config.ArgileDemoIds

ui.WrappedTextLine = layout.WrappedTextLine
ui.TextElementData = layout.TextElementData
ui.LayoutElementChildren = layout.LayoutElementChildren
ui.LayoutElement = layout.LayoutElement
ui.LayoutElementTreeNode = layout.LayoutElementTreeNode
ui.LayoutElementTreeRoot = layout.LayoutElementTreeRoot
ui.ScrollContainerDataInternal = layout.ScrollContainerDataInternal

ui.Context = context.Context
ui.ARGILE_API_VERSION = context.ARGILE_API_VERSION
ui.GetApiVersion = context.GetApiVersion
ui.GetContextSize = context.GetContextSize
ui.Initialize = context.Initialize
ui.InitializeContext = context.InitializeContext
ui.GetCurrentContext = context.GetCurrentContext
ui.SetCurrentContext = context.SetCurrentContext
ui.BeginLayout = context.BeginLayout
ui.BeginLayoutForContext = context.BeginLayoutForContext
ui.OpenElementWithDesc = context.OpenElementWithDesc
ui.OpenElementWithDescForContext = context.OpenElementWithDescForContext
ui.OpenElementWithIdAndDesc = context.OpenElementWithIdAndDesc
ui.OpenElementWithIdAndDescForContext = context.OpenElementWithIdAndDescForContext
ui.OpenElementWithIdCharsAndDesc = context.OpenElementWithIdCharsAndDesc
ui.OpenElementWithIdCharsAndDescForContext = context.OpenElementWithIdCharsAndDescForContext
ui.OpenTextElement = context.OpenTextElement
ui.OpenTextElementForContext = context.OpenTextElementForContext
ui.OpenTextElementWithId = context.OpenTextElementWithId
ui.OpenTextElementWithIdForContext = context.OpenTextElementWithIdForContext
ui.OpenTextElementWithIdChars = context.OpenTextElementWithIdChars
ui.OpenTextElementWithIdCharsForContext = context.OpenTextElementWithIdCharsForContext
ui.OpenTextElementWithLength = context.OpenTextElementWithLength
ui.OpenTextElementWithLengthForContext = context.OpenTextElementWithLengthForContext
ui.OpenTextElementWithLengthAndId = context.OpenTextElementWithLengthAndId
ui.OpenTextElementWithLengthAndIdForContext = context.OpenTextElementWithLengthAndIdForContext
ui.StringFromChars = context.StringFromChars
ui.GetElementId = context.GetElementId
ui.GetElementIdWithIndex = context.GetElementIdWithIndex
ui.GetElementIdFromChars = context.GetElementIdFromChars
ui.GetElementIdWithIndexFromChars = context.GetElementIdWithIndexFromChars
ui.SetMeasureTextFunction = context.SetMeasureTextFunction
ui.SetMeasureTextFunctionForContext = context.SetMeasureTextFunctionForContext
ui.SetErrorHandler = context.SetErrorHandler
ui.SetQueryScrollOffsetFunction = context.SetQueryScrollOffsetFunction
ui.SetLayoutDimensions = context.SetLayoutDimensions
ui.SetLayoutDimensionsForContext = context.SetLayoutDimensionsForContext
ui.GetMaxElementCount = context.GetMaxElementCount
ui.SetMaxElementCount = context.SetMaxElementCount
ui.MinMemorySize = context.MinMemorySize
ui.GetMaxMeasureTextCacheWordCount = context.GetMaxMeasureTextCacheWordCount
ui.SetMaxMeasureTextCacheWordCount = context.SetMaxMeasureTextCacheWordCount
ui.ResetMeasureTextCache = context.ResetMeasureTextCache
ui.ResetMeasureTextCacheForContext = context.ResetMeasureTextCacheForContext
ui.SetDisableCulling = context.SetDisableCulling
ui.SetCullingEnabled = context.SetCullingEnabled
ui.SetDebugModeEnabled = context.SetDebugModeEnabled
ui.IsDebugModeEnabled = context.IsDebugModeEnabled
ui.SetExternalScrollHandlingEnabled = context.SetExternalScrollHandlingEnabled
ui.SetPointerState = context.SetPointerState
ui.SetPointerStateForContext = context.SetPointerStateForContext
ui.Hovered = context.Hovered
ui.PointerOver = context.PointerOver
ui.PointerDown = context.PointerDown
ui.ElementActive = context.ElementActive
ui.ElementFocused = context.ElementFocused
ui.ElementSelected = context.ElementSelected
ui.ElementDisabled = context.ElementDisabled
ui.SetElementFocused = context.SetElementFocused
ui.SetElementFocusedForContext = context.SetElementFocusedForContext
ui.SetElementSelected = context.SetElementSelected
ui.SetElementSelectedForContext = context.SetElementSelectedForContext
ui.SetElementDisabled = context.SetElementDisabled
ui.SetElementDisabledForContext = context.SetElementDisabledForContext
ui.OnHoverCurrent = context.OnHoverCurrent
ui.OnHover = context.OnHover
ui.UpdateScrollContainers = context.UpdateScrollContainers
ui.UpdateScrollContainersForContext = context.UpdateScrollContainersForContext
ui.GetScrollOffset = context.GetScrollOffset
ui.SetElementScrollOffset = context.SetElementScrollOffset
ui.SetElementScrollOffsetForContext = context.SetElementScrollOffsetForContext
ui.GetElementScrollOffset = context.GetElementScrollOffset
ui.GetElementScrollOffsetForContext = context.GetElementScrollOffsetForContext
ui.GetElementData = context.GetElementData
ui.GetScrollContainerData = context.GetScrollContainerData
ui.CloseElement = context.CloseElement
ui.CloseElementForContext = context.CloseElementForContext
ui.EndLayout = context.EndLayout
ui.FinalizeLayout = context.FinalizeLayout
ui.FinalizeLayoutForContext = context.FinalizeLayoutForContext
ui.GetRenderCommandCount = context.GetRenderCommandCount
ui.GetRenderCommandCountForContext = context.GetRenderCommandCountForContext
ui.GetRenderCommandBuffer = context.GetRenderCommandBuffer
ui.GetRenderCommandBufferForContext = context.GetRenderCommandBufferForContext
ui.GetRenderCommandAt = context.GetRenderCommandAt
ui.GetRenderCommandAtForContext = context.GetRenderCommandAtForContext
ui.ElementHasConfig = context.ElementHasConfig
ui.FindElementConfigWithType = context.FindElementConfigWithType
ui.FloatEqual = context.FloatEqual
ui.clamp = context.clamp
ui.EPSILON = context.EPSILON
ui.MAXFLOAT = context.MAXFLOAT

-- Stable C/FFI-facing function surface. This is intentionally narrower
-- than the full Terra `ui` table, which still exposes internal helpers.
--
-- Host-side DSL AST builder/compiler API is intentionally exposed separately
-- from `ui.capi` because it relies on Lua/Terra metaprogramming and cannot be
-- exported through `terralib.saveobj`.
function ui.GetDslAstApi()
    return require("src/capi_dsl_host")
end
--
-- Grouped by domain:
--   1. Context/Init
--   2. Layout/Frame
--   3. Element Construction
--   4. Text
--   5. Input/State
--   6. Render Output
--   7. Hashing/Id
ui.capi = require("src.capi").build(ui)

return ui
