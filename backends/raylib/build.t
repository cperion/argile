-- Build the raylib demo as a native executable (AOT) to avoid the Terra JIT
-- process colliding with Mesa/LLVM on some systems.

local function split_words(s)
    local out = {}
    if not s then return out end
    for w in s:gmatch("%S+") do
        table.insert(out, w)
    end
    return out
end

local function pkg_config(args)
    local p = io.popen("pkg-config " .. args .. " raylib 2>/dev/null")
    if not p then return nil end
    local out = p:read("*a")
    local ok, why, code = p:close()
    if ok == false then return nil end
    if why == "exit" and code and code ~= 0 then return nil end
    return out
end

local demo = require("backends.raylib.demo.app")

local link_args = {}

-- Link against the local Argile shared library and keep runtime lookup local to build/.
table.insert(link_args, "-Lbuild")
table.insert(link_args, "-largile")
table.insert(link_args, "-Wl,-rpath,$ORIGIN")

-- raylib and its transitive libs from pkg-config when available.
local ray_libs = split_words(pkg_config("--libs") or "")
for _, arg in ipairs(ray_libs) do
    table.insert(link_args, arg)
end
if #ray_libs == 0 then
    table.insert(link_args, "-lraylib")
end

terralib.saveobj("build/argile_raylib_demo", "executable", { main = demo.run_demo }, link_args)
print("built build/argile_raylib_demo")
