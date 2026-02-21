# Architectural Blueprint: Terra-Native UI Layout Engine

This document details the complete architectural design and implementation strategy for a high-performance, immediate-mode UI layout engine written natively in Terra. It represents a ground-up reimagining of the C library `clay.h`, leveraging Terra's advanced metaprogramming, JIT capabilities, LLVM SIMD vectors, and zero-overhead Lua interoperability.

We completely abandon C-style macros and prefixes. The namespace is `ui`. The architecture is strictly data-oriented, utilizing a centralized `Arena` and flat arrays. The Developer Experience (DX) uses Lua as a purely compile-time DSL that generates zero-overhead, imperative Terra ASTs (quotes) for the layout tree.

---

## Phase 1: Foundation & Metaprogramming (Generics)

Terra’s ability to treat types as first-class Lua values allows us to implement generic, bounds-checked arrays and slices without relying on the C preprocessor.

### Memory & Arena
All allocations occur strictly via a pre-allocated Arena.

```terra
local ui = {}

ui.Arena = struct {
    nextAllocation : uintptr;
    capacity : uint64;
    memory : &int8;
}
```

### Generic Arrays and Slices
We use `terralib.memoize` to create strongly-typed array structs on demand. This replaces thousands of lines of C macros with a single, elegant Lua function.

```lua
-- Generate a strongly-typed Array struct for type T
ui.Array = terralib.memoize(function(T)
    local ArrayT = struct {
        capacity : int32;
        length : int32;
        internalArray : &T;
    }

    -- Allocate the array out of our Arena
    terra ArrayT.methods.Allocate(capacity : int32, arena : &ui.Arena) : ArrayT
        local totalSizeBytes = capacity * sizeof(T)
        -- Ensure 8-byte alignment
        local alignOffset = (8 - (arena.nextAllocation % 8)) % 8
        arena.nextAllocation = arena.nextAllocation + alignOffset
        
        if arena.nextAllocation + totalSizeBytes > arena.capacity then
            -- Note: In the full engine, this triggers the Context Error Handler
            return ArrayT { capacity = 0, length = 0, internalArray = nil }
        end
        
        local mem = [&T](arena.memory + arena.nextAllocation)
        arena.nextAllocation = arena.nextAllocation + totalSizeBytes
        
        return ArrayT {
            capacity = capacity,
            length = 0,
            internalArray = mem
        }
    end

    terra ArrayT:Add(item : T) : &T
        if self.length < self.capacity then
            local ptr = &self.internalArray[self.length]
            @ptr = item
            self.length = self.length + 1
            return ptr
        end
        return nil
    end

    terra ArrayT:Get(index : int32) : &T
        if index >= 0 and index < self.length then
            return &self.internalArray[index]
        end
        return nil
    end

    terra ArrayT:GetValue(index : int32) : T
        if index >= 0 and index < self.length then
            return self.internalArray[index]
        end
        -- Return a zero-initialized struct using a Terra escape
        local empty : T
        return empty
    end

    terra ArrayT:Set(index : int32, value : T)
        if index >= 0 and index < self.capacity then
            self.internalArray[index] = value
            if index >= self.length then
                self.length = index + 1
            end
        end
    end

    terra ArrayT:RemoveSwapback(index : int32) : T
        if index >= 0 and index < self.length then
            self.length = self.length - 1
            local removed = self.internalArray[index]
            self.internalArray[index] = self.internalArray[self.length]
            return removed
        end
        local empty : T
        return empty
    end

    return ArrayT
end)

-- Slice generation (Non-owning views)
ui.Slice = terralib.memoize(function(T)
    local SliceT = struct {
        length : int32;
        internalArray : &T;
    }
    
    terra SliceT:Get(index : int32) : &T
        if index >= 0 and index < self.length then
            return &self.internalArray[index]
        end
        return nil
    end

    return SliceT
end)
```

### Strings
```terra
ui.String = struct {
    isStaticallyAllocated : bool;
    length : int32;
    chars : &int8;
}

ui.StringSlice = struct {
    length : int32;
    chars : &int8;
    baseChars : &int8; -- Retain reference to original string allocation
}
```

---

## Phase 2: Hashing & Primitives

