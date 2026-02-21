
-- Usage: terra ffi_gen.t <header_file.h> > bindings.lua

if not arg[1] then
    print("Usage: terra ffi_gen.t <header.h> [optional clang args...]")
    os.exit(1)
end

local header_file = arg[1]
local clang_args = {}
for i = 2, #arg do
    table.insert(clang_args, arg[i])
end

-- 1. Use Terra's Clang integration to parse the C header
local C = terralib.includec(header_file, unpack(clang_args))

-- Helper: Map Terra primitive types back to C/LuaJIT FFI compatible types
local function terraTypeToC(t)
    if t:isprimitive() then
        local name = tostring(t)
        if name == "bool" then return "bool" end
        if name == "float" or name == "double" then return name end
        if name == "opaque" then return "void" end
        if name == "intptr" then return "intptr_t" end
        if name == "ptrdiff" then return "ptrdiff_t" end
        -- Terra uses sizes for integers (e.g. int32, uint8), mapping them to stdint
        if name:match("^u?int%d+$") then return name .. "_t" end
        return name
    elseif t:ispointer() then
        local pt = t.type
        if pt:isprimitive() and tostring(pt) == "opaque" then return "void*" end
        if pt:isprimitive() and tostring(pt) == "int8" then return "char*" end -- treat &int8 as char*
        
        -- Anonymous function pointers (e.g. callbacks)
        if pt:isfunction() then
            local ret = pt.returntype:isunit() and "void" or terraTypeToC(pt.returntype)
            local params = {}
            for _, p in ipairs(pt.parameters) do table.insert(params, terraTypeToC(p)) end
            local pstr = #params > 0 and table.concat(params, ", ") or "void"
            return ret .. " (*)(" .. pstr .. ")"
        end
        return terraTypeToC(pt) .. "*"
    elseif t:isarray() then
        return terraTypeToC(t.type) .. "[" .. tostring(t.N) .. "]"
    elseif t:isstruct() then
        local sname = tostring(t)
        if not sname:match("^struct ") then sname = "struct " .. sname end
        return sname
    else
        return "void*" -- fallback
    end
end

-- Helper: Format a struct field (Handles nested arrays and function pointers)
local function formatField(name, t)
    if t:isarray() then
        local base = t
        local dims = {}
        while base:isarray() do
            table.insert(dims, base.N)
            base = base.type
        end
        local dim_str = ""
        for _, d in ipairs(dims) do dim_str = dim_str .. "[" .. d .. "]" end
        return "  " .. terraTypeToC(base) .. " " .. name .. dim_str .. ";"
    elseif t:ispointer() and t.type:isfunction() then
        local ftype = t.type
        local ret = ftype.returntype:isunit() and "void" or terraTypeToC(ftype.returntype)
        local params = {}
        for _, p in ipairs(ftype.parameters) do table.insert(params, terraTypeToC(p)) end
        local pstr = #params > 0 and table.concat(params, ", ") or "void"
        return "  " .. ret .. " (*" .. name .. ")(" .. pstr .. ");"
    end
    return "  " .. terraTypeToC(t) .. " " .. name .. ";"
end

local function isSafeLuaJitEnumValue(v)
    -- LuaJIT ffi.cdef reliably accepts enum constants in 32-bit signed range.
    return v >= -2147483648 and v <= 2147483647
end

-- Data structures to hold generated segments safely to prevent C dependency issues
local opaque_structs = {}
local struct_defs = {}
local struct_records = {}
local typedefs = {}
local functions = {}
local constants = {}

local seen_structs = {}

local function shouldSkipName(name)
    if not name then return true end
    if name:match("^__") then return true end
    if name:match("^anon%$") then return true end
    if name:match("^_Float") then return true end
    return false
end

local function canonicalStructName(t)
    local sname = tostring(t)
    if not sname:match("^struct ") then sname = "struct " .. sname end
    return sname
end

local function getRequiredStructDeps(t)
    -- Struct-by-value fields require complete definitions before use.
    while t:isarray() do
        t = t.type
    end
    if t:ispointer() then
        return nil
    end
    if t:isstruct() then
        return canonicalStructName(t)
    end
    return nil
end

local function formatTypedef(name, t)
    if t:ispointer() and t.type:isfunction() then
        local ftype = t.type
        local ret = ftype.returntype:isunit() and "void" or terraTypeToC(ftype.returntype)
        local params = {}
        for _, p in ipairs(ftype.parameters) do table.insert(params, terraTypeToC(p)) end
        local pstr = #params > 0 and table.concat(params, ", ") or "void"
        return string.format("typedef %s (*%s)(%s);", ret, name, pstr)
    end
    return string.format("typedef %s %s;", terraTypeToC(t), name)
end

