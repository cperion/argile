#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define CLAY_IMPLEMENTATION
#include "../ref/clay.h"

#define MAX_PROBES 200000
#define SCENARIO_COUNT 15

static void *g_mem = NULL;
static size_t g_mem_size = 0;
static int g_width = 1920;
static int g_height = 1080;
static bool g_initialized = false;

static uint32_t g_probe_ids[MAX_PROBES];
static int g_probe_count = 0;

static void parity_error_handler(Clay_ErrorData errorData) {
    (void)errorData;
}

static Clay_Dimensions parity_measure_text(Clay_StringSlice text, Clay_TextElementConfig *config, void *userData) {
    (void)config;
    (void)userData;
    Clay_Dimensions d = { (float)(text.length * 8), 16.0f };
    return d;
}

static Clay_String make_string(const char *chars) {
    Clay_String s;
    s.isStaticallyAllocated = true;
    s.length = (int32_t)strlen(chars);
    s.chars = chars;
    return s;
}

static Clay_ElementId make_id(const char *base, uint32_t index) {
    return Clay_GetElementIdWithIndex(make_string(base), index);
}

static void push_probe(Clay_ElementId id) {
    if (g_probe_count < MAX_PROBES) {
        g_probe_ids[g_probe_count++] = id.id;
    }
}

static void configure_current(
    Clay__SizingType width_type, float width_min, float width_max, float width_percent,
    Clay__SizingType height_type, float height_min, float height_max, float height_percent,
    Clay_LayoutDirection dir, uint16_t pad, uint16_t gap, Clay_Color color
) {
    Clay_ElementDeclaration decl = {0};
    decl.layout.sizing.width.type = width_type;
    if (width_type == CLAY__SIZING_TYPE_PERCENT) {
        decl.layout.sizing.width.size.percent = width_percent;
    } else {
        decl.layout.sizing.width.size.minMax.min = width_min;
        decl.layout.sizing.width.size.minMax.max = width_max;
    }

    decl.layout.sizing.height.type = height_type;
    if (height_type == CLAY__SIZING_TYPE_PERCENT) {
        decl.layout.sizing.height.size.percent = height_percent;
    } else {
        decl.layout.sizing.height.size.minMax.min = height_min;
        decl.layout.sizing.height.size.minMax.max = height_max;
    }

    decl.layout.padding.left = pad;
    decl.layout.padding.right = pad;
    decl.layout.padding.top = pad;
    decl.layout.padding.bottom = pad;
    decl.layout.childGap = gap;
    decl.layout.childAlignment.x = CLAY_ALIGN_X_LEFT;
    decl.layout.childAlignment.y = CLAY_ALIGN_Y_TOP;
    decl.layout.layoutDirection = dir;
    decl.backgroundColor = color;
    Clay__ConfigureOpenElement(decl);
}

static void open_fixed_probe(const char *base, uint32_t index, float w, float h, Clay_LayoutDirection dir, uint16_t pad, uint16_t gap, Clay_Color color) {
    Clay_ElementId id = make_id(base, index);
    Clay__OpenElementWithId(id);
    configure_current(
        CLAY__SIZING_TYPE_FIXED, w, w, 0.0f,
        CLAY__SIZING_TYPE_FIXED, h, h, 0.0f,
        dir, pad, gap, color
    );
    push_probe(id);
}

static void open_fit_probe(const char *base, uint32_t index, Clay_LayoutDirection dir, uint16_t pad, uint16_t gap, Clay_Color color) {
    Clay_ElementId id = make_id(base, index);
    Clay__OpenElementWithId(id);
    configure_current(
        CLAY__SIZING_TYPE_FIT, 0.0f, 0.0f, 0.0f,
        CLAY__SIZING_TYPE_FIT, 0.0f, 0.0f, 0.0f,
        dir, pad, gap, color
    );
    push_probe(id);
}

static void open_percent_probe(const char *base, uint32_t index, float width_percent, Clay_LayoutDirection dir, uint16_t pad, uint16_t gap, Clay_Color color) {
    Clay_ElementId id = make_id(base, index);
    Clay__OpenElementWithId(id);
    configure_current(
        CLAY__SIZING_TYPE_PERCENT, 0.0f, 0.0f, width_percent,
        CLAY__SIZING_TYPE_GROW, 0.0f, 0.0f, 0.0f,
        dir, pad, gap, color
    );
    push_probe(id);
}

static void attach_border(uint16_t width, Clay_Color color) {
    Clay_BorderElementConfig border = {0};
    border.color = color;
    border.width.left = width;
    border.width.right = width;
    border.width.top = width;
    border.width.bottom = width;
    border.width.betweenChildren = 0;
    Clay__AttachElementConfig((Clay_ElementConfigUnion){ .borderElementConfig = Clay__StoreBorderElementConfig(border) }, CLAY__ELEMENT_CONFIG_TYPE_BORDER);
}

static void attach_clip(bool horizontal, bool vertical) {
    Clay_ClipElementConfig clip = {0};
    clip.horizontal = horizontal;
    clip.vertical = vertical;
    clip.childOffset = (Clay_Vector2){0, 0};
    Clay__AttachElementConfig((Clay_ElementConfigUnion){ .clipElementConfig = Clay__StoreClipElementConfig(clip) }, CLAY__ELEMENT_CONFIG_TYPE_CLIP);
    if (horizontal || vertical) {
        Clay_Context *ctx = Clay_GetCurrentContext();
        Clay_LayoutElement *open = Clay__GetOpenLayoutElement();
        if (ctx && open) {
            Clay__int32_tArray_Add(&ctx->openClipElementStack, (int)open->id);
            Clay__ScrollContainerDataInternal *scroll = NULL;
            for (int32_t i = 0; i < ctx->scrollContainerDatas.length; i++) {
                Clay__ScrollContainerDataInternal *mapping = Clay__ScrollContainerDataInternalArray_Get(&ctx->scrollContainerDatas, i);
                if (mapping && mapping->elementId == open->id) {
                    scroll = mapping;
                    scroll->layoutElement = open;
                    scroll->openThisFrame = true;
                    break;
                }
            }
            if (!scroll) {
                scroll = Clay__ScrollContainerDataInternalArray_Add(
                    &ctx->scrollContainerDatas,
                    (Clay__ScrollContainerDataInternal){
                        .layoutElement = open,
                        .scrollOrigin = { -1, -1 },
                        .elementId = open->id,
                        .openThisFrame = true
                    }
                );
            }
            if (scroll && ctx->externalScrollHandlingEnabled) {
                scroll->scrollPosition = Clay__QueryScrollOffset(scroll->elementId, ctx->queryScrollOffsetUserData);
            }
        }
    }
}