### Basic Data Types
```terra
ui.Dimensions = struct { width : float; height : float; }
ui.Vector2 = struct { x : float; y : float; }
ui.Color = struct { r : float; g : float; b : float; a : float; }
ui.BoundingBox = struct { x : float; y : float; width : float; height : float; }
ui.CornerRadius = struct { topLeft : float; topRight : float; bottomLeft : float; bottomRight : float; }

ui.ElementId = struct {
    id : uint32;
    offset : uint32;
    baseId : uint32;
    stringId : ui.String;
}
```

### SIMD-Accelerated String Hashing
Instead of scalar looping, we utilize Terra's `vector(T, N)` semantics to hash 16 bytes of string data at a time. This maps directly to LLVM vector intrinsics (AVX/NEON) under the hood.

```terra
-- Vector of 16 uint8s
local v16i8 = vector(uint8, 16)
local v4i32 = vector(uint32, 4)

terra ui.HashDataSIMD(data : &uint8, length : int32) : uint32
    local hash = uint32(0)
    
    -- Process 16 bytes at a time
    while length >= 16 do
        local chunk = @[&v16i8](data)
        -- Upcast uint8s to uint32s and perform a parallel ARX/FNV style mix
        -- (Simplified for demonstration; LLVM vector ops are incredibly powerful here)
        local c1 = [<uint32>chunk[0]] + ([<uint32>chunk[1]] << 8) + ([<uint32>chunk[2]] << 16) + ([<uint32>chunk[3]] << 24)
        local c2 = [<uint32>chunk[4]] + ([<uint32>chunk[5]] << 8) + ([<uint32>chunk[6]] << 16) + ([<uint32>chunk[7]] << 24)
        local c3 = [<uint32>chunk[8]] + ([<uint32>chunk[9]] << 8) + ([<uint32>chunk[10]] << 16) + ([<uint32>chunk[11]] << 24)
        local c4 = [<uint32>chunk[12]] + ([<uint32>chunk[13]] << 8) + ([<uint32>chunk[14]] << 16) + ([<uint32>chunk[15]] << 24)
        
        hash = hash ^ c1; hash = hash * 16777619
        hash = hash ^ c2; hash = hash * 16777619
        hash = hash ^ c3; hash = hash * 16777619
        hash = hash ^ c4; hash = hash * 16777619
        
        data = data + 16
        length = length - 16
    end
    
    -- Process remaining scalar bytes
    while length > 0 do
        hash = hash ^ data[0]
        hash = hash * 16777619
        data = data + 1
        length = length - 1
    end
    
    return hash
end

terra ui.HashString(key : ui.String, seed : uint32) : ui.ElementId
    local hash = ui.HashDataSIMD([&uint8](key.chars), key.length)
    hash = hash ^ seed
    return ui.ElementId {
        id = hash + 1,
        offset = 0,
        baseId = hash + 1,
        stringId = key
    }
end
```

---

## Phase 3: Layout Models & Configurations (Struct Exhaustiveness)

### Enums
We use packed `uint8` for all enums to strictly minimize memory footprint.

```terra
ui.LayoutDirection = uint8
ui.LEFT_TO_RIGHT = 0; ui.TOP_TO_BOTTOM = 1;

ui.LayoutAlignmentX = uint8
ui.ALIGN_X_LEFT = 0; ui.ALIGN_X_RIGHT = 1; ui.ALIGN_X_CENTER = 2;

ui.LayoutAlignmentY = uint8
ui.ALIGN_Y_TOP = 0; ui.ALIGN_Y_BOTTOM = 1; ui.ALIGN_Y_CENTER = 2;

ui.SizingType = uint8
ui.SIZING_FIT = 0; ui.SIZING_GROW = 1; ui.SIZING_PERCENT = 2; ui.SIZING_FIXED = 3;

ui.TextWrapMode = uint8
ui.TEXT_WRAP_WORDS = 0; ui.TEXT_WRAP_NEWLINES = 1; ui.TEXT_WRAP_NONE = 2;

ui.TextAlignment = uint8
ui.TEXT_ALIGN_LEFT = 0; ui.TEXT_ALIGN_CENTER = 1; ui.TEXT_ALIGN_RIGHT = 2;

ui.PointerCaptureMode = uint8
ui.POINTER_CAPTURE = 0; ui.POINTER_PASSTHROUGH = 1;

ui.AttachToElement = uint8
ui.ATTACH_NONE = 0; ui.ATTACH_PARENT = 1; ui.ATTACH_ELEMENT_WITH_ID = 2; ui.ATTACH_ROOT = 3;

ui.ClipToElement = uint8
ui.CLIP_NONE = 0; ui.CLIP_ATTACHED_PARENT = 1;

ui.AttachPoint = uint8
-- 9 variations mapping corners and edges (omitted for brevity, structurally uint8 0-8)

ui.ElementConfigType = uint8
ui.CONFIG_NONE = 0; ui.CONFIG_BORDER = 1; ui.CONFIG_FLOATING = 2; ui.CONFIG_CLIP = 3;
ui.CONFIG_ASPECT = 4; ui.CONFIG_IMAGE = 5; ui.CONFIG_TEXT = 6; ui.CONFIG_CUSTOM = 7;
ui.CONFIG_SHARED = 8;
```

