--[[
    Source Span Utilities for DSL
    
    Provides position tracking for AST nodes and formatted error messages.
]]

local P = {}

-- Span represents a source location.
-- Backward-compatible call forms:
--   Span(line, context)
--   Span({ file=..., line=..., column=..., line_end=..., column_end=..., context=..., tag=... })
function P.Span(line_or_meta, context)
    if type(line_or_meta) == "table" then
        local meta = line_or_meta
        return {
            file = meta.file,
            line = meta.line or 0,
            column = meta.column or 0,
            line_end = meta.line_end or meta.line or 0,
            column_end = meta.column_end or meta.column or 0,
            context = meta.context or "",
            tag = meta.tag,
        }
    end
    return {
        file = nil,
        line = line_or_meta or 0,
        column = 0,
        line_end = line_or_meta or 0,
        column_end = 0,
        context = context or "",
        tag = nil,
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
        local loc
        if span.file and span.file ~= "" then
            if span.column and span.column > 0 then
                loc = string.format("%s:%d:%d", tostring(span.file), span.line, span.column)
            else
                loc = string.format("%s:%d", tostring(span.file), span.line)
            end
        elseif span.column and span.column > 0 then
            loc = string.format("line %d:%d", span.line, span.column)
        else
            loc = string.format("line %d", span.line)
        end

        return string.format("argile error at %s%s: %s",
            loc,
            (span.context ~= nil and span.context ~= "") and " (near '" .. span.context .. "')" or "",
            message)
    else
        return "argile error: " .. message
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
    
    return P.Span({
        file = span1.file or span2.file,
        line = span1.line,  -- use first span's line as anchor
        column = span1.column or 0,
        line_end = span2.line_end or span2.line or span1.line_end or span1.line,
        column_end = span2.column_end or span2.column or span1.column_end or span1.column or 0,
        context = (span1.context ~= nil and span1.context ~= "") and span1.context or span2.context,
        tag = span1.tag or span2.tag,
    })
end

-- Span for synthetic nodes (no real source location)
function P.Synthetic()
    return P.Span(0, "")
end

function P.WithFields(span, fields)
    local s = P.Span(span or {})
    if type(fields) ~= "table" then
        return s
    end
    for k, v in pairs(fields) do
        s[k] = v
    end
    return s
end

return P