static void attach_custom(void) {
    Clay_CustomElementConfig custom = {0};
    custom.customData = NULL;
    Clay__AttachElementConfig((Clay_ElementConfigUnion){ .customElementConfig = Clay__StoreCustomElementConfig(custom) }, CLAY__ELEMENT_CONFIG_TYPE_CUSTOM);
}

static void attach_image(void) {
    Clay_ImageElementConfig image = {0};
    image.imageData = NULL;
    Clay__AttachElementConfig((Clay_ElementConfigUnion){ .imageElementConfig = Clay__StoreImageElementConfig(image) }, CLAY__ELEMENT_CONFIG_TYPE_IMAGE);
}

static void attach_aspect(float ratio) {
    Clay_AspectRatioElementConfig aspect = {0};
    aspect.aspectRatio = ratio;
    Clay__AttachElementConfig((Clay_ElementConfigUnion){ .aspectRatioElementConfig = Clay__StoreAspectRatioElementConfig(aspect) }, CLAY__ELEMENT_CONFIG_TYPE_ASPECT);
    Clay_Context *ctx = Clay_GetCurrentContext();
    if (ctx) {
        Clay__int32_tArray_Add(&ctx->aspectRatioElementIndexes, ctx->layoutElements.length - 1);
    }
}

static void attach_clip_offset(bool horizontal, bool vertical, float offset_x, float offset_y) {
    Clay_ClipElementConfig clip = {0};
    clip.horizontal = horizontal;
    clip.vertical = vertical;
    clip.childOffset = (Clay_Vector2){offset_x, offset_y};
    Clay__AttachElementConfig((Clay_ElementConfigUnion){ .clipElementConfig = Clay__StoreClipElementConfig(clip) }, CLAY__ELEMENT_CONFIG_TYPE_CLIP);
    if (horizontal || vertical) {
        Clay_Context *ctx = Clay_GetCurrentContext();
        Clay_LayoutElement *open = Clay__GetOpenLayoutElement();
        if (ctx && open) {
            Clay__int32_tArray_Add(&ctx->openClipElementStack, (int)open->id);
            Clay__ScrollContainerDataInternal *scroll = NULL;
            for (int32_t i = 0; i < ctx->scrollContainerDatas.length; i++) {
                Clay__ScrollContainerDataInternal *mapping = Clay__ScrollContainerDataInternalArray_Get(&ctx->scrollContainerDatas, i);
                if (mapping && mapping->elementId == open->id) {
                    scroll = mapping;
                    scroll->layoutElement = open;
                    scroll->openThisFrame = true;
                    break;
                }
            }
            if (!scroll) {
                scroll = Clay__ScrollContainerDataInternalArray_Add(
                    &ctx->scrollContainerDatas,
                    (Clay__ScrollContainerDataInternal){
                        .layoutElement = open,
                        .scrollOrigin = { -1, -1 },
                        .elementId = open->id,
                        .openThisFrame = true
                    }
                );
            }
            if (scroll && ctx->externalScrollHandlingEnabled) {
                scroll->scrollPosition = Clay__QueryScrollOffset(scroll->elementId, ctx->queryScrollOffsetUserData);
            }
        }
    }
}

static void attach_border_between(uint16_t width, uint16_t between_children, Clay_Color color) {
    Clay_BorderElementConfig border = {0};
    border.color = color;
    border.width.left = width;
    border.width.right = width;
    border.width.top = width;
    border.width.bottom = width;
    border.width.betweenChildren = between_children;
    Clay__AttachElementConfig((Clay_ElementConfigUnion){ .borderElementConfig = Clay__StoreBorderElementConfig(border) }, CLAY__ELEMENT_CONFIG_TYPE_BORDER);
}

static Clay_FloatingAttachPointType attach_point_from_index(int idx) {
    switch (idx % 9) {
        case 0: return CLAY_ATTACH_POINT_LEFT_TOP;
        case 1: return CLAY_ATTACH_POINT_LEFT_CENTER;
        case 2: return CLAY_ATTACH_POINT_LEFT_BOTTOM;
        case 3: return CLAY_ATTACH_POINT_CENTER_TOP;
        case 4: return CLAY_ATTACH_POINT_CENTER_CENTER;
        case 5: return CLAY_ATTACH_POINT_CENTER_BOTTOM;
        case 6: return CLAY_ATTACH_POINT_RIGHT_TOP;
        case 7: return CLAY_ATTACH_POINT_RIGHT_CENTER;
        default: return CLAY_ATTACH_POINT_RIGHT_BOTTOM;
    }
}

