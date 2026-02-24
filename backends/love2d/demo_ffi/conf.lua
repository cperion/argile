-- Love2D configuration for Argile FFI Authoring Demo
-- This demo proves non-Terra users can author UIs with Argile through FFI

function love.conf(t)
    t.title = "Argile + Love2D (LuaJIT FFI Authoring Demo)"
    t.version = "11.5"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.vsync = 1
    
    t.console = true
    t.accelerometerjoystick = false
    t.externalstorage = false
    t.gammacorrect = false
end
