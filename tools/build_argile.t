-- Build full Terra UI shared library and generate LuaJIT ffi.cdef bindings
-- from the final exposed API table in src/init.t.

local ui = require("src.init")

local function sorted_keys(tbl, predicate)
    local keys = {}
    for k, v in pairs(tbl) do
        if predicate == nil or predicate(k, v) then
            keys[#keys + 1] = k
        end
    end
    table.sort(keys)
    return keys
end

local named_structs = {}
local struct_name_of = {}
for _, key in ipairs(sorted_keys(ui, function(_, v) return terralib.type(v) == "terratype" and v:isstruct() end)) do
    local t = ui[key]
    named_structs[key] = t
    struct_name_of[t] = key
end

local anon_count = 0
local function struct_name(t)
    local name = struct_name_of[t]
    if name ~= nil then
        return name
    end
    anon_count = anon_count + 1
    name = "UiAnonType" .. tostring(anon_count)
    struct_name_of[t] = name
    return name
end

local function primitive_to_c(name)
    if name == "int" or name == "int32" then return "int32_t" end
    if name == "uint32" then return "uint32_t" end
    if name == "int64" then return "int64_t" end
    if name == "uint64" then return "uint64_t" end
    if name == "int16" then return "int16_t" end
    if name == "uint16" then return "uint16_t" end
    if name == "int8" then return "int8_t" end
    if name == "uint8" then return "uint8_t" end
    if name == "float" then return "float" end
    if name == "double" then return "double" end
    if name == "bool" then return "bool" end
    if name == "opaque" then return "void" end
    if name == "intptr" then return "intptr_t" end
    if name == "ptrdiff" then return "ptrdiff_t" end
    return name
end

local function type_to_c(t)
    if tostring(t) == "opaque" then
        return "void"
    end
    if t:isprimitive() then
        return primitive_to_c(tostring(t))
    elseif t:ispointer() then
        local base = t
        while base:ispointer() do
            base = base.type
        end
        if tostring(base) == "opaque" then
            -- Normalize all opaque pointer chains to user-facing void*.
            return "void*"
        end
        base = t.type
        if base:isprimitive() and tostring(base) == "int8" then
            return "char*"
        end
        if base:isfunction() then
            local ret = base.returntype:isunit() and "void" or type_to_c(base.returntype)
            local params = {}
            for _, p in ipairs(base.parameters) do
                params[#params + 1] = type_to_c(p)
            end
            local pstr = (#params > 0) and table.concat(params, ", ") or "void"
            return ret .. " (*)(" .. pstr .. ")"
        end
        return type_to_c(base) .. "*"
    elseif t:isarray() then
        return type_to_c(t.type) .. "[" .. tostring(t.N) .. "]"
    elseif t:isstruct() then
        return "struct " .. struct_name(t)
    end
    return "void*"
end

local function walk_type(t, by_value, seen, want_forward, want_complete)
    if t == nil or seen[t] then
        return
    end
    seen[t] = true

    if t:ispointer() then
        local base = t.type
        if base:isstruct() then
            local s = struct_name(base)
            want_forward[s] = base
            local nested_seen = {}
            if s == "Context" then
                -- Keep Context opaque in generated C/FFI surface.
                walk_type(base, false, nested_seen, want_forward, want_complete)
            else
                -- Pointer parameters can still require complete layouts when they
                -- contain by-value nested structs (for example ElementDesc).
                walk_type(base, true, nested_seen, want_forward, want_complete)
            end
        elseif base:isfunction() then
            local nested_seen = {}
            walk_type(base.returntype, true, nested_seen, want_forward, want_complete)
            for _, p in ipairs(base.parameters) do
                local sp = {}
                walk_type(p, true, sp, want_forward, want_complete)
            end
        end
        return
    end

    if t:isarray() then
        walk_type(t.type, true, seen, want_forward, want_complete)
        return
    end

    if t:isstruct() then
        local s = struct_name(t)
        if by_value then
            want_complete[s] = t
        else
            want_forward[s] = t
        end
        return
    end

    if t:isfunction() then
        walk_type(t.returntype, true, seen, want_forward, want_complete)
        for _, p in ipairs(t.parameters) do
            local sp = {}
            walk_type(p, true, sp, want_forward, want_complete)
        end
    end
end

local function field_is_union(entry)
    return terralib.islist(entry) or (#entry > 0 and type(entry[1]) == "table")
end

local function field_name(entry)
    return entry.field or entry[1]
end

local function field_type(entry)
    return entry.type or entry[2]
end

local function format_field(name, t)
    if t:isarray() then
        local base = t
        local dims = {}
        while base:isarray() do
            dims[#dims + 1] = base.N
            base = base.type
        end
        local dim_str = ""
        for _, d in ipairs(dims) do
            dim_str = dim_str .. "[" .. tostring(d) .. "]"
        end
        return "    " .. type_to_c(base) .. " " .. name .. dim_str .. ";"
    end
    if t:ispointer() and t.type:isfunction() then
        local ftype = t.type
        local ret = ftype.returntype:isunit() and "void" or type_to_c(ftype.returntype)
        local params = {}
        for _, p in ipairs(ftype.parameters) do
            params[#params + 1] = type_to_c(p)
        end
        local pstr = (#params > 0) and table.concat(params, ", ") or "void"
        return "    " .. ret .. " (*" .. name .. ")(" .. pstr .. ");"
    end
    return "    " .. type_to_c(t) .. " " .. name .. ";"
end

local export_source = ui.capi or ui
local exports = {}
for _, name in ipairs(sorted_keys(export_source, function(_, v) return terralib.type(v) == "terrafunction" end)) do
    exports[name] = export_source[name]
end

-- Example scene exports from examples/scenes/
-- These are backend-neutral scene functions used by Love2D, raylib, and SDL3 demos
local scene_modules = {
    "examples/scenes/dsl_demo_scene",
    "examples/scenes/dsl_conformance_scene",
    "examples/scenes/dsl_state_matrix_scene",
}

for _, module_path in ipairs(scene_modules) do
    local ok, scene_exports = pcall(require, module_path)
    if ok and type(scene_exports) == "table" then
        for _, name in ipairs(sorted_keys(scene_exports, function(_, v) return terralib.type(v) == "terrafunction" end)) do
            if exports[name] ~= nil then
                error("duplicate export name from scene module " .. module_path .. ": " .. tostring(name))
            end
            exports[name] = scene_exports[name]
        end
    elseif not ok then
        io.stderr:write("warning: could not load scene module " .. module_path .. ": " .. tostring(scene_exports) .. "\n")
    end
end

local want_forward = {}
local want_complete = {}
for _, name in ipairs(sorted_keys(exports)) do
    local fn = exports[name]
    local ftype = fn:gettype()
    local sr = {}
    walk_type(ftype.returntype, true, sr, want_forward, want_complete)
    for _, p in ipairs(ftype.parameters) do
        local sp = {}
        walk_type(p, true, sp, want_forward, want_complete)
    end
end

local changed = true
while changed do
    changed = false
    for _, st in pairs(want_complete) do
        local ok = pcall(function() st:complete() end)
        if ok and st.entries ~= nil then
            for _, entry in ipairs(st.entries) do
                if field_is_union(entry) then
                    for _, uentry in ipairs(entry) do
                        local su = {}
                        walk_type(field_type(uentry), true, su, want_forward, want_complete)
                    end
                else
                    local sf = {}
                    walk_type(field_type(entry), true, sf, want_forward, want_complete)
                end
            end
        end
    end
    for name, t in pairs(want_complete) do
        if want_forward[name] == nil then
            want_forward[name] = t
            changed = true
        end
    end
end

-- LuaJIT FFI often needs concrete definitions for structs referenced via
-- pointers inside exported structs (for example `PaintConfig.ops -> PaintOp*`)
-- when client code indexes into those buffers. Promote pointer-target structs
-- to complete definitions transitively.
local function promote_pointer_target_structs()
    local did_change = false
    local opaque_pointer_targets = {
        Context = true, -- keep runtime context opaque in C/FFI surface
    }

    local function consider_type(t)
        if t == nil then return end
        while t:isarray() do
            t = t.type
        end
        if t:ispointer() then
            local base = t.type
            while base:isarray() do
                base = base.type
            end
            if base:isstruct() then
                local s = struct_name(base)
                if opaque_pointer_targets[s] then
                    return
                end
                want_forward[s] = base
                if want_complete[s] == nil then
                    want_complete[s] = base
                    did_change = true
                end
            end
        end
    end

    -- Public pointer-only structs used in exported function signatures (e.g.
    -- ArgileFrameInput*) need full definitions for LuaJIT FFI allocation/access.
    for _, name in ipairs(sorted_keys(exports)) do
        local fn = exports[name]
        local ftype = fn:gettype()
        consider_type(ftype.returntype)
        for _, p in ipairs(ftype.parameters) do
            consider_type(p)
        end
    end

    for _, st in pairs(want_complete) do
        local ok = pcall(function() st:complete() end)
        if ok and st.entries ~= nil then
            for _, entry in ipairs(st.entries) do
                if field_is_union(entry) then
                    for _, uentry in ipairs(entry) do
                        consider_type(field_type(uentry))
                    end
                else
                    consider_type(field_type(entry))
                end
            end
        end
    end

    return did_change
end

while promote_pointer_target_structs() do
    -- repeat until closure over pointer-target struct fields stabilizes
end

local forward_names = sorted_keys(want_forward)

local typedef_lines = {
    "typedef signed char int8_t;",
    "typedef unsigned char uint8_t;",
    "typedef short int16_t;",
    "typedef unsigned short uint16_t;",
    "typedef int int32_t;",
    "typedef unsigned int uint32_t;",
    "typedef long long int64_t;",
    "typedef unsigned long long uint64_t;",
}

local alias_typedef_lines = {}
for _, key in ipairs(sorted_keys(ui, function(_, v)
    return terralib.type(v) == "terratype" and not v:isstruct()
end)) do
    local t = ui[key]
    alias_typedef_lines[#alias_typedef_lines + 1] = string.format("typedef %s %s;", type_to_c(t), key)
end

for _, line in ipairs(alias_typedef_lines) do
    typedef_lines[#typedef_lines + 1] = line
end

local function struct_dep_name(t)
    while t:isarray() do
        t = t.type
    end
    if t:ispointer() then
        return nil
    end
    if t:isstruct() then
        return struct_name(t)
    end
    return nil
end

local remaining = {}
for name, st in pairs(want_complete) do
    remaining[#remaining + 1] = { name = name, st = st }
end
table.sort(remaining, function(a, b) return a.name < b.name end)

local emitted = {}
local struct_defs = {}
local function emit_struct(rec)
    local st = rec.st
    local ok = pcall(function() st:complete() end)
    if not ok or st.entries == nil then
        return false
    end
    local out = {}
    out[#out + 1] = "struct " .. rec.name .. " {"
    for _, entry in ipairs(st.entries) do
        if field_is_union(entry) then
            out[#out + 1] = "    union {"
            for _, uentry in ipairs(entry) do
                out[#out + 1] = format_field(field_name(uentry), field_type(uentry))
            end
            out[#out + 1] = "    };"
        else
            out[#out + 1] = format_field(field_name(entry), field_type(entry))
        end
    end
    out[#out + 1] = "};"
    struct_defs[#struct_defs + 1] = table.concat(out, "\n")
    emitted[rec.name] = true
    return true
end

while #remaining > 0 do
    local progressed = false
    local i = 1
    while i <= #remaining do
        local rec = remaining[i]
        local st = rec.st
        local ok = pcall(function() st:complete() end)
        if not ok or st.entries == nil then
            i = i + 1
        else
            local blocked = false
            for _, entry in ipairs(st.entries) do
                if field_is_union(entry) then
                    for _, uentry in ipairs(entry) do
                        local dep = struct_dep_name(field_type(uentry))
                        if dep ~= nil and dep ~= rec.name and want_complete[dep] ~= nil and not emitted[dep] then
                            blocked = true
                            break
                        end
                    end
                else
                    local dep = struct_dep_name(field_type(entry))
                    if dep ~= nil and dep ~= rec.name and want_complete[dep] ~= nil and not emitted[dep] then
                        blocked = true
                    end
                end
                if blocked then
                    break
                end
            end
            if blocked then
                i = i + 1
            else
                emit_struct(rec)
                table.remove(remaining, i)
                progressed = true
            end
        end
    end
    if not progressed then
        break
    end
end

local constants = {}
for _, key in ipairs(sorted_keys(ui, function(_, v) return type(v) == "number" end)) do
    local v = ui[key]
    if math.floor(v) == v and v >= -2147483648 and v <= 2147483647 then
        constants[#constants + 1] = string.format("enum { %s = %d };", key, v)
    end
end

local function_decls = {}
for _, name in ipairs(sorted_keys(exports)) do
    local fn = exports[name]
    local ftype = fn:gettype()
    local ret = ftype.returntype:isunit() and "void" or type_to_c(ftype.returntype)
    local params = {}
    for _, p in ipairs(ftype.parameters) do
        params[#params + 1] = type_to_c(p)
    end
    local pstr = (#params > 0) and table.concat(params, ", ") or "void"
    function_decls[#function_decls + 1] = string.format("%s %s(%s);", ret, name, pstr)
end

os.execute("mkdir -p build")
terralib.saveobj("build/libargile.so", "sharedlibrary", exports, nil, nil, { fastmath = true })

local out = {}
out[#out + 1] = "local ffi = require('ffi')"
out[#out + 1] = "ffi.cdef[["
out[#out + 1] = "/* Forward Struct Declarations */"
for _, name in ipairs(forward_names) do
    out[#out + 1] = "struct " .. name .. ";"
end
out[#out + 1] = ""
out[#out + 1] = "/* Typedefs */"
for _, line in ipairs(typedef_lines) do
    out[#out + 1] = line
end
out[#out + 1] = ""
out[#out + 1] = "/* Struct Definitions */"
for _, def in ipairs(struct_defs) do
    out[#out + 1] = def
end
out[#out + 1] = ""
out[#out + 1] = "/* Constants */"
for _, c in ipairs(constants) do
    out[#out + 1] = c
end
out[#out + 1] = ""
out[#out + 1] = "/* Functions */"
for _, fdecl in ipairs(function_decls) do
    out[#out + 1] = fdecl
end
out[#out + 1] = "]]"
out[#out + 1] = "return ffi"
out[#out + 1] = ""

local f = assert(io.open("build/argile_api_ffi.lua", "w"))
f:write(table.concat(out, "\n"))
f:close()

local out_h = {}
out_h[#out_h + 1] = "#ifndef ARGILE_API_H"
out_h[#out_h + 1] = "#define ARGILE_API_H"
out_h[#out_h + 1] = ""
out_h[#out_h + 1] = "#include <stdbool.h>"
out_h[#out_h + 1] = "#include <stddef.h>"
out_h[#out_h + 1] = "#include <stdint.h>"
out_h[#out_h + 1] = ""
out_h[#out_h + 1] = "#ifdef __cplusplus"
out_h[#out_h + 1] = "extern \"C\" {"
out_h[#out_h + 1] = "#endif"
out_h[#out_h + 1] = ""
out_h[#out_h + 1] = "/* Forward Struct Declarations */"
for _, name in ipairs(forward_names) do
    out_h[#out_h + 1] = "struct " .. name .. ";"
end
out_h[#out_h + 1] = ""
out_h[#out_h + 1] = "/* Typedefs */"
for _, line in ipairs(alias_typedef_lines) do
    out_h[#out_h + 1] = line
end
out_h[#out_h + 1] = ""
out_h[#out_h + 1] = "/* Struct Definitions */"
for _, def in ipairs(struct_defs) do
    out_h[#out_h + 1] = def
end
out_h[#out_h + 1] = ""
out_h[#out_h + 1] = "/* Constants */"
for _, c in ipairs(constants) do
    out_h[#out_h + 1] = c
end
out_h[#out_h + 1] = ""
out_h[#out_h + 1] = "/* Functions */"
for _, fdecl in ipairs(function_decls) do
    out_h[#out_h + 1] = fdecl
end
out_h[#out_h + 1] = ""
out_h[#out_h + 1] = "#ifdef __cplusplus"
out_h[#out_h + 1] = "}"
out_h[#out_h + 1] = "#endif"
out_h[#out_h + 1] = ""
out_h[#out_h + 1] = "#endif /* ARGILE_API_H */"

local h = assert(io.open("build/argile_api.h", "w"))
h:write(table.concat(out_h, "\n"))
h:close()

print("built build/libargile.so")
print("generated build/argile_api_ffi.lua")
print("generated build/argile_api.h")
