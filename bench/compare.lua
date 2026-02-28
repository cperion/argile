local ffi = require("ffi")

ffi.cdef[[
struct Clay_Context;

struct Clay_String {
    bool isStaticallyAllocated;
    int32_t length;
    const char *chars;
};

struct Clay_StringSlice {
    int32_t length;
    const char *chars;
    const char *baseChars;
};

struct Clay_Arena {
    uintptr_t nextAllocation;
    size_t capacity;
    char *memory;
};

struct Clay_Dimensions {
    float width;
    float height;
};

struct Clay_Vector2 {
    float x;
    float y;
};

struct Clay_Color {
    float r;
    float g;
    float b;
    float a;
};

struct Clay_CornerRadius {
    float topLeft;
    float topRight;
    float bottomLeft;
    float bottomRight;
};

struct Clay_ErrorData {
    uint8_t errorType;
    struct Clay_String errorText;
    void *userData;
};

struct Clay_ErrorHandler {
    void (*errorHandlerFunction)(struct Clay_ErrorData);
    void *userData;
};

struct Clay_SizingMinMax {
    float min;
    float max;
};

struct Clay_SizingAxis {
    union {
        struct Clay_SizingMinMax minMax;
        float percent;
    } size;
    uint8_t type;
};

struct Clay_Sizing {
    struct Clay_SizingAxis width;
    struct Clay_SizingAxis height;
};

struct Clay_Padding {
    uint16_t left;
    uint16_t right;
    uint16_t top;
    uint16_t bottom;
};

struct Clay_ChildAlignment {
    uint8_t x;
    uint8_t y;
};

struct Clay_LayoutConfig {
    struct Clay_Sizing sizing;
    struct Clay_Padding padding;
    uint16_t childGap;
    struct Clay_ChildAlignment childAlignment;
    uint8_t layoutDirection;
};

struct Clay_TextElementConfig {
    void *userData;
    struct Clay_Color textColor;
    uint16_t fontId;
    uint16_t fontSize;
    uint16_t letterSpacing;
    uint16_t lineHeight;
    uint8_t wrapMode;
    uint8_t textAlignment;
};

struct Clay_AspectRatioElementConfig {
    float aspectRatio;
};

struct Clay_ImageElementConfig {
    void *imageData;
};

struct Clay_FloatingAttachPoints {
    uint8_t element;
    uint8_t parent;
};

struct Clay_FloatingElementConfig {
    struct Clay_Vector2 offset;
    struct Clay_Dimensions expand;
    uint32_t parentId;
    int16_t zIndex;
    struct Clay_FloatingAttachPoints attachPoints;
    uint8_t pointerCaptureMode;
    uint8_t attachTo;
    uint8_t clipTo;
};

struct Clay_CustomElementConfig {
    void *customData;
};

struct Clay_ClipElementConfig {
    bool horizontal;
    bool vertical;
    struct Clay_Vector2 childOffset;
};

struct Clay_BorderWidth {
    uint16_t left;
    uint16_t right;
    uint16_t top;
    uint16_t bottom;
    uint16_t betweenChildren;
};

struct Clay_BorderElementConfig {
    struct Clay_Color color;
    struct Clay_BorderWidth width;
};

struct Clay_ElementDeclaration {
    struct Clay_LayoutConfig layout;
    struct Clay_Color backgroundColor;
    struct Clay_CornerRadius cornerRadius;
    struct Clay_AspectRatioElementConfig aspectRatio;
    struct Clay_ImageElementConfig image;
    struct Clay_FloatingElementConfig floating;
    struct Clay_CustomElementConfig custom;
    struct Clay_ClipElementConfig clip;
    struct Clay_BorderElementConfig border;
    void *userData;
};

struct Clay_RenderCommandArray {
    int32_t capacity;
    int32_t length;
    void *internalArray;
};

enum { CLAY_LEFT_TO_RIGHT = 0 };
enum { CLAY_TOP_TO_BOTTOM = 1 };
enum { CLAY__SIZING_TYPE_FIXED = 3 };
enum { CLAY_TEXT_WRAP_WORDS = 0 };
enum { CLAY_TEXT_WRAP_NONE = 2 };
enum { CLAY_TEXT_ALIGN_LEFT = 0 };

uint32_t Clay_MinMemorySize(void);
struct Clay_Arena Clay_CreateArenaWithCapacityAndMemory(size_t capacity, void *memory);
struct Clay_Context *Clay_Initialize(struct Clay_Arena arena, struct Clay_Dimensions layoutDimensions, struct Clay_ErrorHandler errorHandler);
void Clay_SetCurrentContext(struct Clay_Context *context);
void Clay_SetCullingEnabled(bool enabled);
void Clay_SetLayoutDimensions(struct Clay_Dimensions dimensions);
void Clay_SetMaxElementCount(int32_t maxElementCount);
void Clay_SetMeasureTextFunction(
    struct Clay_Dimensions (*measureTextFunction)(struct Clay_StringSlice text, struct Clay_TextElementConfig *config, void *userData),
    void *userData
);
void Clay_BeginLayout(void);
struct Clay_RenderCommandArray Clay_EndLayout(void);

void Clay__OpenElement(void);
void Clay__ConfigureOpenElementPtr(const struct Clay_ElementDeclaration *config);
void Clay__CloseElement(void);
void Clay__OpenTextElement(struct Clay_String text, struct Clay_TextElementConfig *textConfig);

struct Clay_Dimensions ClayBenchmarkMeasureText(struct Clay_StringSlice text, struct Clay_TextElementConfig *config, void *userData);
void ClayBenchmarkErrorHandler(struct Clay_ErrorData errorData);

struct StringSlice;
struct TextConfig;
struct Dimensions;
int32_t ArgileBenchmarkMeasureText(struct StringSlice *text, struct TextConfig *config, void *userData, struct Dimensions *outDims);
]]