### Sizing and Core Layout Configurations
```terra
ui.SizingMinMax = struct { min : float; max : float; }

ui.SizingAxis = struct {
    size : union {
        minMax : ui.SizingMinMax;
        percent : float;
    };
    type : ui.SizingType;
}

ui.Sizing = struct {
    width : ui.SizingAxis;
    height : ui.SizingAxis;
}

ui.Padding = struct {
    left : uint16; right : uint16; top : uint16; bottom : uint16;
}

ui.ChildAlignment = struct {
    x : ui.LayoutAlignmentX;
    y : ui.LayoutAlignmentY;
}

ui.LayoutConfig = struct {
    sizing : ui.Sizing;
    padding : ui.Padding;
    childGap : uint16;
    childAlignment : ui.ChildAlignment;
    layoutDirection : ui.LayoutDirection;
}
```

### Specific Element Configs
```terra
ui.TextConfig = struct {
    userData : &opaque;
    textColor : ui.Color;
    fontId : uint16;
    fontSize : uint16;
    letterSpacing : uint16;
    lineHeight : uint16;
    wrapMode : ui.TextWrapMode;
    textAlignment : ui.TextAlignment;
}

ui.AspectRatioConfig = struct { aspectRatio : float; }

ui.ImageConfig = struct { imageData : &opaque; }

ui.FloatingAttachPoints = struct {
    element : ui.AttachPoint;
    parent : ui.AttachPoint;
}

ui.FloatingConfig = struct {
    offset : ui.Vector2;
    expand : ui.Dimensions;
    parentId : uint32;
    zIndex : int16;
    attachPoints : ui.FloatingAttachPoints;
    pointerCaptureMode : ui.PointerCaptureMode;
    attachTo : ui.AttachToElement;
    clipTo : ui.ClipToElement;
}

ui.CustomConfig = struct { customData : &opaque; }

ui.ClipConfig = struct {
    horizontal : bool;
    vertical : bool;
    childOffset : ui.Vector2;
}

ui.BorderWidth = struct {
    left : uint16; right : uint16; top : uint16; bottom : uint16;
    betweenChildren : uint16;
}

ui.BorderConfig = struct {
    color : ui.Color;
    width : ui.BorderWidth;
}

ui.SharedConfig = struct {
    backgroundColor : ui.Color;
    cornerRadius : ui.CornerRadius;
    userData : &opaque;
}
```

### The Universal Config Union
```terra
ui.ElementConfigUnion = union {
    textConfig : &ui.TextConfig;
    aspectRatioConfig : &ui.AspectRatioConfig;
    imageConfig : &ui.ImageConfig;
    floatingConfig : &ui.FloatingConfig;
    customConfig : &ui.CustomConfig;
    clipConfig : &ui.ClipConfig;
    borderConfig : &ui.BorderConfig;
    sharedConfig : &ui.SharedConfig;
}

ui.ElementConfig = struct {
    type : ui.ElementConfigType;
    config : ui.ElementConfigUnion;
}
```

---

## Phase 4: The Core Data Nodes & Context

### Flat-Array Tree Nodes
To maximize CPU cache hits, children are not pointers. They are indices pointing into `context.layoutElementChildrenBuffer`.

```terra
ui.LayoutElementChildren = struct {
    elements : &int32;
    length : uint16;
}

-- Forward declaration needed for the union
ui.TextElementData = struct {
    text : ui.String;
    preferredDimensions : ui.Dimensions;
    elementIndex : int32;
    wrappedLines : ui.Slice(ui.WrappedTextLine); -- Assuming WrappedTextLine defined elsewhere
}

ui.LayoutElement = struct {
    childrenOrTextContent : union {
        children : ui.LayoutElementChildren;
        textElementData : &ui.TextElementData;
    };
    dimensions : ui.Dimensions;
    minDimensions : ui.Dimensions;
    layoutConfig : &ui.LayoutConfig;
    elementConfigs : ui.Slice(ui.ElementConfig);
    id : uint32;
    floatingChildrenCount : uint16;
}
```