-- 2. Inspect the returned Lua table of Terra objects
for k, v in pairs(C) do
    if not shouldSkipName(k) then
    local t = terralib.type(v)
    
    if t == "terratype" then
        local tname = tostring(v)
        
        if v:isstruct() then
            local sname = tname
            if not sname:match("^struct ") then sname = "struct " .. sname end
            local bare = sname:gsub("^struct ", "")
            if not shouldSkipName(bare) then
            
            -- Prevent duplicate generation of structs
            if not seen_structs[sname] then
                seen_structs[sname] = true
                -- Forward declaration handles circular dependencies natively
                table.insert(opaque_structs, sname .. ";")
                
                -- Don't force completion on incomplete/recursive forward-declared structs.
                local ok_complete = pcall(function() v:complete() end)
                if ok_complete then
                    table.insert(struct_records, { name = sname, entries = v.entries or {} })
                end
            end
            
            -- Identify typedefs representing structs
            if k ~= tname and k ~= tname:gsub("^struct ", "") then
                table.insert(typedefs, "typedef " .. sname .. " " .. k .. ";")
            end
            end
        else
            -- Identify primitive/pointer typedefs
            if k ~= tname then
                table.insert(typedefs, formatTypedef(k, v))
            end
        end
        
    elseif t == "terrafunction" then
        local ftype = v:gettype()
        local ret = ftype.returntype:isunit() and "void" or terraTypeToC(ftype.returntype)
        
        local params = {}
        for _, p in ipairs(ftype.parameters) do
            table.insert(params, terraTypeToC(p))
        end
        
        local pstr = #params > 0 and table.concat(params, ", ") or "void"
        table.insert(functions, string.format("%s %s(%s);", ret, k, pstr))
        
    elseif type(v) == "number" then
        -- Handle C macros (#define FOO 1) extracted by Clang as constants
        if math.floor(v) == v and isSafeLuaJitEnumValue(v) then
            table.insert(constants, string.format("enum { %s = %d };", k, v))
        elseif math.floor(v) ~= v then
            table.insert(constants, string.format("static const double %s = %f;", k, v))
        end
    end
    end
end

-- Topologically sort struct definitions so by-value struct members are defined first.
local emitted_structs = {}
local remaining = {}
for _, r in ipairs(struct_records) do remaining[#remaining + 1] = r end

local function emitStructDef(rec)
    local def = rec.name .. " {\n"
    for _, entry in ipairs(rec.entries) do
        -- Terra structures an anonymous union as a list of fields
        if terralib.islist(entry) or (#entry > 0 and type(entry[1]) == "table") then
            def = def .. "  union {\n"
            for _, u_entry in ipairs(entry) do
                local fname = u_entry.field or u_entry[1]
                local ftype = u_entry.type or u_entry[2]
                def = def .. "  " .. formatField(fname, ftype) .. "\n"
            end
            def = def .. "  };\n"
        else
            local fname = entry.field or entry[1]
            local ftype = entry.type or entry[2]
            def = def .. formatField(fname, ftype) .. "\n"
        end
    end
    def = def .. "};"
    struct_defs[#struct_defs + 1] = def
    emitted_structs[rec.name] = true
end

while #remaining > 0 do
    local progressed = false
    local i = 1
    while i <= #remaining do
        local rec = remaining[i]
        local blocked = false
        for _, entry in ipairs(rec.entries) do
            if terralib.islist(entry) or (#entry > 0 and type(entry[1]) == "table") then
                for _, u_entry in ipairs(entry) do
                    local dep = getRequiredStructDeps(u_entry.type or u_entry[2])
                    if dep ~= nil and dep ~= rec.name and not emitted_structs[dep] then
                        blocked = true
                        break
                    end
                end
            else
                local dep = getRequiredStructDeps(entry.type or entry[2])
                if dep ~= nil and dep ~= rec.name and not emitted_structs[dep] then
                    blocked = true
                end
            end
            if blocked then break end
        end
        if not blocked then
            emitStructDef(rec)
            table.remove(remaining, i)
            progressed = true
        else
            i = i + 1
        end
    end
    if not progressed then
        -- Cycles of by-value members are invalid C. Skip to preserve output validity.
        break
    end
end

-- 3. Assemble and print the LuaJIT ffi script
print("local ffi = require('ffi')\n")
print("ffi.cdef[[")

print("/* Forward Declarations */")
for _, s in ipairs(opaque_structs) do print(s) end

print("\n/* Typedefs */")
for _, t in ipairs(typedefs) do print(t) end

print("\n/* Struct Definitions */")
for _, s in ipairs(struct_defs) do print(s) end

print("\n/* Constants */")
for _, c in ipairs(constants) do print(c) end

print("\n/* Functions */")
for _, f in ipairs(functions) do print(f) end

print("]]\n")