static void attach_floating(
    uint32_t parent_id,
    Clay_FloatingAttachToElement attach_to,
    Clay_FloatingAttachPointType element_attach,
    Clay_FloatingAttachPointType parent_attach,
    float offset_x,
    float offset_y,
    int16_t z_index,
    Clay_FloatingClipToElement clip_to
) {
    Clay_FloatingElementConfig floating = {0};
    floating.offset.x = offset_x;
    floating.offset.y = offset_y;
    floating.expand.width = 0;
    floating.expand.height = 0;
    floating.parentId = parent_id;
    floating.zIndex = z_index;
    floating.attachPoints.element = element_attach;
    floating.attachPoints.parent = parent_attach;
    floating.pointerCaptureMode = CLAY_POINTER_CAPTURE_MODE_CAPTURE;
    floating.attachTo = attach_to;
    floating.clipTo = clip_to;
    Clay_Context *context = Clay_GetCurrentContext();
    if (context == NULL || context->openLayoutElementStack.length < 2) {
        return;
    }

    Clay_LayoutElement *hierarchical_parent = Clay_LayoutElementArray_Get(
        &context->layoutElements,
        Clay__int32_tArray_GetValue(&context->openLayoutElementStack, context->openLayoutElementStack.length - 2)
    );
    if (hierarchical_parent == NULL) {
        return;
    }

    uint32_t clip_element_id = 0;
    if (attach_to == CLAY_ATTACH_TO_PARENT) {
        floating.parentId = hierarchical_parent->id;
        if (context->openClipElementStack.length > 0) {
            clip_element_id = (uint32_t)Clay__int32_tArray_GetValue(&context->openClipElementStack, context->openClipElementStack.length - 1);
        }
    } else if (attach_to == CLAY_ATTACH_TO_ELEMENT_WITH_ID) {
        Clay_LayoutElementHashMapItem *parent_item = Clay__GetHashMapItem(floating.parentId);
        if (parent_item != &Clay_LayoutElementHashMapItem_DEFAULT) {
            clip_element_id = (uint32_t)Clay__int32_tArray_GetValue(
                &context->layoutElementClipElementIds,
                (int32_t)(parent_item->layoutElement - context->layoutElements.internalArray)
            );
        }
    } else if (attach_to == CLAY_ATTACH_TO_ROOT) {
        floating.parentId = Clay__HashString(CLAY_STRING("Clay__RootContainer"), 0).id;
    }

    if (clip_to == CLAY_CLIP_TO_NONE) {
        clip_element_id = 0;
    }

    int32_t current_element_index = Clay__int32_tArray_GetValue(&context->openLayoutElementStack, context->openLayoutElementStack.length - 1);
    Clay__int32_tArray_Set(&context->layoutElementClipElementIds, current_element_index, clip_element_id);
    Clay__int32_tArray_Add(&context->openClipElementStack, (int32_t)clip_element_id);
    Clay__LayoutElementTreeRootArray_Add(&context->layoutElementTreeRoots, (Clay__LayoutElementTreeRoot){
        .layoutElementIndex = (uint32_t)current_element_index,
        .parentId = floating.parentId,
        .clipElementId = clip_element_id,
        .zIndex = floating.zIndex,
        .pointerOffset = {0, 0}
    });

    Clay__AttachElementConfig((Clay_ElementConfigUnion){ .floatingElementConfig = Clay__StoreFloatingElementConfig(floating) }, CLAY__ELEMENT_CONFIG_TYPE_FLOATING);
}

static Clay_TextElementConfig *text_cfg(
    Clay_TextElementConfigWrapMode wrap_mode,
    Clay_TextAlignment alignment,
    uint16_t line_height,
    uint16_t letter_spacing,
    uint16_t font_size
) {
    Clay_TextElementConfig tc = {0};
    tc.textColor = (Clay_Color){240, 240, 240, 255};
    tc.fontId = 0;
    tc.fontSize = font_size;
    tc.letterSpacing = letter_spacing;
    tc.lineHeight = line_height;
    tc.wrapMode = wrap_mode;
    tc.textAlignment = alignment;
    return Clay__StoreTextElementConfig(tc);
}

static uint32_t rng_next(uint32_t *state) {
    *state = *state * 1664525u + 1013904223u;
    return *state;
}

static void scenario_fixed_grid(void) {
    const int rows = 18;
    const int cols = 30;
    const float row_w = (float)g_width - 28.0f;

    Clay_ElementId root_id = make_id("s0_root", 0);
    Clay__OpenElementWithId(root_id);
    configure_current(
        CLAY__SIZING_TYPE_FIXED, (float)g_width - 4.0f, (float)g_width - 4.0f, 0.0f,
        CLAY__SIZING_TYPE_FIXED, (float)g_height - 4.0f, (float)g_height - 4.0f, 0.0f,
        CLAY_TOP_TO_BOTTOM, 0, 0, (Clay_Color){18, 24, 34, 255}
    );

    for (int y = 0; y < rows; y++) {
        open_fixed_probe("s0_row", (uint32_t)y, row_w, 18.0f, CLAY_LEFT_TO_RIGHT, 1, 2, (Clay_Color){32, 44, 62, 255});
        for (int x = 0; x < cols; x++) {
            int idx = y * cols + x;
            float cw = 12.0f + (float)(x % 5) * 2.0f;
            float ch = 10.0f + (float)(y % 3) * 2.0f;
            open_fixed_probe("s0_cell", (uint32_t)idx, cw, ch, CLAY_LEFT_TO_RIGHT, 0, 0, (Clay_Color){76, 112, 166, 255});
            Clay__CloseElement();
        }
        Clay__CloseElement();
    }

    Clay__CloseElement();
}

static void build_nested_fit(int depth, int branch, int *counter) {
    uint32_t idx = (uint32_t)(*counter);
    (*counter)++;

    if (depth > 1) {
        Clay_LayoutDirection dir = (depth % 2 == 0) ? CLAY_LEFT_TO_RIGHT : CLAY_TOP_TO_BOTTOM;
        open_fit_probe("s1_node", idx, dir, 1, 1, (Clay_Color){40 + depth * 10, 70 + depth * 8, 110 + depth * 6, 255});
        for (int i = 0; i < branch; i++) {
            build_nested_fit(depth - 1, branch, counter);
        }
    } else {
        float w = 24.0f + (float)(idx % 5) * 3.0f;
        float h = 14.0f + (float)(idx % 4) * 2.0f;
        open_fixed_probe("s1_node", idx, w, h, CLAY_LEFT_TO_RIGHT, 0, 0, (Clay_Color){110, 148, 204, 255});
    }
    Clay__CloseElement();
}

static void scenario_nested(void) {
    int counter = 0;
    build_nested_fit(5, 3, &counter);
}

