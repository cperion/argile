#include <stdint.h>

#include "../build/argile_api.h"

int32_t ArgileBenchmarkMeasureText(struct StringSlice *text, struct TextConfig *config, void *userData, struct Dimensions *outDims) {
    (void)userData;
    if (outDims == NULL) {
        return 0;
    }

    int32_t len = 0;
    if (text != NULL) {
        len = text->length;
    }
    outDims->width = (float)(len * 8);

    if (config != NULL && config->lineHeight > 0) {
        outDims->height = (float)config->lineHeight;
    } else {
        outDims->height = 16.0f;
    }
    return 1;
}
