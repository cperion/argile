# Clay-to-Terra Implementation Guide: AI Coding Reference Manual

**ATTENTION AI AGENT:** This document is your strict reference manual for translating the provided `clay.h` C source code into the native Terra `ui` layout engine. 

Do **not** hallucinate algorithms. Do **not** simplify the math. UI layout requires absolute pixel-perfect precision. This guide maps the conceptual Terra blueprint to the exact functions, loops, and structs in the original `clay.h` file. When you write the Terra code, you will look up the corresponding C code listed here and port the logic exactly, adapting only the syntax and memory access patterns to match our Terra design.

---

## 1. Memory Management & Arrays (Generics)

In C, Clay uses massive macros to fake generics. In Terra, we use `terralib.memoize`.

*   **C Source Reference:** 
    *   Look at `struct Clay_Arena` and `Clay_CreateArenaWithCapacityAndMemory`.
    *   Look at `#define CLAY__ARRAY_DEFINE_FUNCTIONS(typeName, arrayName)`.
    *   Look at `Clay__Array_Allocate_Arena`, `Clay__Array_RangeCheck`, `Clay__Array_AddCapacityCheck`.
*   **Terra Target:** `ui.Array = terralib.memoize(function(T) ... end)`
*   **Implementation Directives:**
    *   **DO NOT** port the C macros. Implement the `ui.Array` Lua function exactly as specified in the blueprint.
    *   Inside the Terra methods for the generated array (e.g., `:Add()`, `:Get()`, `:RemoveSwapback()`, `:Set()`), you **must** include the logic from `Clay__Array_RangeCheck` and `Clay__Array_AddCapacityCheck`. If bounds are exceeded, you must trigger the context error handler (see `context.errorHandler`).
    *   The C code uses `_DEFAULT` structs (e.g., `typeName##_DEFAULT`) to return on failure. In Terra, return a nil pointer (`return nil`) for `&T` returns, or construct a zeroed struct using an escape `[T]()` for value returns.

## 2. Hashing & Strings

Clay uses a custom hashing algorithm (based on FNV/BLAKE concepts) to generate `ElementId`s. It is vital that collisions are handled exactly as they are in C.