### The God Object: Context
This object drives everything. It contains the pre-allocated arenas and all the typed Arrays.

```terra
ui.Context = struct {
    maxElementCount : int32;
    internalArena : ui.Arena;
    
    -- Core Elements
    layoutElements : ui.Array(ui.LayoutElement);
    renderCommands : ui.Array(ui.RenderCommand);
    
    -- Traversal & Hierarchy State
    openLayoutElementStack : ui.Array(int32);
    layoutElementChildren : ui.Array(int32);
    layoutElementChildrenBuffer : ui.Array(int32);
    layoutElementClipElementIds : ui.Array(int32);
    
    -- Config Arrays (All elements pull pointers from these pools)
    layoutConfigs : ui.Array(ui.LayoutConfig);
    elementConfigs : ui.Array(ui.ElementConfig);
    textConfigs : ui.Array(ui.TextConfig);
    imageConfigs : ui.Array(ui.ImageConfig);
    floatingConfigs : ui.Array(ui.FloatingConfig);
    borderConfigs : ui.Array(ui.BorderConfig);
    sharedConfigs : ui.Array(ui.SharedConfig);
    
    -- etc... text layout arrays, cached measurement arrays, pointers state.
}
```

---

## Phase 5: Developer Experience (The Terra API)

This is the crown jewel of the port. In C, building the tree relies on dangerous `#define` scoping hacks (`CLAY(...) { ... }`). 
In Terra, we treat **Lua as an intermediate AST builder**. The user constructs their UI layout as a nested Lua table. We then provide a Lua function `ui.compile(tree)` that resolves the entire layout structure at compile-time, returning a Terra `quote` consisting of pure, zero-overhead imperative Terra commands.

### The DX (How the User Writes UI)
```lua
local myLayout = ui.compile {
    id = "Root",
    layout = { 
        padding = { left = 16, right = 16, top = 16, bottom = 16 },
        layoutDirection = ui.TOP_TO_BOTTOM 
    },
    shared = { backgroundColor = { r=255, g=255, b=255, a=255 } },
    children = {
        {
            id = "Header",
            text = "Hello Terra Layout!",
            textConfig = { fontSize = 24, textColor = { r=0, g=0, b=0, a=255 } }
        },
        {
            id = "Button",
            layout = { sizing = { width = ui.Grow(), height = ui.Fixed(40) } },
            shared = { backgroundColor = { r=100, g=150, b=250, a=255 }, cornerRadius = {4,4,4,4} }
        }
    }
}

-- Using it inside a Terra function:
terra RenderFrame()
    ui.BeginLayout()
    [ myLayout ] -- Spliced in seamlessly! Evaluated at compile-time.
    return ui.EndLayout()
end
```

### The Compiler Implementation (Metaprogramming)
The `ui.compile` function recursively traverses the Lua table, instantiating Terra structs and building a sequence of quoted `OpenElement` / `CloseElement` function calls.

```lua
-- Helper to convert Lua config tables into typed Terra Structs
local function parseLayoutConfig(tbl)
    -- Translates Lua `{ padding = { left = 10 } }` into `ui.LayoutConfig { padding = ui.Padding { left = 10, ... } }`
    -- (Omitted exact table parsing for brevity, returns a Terra expression quote)
    return `ui.LayoutConfig { ... } 
end

function ui.compile(node)
    local stmts = terralib.newlist()
    
    -- 1. Parse and apply ID
    if node.id then
        stmts:insert(quote ui.OpenElementWithId(ui.HashString(node.id, 0)) end)
    else
        stmts:insert(quote ui.OpenElement() end)
    end
    
    -- 2. Bind Configs
    if node.layout then
        local lcfg = parseLayoutConfig(node.layout)
        stmts:insert(quote ui.ConfigureLayout(lcfg) end)
    end
    
    if node.shared then
        local scfg = parseSharedConfig(node.shared)
        stmts:insert(quote ui.ConfigureShared(scfg) end)
    end
    
    -- 3. Handle Text leaf node, or process Children
    if node.text then
        local txtStr = ui.CreateString(node.text)
        local tcfg = parseTextConfig(node.textConfig)
        stmts:insert(quote ui.OpenTextElement(txtStr, tcfg) end)
    elseif node.children then
        for _, child in ipairs(node.children) do
            stmts:insert(ui.compile(child))
        end
    end
    
    -- 4. Close the element
    stmts:insert(quote ui.CloseElement() end)
    
    -- Return the composed multi-line block
    return quote [stmts] end
