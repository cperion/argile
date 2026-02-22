# Raylib Backend for Argile

Pure Terra backend adapter for the Argile UI library using [raylib](https://www.raylib.com/).

## Status

⚠️ **Platform Limitation: Wayland**

This demo may crash on Wayland display servers due to GLFW/raylib limitations. GLFW (which raylib uses for windowing) has incomplete Wayland support.

### Workarounds

1. **Use X11/XWayland session** (Recommended)
   - Most Wayland compositors provide XWayland for X11 app compatibility
   - The demo should work in an XWayland context

2. **Use Love2D demo instead** 
   - Love2D uses SDL2 which has excellent Wayland support
   - Both demos validate the same portable ABI

3. **Use SDL3 backend** (Coming soon)
   - SDL3 has native Wayland support
   - Recommended for Wayland-first environments

## Requirements

- `terra` (Terra language)
- `raylib` (Graphics library)
- Display server: X11 or XWayland (Wayland native may crash)

## Usage

```bash
# Build and run
make raylib-demo

# Build only (AOT executable)
ARGILE_RAYLIB_DEMO_BUILD_ONLY=1 ./backends/raylib/build.sh

# Optional JIT runner (debug only; more likely to hit Terra+Mesa LLVM collision)
ARGILE_RAYLIB_DEMO_NO_RUN=1 terra backends/raylib/demo/main.t
```

## Implementation Notes

- Pure Terra implementation (no C adapter code, no LuaJIT `ffi.cdef`)
- Uses Terra C interop (`terralib.includec` / `terralib.includecstring`) to parse `raylib.h` and `build/argile_api.h`
- Uses `terralib.linklibrary(...)` for `raylib` and `libargile.so`
- Builds an AOT executable for normal runs (`build/argile_raylib_demo`) to avoid Terra JIT + Mesa/LLVM process conflicts
- Implements the portable scene ABI:
  - `ArgileDemoFrameForContext(ctx, &ArgileFrameInput)`
  - `ArgileDemoGetIds(&ArgileDemoIds)`
- Supports render commands: RECTANGLE, BORDER, TEXT, PAINT

## Architecture

```
Terra Scene (examples/scenes/*.t)
    ↓
libargile.so (portable ABI)
    ↓
Terra Backend Adapter (backends/raylib/demo/main.t)
    ↓
raylib (rendering, input, text)
```

## Controls

Same as other demos:
- `F` - Toggle focus state
- `S` - Toggle selected state  
- `D` - Toggle disabled state
- `R` - Reset all states
- Mouse hover/click - Hover/active states
