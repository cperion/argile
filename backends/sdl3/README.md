# SDL3 Backend for Argile

Pure Terra backend adapter for the Argile UI library using [SDL3](https://libsdl.org/) with full [SDL_ttf](https://github.com/libsdl-org/SDL_ttf) text rendering support.

## Status

**Platform: All (Wayland, X11, macOS, Windows)**

Unlike raylib (which uses GLFW), SDL3 has native Wayland support and should work on all modern platforms.

## Requirements

- `terra` (Terra language)
- `SDL3` (Graphics library)
- `SDL3_ttf` (TrueType font rendering)
- Display server: Wayland, X11, or others supported by SDL3

## Usage

```bash
# Build and run
make sdl3-demo

# Build only (AOT executable)
ARGILE_SDL3_DEMO_BUILD_ONLY=1 ./backends/sdl3/build.sh

# Optional JIT runner
ARGILE_SDL3_DEMO_NO_RUN=1 terra backends/sdl3/demo/main.t
```

## Implementation Notes

- Pure Terra implementation using Terra FFI module
- Uses `terralib.includec` / `terralib.includecstring` to parse headers
- Uses `terralib.linklibrary(...)` for `SDL3`, `SDL3_ttf`, and `libargile.so`
- Builds an AOT executable for normal runs (`build/argile_sdl3_demo`)
- Implements the portable scene ABI:
  - `ArgileDemoFrameForContext(ctx, &ArgileFrameInput)`
  - `ArgileDemoGetIds(&ArgileDemoIds)`
- Supports render commands: RECTANGLE, BORDER, TEXT (full TTF rendering), PAINT
- **Text rendering**: Full SDL_ttf support with caching
  - Uses Liberation Sans font by default
  - Text measurement via `TTF_SizeText`
  - Text rendering via `TTF_RenderText_Blended` → `SDL_CreateTextureFromSurface` → `SDL_RenderTexture`
  - Simple LRU-style texture cache for performance

## Architecture

```
Terra Scene (examples/scenes/*.t)
    ↓
libargile.so (portable ABI)
    ↓
Terra Backend Adapter (backends/sdl3/demo/app.t)
    ↓
SDL3/SDL_ttf (rendering, input, windowing, text)
```

## Controls

Same as other demos:
- `F` - Toggle focus state
- `S` - Toggle selected state  
- `D` - Toggle disabled state
- `R` - Reset all states
- Mouse hover/click - Hover/active states

## Known Limitations

- Rounded rectangles are approximated (SDL3 doesn't have native rounded rect support)
- Circle rendering uses rectangles as fallback
- Text texture cache is fixed size (64 entries) with simple eviction

## Comparison with Other Backends

| Feature | Love2D | raylib | SDL3 |
|---------|--------|--------|------|
| Wayland Support | ✅ (via SDL2) | ❌ (GLFW limitation) | ✅ Native |
| X11 Support | ✅ | ✅ | ✅ |
| Text Rendering | ✅ | ✅ | ✅ (SDL_ttf) |
| Rounded Rect | ✅ | ✅ | ⚠️ (approx) |
