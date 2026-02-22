--[[
    Source Span Utilities for V3
    
    Provides position tracking for AST nodes and formatted error messages.
]]

local P = {}

-- Span represents a source location
-- Minimal implementation: line number + context
-- Can be extended to include column, file, etc. if lexer provides them
function P.Span(line, context)
    return {
        line = line or 0,
        context = context or "",
    }
end

-- Create a span from Terra lexer
-- Terra's lexer doesn't expose column/file directly, so we use line + current token
function P.SpanFromLexer(lex)
    -- Terra lexer has line tracking internally
    -- Try to get line from lexer's internal state (may not be available)
    local line = 1
    
    -- Build context string from current token
    local context = ""
    if lex then
        local cur = lex:cur()
        if cur and cur.value then
            context = tostring(cur.value)
        end
    end
    
    return P.Span(line, context)
end

-- Format an error message with span information
function P.Error(span, message)
    if span and span.line and span.line > 0 then
        return string.format("argile v3 error at line %d%s: %s",
            span.line,
            span.context ~= "" and " (near '" .. span.context .. "')" or "",
            message)
    else
        return "argile v3 error: " .. message
    end
end

-- Raise an error with span
function P.Raise(span, message)
    error(P.Error(span, message), 0)
end

-- Merge two spans to create a combined span
-- Useful for composite AST nodes
function P.Merge(span1, span2)
    if not span1 then return span2 end
    if not span2 then return span1 end
    
    return P.Span(
        span1.line,  -- use first span's line as anchor
        span1.context ~= "" and span1.context or span2.context
    )
end

-- Span for synthetic nodes (no real source location)
function P.Synthetic()
    return P.Span(0, "")
end

return P