local runtime_mod = require("bindings.luajit.argile_lj.runtime")
local clay_lib = ffi.load("build/libclay.so")
local argile_runtime_lib = ffi.load("build/libargile_runtime.so")

local clay_culling_enabled = false
local argile_culling_enabled = false

local profile = arg[1] or "heavy" -- quick | heavy | stress

local profile_cfg = {
    quick = { width = 1920, height = 1080, max_elements = 30000, arena_bytes = 256 * 1024 * 1024, scale = 0.35 },
    heavy = { width = 2560, height = 1440, max_elements = 50000, arena_bytes = 512 * 1024 * 1024, scale = 1.0 },
    stress = { width = 3840, height = 2160, max_elements = 80000, arena_bytes = 1024 * 1024 * 1024, scale = 1.8 },
}

local cfg = profile_cfg[profile]
if not cfg then
    error("unknown profile: " .. tostring(profile) .. " (use quick|heavy|stress)")
end

local function scaled(n)
    return math.max(1, math.floor(n * cfg.scale))
end

local scenarios = {
    { name = "Flat children", category = "Layout", fn = "bench_frame_fixed_children", args = { scaled(2500) }, iterations = scaled(120), warmup = scaled(16) },
    { name = "Flat children extreme", category = "Stress", fn = "bench_frame_fixed_children", args = { scaled(7000) }, iterations = scaled(40), warmup = scaled(8) },

    { name = "Nested tree 4x4", category = "Layout", fn = "bench_frame_nested", args = { 4, 4 }, iterations = scaled(140), warmup = scaled(12) },
    { name = "Nested tree 5x4", category = "Layout", fn = "bench_frame_nested", args = { 5, 4 }, iterations = scaled(90), warmup = scaled(10) },
    { name = "Nested tree 5x5", category = "Stress", fn = "bench_frame_nested", args = { 5, 5 }, iterations = scaled(36), warmup = scaled(6) },

    { name = "Text feed", category = "Text", fn = "bench_frame_text_rows", args = { scaled(3000) }, iterations = scaled(80), warmup = scaled(10) },
    { name = "Text feed extreme", category = "Stress", fn = "bench_frame_text_rows", args = { scaled(7000) }, iterations = scaled(28), warmup = scaled(5) },

    { name = "Dashboard mixed", category = "Realistic", fn = "bench_frame_dashboard", args = { scaled(24), scaled(36) }, iterations = scaled(80), warmup = scaled(8) },
    { name = "Dashboard dense", category = "Realistic", fn = "bench_frame_dashboard", args = { scaled(40), scaled(50) }, iterations = scaled(36), warmup = scaled(6) },

    { name = "Clip lists", category = "Realistic", fn = "bench_frame_clip_lists", args = { scaled(18), scaled(120) }, iterations = scaled(70), warmup = scaled(8) },
    { name = "Clip lists extreme", category = "Stress", fn = "bench_frame_clip_lists", args = { scaled(30), scaled(180) }, iterations = scaled(24), warmup = scaled(5) },

    { name = "Config churn mixed", category = "Stress", fn = "bench_frame_stress_mixed", args = { scaled(5000) }, iterations = scaled(40), warmup = scaled(8) },
}

local JIT_PREHEAT_CALLS = 128
local SAMPLES_PER_SCENARIO = 3
if (SAMPLES_PER_SCENARIO % 2) == 0 then
    error("SAMPLES_PER_SCENARIO must be odd")
end

local ClayRawBackend = {}
ClayRawBackend.__index = ClayRawBackend

local function init_clay_text_config(tc, lib, r, g, b, a, font_size, line_height)
    tc.userData = nil
    tc.textColor.r = r
    tc.textColor.g = g
    tc.textColor.b = b
    tc.textColor.a = a
    tc.fontId = 0
    tc.fontSize = font_size
    tc.letterSpacing = 0
    tc.lineHeight = line_height
    tc.wrapMode = lib.CLAY_TEXT_WRAP_WORDS
    tc.textAlignment = lib.CLAY_TEXT_ALIGN_LEFT
