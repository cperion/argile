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

ui.RenderCommandType = config.RenderCommandType
ui.RENDER_NONE = config.RENDER_NONE
ui.RENDER_RECTANGLE = config.RENDER_RECTANGLE
ui.RENDER_BORDER = config.RENDER_BORDER
ui.RENDER_TEXT = config.RENDER_TEXT
ui.RENDER_IMAGE = config.RENDER_IMAGE
ui.RENDER_SCISSOR_START = config.RENDER_SCISSOR_START
ui.RENDER_SCISSOR_END = config.RENDER_SCISSOR_END
ui.RENDER_CUSTOM = config.RENDER_CUSTOM

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
ui.BorderWidth = config.BorderWidth
ui.BorderConfig = config.BorderConfig
ui.SharedConfig = config.SharedConfig
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
ui.ElementConfigUnion = config.ElementConfigUnion
ui.ElementConfig = config.ElementConfig

ui.WrappedTextLine = layout.WrappedTextLine
ui.TextElementData = layout.TextElementData
ui.LayoutElementChildren = layout.LayoutElementChildren
ui.LayoutElement = layout.LayoutElement
ui.LayoutElementTreeNode = layout.LayoutElementTreeNode
ui.LayoutElementTreeRoot = layout.LayoutElementTreeRoot
ui.ScrollContainerDataInternal = layout.ScrollContainerDataInternal

ui.Context = context.Context
ui.GetCurrentContext = context.GetCurrentContext
ui.SetCurrentContext = context.SetCurrentContext
ui.BeginLayout = context.BeginLayout
ui.OpenElement = context.OpenElement
ui.OpenElementWithId = context.OpenElementWithId
ui.OpenTextElement = context.OpenTextElement
ui.SetMeasureTextFunction = context.SetMeasureTextFunction
ui.SetQueryScrollOffsetFunction = context.SetQueryScrollOffsetFunction
ui.SetPointerState = context.SetPointerState
ui.UpdateScrollContainers = context.UpdateScrollContainers
ui.GetScrollOffset = context.GetScrollOffset
ui.GetScrollContainerData = context.GetScrollContainerData
ui.CloseElement = context.CloseElement
ui.EndLayout = context.EndLayout
ui.ElementHasConfig = context.ElementHasConfig
ui.FindElementConfigWithType = context.FindElementConfigWithType
ui.FloatEqual = context.FloatEqual
ui.clamp = context.clamp
ui.EPSILON = context.EPSILON
ui.MAXFLOAT = context.MAXFLOAT

return ui
