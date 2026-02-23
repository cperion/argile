local Ast = require("src/capi_dsl_ast")
local Compile = require("src/capi_dsl_compile")

local M = {}

for k, v in pairs(Ast) do
    if M[k] ~= nil then
        error("argile: duplicate host AST API symbol '" .. tostring(k) .. "'")
    end
    M[k] = v
end

for k, v in pairs(Compile) do
    if M[k] ~= nil then
        error("argile: duplicate host AST compile API symbol '" .. tostring(k) .. "'")
    end
    M[k] = v
end

return M