end

function ClayRawBackend.new()
    local self = setmetatable({
        lib = clay_lib,
        ctx = nil,
        arena_mem = nil,
        width = 800,
        height = 600,
        decl = ffi.new("struct Clay_ElementDeclaration[1]"),
        text_cfg_14 = ffi.new("struct Clay_TextElementConfig[1]"),
        text_cfg_13 = ffi.new("struct Clay_TextElementConfig[1]"),
        custom_token = ffi.new("char[1]", 0),
        image_token = ffi.new("char[1]", 0),
    }, ClayRawBackend)

    init_clay_text_config(self.text_cfg_14[0], self.lib, 255, 255, 255, 255, 14, 16)
    init_clay_text_config(self.text_cfg_13[0], self.lib, 230, 230, 240, 255, 13, 16)

    self.text_hello_raw = "hello world"
    self.text_hello = ffi.new("struct Clay_String", {
        isStaticallyAllocated = true,
        length = #self.text_hello_raw,
        chars = self.text_hello_raw,
    })

    self.text_widget_raw = "widget title value"
    self.text_widget = ffi.new("struct Clay_String", {
        isStaticallyAllocated = true,
        length = #self.text_widget_raw,
        chars = self.text_widget_raw,
    })

    return self
end

function ClayRawBackend:bench_init(width, height, max_elements, arena_bytes)
    self:bench_shutdown()

    self.width = width
    self.height = height

    local lib = self.lib
    local arena_cap = arena_bytes
    if arena_cap <= 0 then
        arena_cap = 32 * 1024 * 1024
    end
    local min_required = tonumber(lib.Clay_MinMemorySize())
    if arena_cap < min_required then
        arena_cap = min_required
    end

    self.arena_mem = ffi.new("char[?]", arena_cap)
    local arena = lib.Clay_CreateArenaWithCapacityAndMemory(arena_cap, self.arena_mem)
    local dims = ffi.new("struct Clay_Dimensions", { width = width, height = height })
    local error_handler = ffi.new("struct Clay_ErrorHandler", {
        errorHandlerFunction = lib.ClayBenchmarkErrorHandler,
        userData = nil,
    })

    self.ctx = lib.Clay_Initialize(arena, dims, error_handler)
    if self.ctx == nil or self.ctx == ffi.NULL then
        self.ctx = nil
        self.arena_mem = nil
        return 0
    end

    lib.Clay_SetCurrentContext(self.ctx)
    lib.Clay_SetMaxElementCount(max_elements)
    lib.Clay_SetCullingEnabled(clay_culling_enabled)
    lib.Clay_SetLayoutDimensions(dims)
    lib.Clay_SetMeasureTextFunction(lib.ClayBenchmarkMeasureText, nil)
    return 1
end

function ClayRawBackend:bench_shutdown()
    if self.ctx ~= nil then
        self.lib.Clay_SetCurrentContext(nil)
    end
    self.ctx = nil
    self.arena_mem = nil
    return 1
end

function ClayRawBackend:_open_box(width, height, direction, padding, child_gap, r, g, b, a, border_width, border_r, border_g, border_b, clip_h, clip_v, custom, image, aspect_ratio)
    local lib = self.lib
    local decl = self.decl[0]

    decl.layout.sizing.width.type = lib.CLAY__SIZING_TYPE_FIXED
    decl.layout.sizing.width.size.minMax.min = width
    decl.layout.sizing.width.size.minMax.max = width
    decl.layout.sizing.height.type = lib.CLAY__SIZING_TYPE_FIXED
    decl.layout.sizing.height.size.minMax.min = height
    decl.layout.sizing.height.size.minMax.max = height
    decl.layout.layoutDirection = direction
    decl.layout.padding.left = padding
    decl.layout.padding.right = padding
    decl.layout.padding.top = padding
    decl.layout.padding.bottom = padding
    decl.layout.childGap = child_gap

    decl.backgroundColor.r = r
    decl.backgroundColor.g = g
    decl.backgroundColor.b = b
    decl.backgroundColor.a = a

    decl.border.width.left = 0
    decl.border.width.right = 0
    decl.border.width.top = 0
    decl.border.width.bottom = 0
    decl.border.width.betweenChildren = 0
    decl.clip.horizontal = false
    decl.clip.vertical = false
    decl.clip.childOffset.x = 0
    decl.clip.childOffset.y = 0
    decl.custom.customData = nil
    decl.image.imageData = nil
    decl.aspectRatio.aspectRatio = 0

    if border_width ~= nil and border_width > 0 then
        decl.border.color.r = border_r or 255
        decl.border.color.g = border_g or 255
        decl.border.color.b = border_b or 255
        decl.border.color.a = 255
        decl.border.width.left = border_width
        decl.border.width.right = border_width
        decl.border.width.top = border_width
        decl.border.width.bottom = border_width
    end

    if clip_h ~= nil or clip_v ~= nil then
        decl.clip.horizontal = clip_h and true or false
        decl.clip.vertical = clip_v and true or false
    end

    if custom then
        decl.custom.customData = self.custom_token
    end
    if image then
        decl.image.imageData = self.image_token
    end
    if aspect_ratio ~= nil then
        decl.aspectRatio.aspectRatio = aspect_ratio
    end

    lib.Clay__OpenElement()
    lib.Clay__ConfigureOpenElementPtr(self.decl)
