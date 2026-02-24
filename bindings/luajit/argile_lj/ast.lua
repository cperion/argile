local M = {}

local function ensure_t_path()
    local p = package.path or ""
    if not p:find("%?%.t", 1, true) then
        package.path = "./?.t;" .. p
    end
end

ensure_t_path()

local AST = require("src/lang/ast")

M.AST = AST

local function walk(node, fn, path)
    path = path or {}
    if type(node) ~= "table" then return end
    if node._kind then
        fn(node, path)
    end
    for k, v in pairs(node) do
        if k ~= "_span" and k ~= "_kind" then
            if type(v) == "table" then
                if v._kind then
                    local p2 = { unpack(path) }
                    p2[#p2 + 1] = k
                    walk(v, fn, p2)
                else
                    for i, item in pairs(v) do
                        if type(item) == "table" and item._kind then
                            local p2 = { unpack(path) }
                            p2[#p2 + 1] = string.format("%s[%s]", tostring(k), tostring(i))
                            walk(item, fn, p2)
                        end
                    end
                end
            end
        end
    end
end

M.walk = walk

function M.validate_portable(program)
    local errors = {}
    walk(program, function(node, path)
        if node._kind == "LuaExpr" then
            errors[#errors + 1] = table.concat(path, ".") .. ": LuaExpr is host-only"
        elseif node._kind == "Splice" then
            errors[#errors + 1] = table.concat(path, ".") .. ": Splice is host-only"
        end
    end)
    return #errors == 0, errors
end

function M.debug(node)
    return AST.Debug(node)
end

return setmetatable(M, {
    __index = function(_, k)
        return AST[k]
    end
})