static void scenario_percent_and_grow(void) {
    open_fixed_probe("s2_root", 0, (float)g_width - 28.0f, (float)g_height - 28.0f, CLAY_LEFT_TO_RIGHT, 4, 6, (Clay_Color){20, 24, 30, 255});
    const float splits[4] = {0.20f, 0.30f, 0.25f, 0.25f};
    for (int p = 0; p < 4; p++) {
        open_percent_probe("s2_col", (uint32_t)p, splits[p], CLAY_TOP_TO_BOTTOM, 3, 2, (Clay_Color){28 + p * 8, 36 + p * 6, 52 + p * 7, 255});
        for (int i = 0; i < 35; i++) {
            uint32_t idx = (uint32_t)(p * 1000 + i);
            Clay_ElementId id = make_id("s2_item", idx);
            Clay__OpenElementWithId(id);
            configure_current(
                CLAY__SIZING_TYPE_GROW, 0.0f, 0.0f, 0.0f,
                CLAY__SIZING_TYPE_FIXED, 10.0f + (float)(i % 4), 10.0f + (float)(i % 4), 0.0f,
                CLAY_LEFT_TO_RIGHT, 0, 0, (Clay_Color){70, 90, 120, 255}
            );
            push_probe(id);
            Clay__CloseElement();
        }
        Clay__CloseElement();
    }
    Clay__CloseElement();
}

static Clay_TextElementConfig *text_cfg_default(void) {
    Clay_TextElementConfig tc = {0};
    tc.textColor = (Clay_Color){240, 240, 240, 255};
    tc.fontId = 0;
    tc.fontSize = 14;
    tc.letterSpacing = 0;
    tc.lineHeight = 16;
    tc.wrapMode = CLAY_TEXT_WRAP_WORDS;
    tc.textAlignment = CLAY_TEXT_ALIGN_LEFT;
    return Clay__StoreTextElementConfig(tc);
}

static void scenario_text_flow(void) {
    open_fixed_probe("s3_root", 0, (float)g_width - 24.0f, (float)g_height - 24.0f, CLAY_TOP_TO_BOTTOM, 3, 4, (Clay_Color){16, 20, 26, 255});

    Clay_String short_text = make_string("argile parity short text");
    Clay_String med_text = make_string("argile parity medium text line for wrapping checks");
    Clay_String long_text = make_string("argile parity long text block with several words to force line breaks and exercise fit sizing in parent containers");

    for (int i = 0; i < 160; i++) {
        float bw = 260.0f + (float)(i % 3) * 30.0f;
        open_fit_probe("s3_box", (uint32_t)i, CLAY_TOP_TO_BOTTOM, 2, 1, (Clay_Color){52, 68, 92, 255});

        Clay_LayoutElement *box = Clay__GetOpenLayoutElement();
        if (box && box->layoutConfig) {
            box->layoutConfig->sizing.width.type = CLAY__SIZING_TYPE_FIXED;
            box->layoutConfig->sizing.width.size.minMax.min = bw;
            box->layoutConfig->sizing.width.size.minMax.max = bw;
            box->layoutConfig->sizing.height.type = CLAY__SIZING_TYPE_FIT;
        }

        Clay_TextElementConfig *tc = text_cfg_default();
        if (i % 3 == 0) {
            Clay__OpenTextElement(short_text, tc);
        } else if (i % 3 == 1) {
            Clay__OpenTextElement(med_text, tc);
        } else {
            Clay__OpenTextElement(long_text, tc);
        }
        Clay__CloseElement();
    }

    Clay__CloseElement();
}

static void scenario_clip_lists(void) {
    const int list_count = 10;
    const int rows_per = 90;

    Clay_ElementId root_id = make_id("s4_root", 0);
    Clay__OpenElementWithId(root_id);
    configure_current(
        CLAY__SIZING_TYPE_FIXED, (float)g_width - 6.0f, (float)g_width - 6.0f, 0.0f,
        CLAY__SIZING_TYPE_FIXED, (float)g_height - 6.0f, (float)g_height - 6.0f, 0.0f,
        CLAY_LEFT_TO_RIGHT, 2, 2, (Clay_Color){12, 16, 24, 255}
    );

    for (int i = 0; i < list_count; i++) {
        open_fixed_probe("s4_list", (uint32_t)i, 300.0f, 210.0f, CLAY_TOP_TO_BOTTOM, 3, 1, (Clay_Color){20, 26, 34, 255});
        attach_clip(true, true);
        attach_border(1, (Clay_Color){38, 50, 70, 255});

        for (int r = 0; r < rows_per; r++) {
            uint32_t idx = (uint32_t)(i * 1000 + r);
            open_fixed_probe("s4_row", idx, 270.0f, 15.0f + (float)(r % 3), CLAY_LEFT_TO_RIGHT, 0, 0, (Clay_Color){72, 95, 122, 255});
            Clay__CloseElement();
        }

        Clay__CloseElement();
    }

    Clay__CloseElement();
}

static void scenario_aspect_sweep(void) {
    open_fixed_probe("s5_root", 0, (float)g_width - 20.0f, (float)g_height - 20.0f, CLAY_LEFT_TO_RIGHT, 2, 2, (Clay_Color){18, 22, 30, 255});

    for (int i = 0; i < 420; i++) {
        float w = 42.0f + (float)(i % 8) * 8.0f;
        float h = 18.0f;
        open_fixed_probe("s5_card", (uint32_t)i, w, h, CLAY_LEFT_TO_RIGHT, 0, 0, (Clay_Color){62, 102, 152, 255});
        attach_aspect(1.2f + (float)(i % 6) * 0.1f);
        Clay__CloseElement();
    }

    Clay__CloseElement();
}

