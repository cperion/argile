local C = terralib.includecstring [[
#include <stdio.h>
#include <stdlib.h>
]]

local ui = require("src.builder")
local ds = require("src/style/default_theme")
import "src/lang.argile"

-- Test that hover state without id produces a compile-time error
local caught_error = false
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
    os.exit(1)
else
    if string.find(err, "hover") and string.find(err, "id") then
        C.printf("PASS: correctly caught error for hover without id\n")
        os.exit(0)
    else
        C.printf("FAIL: unexpected error message: %s\n", err)
        os.exit(1)
    end
end