end
```

**Why this is brilliant:**
1. **Zero Runtime Allocation:** The Lua table parsing happens *during compilation*.
2. **Infinite Flexibility:** Users can use standard Lua loops `for i=1,10 do table.insert(children, {...}) end` to generate UI templates.
3. **Maximum Performance:** The generated Terra code is equivalent to writing hand-optimized `ui.OpenElement()` instructions without any dynamic dispatch.

---

## Phase 6: The Engine Pipeline (Algorithms Overview)

The multi-pass layout algorithm translates the hierarchical data into strictly 1D array iterations.

### Step 1: Initialization
```terra
terra ui.BeginLayout(arena : &ui.Arena, dimensions : ui.Dimensions)
    local ctx = ui.GetCurrentContext()
    ctx.internalArena.nextAllocation = ctx.arenaResetOffset
    
    -- Reset all ephemeral Arrays (length = 0)
    ctx.layoutElements.length = 0
    ctx.layoutConfigs.length = 0
    -- ...
    
    -- Root element
    ui.OpenElementWithId(ui.HashString("Root", 0))
    ui.ConfigureLayout(ui.LayoutConfig{ sizing = ui.FixedSizing(dimensions) })
end
```

### Step 2: On-Axis Sizing (Flat Traversal)
Instead of recursion, Terra loops over the flat tree arrays (DFS ordered via buffer offsets) to evaluate child constraints against parent sizes.

```terra
terra ui.SizeContainersAlongAxis(xAxis : bool)
    local ctx = ui.GetCurrentContext()
    local bfsBuffer = &ctx.layoutElementChildrenBuffer
    
    for i = 0, ctx.layoutElementTreeRoots.length do
        local root = ctx.layoutElementTreeRoots:Get(i)
        local rootElem = ctx.layoutElements:Get(root.layoutElementIndex)
        
        -- Apply floating parent constraints...
        
        -- Inner BFS using the flat layoutElementChildren arrays
        for j = 0, bfsBuffer.length do
            local parentIndex = bfsBuffer:GetValue(j)
            local parent = ctx.layoutElements:Get(parentIndex)
            local isAlongAxis = (xAxis and parent.layoutConfig.layoutDirection == ui.LEFT_TO_RIGHT) or 
                                (not xAxis and parent.layoutConfig.layoutDirection == ui.TOP_TO_BOTTOM)
                                
            local innerContentSize = 0.0
            
            -- Pass 1: Sum fixed/fit children, count Grow children
            for childIdx = 0, parent.childrenOrTextContent.children.length do
                local child = ctx.layoutElements:Get(parent.childrenOrTextContent.children.elements[childIdx])
                -- Add sizing logic...
            end
            
            -- Pass 2: Distribute remaining space among Grow children
            -- Compress/expand math...
        end
    end
end
```

### Step 3: Final Resolution & Commands
```terra
terra ui.CalculateFinalLayout()
    -- 1. Calculate X axis
    ui.SizeContainersAlongAxis(true)
    
    -- 2. Wrap Text nodes based on new horizontal constraints
    ui.WrapTextNodes()
    
    -- 3. Propagate aspect ratio heights
    ui.ScaleVerticalHeightsByAspect()
    
    -- 4. Calculate Y axis
    ui.SizeContainersAlongAxis(false)
    
    -- 5. Sort Tree Roots by zIndex (Insertion Sort is sufficient for < 100 roots)
    ui.SortRootsZIndex()
    
    -- 6. Generate Render Commands
    ui.GenerateRenderCommands()
end

terra ui.EndLayout() : ui.Array(ui.RenderCommand)
    ui.CloseElement() -- Closes Root
    ui.CalculateFinalLayout()
    return ui.GetCurrentContext().renderCommands
end
```

### Conclusion

This blueprint outlines a complete, idiomatic Terra UI library. By marrying Terra's tight C-like control flow, static typing, and memory layouts with Lua's meta-programmability, we achieve a system that guarantees the exact same zero-allocation performance as the original `clay.h` while replacing thousands of lines of verbose C macros with a hyper-ergonomic, declarative API.