static void scenario_mixed_stress(void) {
    const int n = 3500;

    Clay_ElementId root_id = make_id("s6_root", 0);
    Clay__OpenElementWithId(root_id);
    configure_current(
        CLAY__SIZING_TYPE_FIXED, (float)g_width - 6.0f, (float)g_width - 6.0f, 0.0f,
        CLAY__SIZING_TYPE_FIXED, (float)g_height - 6.0f, (float)g_height - 6.0f, 0.0f,
        CLAY_LEFT_TO_RIGHT, 2, 2, (Clay_Color){10, 14, 20, 255}
    );

    for (int i = 0; i < n; i++) {
        float w = 16.0f + (float)(i % 7) * 5.0f;
        float h = 12.0f + (float)(i % 5) * 4.0f;
        Clay_Color c = {35.0f + (float)(i % 170), 45.0f + (float)(i % 140), 80.0f + (float)(i % 120), 255.0f};
        open_fixed_probe("s6_elem", (uint32_t)i, w, h, CLAY_LEFT_TO_RIGHT, 0, 0, c);
        if (i % 5 == 0) attach_border(1, (Clay_Color){170, 145, 90, 255});
        else if (i % 5 == 1) attach_custom();
        else if (i % 5 == 2) attach_image();
        else if (i % 5 == 3) attach_aspect(1.1f + (float)(i % 4) * 0.15f);
        Clay__CloseElement();
    }

    Clay__CloseElement();
}

static void scenario_floating_matrix(void) {
    open_fixed_probe("s7_root", 0, (float)g_width - 8.0f, (float)g_height - 8.0f, CLAY_TOP_TO_BOTTOM, 4, 8, (Clay_Color){16, 22, 30, 255});

    for (int row = 0; row < 2; row++) {
        open_fixed_probe("s7_row", (uint32_t)row, (float)g_width - 24.0f, 170.0f, CLAY_LEFT_TO_RIGHT, 2, 14, (Clay_Color){28, 36, 48, 255});
        for (int col = 0; col < 3; col++) {
            int a = row * 3 + col;
            open_fixed_probe("s7_anchor", (uint32_t)a, 220.0f, 110.0f, CLAY_LEFT_TO_RIGHT, 2, 0, (Clay_Color){62, 82, 110, 255});
            attach_border(1, (Clay_Color){90, 110, 136, 255});
            Clay__CloseElement();
        }
        Clay__CloseElement();
    }

    for (int i = 0; i < 18; i++) {
        float w = 58.0f + (float)(i % 3) * 9.0f;
        float h = 22.0f + (float)(i % 2) * 7.0f;
        open_fixed_probe("s7_float", (uint32_t)i, w, h, CLAY_LEFT_TO_RIGHT, 0, 0, (Clay_Color){204, 112 + (i % 5) * 14, 96 + (i % 4) * 18, 255});
        uint32_t parent_id = make_id("s7_anchor", (uint32_t)(i % 6)).id;
        attach_floating(
            parent_id,
            CLAY_ATTACH_TO_ELEMENT_WITH_ID,
            attach_point_from_index(i),
            attach_point_from_index(i * 2 + 1),
            (float)((i % 5) - 2) * 7.0f,
            (float)((i % 4) - 1) * 5.0f,
            (int16_t)(i % 7),
            (i % 3 == 0) ? CLAY_CLIP_TO_ATTACHED_PARENT : CLAY_CLIP_TO_NONE
        );
        Clay__CloseElement();
    }

    open_fixed_probe("s7_root_float", 0, 92.0f, 30.0f, CLAY_LEFT_TO_RIGHT, 0, 0, (Clay_Color){248, 160, 92, 255});
    attach_floating(
        0,
        CLAY_ATTACH_TO_ROOT,
        CLAY_ATTACH_POINT_RIGHT_BOTTOM,
        CLAY_ATTACH_POINT_RIGHT_BOTTOM,
        -36.0f,
        -28.0f,
        120,
        CLAY_CLIP_TO_NONE
    );
    Clay__CloseElement();

    open_fixed_probe("s7_parent_wrap", 0, 160.0f, 90.0f, CLAY_LEFT_TO_RIGHT, 2, 0, (Clay_Color){34, 44, 58, 255});
    open_fixed_probe("s7_parent_float", 0, 66.0f, 32.0f, CLAY_LEFT_TO_RIGHT, 0, 0, (Clay_Color){236, 132, 100, 255});
    attach_floating(
        0,
        CLAY_ATTACH_TO_PARENT,
        CLAY_ATTACH_POINT_RIGHT_BOTTOM,
        CLAY_ATTACH_POINT_LEFT_TOP,
        4.0f,
        -6.0f,
        64,
        CLAY_CLIP_TO_NONE
    );
    Clay__CloseElement();
    Clay__CloseElement();

    Clay__CloseElement();
}

static void scenario_zindex_overlap(void) {
    open_fixed_probe("s8_root", 0, (float)g_width - 12.0f, (float)g_height - 12.0f, CLAY_LEFT_TO_RIGHT, 4, 0, (Clay_Color){12, 18, 24, 255});
    open_fixed_probe("s8_anchor", 0, 620.0f, 420.0f, CLAY_LEFT_TO_RIGHT, 0, 0, (Clay_Color){34, 48, 66, 255});
    Clay__CloseElement();

    uint32_t anchor_id = make_id("s8_anchor", 0).id;
    for (int i = 0; i < 16; i++) {
        open_fixed_probe("s8_float", (uint32_t)i, 122.0f, 48.0f, CLAY_LEFT_TO_RIGHT, 0, 0, (Clay_Color){160 + i * 4, 100 + i * 3, 84 + i * 2, 220});
        attach_floating(
            anchor_id,
            CLAY_ATTACH_TO_ELEMENT_WITH_ID,
            CLAY_ATTACH_POINT_LEFT_TOP,
            CLAY_ATTACH_POINT_LEFT_TOP,
            18.0f + (float)(i % 4) * 7.0f,
            22.0f + (float)(i % 5) * 5.0f,
            (int16_t)(i - 8),
            CLAY_CLIP_TO_NONE
        );
        Clay__CloseElement();
    }

    for (int i = 0; i < 6; i++) {
        open_fixed_probe("s8_root_float", (uint32_t)i, 86.0f, 34.0f, CLAY_LEFT_TO_RIGHT, 0, 0, (Clay_Color){220, 168, 102 + i * 12, 255});
        attach_floating(
            0,
            CLAY_ATTACH_TO_ROOT,
            CLAY_ATTACH_POINT_LEFT_TOP,
            CLAY_ATTACH_POINT_LEFT_TOP,
            26.0f + (float)i * 5.0f,
            42.0f + (float)i * 3.0f,
            (int16_t)(100 + i),
            CLAY_CLIP_TO_NONE
        );
        Clay__CloseElement();
    }

    Clay__CloseElement();
}