end

function ClayRawBackend:_open_text(text, text_cfg)
    self.lib.Clay__OpenTextElement(text, text_cfg)
end

function ClayRawBackend:_close()
    self.lib.Clay__CloseElement()
end

function ClayRawBackend:begin_frame()
    self.lib.Clay_SetCurrentContext(self.ctx)
    self.lib.Clay_BeginLayout()
end

function ClayRawBackend:end_frame()
    return tonumber(self.lib.Clay_EndLayout().length)
end

function ClayRawBackend:_build_nested(depth, branch)
    if depth <= 0 then
        return
    end

    for _ = 1, branch do
        self:_open_box(20.0 + depth, 20.0 + depth, self.lib.CLAY_LEFT_TO_RIGHT, 0, 0, 80, 140, 240, 255)
        if depth > 1 then
            self:_build_nested(depth - 1, branch)
        end
        self:_close()
    end
end

function ClayRawBackend:bench_frame_fixed_children(child_count)
    self:begin_frame()
    for _ = 1, child_count do
        self:_open_box(24.0, 24.0, self.lib.CLAY_LEFT_TO_RIGHT, 0, 0, 220, 120, 90, 255)
        self:_close()
    end
    return self:end_frame()
end

function ClayRawBackend:bench_frame_nested(depth, branch)
    self:begin_frame()
    self:_build_nested(depth, branch)
    return self:end_frame()
end

function ClayRawBackend:bench_frame_text_rows(row_count)
    self:begin_frame()
    for _ = 1, row_count do
        self:_open_text(self.text_hello, self.text_cfg_14)
    end
    return self:end_frame()
end

function ClayRawBackend:bench_frame_dashboard(panel_count, widgets_per_panel)
    self:begin_frame()

    for _ = 1, panel_count do
        self:_open_box(360.0, 320.0, self.lib.CLAY_TOP_TO_BOTTOM, 8, 4, 25, 35, 50, 255, 1, 60, 70, 90)

        for w = 0, widgets_per_panel - 1 do
            if w % 3 == 0 then
                self:_open_text(self.text_widget, self.text_cfg_13)
            else
                self:_open_box(330.0, 24.0, self.lib.CLAY_LEFT_TO_RIGHT, 0, 0, 50, 80, 120, 255, nil, nil, nil, nil, nil, nil, (w % 2 == 0), (w % 2 ~= 0))
                self:_close()
            end
        end

        self:_close()
    end

    return self:end_frame()
end

function ClayRawBackend:bench_frame_clip_lists(list_count, rows_per_list)
    self:begin_frame()

    for _ = 1, list_count do
        self:_open_box(280.0, 220.0, self.lib.CLAY_TOP_TO_BOTTOM, 4, 2, 20, 25, 32, 255, 1, 40, 50, 70, true, true)

        for _ = 1, rows_per_list do
            self:_open_box(260.0, 18.0, self.lib.CLAY_LEFT_TO_RIGHT, 0, 0, 70, 90, 110, 255)
            self:_close()
        end

        self:_close()
    end

    return self:end_frame()
end

function ClayRawBackend:bench_frame_stress_mixed(element_count)
    self:begin_frame()

    for i = 0, element_count - 1 do
        local w = 16.0 + (i % 7) * 6.0
        local h = 12.0 + (i % 5) * 5.0
        local border_width, border_r, border_g, border_b = nil, nil, nil, nil
        local custom, image, aspect_ratio = nil, nil, nil
        local mode = i % 5
        if mode == 0 then
            border_width, border_r, border_g, border_b = 1, 180, 150, 90
        elseif mode == 1 then
            custom = true
        elseif mode == 2 then
            image = true
        elseif mode == 3 then
            aspect_ratio = 1.5
        end

        self:_open_box(
            w, h, self.lib.CLAY_LEFT_TO_RIGHT, 0, 0,
            30 + (i % 200), 40 + (i % 160), 80 + (i % 120), 255,
            border_width, border_r, border_g, border_b,
            nil, nil,
            custom, image, aspect_ratio
        )
        self:_close()
    end

    return self:end_frame()
end

local ArgileCapiBackend = {}
ArgileCapiBackend.__index = ArgileCapiBackend

