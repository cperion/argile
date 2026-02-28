local M = {}

function M.build(ui)
    return {
    -- Context/Init
    GetApiVersion = ui.GetApiVersion,
    GetContextSize = ui.GetContextSize,
    CreateArenaWithCapacityAndMemory = ui.CreateArenaWithCapacityAndMemory,
    Initialize = ui.Initialize,
    InitializeContext = ui.InitializeContext,
    GetCurrentContext = ui.GetCurrentContext,
    SetCurrentContext = ui.SetCurrentContext,
    SetMeasureTextFunction = ui.SetMeasureTextFunction,
    SetMeasureTextFunctionForContext = ui.SetMeasureTextFunctionForContext,
    SetErrorHandler = ui.SetErrorHandler,
    SetQueryScrollOffsetFunction = ui.SetQueryScrollOffsetFunction,
    SetLayoutDimensions = ui.SetLayoutDimensions,
    SetLayoutDimensionsForContext = ui.SetLayoutDimensionsForContext,
    GetMaxElementCount = ui.GetMaxElementCount,
    SetMaxElementCount = ui.SetMaxElementCount,
    MinMemorySize = ui.MinMemorySize,
    GetMaxMeasureTextCacheWordCount = ui.GetMaxMeasureTextCacheWordCount,
    SetMaxMeasureTextCacheWordCount = ui.SetMaxMeasureTextCacheWordCount,
    ResetMeasureTextCache = ui.ResetMeasureTextCache,
    ResetMeasureTextCacheForContext = ui.ResetMeasureTextCacheForContext,
    SetDisableCulling = ui.SetDisableCulling,
    SetCullingEnabled = ui.SetCullingEnabled,
    SetDebugModeEnabled = ui.SetDebugModeEnabled,
    IsDebugModeEnabled = ui.IsDebugModeEnabled,
    SetExternalScrollHandlingEnabled = ui.SetExternalScrollHandlingEnabled,

    -- Layout/Frame
    BeginLayout = ui.BeginLayout,
    BeginLayoutForContext = ui.BeginLayoutForContext,
    FinalizeLayout = ui.FinalizeLayout,
    FinalizeLayoutForContext = ui.FinalizeLayoutForContext,
    UpdateScrollContainers = ui.UpdateScrollContainers,
    UpdateScrollContainersForContext = ui.UpdateScrollContainersForContext,
    GetScrollOffset = ui.GetScrollOffset,
    SetElementScrollOffset = ui.SetElementScrollOffset,
    SetElementScrollOffsetForContext = ui.SetElementScrollOffsetForContext,
    GetElementScrollOffset = ui.GetElementScrollOffset,
    GetElementScrollOffsetForContext = ui.GetElementScrollOffsetForContext,
    GetScrollContainerData = ui.GetScrollContainerData,

    -- Element Construction (v2 Descriptor Path)
    OpenElementWithDescForContext = ui.OpenElementWithDescForContext,
    OpenElementWithIdAndDescForContext = ui.OpenElementWithIdAndDescForContext,
    OpenElementWithIdCharsAndDescForContext = ui.OpenElementWithIdCharsAndDescForContext,
    CloseElementForContext = ui.CloseElementForContext,
    GetElementData = ui.GetElementData,

    -- Text
    OpenTextElement = ui.OpenTextElement,
    OpenTextElementForContext = ui.OpenTextElementForContext,
    OpenTextElementWithId = ui.OpenTextElementWithId,
    OpenTextElementWithIdForContext = ui.OpenTextElementWithIdForContext,
    OpenTextElementWithIdChars = ui.OpenTextElementWithIdChars,
    OpenTextElementWithIdCharsForContext = ui.OpenTextElementWithIdCharsForContext,
    OpenTextElementWithLength = ui.OpenTextElementWithLength,
    OpenTextElementWithLengthForContext = ui.OpenTextElementWithLengthForContext,
    OpenTextElementWithLengthAndId = ui.OpenTextElementWithLengthAndId,
    OpenTextElementWithLengthAndIdForContext = ui.OpenTextElementWithLengthAndIdForContext,
    StringFromChars = ui.StringFromChars,

    -- Input/State
    SetPointerState = ui.SetPointerState,
    SetPointerStateForContext = ui.SetPointerStateForContext,
    Hovered = ui.Hovered,
    PointerOver = ui.PointerOver,
    PointerDown = ui.PointerDown,
    ElementActive = ui.ElementActive,
    ElementFocused = ui.ElementFocused,
    ElementSelected = ui.ElementSelected,
    ElementDisabled = ui.ElementDisabled,
    SetElementFocused = ui.SetElementFocused,
    SetElementFocusedForContext = ui.SetElementFocusedForContext,
    SetElementSelected = ui.SetElementSelected,
    SetElementSelectedForContext = ui.SetElementSelectedForContext,
    SetElementDisabled = ui.SetElementDisabled,
    SetElementDisabledForContext = ui.SetElementDisabledForContext,
    OnHoverCurrent = ui.OnHoverCurrent,
    OnHover = ui.OnHover,

    -- Render Output
    GetRenderCommandCount = ui.GetRenderCommandCount,
    GetRenderCommandCountForContext = ui.GetRenderCommandCountForContext,
    GetRenderCommandBuffer = ui.GetRenderCommandBuffer,
    GetRenderCommandBufferForContext = ui.GetRenderCommandBufferForContext,
    GetRenderCommandAt = ui.GetRenderCommandAt,
    GetRenderCommandAtForContext = ui.GetRenderCommandAtForContext,

    -- Hashing/Id
    GetElementId = ui.GetElementId,
    GetElementIdWithIndex = ui.GetElementIdWithIndex,
    GetElementIdFromChars = ui.GetElementIdFromChars,
    GetElementIdWithIndexFromChars = ui.GetElementIdWithIndexFromChars,
    HashData = ui.HashData,
    HashNumber = ui.HashNumber,
    HashString = ui.HashString,
    HashStringWithOffset = ui.HashStringWithOffset,
    }
end

return M