static void scenario_nested_clip_offsets(void) {
    open_fixed_probe("s9_root", 0, (float)g_width - 10.0f, (float)g_height - 10.0f, CLAY_LEFT_TO_RIGHT, 2, 8, (Clay_Color){14, 18, 24, 255});

    for (int lane = 0; lane < 3; lane++) {
        open_fixed_probe("s9_outer", (uint32_t)lane, 420.0f, 300.0f, CLAY_TOP_TO_BOTTOM, 4, 2, (Clay_Color){26, 32, 42, 255});
        attach_clip_offset(true, true, -30.0f - (float)lane * 10.0f, -20.0f - (float)lane * 7.0f);
        attach_border_between(1, 1, (Clay_Color){68, 86, 114, 255});

        for (int c = 0; c < 3; c++) {
            int inner = lane * 10 + c;
            open_fixed_probe("s9_inner", (uint32_t)inner, 360.0f, 220.0f, CLAY_TOP_TO_BOTTOM, 2, 1, (Clay_Color){44, 58, 78, 255});
            attach_clip_offset(true, true, -12.0f - (float)c * 5.0f, -18.0f - (float)c * 4.0f);
            for (int r = 0; r < 35; r++) {
                uint32_t idx = (uint32_t)(lane * 1000 + c * 100 + r);
                open_fixed_probe("s9_row", idx, 340.0f, 14.0f + (float)(r % 3), CLAY_LEFT_TO_RIGHT, 0, 0, (Clay_Color){76, 98, 124, 255});
                Clay__CloseElement();
            }
            Clay__CloseElement();
        }

        Clay__CloseElement();
    }

    Clay__CloseElement();
}

static void scenario_text_wrap_matrix(void) {
    open_fixed_probe("s10_root", 0, (float)g_width - 10.0f, (float)g_height - 10.0f, CLAY_TOP_TO_BOTTOM, 3, 3, (Clay_Color){18, 22, 28, 255});

    Clay_String texts[3] = {
        make_string("short text for argile parity"),
        make_string("line one\nline two with newline wrapping"),
        make_string("long content for text wrapping checks across wrap modes and alignments in parity suite")
    };

    for (int wrap = 0; wrap < 3; wrap++) {
        for (int align = 0; align < 3; align++) {
            int idx = wrap * 10 + align;
            float bw = 220.0f + (float)align * 36.0f;
            open_fit_probe("s10_block", (uint32_t)idx, CLAY_TOP_TO_BOTTOM, 2, 1, (Clay_Color){52 + wrap * 18, 66 + align * 11, 92 + wrap * 9, 255});
            Clay_LayoutElement *box = Clay__GetOpenLayoutElement();
            if (box && box->layoutConfig) {
                box->layoutConfig->sizing.width.type = CLAY__SIZING_TYPE_FIXED;
                box->layoutConfig->sizing.width.size.minMax.min = bw;
                box->layoutConfig->sizing.width.size.minMax.max = bw;
                box->layoutConfig->sizing.height.type = CLAY__SIZING_TYPE_FIT;
            }
            Clay_TextElementConfig *tc = text_cfg(
                (Clay_TextElementConfigWrapMode)wrap,
                (Clay_TextAlignment)align,
                (uint16_t)(14 + wrap * 2),
                (uint16_t)align,
                (uint16_t)(13 + wrap)
            );
            Clay__OpenTextElement(texts[(wrap + align) % 3], tc);
            Clay__CloseElement();
        }
    }

    Clay__CloseElement();
}

static void scenario_sizing_edge_cases(void) {
    open_fixed_probe("s11_root", 0, (float)g_width - 10.0f, (float)g_height - 10.0f, CLAY_TOP_TO_BOTTOM, 4, 6, (Clay_Color){16, 21, 28, 255});

    open_fixed_probe("s11_h", 0, (float)g_width - 40.0f, 190.0f, CLAY_LEFT_TO_RIGHT, 3, 4, (Clay_Color){28, 36, 48, 255});
    const float percents[4] = {0.05f, 0.20f, 0.35f, 0.40f};
    for (int i = 0; i < 4; i++) {
        Clay_ElementId id = make_id("s11_pct", (uint32_t)i);
        Clay__OpenElementWithId(id);
        configure_current(
            CLAY__SIZING_TYPE_PERCENT, 0.0f, 0.0f, percents[i],
            CLAY__SIZING_TYPE_FIXED, 30.0f + (float)i * 6.0f, 30.0f + (float)i * 6.0f, 0.0f,
            CLAY_LEFT_TO_RIGHT, 0, 0, (Clay_Color){78 + i * 20, 106, 142, 255}
        );
        push_probe(id);
        Clay__CloseElement();
    }
    for (int i = 0; i < 5; i++) {
        Clay_ElementId id = make_id("s11_grow", (uint32_t)i);
        Clay__OpenElementWithId(id);
        configure_current(
            CLAY__SIZING_TYPE_GROW, 0.0f, 0.0f, 0.0f,
            CLAY__SIZING_TYPE_FIXED, 26.0f + (float)i * 4.0f, 26.0f + (float)i * 4.0f, 0.0f,
            CLAY_LEFT_TO_RIGHT, 0, 0, (Clay_Color){126, 82 + i * 12, 74 + i * 8, 255}
        );
        Clay_LayoutElement *e = Clay__GetOpenLayoutElement();
        if (e && e->layoutConfig) {
            e->layoutConfig->sizing.width.size.minMax.min = 44.0f + (float)i * 16.0f;
            e->layoutConfig->sizing.width.size.minMax.max = 96.0f + (float)i * 22.0f;
        }
        push_probe(id);
        Clay__CloseElement();
    }
    Clay__CloseElement();

    open_fixed_probe("s11_v", 0, 420.0f, 280.0f, CLAY_TOP_TO_BOTTOM, 3, 3, (Clay_Color){30, 40, 56, 255});
    const float hperc[3] = {0.15f, 0.25f, 0.60f};
    for (int i = 0; i < 3; i++) {
        Clay_ElementId id = make_id("s11_vpct", (uint32_t)i);
        Clay__OpenElementWithId(id);
        configure_current(
            CLAY__SIZING_TYPE_GROW, 0.0f, 0.0f, 0.0f,
            CLAY__SIZING_TYPE_PERCENT, 0.0f, 0.0f, hperc[i],
            CLAY_LEFT_TO_RIGHT, 0, 0, (Clay_Color){74 + i * 22, 94 + i * 14, 136, 255}
        );
        push_probe(id);
        Clay__CloseElement();
    }
    Clay__CloseElement();

    Clay__CloseElement();
}