local function init_text_config(tc, lib, r, g, b, a, font_size, line_height)
    tc.userData = nil
    tc.textColor.r = r
    tc.textColor.g = g
    tc.textColor.b = b
    tc.textColor.a = a
    tc.fontId = 0
    tc.fontSize = font_size
    tc.letterSpacing = 0
    tc.lineHeight = line_height
    tc.wrapMode = lib.TEXT_WRAP_WORDS
    tc.textAlignment = lib.TEXT_ALIGN_LEFT
end

function ArgileCapiBackend.new()
    local runtime = runtime_mod.load({
        ffi_def_path = "build/argile_api_ffi.lua",
        lib_path = "build/libargile.so",
    })

    local self = setmetatable({
        runtime = runtime,
        ffi = runtime.ffi,
        lib = runtime.lib,
        ctx = nil,
        ctx_storage = nil,
        arena_mem = nil,
        width = 800,
        height = 600,
    }, ArgileCapiBackend)

    self.text_hello = "hello world"
    self.text_hello_ptr = self.ffi.cast("char*", self.text_hello)
    self.text_hello_len = #self.text_hello
    self.text_widget = "widget title value"
    self.text_widget_ptr = self.ffi.cast("char*", self.text_widget)
    self.text_widget_len = #self.text_widget

    self.text_cfg_14 = self.ffi.new("struct TextConfig[1]")
    init_text_config(self.text_cfg_14[0], self.lib, 255, 255, 255, 255, 14, 16)
    self.text_cfg_13 = self.ffi.new("struct TextConfig[1]")
    init_text_config(self.text_cfg_13[0], self.lib, 230, 230, 240, 255, 13, 16)

    self.layout_cfg = self.ffi.new("struct LayoutConfig[1]")
    self.shared_cfg = self.ffi.new("struct SharedConfig[1]")
    self.border_cfg = self.ffi.new("struct BorderConfig[1]")
    self.clip_cfg = self.ffi.new("struct ClipConfig[1]")
    self.custom_cfg = self.ffi.new("struct CustomConfig[1]")
    self.image_cfg = self.ffi.new("struct ImageConfig[1]")
    self.aspect_cfg = self.ffi.new("struct AspectRatioConfig[1]")
    self.desc = self.ffi.new("struct ElementDesc[1]")

    self.custom_cfg[0].customData = nil
    self.image_cfg[0].imageData = nil
    self.clip_cfg[0].childOffset.x = 0
    self.clip_cfg[0].childOffset.y = 0

    return self
end

function ArgileCapiBackend:bench_init(width, height, max_elements, arena_bytes)
    self:bench_shutdown()

    self.width = width
    self.height = height

    local lib = self.lib
    local ffi_local = self.ffi
    local arena_cap = arena_bytes
    if arena_cap <= 0 then
        arena_cap = 32 * 1024 * 1024
    end

    self.arena_mem = ffi_local.new("char[?]", arena_cap)
    local arena = lib.CreateArenaWithCapacityAndMemory(arena_cap, self.arena_mem)

    local ctx_size = tonumber(lib.GetContextSize())
    self.ctx_storage = ffi_local.new("uint8_t[?]", ctx_size)
    self.ctx = ffi_local.cast("struct Context*", self.ctx_storage)

    local ok = lib.InitializeContext(self.ctx, arena, max_elements)
    if not ok then
        self.ctx = nil
        self.ctx_storage = nil
        self.arena_mem = nil
        return 0
    end

    local dims = ffi_local.new("struct Dimensions", { width = width, height = height })
    lib.SetLayoutDimensionsForContext(self.ctx, dims)
    lib.SetCullingEnabled(argile_culling_enabled)
    lib.SetMeasureTextFunctionForContext(self.ctx, argile_runtime_lib.ArgileBenchmarkMeasureText, nil)
    return 1
end

function ArgileCapiBackend:bench_shutdown()
    if self.ctx ~= nil then
        self.lib.SetMeasureTextFunctionForContext(self.ctx, nil, nil)
    end
    self.ctx = nil
    self.ctx_storage = nil
    self.arena_mem = nil
    return 1
end

function ArgileCapiBackend:dispose()
    self:bench_shutdown()
end

