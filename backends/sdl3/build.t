-- Build the SDL3 demo as a native executable (AOT)

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
    if ok == false then return nil end
    if why == "exit" and code and code ~= 0 then return nil end
    return out
end

local demo = require("backends.sdl3.demo.app")

local link_args = {}

-- Link against the local Argile shared library and keep runtime lookup local to build/.
table.insert(link_args, "-Lbuild")
table.insert(link_args, "-largile")
table.insert(link_args, "-Wl,-rpath,$ORIGIN")

-- SDL3 and its transitive libs from pkg-config when available.
local sdl_libs = split_words(pkg_config("--libs", "sdl3") or "")
for _, arg in ipairs(sdl_libs) do
    table.insert(link_args, arg)
end
if #sdl_libs == 0 then
    table.insert(link_args, "-lSDL3")
end

-- SDL3_ttf and its transitive libs from pkg-config when available.
local ttf_libs = split_words(pkg_config("--libs", "SDL3_ttf") or "")
for _, arg in ipairs(ttf_libs) do
    table.insert(link_args, arg)
end
if #ttf_libs == 0 then
    table.insert(link_args, "-lSDL3_ttf")
end

terralib.saveobj("build/argile_sdl3_demo", "executable", { main = demo.run_demo }, link_args)
print("built build/argile_sdl3_demo")
