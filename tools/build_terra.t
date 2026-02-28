-- Build Terra benchmark shared library and generate LuaJIT cdefs from exported API.

local api = require("tools.terra_bench_api")

local function type_to_c(t)
    if t:isprimitive() then
        local n = tostring(t)
        if n == "int" or n == "int32" then return "int" end
        if n == "uint32" then return "unsigned int" end
        if n == "bool" then return "bool" end
        if n == "float" then return "float" end
        if n == "double" then return "double" end
        if n == "int64" then return "long long" end
        if n == "uint64" then return "unsigned long long" end
        if n == "int8" then return "signed char" end
        if n == "uint8" then return "unsigned char" end
        if n == "opaque" then return "void" end
        return n
    elseif t:ispointer() then
        local base = t.type
        if base:isprimitive() and tostring(base) == "opaque" then
            return "void*"
        end
        return type_to_c(base) .. "*"
    elseif t:isstruct() then
        local sname = tostring(t)
        if not sname:match("^struct ") then sname = "struct " .. sname end
        return sname
    end
    return "void*"
end

local function gen_cdef(function_table)
    local out = {}
    table.insert(out, "local ffi = require('ffi')")
    table.insert(out, "ffi.cdef[[")
    for name, fn in pairs(function_table) do
        local ftype = fn:gettype()
        local ret = ftype.returntype:isunit() and "void" or type_to_c(ftype.returntype)
        local params = {}
        for _, p in ipairs(ftype.parameters) do
            table.insert(params, type_to_c(p))
        end
        local pstr = (#params > 0) and table.concat(params, ", ") or "void"
        table.insert(out, string.format("%s %s(%s);", ret, name, pstr))
    end
    table.insert(out, "]]\n")
    table.insert(out, "return ffi")
    return table.concat(out, "\n")
end

os.execute("mkdir -p build")

terralib.saveobj("build/libargile_bench.so", "sharedlibrary", api.exports)

local ffi_text = gen_cdef(api.exports)
local f = assert(io.open("build/argile_bench_api.lua", "w"))
f:write(ffi_text)
f:close()

print("built build/libargile_bench.so")
print("generated build/argile_bench_api.lua")