function ArgileCapiBackend:open_box(width, height, direction, padding, child_gap, r, g, b, a, border_width, border_r, border_g, border_b, clip_h, clip_v, custom, image, aspect_ratio)
    local lib = self.lib
    local layout_cfg = self.layout_cfg[0]
    layout_cfg.sizing.width.type = lib.SIZING_FIXED
    layout_cfg.sizing.width.size.min = width
    layout_cfg.sizing.width.size.max = width
    layout_cfg.sizing.width.percent = 0
    layout_cfg.sizing.height.type = lib.SIZING_FIXED
    layout_cfg.sizing.height.size.min = height
    layout_cfg.sizing.height.size.max = height
    layout_cfg.sizing.height.percent = 0
    layout_cfg.padding.left = padding
    layout_cfg.padding.right = padding
    layout_cfg.padding.top = padding
    layout_cfg.padding.bottom = padding
    layout_cfg.childGap = child_gap
    layout_cfg.childAlignment.x = lib.ALIGN_X_LEFT
    layout_cfg.childAlignment.y = lib.ALIGN_Y_TOP
    layout_cfg.layoutDirection = direction

    local shared_cfg = self.shared_cfg[0]
    shared_cfg.backgroundColor.r = r
    shared_cfg.backgroundColor.g = g
    shared_cfg.backgroundColor.b = b
    shared_cfg.backgroundColor.a = a
    shared_cfg.cornerRadius.topLeft = 0
    shared_cfg.cornerRadius.topRight = 0
    shared_cfg.cornerRadius.bottomLeft = 0
    shared_cfg.cornerRadius.bottomRight = 0
    shared_cfg.userData = nil

    local desc = self.desc[0]
    desc.flags = lib.DESC_HAS_LAYOUT + lib.DESC_HAS_SHARED
    desc.layout = self.layout_cfg[0]
    desc.shared = self.shared_cfg[0]

    if border_width ~= nil and border_width > 0 then
        local cfg = self.border_cfg[0]
        cfg.color.r = border_r or 255
        cfg.color.g = border_g or 255
        cfg.color.b = border_b or 255
        cfg.color.a = 255
        cfg.width.left = border_width
        cfg.width.right = border_width
        cfg.width.top = border_width
        cfg.width.bottom = border_width
        cfg.width.betweenChildren = 0
        desc.flags = desc.flags + lib.DESC_HAS_BORDER
        desc.border = cfg
    end

    if clip_h ~= nil or clip_v ~= nil then
        local cfg = self.clip_cfg[0]
        cfg.horizontal = clip_h and true or false
        cfg.vertical = clip_v and true or false
        cfg.childOffset.x = 0
        cfg.childOffset.y = 0
        desc.flags = desc.flags + lib.DESC_HAS_CLIP
        desc.clip = cfg
    end

    if custom then
        self.custom_cfg[0].customData = nil
        desc.flags = desc.flags + lib.DESC_HAS_CUSTOM
        desc.custom = self.custom_cfg[0]
    end
    if image then
        self.image_cfg[0].imageData = nil
        desc.flags = desc.flags + lib.DESC_HAS_IMAGE
        desc.image = self.image_cfg[0]
    end
    if aspect_ratio ~= nil then
        self.aspect_cfg[0].aspectRatio = aspect_ratio
        desc.flags = desc.flags + lib.DESC_HAS_ASPECT
        desc.aspect = self.aspect_cfg[0]
    end

    lib.OpenElementWithDescForContext(self.ctx, self.desc)
end

function ArgileCapiBackend:open_text(ptr, len, text_cfg_ptr)
    self.lib.OpenTextElementWithLengthForContext(self.ctx, ptr, len, text_cfg_ptr)
end

function ArgileCapiBackend:begin_frame()
    self.lib.BeginLayoutForContext(self.ctx, self.width, self.height)
end

function ArgileCapiBackend:end_frame()
    return tonumber(self.lib.FinalizeLayoutForContext(self.ctx))
end

function ArgileCapiBackend:_build_nested(depth, branch)
    if depth <= 0 then
        return
    end

    for _ = 1, branch do
        self:open_box(20.0 + depth, 20.0 + depth, self.lib.LEFT_TO_RIGHT, 0, 0, 80, 140, 240, 255)
        if depth > 1 then
            self:_build_nested(depth - 1, branch)
        end
        self.lib.CloseElementForContext(self.ctx)
    end
end

function ArgileCapiBackend:bench_frame_fixed_children(child_count)
    self:begin_frame()
    for _ = 1, child_count do
        self:open_box(24.0, 24.0, self.lib.LEFT_TO_RIGHT, 0, 0, 220, 120, 90, 255)
        self.lib.CloseElementForContext(self.ctx)
    end
    return self:end_frame()
end

function ArgileCapiBackend:bench_frame_nested(depth, branch)
    self:begin_frame()
    self:_build_nested(depth, branch)
    return self:end_frame()
end

function ArgileCapiBackend:bench_frame_text_rows(row_count)
    self:begin_frame()
    for _ = 1, row_count do
        self:open_text(self.text_hello_ptr, self.text_hello_len, self.text_cfg_14)
    end
    return self:end_frame()
end

function ArgileCapiBackend:bench_frame_dashboard(panel_count, widgets_per_panel)
    self:begin_frame()

    for _ = 1, panel_count do
        self:open_box(360.0, 320.0, self.lib.TOP_TO_BOTTOM, 8, 4, 25, 35, 50, 255, 1, 60, 70, 90)

        for w = 0, widgets_per_panel - 1 do
            if w % 3 == 0 then
                self:open_text(self.text_widget_ptr, self.text_widget_len, self.text_cfg_13)
            else
                self:open_box(330.0, 24.0, self.lib.LEFT_TO_RIGHT, 0, 0, 50, 80, 120, 255, nil, nil, nil, nil, nil, nil, (w % 2 == 0), (w % 2 ~= 0))
                self.lib.CloseElementForContext(self.ctx)
            end
        end

        self.lib.CloseElementForContext(self.ctx)
    end

    return self:end_frame()
