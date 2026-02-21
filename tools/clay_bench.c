#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define CLAY_IMPLEMENTATION
#include "../ref/clay.h"

static void *g_mem = NULL;
static size_t g_mem_size = 0;

static void bench_error_handler(Clay_ErrorData errorData) {
    (void)errorData;
}

static Clay_Dimensions bench_measure_text(Clay_StringSlice text, Clay_TextElementConfig *config, void *userData) {
    (void)config;
    (void)userData;
    Clay_Dimensions d = { (float)(text.length * 8), 16.0f };
    return d;
}

static void configure_box(float w, float h, Clay_Color color) {
    Clay_ElementDeclaration decl = {0};
    decl.layout.sizing.width.type = CLAY__SIZING_TYPE_FIXED;
    decl.layout.sizing.width.size.minMax.min = w;
    decl.layout.sizing.width.size.minMax.max = w;
    decl.layout.sizing.height.type = CLAY__SIZING_TYPE_FIXED;
    decl.layout.sizing.height.size.minMax.min = h;
    decl.layout.sizing.height.size.minMax.max = h;
    decl.layout.layoutDirection = CLAY_LEFT_TO_RIGHT;
    decl.backgroundColor = color;
    Clay__ConfigureOpenElement(decl);
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

static void build_nested(int depth, int branch) {
    if (depth <= 0) return;
    for (int i = 0; i < branch; i++) {
        Clay__OpenElement();
        Clay_Color c = {80, 140, 240, 255};
        configure_box(20.0f + (float)depth, 20.0f + (float)depth, c);
        if (depth > 1) {
            build_nested(depth - 1, branch);
        }
        Clay__CloseElement();
    }
}

int bench_init(int width, int height, int max_elements, int arena_bytes) {
    if (g_mem) {
        free(g_mem);
        g_mem = NULL;
    }

    if (arena_bytes <= 0) arena_bytes = 32 * 1024 * 1024;
    uint32_t min_required = Clay_MinMemorySize();
    if ((uint32_t)arena_bytes < min_required) {
        arena_bytes = (int)min_required;
    }
    g_mem_size = (size_t)arena_bytes;
    g_mem = malloc(g_mem_size);
    if (!g_mem) return 0;

    Clay_Arena arena = Clay_CreateArenaWithCapacityAndMemory(g_mem_size, g_mem);
    Clay_Dimensions dims = { (float)width, (float)height };
    Clay_ErrorHandler eh = { .errorHandlerFunction = bench_error_handler, .userData = NULL };
    Clay_Context *ctx = Clay_Initialize(arena, dims, eh);
    if (!ctx) {
        free(g_mem);
        g_mem = NULL;
        return 0;
    }
    Clay_SetCurrentContext(ctx);
    Clay_SetMaxElementCount(max_elements);
    Clay_SetMeasureTextFunction(bench_measure_text, NULL);
    return 1;
}

int bench_shutdown(void) {
    Clay_SetCurrentContext(NULL);
    if (g_mem) {
        free(g_mem);
        g_mem = NULL;
    }
    g_mem_size = 0;
    return 1;
}

int bench_frame_fixed_children(int child_count) {
    Clay_BeginLayout();
    for (int i = 0; i < child_count; i++) {
        Clay__OpenElement();
        Clay_Color c = {220, 120, 90, 255};
        configure_box(24.0f, 24.0f, c);
        Clay__CloseElement();
    }
    Clay_RenderCommandArray cmds = Clay_EndLayout();
    return cmds.length;
}

int bench_frame_nested(int depth, int branch) {
    Clay_BeginLayout();
    build_nested(depth, branch);
    Clay_RenderCommandArray cmds = Clay_EndLayout();
    return cmds.length;
}

int bench_frame_text_rows(int row_count) {
    Clay_BeginLayout();

    Clay_TextElementConfig tc = {0};
    tc.textColor = (Clay_Color){255, 255, 255, 255};
    tc.fontId = 0;
    tc.fontSize = 14;
    tc.letterSpacing = 0;
    tc.lineHeight = 16;
    tc.wrapMode = CLAY_TEXT_WRAP_WORDS;
    tc.textAlignment = CLAY_TEXT_ALIGN_LEFT;

    Clay_String s = { .isStaticallyAllocated = true, .length = 11, .chars = "hello world" };

    for (int i = 0; i < row_count; i++) {
        Clay__OpenTextElement(s, &tc);
    }

    Clay_RenderCommandArray cmds = Clay_EndLayout();
    return cmds.length;
}

int bench_frame_dashboard(int panel_count, int widgets_per_panel) {
    Clay_BeginLayout();

    for (int p = 0; p < panel_count; p++) {
        Clay__OpenElement();
        Clay_Color panel = {25, 35, 50, 255};
        configure_box(360.0f, 320.0f, panel);

        Clay_LayoutElement *open = Clay__GetOpenLayoutElement();
        if (open && open->layoutConfig) {
            open->layoutConfig->layoutDirection = CLAY_TOP_TO_BOTTOM;
            open->layoutConfig->padding.left = 8;
            open->layoutConfig->padding.right = 8;
            open->layoutConfig->padding.top = 8;
            open->layoutConfig->padding.bottom = 8;
            open->layoutConfig->childGap = 4;
        }
        attach_border(1, (Clay_Color){60, 70, 90, 255});

        for (int w = 0; w < widgets_per_panel; w++) {
            if (w % 3 == 0) {
                Clay_TextElementConfig tc = {0};
                tc.textColor = (Clay_Color){230, 230, 240, 255};
                tc.fontId = 0;
                tc.fontSize = 13;
                tc.letterSpacing = 0;
                tc.lineHeight = 16;
                tc.wrapMode = CLAY_TEXT_WRAP_WORDS;
                tc.textAlignment = CLAY_TEXT_ALIGN_LEFT;
                Clay_String s = { .isStaticallyAllocated = true, .length = 18, .chars = "widget title value" };
                Clay__OpenTextElement(s, &tc);
            } else {
                Clay__OpenElement();
                Clay_Color wc = {50, 80, 120, 255};
                configure_box(330.0f, 24.0f, wc);
                if (w % 2 == 0) attach_custom();
                else attach_image();
                Clay__CloseElement();
            }
        }

        Clay__CloseElement();
    }

    Clay_RenderCommandArray cmds = Clay_EndLayout();
    return cmds.length;
}

int bench_frame_clip_lists(int list_count, int rows_per_list) {
    Clay_BeginLayout();

    for (int i = 0; i < list_count; i++) {
        Clay__OpenElement();
        Clay_Color list = {20, 25, 32, 255};
        configure_box(280.0f, 220.0f, list);

        Clay_LayoutElement *open = Clay__GetOpenLayoutElement();
        if (open && open->layoutConfig) {
            open->layoutConfig->layoutDirection = CLAY_TOP_TO_BOTTOM;
            open->layoutConfig->childGap = 2;
            open->layoutConfig->padding.left = 4;
            open->layoutConfig->padding.right = 4;
            open->layoutConfig->padding.top = 4;
            open->layoutConfig->padding.bottom = 4;
        }
        attach_clip(true, true);
        attach_border(1, (Clay_Color){40, 50, 70, 255});

        for (int r = 0; r < rows_per_list; r++) {
            Clay__OpenElement();
            Clay_Color row = {70, 90, 110, 255};
            configure_box(260.0f, 18.0f, row);
            Clay__CloseElement();
        }

        Clay__CloseElement();
    }

    Clay_RenderCommandArray cmds = Clay_EndLayout();
    return cmds.length;
}

int bench_frame_stress_mixed(int element_count) {
    Clay_BeginLayout();

    for (int i = 0; i < element_count; i++) {
        Clay__OpenElement();
        float w = 16.0f + (float)(i % 7) * 6.0f;
        float h = 12.0f + (float)(i % 5) * 5.0f;
        Clay_Color c = {30.0f + (float)(i % 200), 40.0f + (float)(i % 160), 80.0f + (float)(i % 120), 255.0f};
        configure_box(w, h, c);

        if (i % 5 == 0) {
            attach_border(1, (Clay_Color){180, 150, 90, 255});
        } else if (i % 5 == 1) {
            attach_custom();
        } else if (i % 5 == 2) {
            attach_image();
        } else if (i % 5 == 3) {
            Clay_AspectRatioElementConfig aspect = { .aspectRatio = 1.5f };
            Clay__AttachElementConfig((Clay_ElementConfigUnion){ .aspectRatioElementConfig = Clay__StoreAspectRatioElementConfig(aspect) }, CLAY__ELEMENT_CONFIG_TYPE_ASPECT);
        }

        Clay__CloseElement();
    }

    Clay_RenderCommandArray cmds = Clay_EndLayout();
    return cmds.length;
}
