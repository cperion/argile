import "src/lang.argile_v3"

component test_label(props)
    root
        id(props.id)
        text(props.content)
            part(content)
        end
    end
end

local scene = argile
    el id("parent") layout width_grow() height_grow() end
        test_label(id = "lbl", content = "Hello")
        end
    end
end

local str = tostring(scene)
local opens = 0
local closes = 0
for line in str:gmatch("[^\n]+") do
    if line:match("OpenElement") and not line:match("SetOpenElement") then
        opens = opens + 1
        print("OPEN: " .. line:sub(1, 80))
    end
    if line:match("CloseElement") then
        closes = closes + 1
        print("CLOSE: " .. line:sub(1, 80))
    end
end
print("---")
print("Opens: " .. opens .. ", Closes: " .. closes)
print("Balanced: " .. tostring(opens == closes))
