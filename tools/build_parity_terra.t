-- Build Terra parity shared library and generate LuaJIT cdefs
-- from the final exported parity API table.

local api = require("tools.terra_parity_api")

local function sorted_keys(tbl)
    local keys = {}
    for k, _ in pairs(tbl) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    return keys
end

local function type_to_c(t)
    if t:isprimitive() then
        local n = tostring(t)
        if n == "int" or n == "int32" then return "int" end
        if n == "uint32" then return "unsigned int" end
        if n == "int64" then return "long long" end
        if n == "uint64" then return "unsigned long long" end
        if n == "int16" then return "short" end
        if n == "uint16" then return "unsigned short" end
        if n == "int8" then return "signed char" end
        if n == "uint8" then return "unsigned char" end
        if n == "float" then return "float" end
        if n == "double" then return "double" end
        if n == "bool" then return "bool" end
        if n == "opaque" then return "void" end
        return n
    elseif t:ispointer() then
        local base = t.type
        if base:isprimitive() then
            local bn = tostring(base)
            if bn == "opaque" then
                return "void*"
            end
            if bn == "int8" then
                return "char*"
            end
        end
        return type_to_c(base) .. "*"
    elseif t:isstruct() then
        local sname = tostring(t)
        if not sname:match("^struct ") then
            sname = "struct " .. sname
        end
        return sname
    end
    return "void*"
end

local function gen_cdef(exports)
    local out = {}
    out[#out + 1] = "local ffi = require('ffi')"
    out[#out + 1] = "ffi.cdef[["
    for _, name in ipairs(sorted_keys(exports)) do
        local fn = exports[name]
        local ftype = fn:gettype()
        local ret = ftype.returntype:isunit() and "void" or type_to_c(ftype.returntype)
        local params = {}
        for _, p in ipairs(ftype.parameters) do
            params[#params + 1] = type_to_c(p)
        end
        local pstr = (#params > 0) and table.concat(params, ", ") or "void"
        out[#out + 1] = string.format("%s %s(%s);", ret, name, pstr)
    end
    out[#out + 1] = "]]"
    out[#out + 1] = "return ffi"
    out[#out + 1] = ""
    return table.concat(out, "\n")
end

os.execute("mkdir -p build")

terralib.saveobj("build/libargile_parity.so", "sharedlibrary", api.exports, nil, nil, { fastmath = true })

local ffi_text = gen_cdef(api.exports)
local f = assert(io.open("build/argile_parity_api.lua", "w"))
f:write(ffi_text)
f:close()

print("built build/libargile_parity.so")
print("generated build/argile_parity_api.lua")
