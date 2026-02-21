local ffi = require("ffi")
dofile("build/argile_bench_api.lua")

local clay = ffi.load("build/libclay_bench.so")
local argile = ffi.load("build/libargile_bench.so")

local profile = arg[1] or "heavy" -- quick | heavy | stress

local profile_cfg = {
    quick = { width = 1920, height = 1080, max_elements = 30000, arena_bytes = 256 * 1024 * 1024, scale = 0.35 },
    heavy = { width = 2560, height = 1440, max_elements = 50000, arena_bytes = 512 * 1024 * 1024, scale = 1.0 },
    stress = { width = 3840, height = 2160, max_elements = 80000, arena_bytes = 1024 * 1024 * 1024, scale = 1.8 },
}

local cfg = profile_cfg[profile]
if not cfg then
    error("unknown profile: " .. tostring(profile) .. " (use quick|heavy|stress)")
end

local function scaled(n)
    return math.max(1, math.floor(n * cfg.scale))
end

local scenarios = {
    { name = "Flat children", category = "Layout", fn = "bench_frame_fixed_children", args = { scaled(2500) }, iterations = scaled(120), warmup = scaled(16) },
    { name = "Flat children extreme", category = "Stress", fn = "bench_frame_fixed_children", args = { scaled(7000) }, iterations = scaled(40), warmup = scaled(8) },

    { name = "Nested tree 4x4", category = "Layout", fn = "bench_frame_nested", args = { 4, 4 }, iterations = scaled(140), warmup = scaled(12) },
    { name = "Nested tree 5x4", category = "Layout", fn = "bench_frame_nested", args = { 5, 4 }, iterations = scaled(90), warmup = scaled(10) },
    { name = "Nested tree 5x5", category = "Stress", fn = "bench_frame_nested", args = { 5, 5 }, iterations = scaled(36), warmup = scaled(6) },

    { name = "Text feed", category = "Text", fn = "bench_frame_text_rows", args = { scaled(3000) }, iterations = scaled(80), warmup = scaled(10) },
    { name = "Text feed extreme", category = "Stress", fn = "bench_frame_text_rows", args = { scaled(7000) }, iterations = scaled(28), warmup = scaled(5) },

    { name = "Dashboard mixed", category = "Realistic", fn = "bench_frame_dashboard", args = { scaled(24), scaled(36) }, iterations = scaled(80), warmup = scaled(8) },
    { name = "Dashboard dense", category = "Realistic", fn = "bench_frame_dashboard", args = { scaled(40), scaled(50) }, iterations = scaled(36), warmup = scaled(6) },

    { name = "Clip lists", category = "Realistic", fn = "bench_frame_clip_lists", args = { scaled(18), scaled(120) }, iterations = scaled(70), warmup = scaled(8) },
    { name = "Clip lists extreme", category = "Stress", fn = "bench_frame_clip_lists", args = { scaled(30), scaled(180) }, iterations = scaled(24), warmup = scaled(5) },

    { name = "Config churn mixed", category = "Stress", fn = "bench_frame_stress_mixed", args = { scaled(5000) }, iterations = scaled(40), warmup = scaled(8) },
}

local function run_lib(lib, scenario)
    local ok = tonumber(lib.bench_init(cfg.width, cfg.height, cfg.max_elements, cfg.arena_bytes))
    if ok ~= 1 then
        error("bench_init failed for " .. scenario.name)
    end

    for _ = 1, scenario.warmup do
        lib[scenario.fn](unpack(scenario.args))
    end

    local checksum = 0
    local t0 = os.clock()
    for _ = 1, scenario.iterations do
        checksum = checksum + tonumber(lib[scenario.fn](unpack(scenario.args)))
    end
    local dt = os.clock() - t0

    lib.bench_shutdown()

    return {
        total_s = dt,
        ms_per_frame = (dt * 1000.0) / scenario.iterations,
        fps = scenario.iterations / dt,
        checksum = checksum,
    }
end

local function fmt_args(args)
    local t = {}
    for i = 1, #args do t[i] = tostring(args[i]) end
    return table.concat(t, ",")
end

local function pad(s, w)
    s = tostring(s)
    if #s >= w then return s end
    return s .. string.rep(" ", w - #s)
end

local results = {}

print(("Clay vs Argile Benchmark Suite (%s profile)"):format(profile))
print(("Resolution=%dx%d max_elements=%d arena=%.1fMB"):format(cfg.width, cfg.height, cfg.max_elements, cfg.arena_bytes / 1024 / 1024))
print(("Scenarios=%d"):format(#scenarios))
io.stdout:flush()

for i, s in ipairs(scenarios) do
    print(("[%02d/%02d] %-20s (%s) fn=%s(%s)"):format(i, #scenarios, s.name, s.category, s.fn, fmt_args(s.args)))
    io.stdout:flush()

    local clay_r = run_lib(clay, s)
    local argile_r = run_lib(argile, s)

    local speedup = clay_r.total_s / argile_r.total_s
    local checksum_delta = argile_r.checksum - clay_r.checksum

    results[#results + 1] = {
        scenario = s.name,
        category = s.category,
        clay_ms = clay_r.ms_per_frame,
        argile_ms = argile_r.ms_per_frame,
        clay_fps = clay_r.fps,
        argile_fps = argile_r.fps,
        speedup = speedup,
        clay_checksum = clay_r.checksum,
        argile_checksum = argile_r.checksum,
        checksum_delta = checksum_delta,
    }
end

print("\nFinal Comparison Table")
local headers = {
    {"Scenario", 24},
    {"Category", 10},
    {"Clay ms/f", 10},
    {"Argile ms/f", 11},
    {"Clay FPS", 10},
    {"Argile FPS", 10},
    {"Speedup", 8},
    {"Clay Sum", 10},
    {"Argile Sum", 10},
}

local line = {}
for _, h in ipairs(headers) do line[#line + 1] = pad(h[1], h[2]) end
print(table.concat(line, " | "))
print(string.rep("-", 24 + 3 + 10 + 3 + 10 + 3 + 11 + 3 + 10 + 3 + 10 + 3 + 8 + 3 + 10 + 3 + 10))

local sum_speedup = 0
local prod_speedup = 1
local best = nil
local worst = nil

for _, r in ipairs(results) do
    local row = {
        pad(r.scenario, 24),
        pad(r.category, 10),
        pad(string.format("%.3f", r.clay_ms), 10),
        pad(string.format("%.3f", r.argile_ms), 11),
        pad(string.format("%.0f", r.clay_fps), 10),
        pad(string.format("%.0f", r.argile_fps), 10),
        pad(string.format("%.2fx", r.speedup), 8),
        pad(tostring(r.clay_checksum), 10),
        pad(tostring(r.argile_checksum), 10),
    }
    print(table.concat(row, " | "))

    sum_speedup = sum_speedup + r.speedup
    prod_speedup = prod_speedup * r.speedup
    if (not best) or r.speedup > best.speedup then best = r end
    if (not worst) or r.speedup < worst.speedup then worst = r end
end

local avg_speedup = sum_speedup / #results
local geo_speedup = prod_speedup ^ (1 / #results)

print("\nSummary")
print(("  Average speedup (arithmetic): %.2fx"):format(avg_speedup))
print(("  Average speedup (geometric):  %.2fx"):format(geo_speedup))
print(("  Best scenario:  %s (%.2fx)"):format(best.scenario, best.speedup))
print(("  Worst scenario: %s (%.2fx)"):format(worst.scenario, worst.speedup))