end

function ArgileCapiBackend:bench_frame_clip_lists(list_count, rows_per_list)
    self:begin_frame()

    for _ = 1, list_count do
        self:open_box(280.0, 220.0, self.lib.TOP_TO_BOTTOM, 4, 2, 20, 25, 32, 255, 1, 40, 50, 70, true, true)

        for _ = 1, rows_per_list do
            self:open_box(260.0, 18.0, self.lib.LEFT_TO_RIGHT, 0, 0, 70, 90, 110, 255)
            self.lib.CloseElementForContext(self.ctx)
        end

        self.lib.CloseElementForContext(self.ctx)
    end

    return self:end_frame()
end

function ArgileCapiBackend:bench_frame_stress_mixed(element_count)
    self:begin_frame()

    for i = 0, element_count - 1 do
        local w = 16.0 + (i % 7) * 6.0
        local h = 12.0 + (i % 5) * 5.0
        local border_width, border_r, border_g, border_b = nil, nil, nil, nil
        local custom, image, aspect_ratio = nil, nil, nil
        local mode = i % 5
        if mode == 0 then
            border_width, border_r, border_g, border_b = 1, 180, 150, 90
        elseif mode == 1 then
            custom = true
        elseif mode == 2 then
            image = true
        elseif mode == 3 then
            aspect_ratio = 1.5
        end

        self:open_box(
            w, h, self.lib.LEFT_TO_RIGHT, 0, 0,
            30 + (i % 200), 40 + (i % 160), 80 + (i % 120), 255,
            border_width, border_r, border_g, border_b,
            nil, nil,
            custom, image, aspect_ratio
        )
        self.lib.CloseElementForContext(self.ctx)
    end

    return self:end_frame()
end

local function scenario_signature(scenario)
    local args = {}
    for i = 1, #scenario.args do
        args[i] = tostring(scenario.args[i])
    end
    return scenario.fn .. "(" .. table.concat(args, ",") .. ")"
end

local function run_lib(lib, scenario, preheated)
    local ok = tonumber(lib:bench_init(cfg.width, cfg.height, cfg.max_elements, cfg.arena_bytes))
    if ok ~= 1 then
        error("bench_init failed for " .. scenario.name)
    end

    local sig = scenario_signature(scenario)
    if not preheated[sig] then
        for _ = 1, JIT_PREHEAT_CALLS do
            lib[scenario.fn](lib, unpack(scenario.args))
        end
        preheated[sig] = true
    end

    for _ = 1, scenario.warmup do
        lib[scenario.fn](lib, unpack(scenario.args))
    end

    local checksum = 0
    -- Keep GC pauses out of timed sections for more stable per-scenario numbers.
    collectgarbage("collect")
    collectgarbage("stop")
    local t0 = os.clock()
    for _ = 1, scenario.iterations do
        checksum = checksum + tonumber(lib[scenario.fn](lib, unpack(scenario.args)))
    end
    local dt = os.clock() - t0
    collectgarbage("restart")

    lib:bench_shutdown()

    return {
        total_s = dt,
        ms_per_frame = (dt * 1000.0) / scenario.iterations,
        fps = scenario.iterations / dt,
        checksum = checksum,
    }
end

local function fmt_args(args)
    local t = {}
    for i = 1, #args do t[i] = tostring(args[i]) end
    return table.concat(t, ",")
end