static void scenario_border_between_children(void) {
    open_fixed_probe("s12_root", 0, (float)g_width - 10.0f, (float)g_height - 10.0f, CLAY_TOP_TO_BOTTOM, 4, 10, (Clay_Color){16, 22, 30, 255});

    open_fixed_probe("s12_h", 0, (float)g_width - 26.0f, 130.0f, CLAY_LEFT_TO_RIGHT, 2, 8, (Clay_Color){36, 46, 64, 255});
    attach_border_between(2, 3, (Clay_Color){176, 120, 74, 255});
    for (int i = 0; i < 8; i++) {
        open_fixed_probe("s12_hc", (uint32_t)i, 56.0f + (float)(i % 3) * 12.0f, 72.0f, CLAY_LEFT_TO_RIGHT, 0, 0, (Clay_Color){86, 112 + i * 8, 146, 255});
        Clay__CloseElement();
    }
    Clay__CloseElement();

    open_fixed_probe("s12_v", 0, 520.0f, 280.0f, CLAY_TOP_TO_BOTTOM, 2, 6, (Clay_Color){28, 36, 52, 255});
    attach_border_between(2, 4, (Clay_Color){90, 168, 120, 255});
    for (int i = 0; i < 10; i++) {
        open_fixed_probe("s12_vc", (uint32_t)i, 480.0f, 18.0f + (float)(i % 4) * 6.0f, CLAY_LEFT_TO_RIGHT, 0, 0, (Clay_Color){96, 124, 164, 255});
        Clay__CloseElement();
    }
    Clay__CloseElement();

    Clay__CloseElement();
}

static void scenario_relayout_phase(int phase) {
    open_fixed_probe("s13_root", 0, (float)g_width - 8.0f, (float)g_height - 8.0f, CLAY_TOP_TO_BOTTOM, 3, 4, (Clay_Color){14, 18, 24, 255});

    if (phase == 0) {
        for (int i = 0; i < 120; i++) {
            open_fixed_probe("s13_box", (uint32_t)i, 120.0f + (float)(i % 5) * 14.0f, 18.0f + (float)(i % 3) * 4.0f, CLAY_LEFT_TO_RIGHT, 0, 0, (Clay_Color){72, 88, 118, 255});
            if (i % 6 == 0) attach_clip_offset(true, false, -6.0f, 0.0f);
            Clay__CloseElement();
        }
    } else if (phase == 1) {
        for (int i = 0; i < 90; i++) {
            open_fixed_probe("s13_box", (uint32_t)i, 80.0f + (float)(i % 4) * 18.0f, 28.0f + (float)(i % 5) * 5.0f, CLAY_LEFT_TO_RIGHT, 0, 0, (Clay_Color){90, 104, 130, 255});
            if (i % 4 == 0) attach_aspect(1.1f + (float)(i % 3) * 0.2f);
            Clay__CloseElement();
        }
    } else {
        open_fixed_probe("s13_final_h", 0, (float)g_width - 26.0f, 220.0f, CLAY_LEFT_TO_RIGHT, 2, 4, (Clay_Color){34, 46, 66, 255});
        for (int i = 0; i < 40; i++) {
            open_fixed_probe("s13_final", (uint32_t)i, 26.0f + (float)(i % 7) * 8.0f, 24.0f + (float)(i % 4) * 6.0f, CLAY_LEFT_TO_RIGHT, 0, 0, (Clay_Color){118, 146, 188, 255});
            if (i % 3 == 0) attach_aspect(1.0f + (float)(i % 5) * 0.12f);
            Clay__CloseElement();
        }
        Clay__CloseElement();
    }

    Clay__CloseElement();
}

static void scenario_seeded_fuzz(void) {
    uint32_t state = 0xC0FFEEu;

    open_fixed_probe("s14_root", 0, (float)g_width - 8.0f, (float)g_height - 8.0f, CLAY_LEFT_TO_RIGHT, 3, 3, (Clay_Color){12, 16, 22, 255});

    const int columns = 5;
    float col_width = ((float)g_width - 40.0f) / (float)columns;
    for (int c = 0; c < columns; c++) {
        open_fixed_probe("s14_col", (uint32_t)c, col_width, (float)g_height - 40.0f, CLAY_TOP_TO_BOTTOM, 2, 1, (Clay_Color){24 + c * 8, 32 + c * 9, 46 + c * 10, 255});

        for (int i = 0; i < 180; i++) {
            uint32_t rv = rng_next(&state);
            uint32_t idx = (uint32_t)(c * 1000 + i);
            float w = 14.0f + (float)(rv % 56u);
            float h = 12.0f + (float)((rv >> 8) % 38u);

            Clay_ElementId id = make_id("s14_elem", idx);
            Clay__OpenElementWithId(id);

            Clay__SizingType wt = CLAY__SIZING_TYPE_FIXED;
            Clay__SizingType ht = CLAY__SIZING_TYPE_FIXED;
            if ((rv & 7u) == 0u) wt = CLAY__SIZING_TYPE_GROW;
            else if ((rv & 7u) == 1u) wt = CLAY__SIZING_TYPE_FIT;
            if (((rv >> 3) & 7u) == 0u) ht = CLAY__SIZING_TYPE_GROW;

            configure_current(
                wt, w, w, 0.0f,
                ht, h, h, 0.0f,
                CLAY_LEFT_TO_RIGHT, 0, 0,
                (Clay_Color){64 + (float)(rv % 160u), 72 + (float)((rv >> 5) % 130u), 82 + (float)((rv >> 11) % 120u), 255}
            );
            Clay_LayoutElement *e = Clay__GetOpenLayoutElement();
            if (e && e->layoutConfig && wt == CLAY__SIZING_TYPE_GROW) {
                e->layoutConfig->sizing.width.size.minMax.min = 18.0f + (float)(rv % 22u);
                e->layoutConfig->sizing.width.size.minMax.max = 74.0f + (float)(rv % 54u);
            }

            if ((rv % 9u) == 0u) attach_border(1, (Clay_Color){176, 136, 86, 255});
            else if ((rv % 9u) == 1u) attach_custom();
            else if ((rv % 9u) == 2u) attach_image();
            else if ((rv % 9u) == 3u) attach_aspect(1.0f + (float)(rv % 5u) * 0.17f);
            else if ((rv % 9u) == 4u) attach_clip_offset(true, false, -4.0f, 0.0f);

            push_probe(id);

            if ((rv % 11u) == 0u) {
                open_fixed_probe("s14_leaf", idx, 8.0f + (float)(rv % 20u), 8.0f + (float)((rv >> 7) % 16u), CLAY_LEFT_TO_RIGHT, 0, 0, (Clay_Color){208, 154, 106, 255});
                Clay__CloseElement();
            }

            Clay__CloseElement();
        }

        Clay__CloseElement();
    }

    Clay__CloseElement();
}