*   **C Source Reference:**
    *   `Clay__HashData` (Look at the scalar fallback at the bottom of the `#ifdef` block if you don't implement the SIMD version).
    *   `Clay__HashString` and `Clay__HashStringWithOffset`.
    *   `Clay__HashNumber`.
*   **Terra Target:** `ui.HashData`, `ui.HashString`, `ui.HashStringWithOffset`, `ui.HashNumber`.
*   **Implementation Directives:**
    *   Copy the bitwise math exactly: `hash += data[i]; hash += (hash << 10); hash ^= (hash >> 6);` followed by the final shifts.
    *   **Do not** invent your own hash function. The layout engine relies on the specific distribution of these hashes.

## 3. Data Structures: Configs & Context

Clay maps declarative UI to strictly packed structs.

*   **C Source Reference:**
    *   Structs: `Clay_SizingAxis`, `Clay_LayoutConfig`, `Clay_TextElementConfig`, `Clay_FloatingElementConfig`, etc.
    *   Union: `Clay_ElementConfigUnion`.
    *   State: `struct Clay_Context`, `Clay__InitializeEphemeralMemory`, `Clay__InitializePersistentMemory`.
*   **Terra Target:** `ui.Context`, `ui.LayoutConfig`, etc.
*   **Implementation Directives:**
    *   **Exhaustiveness:** You must port *every single field* of the configuration structs. Do not leave out `pointerCaptureMode`, `letterSpacing`, `childGap`, etc. 
    *   **Prefixes:** Strip all `Clay_` and `CLAY__` prefixes. `Clay_LayoutConfig` becomes `ui.LayoutConfig`. `CLAY_SIZING_TYPE_GROW` becomes `ui.SIZING_GROW`.
    *   **Context Setup:** In `ui.BeginLayout`, you must reset the `arena.nextAllocation` to `arenaResetOffset` and set the `.length` of all ephemeral arrays (like `layoutElements`, `renderCommands`) to `0`. Read `Clay__InitializeEphemeralMemory` to see exactly which arrays are ephemeral.

## 4. The Tree Building Pipeline (Open / Close)

This is how elements are added to the flat array.

*   **C Source Reference:**
    *   `Clay__OpenElement`, `Clay__OpenElementWithId`, `Clay__CloseElement`.
    *   `Clay__ConfigureOpenElementPtr`.
*   **Terra Target:** `ui.OpenElement`, `ui.OpenElementWithId`, `ui.CloseElement`, `ui.ConfigureLayout`, `ui.AttachElementConfig`.
*   **Implementation Directives:**
    *   **DO NOT** port the `CLAY(...)` `for`-loop latch macros. The Terra version uses a Lua AST builder (`ui.compile`) for the DX, which will output flat calls to `ui.OpenElement` and `ui.CloseElement`.
    *   **CloseElement Logic:** Look closely at `Clay__CloseElement`. This function is massive. It applies padding, calculates preliminary `minDimensions`, and updates `childrenOrTextContent.children.elements` by pushing to `context.layoutElementChildren`. **Do not summarize this function.** Port the `CLAY_LEFT_TO_RIGHT` and `CLAY_TOP_TO_BOTTOM` switch cases exactly.

## 5. The Layout Algorithm (The Beast)

This is the most critical part of the entire library. It calculates the sizes of all boxes using a multi-pass approach.

*   **C Source Reference:**
    *   `Clay__SizeContainersAlongAxis(bool xAxis)`.
    *   `Clay__CalculateFinalLayout(void)`.
*   **Terra Target:** `ui.SizeContainersAlongAxis`, `ui.CalculateFinalLayout`.
*   **Implementation Directives for `SizeContainersAlongAxis`:**
    *   This function uses a custom BFS queue (`bfsBuffer`) and a `resizableContainerBuffer` to avoid recursion. Port the array indexing exactly.
    *   **Pass 1:** It sums the fixed/fit children and counts `CLAY__SIZING_TYPE_GROW` containers.
    *   **Pass 2:** It expands `CLAY__SIZING_TYPE_PERCENT` containers.
    *   **Pass 3 (Compression/Expansion):** Look for `while (sizeToDistribute < -CLAY__EPSILON ...)`. This loop compresses elements iteratively by finding the largest elements and shrinking them. **DO NOT SIMPLIFY THIS MATH.** Port the `largest`, `secondLargest`, and `widthToAdd` logic verbatim. Do the same for the expansion loop (`while (sizeToDistribute > CLAY__EPSILON ...)`).
*   **Implementation Directives for `CalculateFinalLayout`:**
    *   Follow the exact order of operations:
        1. `Clay__SizeContainersAlongAxis(true)` (X Axis)
        2. Text Wrapping (The `for` loop over `context.textElementData`)
        3. Aspect Ratio height scaling.
        4. DFS traversal to propagate height changes up the tree.
        5. `Clay__SizeContainersAlongAxis(false)` (Y Axis)
        6. Aspect Ratio width scaling.
        7. Z-Index sorting (`sortMax` bubble sort).
        8. Render Command Generation (The final DFS `while (dfsBuffer.length > 0)`).

## 6. Text Measurement & Caching

Text measurement in Clay is cached using an LRU hash map to prevent re-measuring text every frame.

*   **C Source Reference:**
    *   `Clay__MeasureTextCached`, `Clay__AddMeasuredWord`.
*   **Terra Target:** `ui.MeasureTextCached`, `ui.AddMeasuredWord`.
*   **Implementation Directives:**
    *   **Hash Map Logic:** Look at how `elementIndex = context->measureTextHashMap.internalArray[hashBucket]` is used. Port the generation-based eviction logic (`context->generation - hashEntry->generation > 2`).
    *   **Free Lists:** Clay uses `measuredWordsFreeList` and `measureTextHashMapInternalFreeList` to recycle memory within the arena. You must port this exact integer-array-based free list logic. Do not rely on dynamic garbage collection; it does not exist here.
    *   **Wrapping:** In `Clay__CalculateFinalLayout`, look at the text wrapping section (`// Wrap text`). Ensure `ui.WrappedTextLine` structs are correctly generated and added to `context.wrappedTextLines`.

## 7. Render Commands & Output

This converts the layout boxes into drawing instructions.

*   **C Source Reference:**
    *   `Clay_RenderCommand`, `Clay_RenderData` (Union).
    *   The second half of `Clay__CalculateFinalLayout` (under `// Calculate final positions and generate render commands`).
*   **Terra Target:** `ui.RenderCommand`, `ui.RenderData`, `ui.EndLayout`.
*   **Implementation Directives:**
    *   Look at how `currentElementTreeNode.nextChildOffset` is mutated during the final DFS to place children consecutively.
    *   Look at how `CLAY_RENDER_COMMAND_TYPE_SCISSOR_START` and `SCISSOR_END` are inserted around clip elements.
    *   Map `Clay__AddRenderCommand` to `context.renderCommands:Add(...)`. Check for `maxRenderCommandsExceeded` before adding.

---

### Final Agent Instruction Checklist:
1. Open `clay.h`.
2. Find the C function listed in this guide.
3. Read the struct/array manipulation.
4. Write the Terra equivalent using `ui.Array`, `ui.Slice`, and standard Terra pointers.
5. Double-check that no C macros (`CLAY_`, `#define`) leaked into the Terra code.
6. Verify that mathematical formulas for sizing and layout were copied exactly, retaining all floating-point precision logic (`CLAY__EPSILON`).