local function pad(s, w)
    s = tostring(s)
    if #s >= w then return s end
    return s .. string.rep(" ", w - #s)
end

local function median_run(samples)
    local sorted = {}
    for i = 1, #samples do
        sorted[i] = samples[i]
    end
    table.sort(sorted, function(a, b) return a.total_s < b.total_s end)
    return sorted[math.floor((#sorted + 1) / 2)]
end

local function assert_stable_checksums(label, scenario, samples)
    if #samples == 0 then
        return
    end
    local checksum = samples[1].checksum
    for i = 2, #samples do
        if samples[i].checksum ~= checksum then
            error(("%s checksum instability in '%s': sample1=%d sample%d=%d"):format(
                label, scenario.name, checksum, i, samples[i].checksum
            ))
        end
    end
end

local clay = ClayRawBackend.new()
local argile = ArgileCapiBackend.new()
local results = {}
local clay_preheated = {}
local argile_preheated = {}

print(("Clay vs Argile Benchmark Suite (%s profile, LuaJIT FFI raw APIs)"):format(profile))
print(("Resolution=%dx%d max_elements=%d arena=%.1fMB"):format(cfg.width, cfg.height, cfg.max_elements, cfg.arena_bytes / 1024 / 1024))
print("Fair mode: strict (always on)")
print(("Culling: clay=%s argile=%s"):format(tostring(clay_culling_enabled), tostring(argile_culling_enabled)))
print(("JIT preheat: %d untimed calls per backend/function"):format(JIT_PREHEAT_CALLS))
print(("Sampling: %d runs per scenario, alternating backend order, median result"):format(SAMPLES_PER_SCENARIO))
print(("Scenarios=%d"):format(#scenarios))
io.stdout:flush()

for i, s in ipairs(scenarios) do
    print(("[%02d/%02d] %-20s (%s) fn=%s(%s)"):format(i, #scenarios, s.name, s.category, s.fn, fmt_args(s.args)))
    io.stdout:flush()

    local clay_samples = {}
    local argile_samples = {}

    for sample_idx = 1, SAMPLES_PER_SCENARIO do
        local clay_first = ((i + sample_idx) % 2) == 0
        if clay_first then
            clay_samples[#clay_samples + 1] = run_lib(clay, s, clay_preheated)
            argile_samples[#argile_samples + 1] = run_lib(argile, s, argile_preheated)
        else
            argile_samples[#argile_samples + 1] = run_lib(argile, s, argile_preheated)
            clay_samples[#clay_samples + 1] = run_lib(clay, s, clay_preheated)
        end
    end

    assert_stable_checksums("Clay", s, clay_samples)
    assert_stable_checksums("Argile", s, argile_samples)

    local clay_r = median_run(clay_samples)
    local argile_r = median_run(argile_samples)

    local speedup = clay_r.total_s / argile_r.total_s
    local checksum_delta = argile_r.checksum - clay_r.checksum

    results[#results + 1] = {
        scenario = s.name,
        category = s.category,
        clay_ms = clay_r.ms_per_frame,
        argile_ms = argile_r.ms_per_frame,
        clay_fps = clay_r.fps,
        argile_fps = argile_r.fps,
        speedup = speedup,
        clay_checksum = clay_r.checksum,
        argile_checksum = argile_r.checksum,
        checksum_delta = checksum_delta,
    }
end

print("\nFinal Comparison Table")
local headers = {
    {"Scenario", 24},
    {"Category", 10},
    {"Clay ms/f", 10},
    {"Argile ms/f", 11},
    {"Clay FPS", 10},
    {"Argile FPS", 10},
    {"Speedup", 8},
    {"Clay Sum", 10},
    {"Argile Sum", 10},
}

local line = {}
for _, h in ipairs(headers) do line[#line + 1] = pad(h[1], h[2]) end
print(table.concat(line, " | "))
print(string.rep("-", 24 + 3 + 10 + 3 + 10 + 3 + 11 + 3 + 10 + 3 + 10 + 3 + 8 + 3 + 10 + 3 + 10))

local sum_speedup = 0
local prod_speedup = 1
local best = nil
local worst = nil
local mismatches = {}

for _, r in ipairs(results) do
    local row = {
        pad(r.scenario, 24),
        pad(r.category, 10),
        pad(string.format("%.3f", r.clay_ms), 10),
        pad(string.format("%.3f", r.argile_ms), 11),
        pad(string.format("%.0f", r.clay_fps), 10),
        pad(string.format("%.0f", r.argile_fps), 10),
        pad(string.format("%.2fx", r.speedup), 8),
        pad(tostring(r.clay_checksum), 10),
        pad(tostring(r.argile_checksum), 10),
    }
    print(table.concat(row, " | "))

    sum_speedup = sum_speedup + r.speedup
    prod_speedup = prod_speedup * r.speedup
    if (not best) or r.speedup > best.speedup then best = r end
    if (not worst) or r.speedup < worst.speedup then worst = r end
    if r.checksum_delta ~= 0 then
        mismatches[#mismatches + 1] = r
    end
end

local avg_speedup = sum_speedup / #results
local geo_speedup = prod_speedup ^ (1 / #results)

print("\nSummary")
print(("  Average speedup (arithmetic): %.2fx"):format(avg_speedup))
print(("  Average speedup (geometric):  %.2fx"):format(geo_speedup))
print(("  Best scenario:  %s (%.2fx)"):format(best.scenario, best.speedup))
print(("  Worst scenario: %s (%.2fx)"):format(worst.scenario, worst.speedup))
print(("  Parity mismatches: %d"):format(#mismatches))

if #mismatches > 0 then
    print("\nStrict parity failure: checksum mismatch detected")
    for _, m in ipairs(mismatches) do
        print(("  - %s: clay=%d argile=%d delta=%d"):format(m.scenario, m.clay_checksum, m.argile_checksum, m.checksum_delta))
    end
end

argile:dispose()

if #mismatches > 0 then
    os.exit(1)
end