static int run_scenario_internal(int index) {
    switch (index) {
        case 0: scenario_fixed_grid(); break;
        case 1: scenario_nested(); break;
        case 2: scenario_percent_and_grow(); break;
        case 3: scenario_text_flow(); break;
        case 4: scenario_clip_lists(); break;
        case 5: scenario_aspect_sweep(); break;
        case 6: scenario_mixed_stress(); break;
        case 7: scenario_floating_matrix(); break;
        case 8: scenario_zindex_overlap(); break;
        case 9: scenario_nested_clip_offsets(); break;
        case 10: scenario_text_wrap_matrix(); break;
        case 11: scenario_sizing_edge_cases(); break;
        case 12: scenario_border_between_children(); break;
        case 13: scenario_relayout_phase(2); break;
        case 14: scenario_seeded_fuzz(); break;
        default: return 0;
    }
    return 1;
}

int parity_init(int width, int height, int max_elements, int arena_bytes) {
    (void)max_elements;
    if (g_mem) {
        free(g_mem);
        g_mem = NULL;
    }

    if (arena_bytes <= 0) arena_bytes = 512 * 1024 * 1024;
    uint32_t min_required = Clay_MinMemorySize();
    if ((uint32_t)arena_bytes < min_required) {
        arena_bytes = (int)min_required;
    }

    g_width = width;
    g_height = height;
    g_mem_size = (size_t)arena_bytes;
    g_mem = malloc(g_mem_size);
    if (!g_mem) return 0;

    Clay_Arena arena = Clay_CreateArenaWithCapacityAndMemory(g_mem_size, g_mem);
    Clay_Dimensions dims = {(float)width, (float)height};
    Clay_ErrorHandler eh = {.errorHandlerFunction = parity_error_handler, .userData = NULL};
    Clay_Context *ctx = Clay_Initialize(arena, dims, eh);
    if (!ctx) {
        free(g_mem);
        g_mem = NULL;
        return 0;
    }
    Clay_SetCurrentContext(ctx);
    Clay_SetMeasureTextFunction(parity_measure_text, NULL);
    g_probe_count = 0;
    g_initialized = true;
    return 1;
}

int parity_shutdown(void) {
    Clay_SetCurrentContext(NULL);
    if (g_mem) {
        free(g_mem);
        g_mem = NULL;
    }
    g_mem_size = 0;
    g_probe_count = 0;
    g_initialized = false;
    return 1;
}

int parity_scenario_count(void) {
    return SCENARIO_COUNT;
}

const char *parity_scenario_name(int index) {
    static const char *names[SCENARIO_COUNT] = {
        "fixed_grid",
        "nested_fit",
        "percent_and_grow",
        "text_flow_fit",
        "clip_lists",
        "aspect_sweep",
        "mixed_stress",
        "floating_matrix",
        "zindex_overlap",
        "nested_clip_offsets",
        "text_wrap_matrix",
        "sizing_edge_cases",
        "border_between_children",
        "relayout_state",
        "seeded_fuzz",
    };
    if (index < 0 || index >= SCENARIO_COUNT) return "";
    return names[index];
}

int parity_run_scenario(int index) {
    if (!g_initialized) return -1;
    if (index < 0 || index >= SCENARIO_COUNT) return -1;
    g_probe_count = 0;

    if (index == 13) {
        for (int phase = 0; phase < 3; phase++) {
            g_probe_count = 0;
            Clay_BeginLayout();
            scenario_relayout_phase(phase);
            Clay_EndLayout();
        }
        return g_probe_count;
    }

    Clay_BeginLayout();
    if (!run_scenario_internal(index)) return -1;
    Clay_EndLayout();
    return g_probe_count;
}

int parity_probe_count(void) {
    return g_probe_count;
}

uint32_t parity_probe_id(int probe_index) {
    if (probe_index < 0 || probe_index >= g_probe_count) return 0;
    return g_probe_ids[probe_index];
}

int parity_probe_box(int probe_index, float *x, float *y, float *w, float *h) {
    if (x) *x = 0;
    if (y) *y = 0;
    if (w) *w = 0;
    if (h) *h = 0;

    if (probe_index < 0 || probe_index >= g_probe_count) return 0;

    Clay_ElementId id = {0};
    id.id = g_probe_ids[probe_index];
    id.baseId = id.id;
    Clay_ElementData data = Clay_GetElementData(id);
    if (!data.found) return 0;

    if (x) *x = data.boundingBox.x;
    if (y) *y = data.boundingBox.y;
    if (w) *w = data.boundingBox.width;
    if (h) *h = data.boundingBox.height;
    return 1;
}
