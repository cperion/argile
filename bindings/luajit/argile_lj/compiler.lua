local M = {}

local HOST_SYMBOLS = {
    "CapiDslAstHostCreateCompilerContext",
    "CapiDslAstHostDestroyCompilerContext",
    "CapiDslAstHostCreateCallbackBackend",
    "CapiDslAstHostCallbackSetRenderRoute",
    "CapiDslAstHostCallbackGetFetchRenderFunctionPointerCallback",
}

local function has_symbol(lib, name)
    return pcall(function() return lib[name] end)
end

function M.detect(lib)
    local out = {
        host_compiler_exports = false,
        host_callback_backend_exports = false,
        missing = {},
        found = {},
    }
    for _, name in ipairs(HOST_SYMBOLS) do
        local ok = has_symbol(lib, name)
        if ok then
            out.found[#out.found + 1] = name
        else
            out.missing[#out.missing + 1] = name
        end
    end
    out.host_compiler_exports = has_symbol(lib, "CapiDslAstHostCreateCompilerContext")
    out.host_callback_backend_exports = has_symbol(lib, "CapiDslAstHostCreateCallbackBackend")
    return out
end

function M.assert_host_exports(lib)
    local caps = M.detect(lib)
    if not caps.host_compiler_exports then
        error("host AST/compiler exports are not present in this libargile.so (ui.capi runtime-only build)")
    end
    return caps
end

return M
