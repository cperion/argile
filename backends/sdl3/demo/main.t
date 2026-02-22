-- JIT runner for the SDL3 demo.
-- Uses Terra FFI module (not pure Terra C interop like raylib).

local app = require("backends.sdl3.demo.app")

if os.getenv("ARGILE_SDL3_DEMO_NO_RUN") == "1" then
    print("SDL3 demo parsed/loaded (run skipped by ARGILE_SDL3_DEMO_NO_RUN=1)")
else
    app.run_demo()
end
