local DslCompiler = require("src/dsl_compiler")
local AstApi = require("src/capi_dsl_ast")

local M = {}

local ERR_NONE = 0
local ERR_BUILDER = 1
local ERR_COMPILER = 2

local function clear_last_compile_error(builder)
    if type(builder) == "table" then
        builder._last_compile_error = nil
    end
end

local function set_last_compile_error(builder, code, message)
    if type(builder) == "table" then
        builder._last_compile_error = {
            code = code or ERR_COMPILER,
            message = tostring(message or ""),
        }
    end
end

local function try_compile(builder, program_h, compiler_fn)
    clear_last_compile_error(builder)

    local ok_program, program_or_err = pcall(AstApi.CapiDslAstGetProgramAst, builder, program_h)
    if not ok_program then
        set_last_compile_error(builder, ERR_BUILDER, program_or_err)
        return false, nil, program_or_err
    end

    local ok_compile, result_or_err = pcall(compiler_fn, program_or_err)
    if not ok_compile then
        set_last_compile_error(builder, ERR_COMPILER, result_or_err)
        return false, nil, result_or_err
    end

    return true, result_or_err, nil
end

function M.CapiDslAstClearLastCompileError(builder)
    clear_last_compile_error(builder)
    return true
end

function M.CapiDslAstGetLastCompileError(builder)
    local err = type(builder) == "table" and builder._last_compile_error or nil
    if err == nil then
        return { code = ERR_NONE, message = "" }
    end
    return { code = err.code or ERR_COMPILER, message = err.message or "" }
end

function M.CapiDslAstCompileProgramQuote(builder, program_h, env_fn, registry)
    local ok, result, err = try_compile(builder, program_h, function(program)
        return DslCompiler.compileAstProgram(program, env_fn, registry)
    end)
    if not ok then error(err) end
    return result
end

function M.CapiDslAstCompileProgramFunction(builder, name, program_h, env_fn, registry)
    local ok, result, err = try_compile(builder, program_h, function(program)
        return DslCompiler.compileAstProgramFunction(name, program, env_fn, registry)
    end)
    if not ok then error(err) end
    return result
end

function M.CapiDslAstCompileProgramRenderFunction(builder, name, program_h, env_fn, registry)
    local ok, result, err = try_compile(builder, program_h, function(program)
        return DslCompiler.compileAstProgramRenderFunction(name, program, env_fn, registry)
    end)
    if not ok then error(err) end
    return result
end

function M.CapiDslAstTryCompileProgramQuote(builder, program_h, env_fn, registry)
    return try_compile(builder, program_h, function(program)
        return DslCompiler.compileAstProgram(program, env_fn, registry)
    end)
end

function M.CapiDslAstTryCompileProgramFunction(builder, name, program_h, env_fn, registry)
    return try_compile(builder, program_h, function(program)
        return DslCompiler.compileAstProgramFunction(name, program, env_fn, registry)
    end)
end

function M.CapiDslAstTryCompileProgramRenderFunction(builder, name, program_h, env_fn, registry)
    return try_compile(builder, program_h, function(program)
        return DslCompiler.compileAstProgramRenderFunction(name, program, env_fn, registry)
    end)
end

return M
