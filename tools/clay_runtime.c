#include <stdint.h>

#define CLAY_IMPLEMENTATION
#include "../ref/clay.h"

Clay_Dimensions ClayBenchmarkMeasureText(Clay_StringSlice text, Clay_TextElementConfig *config, void *userData) {
    (void)userData;
    Clay_Dimensions d = { (float)(text.length * 8), 16.0f };
    if (config && config->lineHeight > 0) {
        d.height = (float)config->lineHeight;
    }
    return d;
}

void ClayBenchmarkErrorHandler(Clay_ErrorData errorData) {
    (void)errorData;
}
