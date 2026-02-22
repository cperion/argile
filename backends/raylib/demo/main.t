-- JIT runner for the raylib demo.
-- Useful for parse/typecheck/debug, but may crash on some Linux setups because
-- raylib/GLX/Mesa loads LLVM into the same process as the Terra JIT.
-- Prefer the AOT executable path (`backends/raylib/build.t` / `make raylib-demo`).

local app = require("backends.raylib.demo.app")

if os.getenv("ARGILE_RAYLIB_DEMO_NO_RUN") == "1" then
    print("raylib demo parsed/loaded (run skipped by ARGILE_RAYLIB_DEMO_NO_RUN=1)")
else
    app.run_demo()
end
