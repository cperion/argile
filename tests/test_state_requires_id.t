local C = terralib.includecstring [[
#include <stdio.h>
#include <stdlib.h>
]]

local ui = require("src.builder")
local ds = require("src/style/default_theme")
import "src/lang.argile"

local failed = false

-- Test that hover state without id produces a compile-time error
local ok, err = pcall(function()
    -- This should fail because hover requires an id
    -- Element without id: el without parens
    local bad_hover = argile el
        layout
            width_fixed(80.0)
            height_fixed(40.0)
        end
        style
            bg(ds.colors.surface_600)
        end
        when hover
            style
                bg(ds.colors.primary_500)
            end
        end
    end
end)

if ok then
    C.printf("FAIL: expected error when hover used without element id\n")
    failed = true
else
    if string.find(err, "hover") and string.find(err, "id") then
        C.printf("PASS: correctly caught error for hover without id\n")
    else
        C.printf("FAIL: unexpected error message: %s\n", err)
        failed = true
    end
end

-- Test that hover state with non-string id produces a clear compile-time error
local ok2, err2 = pcall(function()
    local bad_hover_id_type = argile el(123)
        layout
            width_fixed(80.0)
            height_fixed(40.0)
        end
        style
            bg(ds.colors.surface_600)
        end
        when hover
            style
                bg(ds.colors.primary_500)
            end
        end
    end
end)

if ok2 then
    C.printf("FAIL: expected error when hover used with non-string id\n")
    failed = true
else
    if string.find(err2, "hover") and string.find(err2, "string id") then
        C.printf("PASS: correctly caught error for hover with non-string id\n")
    else
        C.printf("FAIL: unexpected non-string id error message: %s\n", err2)
        failed = true
    end
end

-- Test that 'when active' produces a clear "not yet implemented" error
local ok3, err3 = pcall(function()
    local bad_active = argile el("btn")
        layout
            width_fixed(80.0)
            height_fixed(40.0)
        end
        when active
            style
                bg(ds.colors.primary_700)
            end
        end
    end
end)

if ok3 then
    C.printf("FAIL: expected error when active used (not yet implemented)\n")
    failed = true
else
    if string.find(err3, "active") and string.find(err3, "not yet implemented") then
        C.printf("PASS: correctly caught error for active (not yet implemented)\n")
    else
        C.printf("FAIL: unexpected active error message: %s\n", err3)
        failed = true
    end
end

-- Test that 'when focus' produces a clear "not yet implemented" error
local ok4, err4 = pcall(function()
    local bad_focus = argile el("inp")
        layout
            width_fixed(120.0)
            height_fixed(32.0)
        end
        when focus
            style
                bg(ds.colors.surface_400)
            end
        end
    end
end)

if ok4 then
    C.printf("FAIL: expected error when focus used (not yet implemented)\n")
    failed = true
else
    if string.find(err4, "focus") and string.find(err4, "not yet implemented") then
        C.printf("PASS: correctly caught error for focus (not yet implemented)\n")
    else
        C.printf("FAIL: unexpected focus error message: %s\n", err4)
        failed = true
    end
end

-- Test that 'when disabled' produces a clear "not yet implemented" error
local okd, errd = pcall(function()
    local bad_disabled = argile el("row")
        layout
            width_fixed(120.0)
            height_fixed(32.0)
        end
        when disabled
            style
                bg(ds.colors.surface_400)
            end
        end
    end
end)

if okd then
    C.printf("FAIL: expected error when disabled used (not yet implemented)\n")
    failed = true
else
    if string.find(errd, "disabled") and string.find(errd, "not yet implemented") then
        C.printf("PASS: correctly caught error for disabled (not yet implemented)\n")
    else
        C.printf("FAIL: unexpected disabled error message: %s\n", errd)
        failed = true
    end
end

-- Test that 'when selected' produces a clear "not yet implemented" error
local oks, errs = pcall(function()
    local bad_selected = argile el("item")
        layout
            width_fixed(120.0)
            height_fixed(32.0)
        end
        when selected
            style
                bg(ds.colors.surface_400)
            end
        end
    end
end)

if oks then
    C.printf("FAIL: expected error when selected used (not yet implemented)\n")
    failed = true
else
    if string.find(errs, "selected") and string.find(errs, "not yet implemented") then
        C.printf("PASS: correctly caught error for selected (not yet implemented)\n")
    else
        C.printf("FAIL: unexpected selected error message: %s\n", errs)
        failed = true
    end
end

-- Test that 'when hover' with typography produces a clear "not yet implemented" error
local ok5, err5 = pcall(function()
    -- Using raw table API to bypass argile syntax limitations
    ui.compile({id = "txt", text = "Label", states = {hover = {textConfig = {fontSize = 18}}}})
end)

if ok5 then
    C.printf("FAIL: expected error when hover used with typography (not yet implemented)\n")
    failed = true
else
    if string.find(err5, "hover") and string.find(err5, "typography") and string.find(err5, "not yet implemented") then
        C.printf("PASS: correctly caught error for hover + typography (not yet implemented)\n")
    else
        C.printf("FAIL: unexpected hover typography error message: %s\n", err5)
        failed = true
    end
end

if failed then
    os.exit(1)
end

os.exit(0)
