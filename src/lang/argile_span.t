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
-- Terra's lexer exposes linenumber via the cur() token
function P.SpanFromLexer(lex)
    local line = 1
    
    -- Build context string from current token
    local context = ""
    if lex then
        local cur = lex:cur()
        if cur then
            -- Extract line number from Terra token (Section 22.3)
            line = cur.linenumber or 1
            if cur.value then
                context = tostring(cur.value)
            end
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
