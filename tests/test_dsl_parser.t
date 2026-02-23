--[[
    DSL Parser Tests
    
    Test parsing of DSL declarations and invocations.
]]

local C = terralib.includecstring[[
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
]]

local AST = require("src/lang/argile_ast")

-- Test AST construction
print("Testing AST construction...")

-- Test NodeDecl
local node = AST.NodeDecl("el", AST.Symbol("test_span", nil))
assert(node._kind == "NodeDecl", "NodeDecl kind mismatch")
assert(node.kind == "el", "NodeDecl kind field mismatch")
print("  NodeDecl: PASS")

-- Test ComponentDecl
local root = AST.NodeDecl("el", nil)
root.id_expr = function() return "btn_root" end
local comp = AST.ComponentDecl("button", {"label", "tone"}, {}, root, nil)
assert(comp._kind == "ComponentDecl", "ComponentDecl kind mismatch")
assert(comp.name == "button", "ComponentDecl name mismatch")
assert(#comp.params == 2, "ComponentDecl params count mismatch")
print("  ComponentDecl: PASS")

-- Test ComponentInvoke
local invoke = AST.ComponentInvoke("button", {label = function() return "Save" end}, nil)
assert(invoke._kind == "ComponentInvoke", "ComponentInvoke kind mismatch")
assert(invoke.name == "button", "ComponentInvoke name mismatch")
print("  ComponentInvoke: PASS")

-- Test Symbol
local sym = AST.Symbol("primary", nil)
assert(sym._kind == "Symbol", "Symbol kind mismatch")
assert(sym.name == "primary", "Symbol name mismatch")
print("  Symbol: PASS")

print("\nAST construction tests: ALL PASS")

-- Test AST debug printing
print("\nTesting AST debug printing...")
local debug_str = AST.Debug(comp)
assert(debug_str:find("ComponentDecl"), "Debug should contain ComponentDecl")
assert(debug_str:find("button"), "Debug should contain component name")
print("  Debug output: PASS")

-- Test Span utilities
local Span = require("src/lang/argile_span")
print("\nTesting Span utilities...")

local span = Span.Span(10, "test_context")
assert(span.line == 10, "Span line mismatch")
assert(span.context == "test_context", "Span context mismatch")
print("  Span construction: PASS")

local merged = Span.Merge(span, Span.Span(20, "other"))
assert(merged.line == 10, "Merged span should use first line")
print("  Span merge: PASS")

local err = Span.Error(span, "test error")
assert(err:find("line 10"), "Error should include line number")
assert(err:find("test error"), "Error should include message")
print("  Error formatting: PASS")

print("\nSpan tests: ALL PASS")

-- Summary
print("\n" .. string.rep("=", 50))
print("DSL Parser Foundation Tests")
print("Status: ALL PASS")
print(string.rep("=", 50))
