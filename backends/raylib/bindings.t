-- Terra-generated bindings for Argile + raylib backend demos.
-- No LuaJIT ffi/cdef is used here; Terra parses the headers directly.

local function split_words(s)
    local out = {}
    if not s then return out end
    for w in s:gmatch("%S+") do
        table.insert(out, w)
    end
    return out
end

local function pkg_config(args)
    local cmd = "pkg-config " .. args .. " 2>/dev/null"
    local p = io.popen(cmd)
    if not p then return nil end
    local out = p:read("*a")
    local ok, why, code = p:close()
    if ok == false then
        return nil
    end
    if why == "exit" and code and code ~= 0 then
        return nil
    end
    return out
end

local function link_library_candidates(candidates)
    local last_err
    for _, name in ipairs(candidates) do
        local ok, err = pcall(terralib.linklibrary, name)
        if ok then
            return name
        end
        last_err = err
    end
    error(last_err or ("failed to link any library candidate: " .. table.concat(candidates, ", ")))
end

-- libc helpers used by the demo
local C = terralib.includecstring([[
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
]])

-- Argile portable ABI (generated header)
local arg = terralib.includec("build/argile_api.h")
link_library_candidates({
    "./build/libargile.so",
    "build/libargile.so",
    "libargile.so",
})

-- Raylib header and library
local ray_cflags = split_words(pkg_config("--cflags raylib") or "")
local ray
local rayshim
do
    local ok, parsed = pcall(function()
        if #ray_cflags > 0 then
            return terralib.includec("raylib.h", unpack(ray_cflags))
        end
        return terralib.includec("raylib.h")
    end)
    if not ok then
        -- Fallback for environments where Clang needs the include via includecstring.
        -- Still header-driven, still no handwritten C wrapper file.
        if #ray_cflags > 0 then
            ray = terralib.includecstring("#include <raylib.h>\n", unpack(ray_cflags))
        else
            ray = terralib.includecstring("#include <raylib.h>\n")
        end
    else
        ray = parsed
    end
end

-- Small input wrappers to avoid any bool/struct-return ABI edge cases in Terra<->raylib.
do
    local shim_src = [[
#include <raylib.h>
int argile_ray_is_key_pressed_i32(int key) { return IsKeyPressed(key) ? 1 : 0; }
int argile_ray_is_mouse_button_down_i32(int button) { return IsMouseButtonDown(button) ? 1 : 0; }
int argile_ray_is_mouse_button_pressed_i32(int button) { return IsMouseButtonPressed(button) ? 1 : 0; }
int argile_ray_is_mouse_button_released_i32(int button) { return IsMouseButtonReleased(button) ? 1 : 0; }
int argile_ray_get_mouse_x_i32(void) { return GetMouseX(); }
int argile_ray_get_mouse_y_i32(void) { return GetMouseY(); }
void argile_ray_clear_background_rgba(unsigned char r, unsigned char g, unsigned char b, unsigned char a) {
    ClearBackground((Color){r,g,b,a});
}
void argile_ray_draw_text_rgba(const char *text, int x, int y, int fontSize,
                               unsigned char r, unsigned char g, unsigned char b, unsigned char a) {
    DrawText(text, x, y, fontSize, (Color){r,g,b,a});
}
void argile_ray_draw_rectangle_rgba(int x, int y, int w, int h,
                                    unsigned char r, unsigned char g, unsigned char b, unsigned char a) {
    DrawRectangle(x, y, w, h, (Color){r,g,b,a});
}
void argile_ray_draw_rectangle_rounded_rgba(float x, float y, float w, float h, float roundness, int segments,
                                            unsigned char r, unsigned char g, unsigned char b, unsigned char a) {
    DrawRectangleRounded((Rectangle){x,y,w,h}, roundness, segments, (Color){r,g,b,a});
}
void argile_ray_draw_rectangle_lines_ex_rgba(float x, float y, float w, float h, float thick,
                                             unsigned char r, unsigned char g, unsigned char b, unsigned char a) {
    DrawRectangleLinesEx((Rectangle){x,y,w,h}, thick, (Color){r,g,b,a});
}
void argile_ray_draw_circle_rgba(int cx, int cy, float radius,
                                 unsigned char r, unsigned char g, unsigned char b, unsigned char a) {
    DrawCircle(cx, cy, radius, (Color){r,g,b,a});
}
void argile_ray_draw_line_ex_rgba(float x1, float y1, float x2, float y2, float thick,
                                  unsigned char r, unsigned char g, unsigned char b, unsigned char a) {
    DrawLineEx((Vector2){x1,y1}, (Vector2){x2,y2}, thick, (Color){r,g,b,a});
}
]]
    if #ray_cflags > 0 then
        rayshim = terralib.includecstring(shim_src, unpack(ray_cflags))
    else
        rayshim = terralib.includecstring(shim_src)
    end
end

-- raylib is often installed as libraylib.so. Let Terra resolve either form.
link_library_candidates({
    "raylib",
    "libraylib.so",
    "/lib64/libraylib.so",
})

return {
    C = C,
    arg = arg,
    ray = ray,
    shim = rayshim,
}
