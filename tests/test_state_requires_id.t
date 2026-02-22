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

if failed then
    os.exit(1)
end

os.exit(0)
