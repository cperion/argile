-- Terra-generated bindings for Argile + SDL3 + SDL_ttf backend demos.
-- Simplified version following the working pattern from parent directory.

local function split_words(s)
    local out = {}
    if not s then return out end
    for w in s:gmatch("%S+") do
        table.insert(out, w)
    end
    return out
end

local function pkg_config(args, lib)
    local cmd = "pkg-config " .. args
    if lib then
        cmd = cmd .. " " .. lib
    end
    cmd = cmd .. " 2>/dev/null"
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

-- SDL3 and SDL3_ttf headers
local sdl3_cflags = split_words(pkg_config("--cflags", "sdl3") or "")
local sdl_include = "#include <SDL3/SDL.h>\n#include <SDL3_ttf/SDL_ttf.h>\n"

local sdl
if #sdl3_cflags > 0 then
    sdl = terralib.includecstring(sdl_include, unpack(sdl3_cflags))
else
    sdl = terralib.includecstring(sdl_include)
end

-- Argile portable ABI (generated header)
local arg = terralib.includec("build/argile_api.h")
link_library_candidates({
    "./build/libargile.so",
    "build/libargile.so",
    "libargile.so",
})

-- Link SDL3 and SDL3_ttf
link_library_candidates({
    "SDL3",
    "libSDL3.so",
    "/lib64/libSDL3.so",
})

link_library_candidates({
    "SDL3_ttf",
    "libSDL3_ttf.so",
    "/lib64/libSDL3_ttf.so",
})

return {
    C = C,
    arg = arg,
    sdl = sdl,
}
