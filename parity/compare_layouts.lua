local ffi = require("ffi")
dofile("build/argile_parity_api.lua")

local clay = ffi.load("build/libclay_parity.so")
local argile = ffi.load("build/libargile_parity.so")

local profile = arg[1] or "heavy" -- quick | heavy | stress

local profile_cfg = {
    quick = {
        width = 1600,
        height = 900,
        max_elements = 40000,
        arena_bytes = 384 * 1024 * 1024,
        repeats = 1,
        warmup = 1,
        abs_tol = 1.0,
        rel_tol = 0.001,
        min_within_ratio = 0.995,
        max_component_err = 3.0,
    },
    heavy = {
        width = 2560,
        height = 1440,
        max_elements = 70000,
        arena_bytes = 768 * 1024 * 1024,
        repeats = 2,
        warmup = 1,
        abs_tol = 0.75,
        rel_tol = 0.001,
        min_within_ratio = 0.997,
        max_component_err = 2.5,
    },
    stress = {
        width = 3840,
        height = 2160,
        max_elements = 120000,
        arena_bytes = 1536 * 1024 * 1024,
        repeats = 3,
        warmup = 1,
        abs_tol = 0.85,
        rel_tol = 0.0015,
        min_within_ratio = 0.995,
        max_component_err = 4.0,
    },
}

local cfg = profile_cfg[profile]
if not cfg then
    error("unknown profile: " .. tostring(profile) .. " (use quick|heavy|stress)")
end

local scenario_category = {
    fixed_grid = "Layout",
    nested_fit = "Layout",
    percent_and_grow = "Layout",
    text_flow_fit = "Text",
    clip_lists = "Realistic",
    aspect_sweep = "Aspect",
    mixed_stress = "Stress",
    floating_matrix = "Floating",
    zindex_overlap = "Floating",
    nested_clip_offsets = "Scroll",
    text_wrap_matrix = "Text",
    sizing_edge_cases = "Sizing",
    border_between_children = "Border",
    relayout_state = "State",
    seeded_fuzz = "Fuzz",
}

local function pad(s, w)
    s = tostring(s)
    if #s >= w then return s end
    return s .. string.rep(" ", w - #s)
end

local function fmt_err(v)
    if v ~= v then
        return "nan"
    end
    if v == math.huge or v == -math.huge then
        return "inf"
    end
    local av = math.abs(v)
    if av >= 100000 then
        return string.format("%.2e", v)
    end
    return string.format("%.3f", v)
end

local function load_scenario_names(lib)
    local count = tonumber(lib.parity_scenario_count())
    local names = {}
    for i = 0, count - 1 do
        names[#names + 1] = ffi.string(lib.parity_scenario_name(i))
    end
    return names
end

local function init_lib(lib, name)
    local ok = tonumber(lib.parity_init(cfg.width, cfg.height, cfg.max_elements, cfg.arena_bytes))
    if ok ~= 1 then
        error(name .. ": parity_init failed")
    end
end

local function shutdown_lib(lib)
    local _ = lib.parity_shutdown()
end

local function reset_lib(lib, name)
    shutdown_lib(lib)
    init_lib(lib, name)
end

local function run_scenario_timed(lib, idx)
    local probes = -1
    for _ = 1, cfg.warmup do
        probes = tonumber(lib.parity_run_scenario(idx))
        if probes < 0 then
            return nil, "parity_run_scenario failed during warmup"
        end
    end

    local total = 0.0
    for _ = 1, cfg.repeats do
        local t0 = os.clock()
        probes = tonumber(lib.parity_run_scenario(idx))
        local dt = os.clock() - t0
        if probes < 0 then
            return nil, "parity_run_scenario failed"
        end
        total = total + dt
    end

    return {
        probes = probes,
        avg_ms = (total / cfg.repeats) * 1000.0,
    }
end

local function run_scenario_once(lib, idx, name)
    local probes = tonumber(lib.parity_run_scenario(idx))
    if probes == nil or probes < 0 then
        error(name .. ": parity_run_scenario failed for snapshot")
    end
    return probes
end

local function collect_probe_snapshot(lib)
    local count = tonumber(lib.parity_probe_count())
    local map = {}
    local duplicates = 0
    local missing_boxes = 0

    local x = ffi.new("float[1]")
    local y = ffi.new("float[1]")
    local w = ffi.new("float[1]")
    local h = ffi.new("float[1]")

    for i = 0, count - 1 do
        local id = tonumber(lib.parity_probe_id(i))
        local ok = tonumber(lib.parity_probe_box(i, x, y, w, h))
        if ok == 1 then
            if map[id] ~= nil then
                duplicates = duplicates + 1
            end
            map[id] = {
                x = tonumber(x[0]),
                y = tonumber(y[0]),
                w = tonumber(w[0]),
                h = tonumber(h[0]),
            }
        else
            missing_boxes = missing_boxes + 1
        end
    end

    local unique_count = 0
    for _ in pairs(map) do
        unique_count = unique_count + 1
    end

    return {
        reported = count,
        unique = unique_count,
        duplicates = duplicates,
        missing_boxes = missing_boxes,
        boxes = map,
    }
end

local function within_tol(a, b)
    local diff = math.abs(a - b)
    local lim = cfg.abs_tol + cfg.rel_tol * math.max(math.abs(a), math.abs(b), 1.0)
    return diff <= lim, diff
end

local function percentile(sorted_vals, p)
    local n = #sorted_vals
    if n == 0 then return 0.0 end
    local idx = math.floor((n - 1) * p + 1)
    if idx < 1 then idx = 1 end
    if idx > n then idx = n end
    return sorted_vals[idx]
end

local function compare_snapshots(clay_s, argile_s)
    local within = 0
    local common = 0
    local missing_in_argile = 0
    local extra_in_argile = 0

    local mean_component_err_sum = 0.0
    local max_component_err = 0.0
    local dmax_values = {}

    local bad_samples = {}
    local missing_samples = {}
    local extra_samples = {}

    for id, cb in pairs(clay_s.boxes) do
        local ab = argile_s.boxes[id]
        if ab == nil then
            missing_in_argile = missing_in_argile + 1
            if #missing_samples < 5 then
                missing_samples[#missing_samples + 1] = id
            end
        else
            common = common + 1
            local okx, dx = within_tol(cb.x, ab.x)
            local oky, dy = within_tol(cb.y, ab.y)
            local okw, dw = within_tol(cb.w, ab.w)
            local okh, dh = within_tol(cb.h, ab.h)

            local dmax = math.max(dx, dy, dw, dh)
            dmax_values[#dmax_values + 1] = dmax
            mean_component_err_sum = mean_component_err_sum + (dx + dy + dw + dh) * 0.25
            if dmax > max_component_err then
                max_component_err = dmax
            end

            if okx and oky and okw and okh then
                within = within + 1
            elseif #bad_samples < 5 then
                bad_samples[#bad_samples + 1] = {
                    id = id,
                    clay = cb,
                    argile = ab,
                    dx = dx,
                    dy = dy,
                    dw = dw,
                    dh = dh,
                    dmax = dmax,
                }
            end
        end
    end

    for id, _ in pairs(argile_s.boxes) do
        if clay_s.boxes[id] == nil then
            extra_in_argile = extra_in_argile + 1
            if #extra_samples < 5 then
                extra_samples[#extra_samples + 1] = id
            end
        end
    end

    table.sort(dmax_values)

    local within_ratio = 0.0
    local mean_component_err = 0.0
    if common > 0 then
        within_ratio = within / common
        mean_component_err = mean_component_err_sum / common
    end

    local p95 = percentile(dmax_values, 0.95)
    local p99 = percentile(dmax_values, 0.99)

    local pass = true
    if missing_in_argile > 0 then pass = false end
    if extra_in_argile > 0 then pass = false end
    if clay_s.duplicates > 0 or argile_s.duplicates > 0 then pass = false end
    if clay_s.missing_boxes > 0 or argile_s.missing_boxes > 0 then pass = false end
    if within_ratio < cfg.min_within_ratio then pass = false end
    if max_component_err > cfg.max_component_err then pass = false end

    return {
        pass = pass,
        clay_reported = clay_s.reported,
        argile_reported = argile_s.reported,
        clay_unique = clay_s.unique,
        argile_unique = argile_s.unique,
        clay_duplicates = clay_s.duplicates,
        argile_duplicates = argile_s.duplicates,
        clay_missing_boxes = clay_s.missing_boxes,
        argile_missing_boxes = argile_s.missing_boxes,
        common = common,
        within = within,
        within_ratio = within_ratio,
        mean_component_err = mean_component_err,
        max_component_err = max_component_err,
        p95 = p95,
        p99 = p99,
        missing_in_argile = missing_in_argile,
        extra_in_argile = extra_in_argile,
        bad_samples = bad_samples,
        missing_samples = missing_samples,
        extra_samples = extra_samples,
    }
end

print(("Argile vs Clay Layout Parity (%s profile)"):format(profile))
print(("Resolution=%dx%d max_elements=%d arena=%.1fMB repeats=%d abs_tol=%.3f rel_tol=%.5f"):format(
    cfg.width,
    cfg.height,
    cfg.max_elements,
    cfg.arena_bytes / 1024 / 1024,
    cfg.repeats,
    cfg.abs_tol,
    cfg.rel_tol
))

init_lib(clay, "clay")
init_lib(argile, "argile")

local clay_names = load_scenario_names(clay)
local argile_names = load_scenario_names(argile)

if #clay_names ~= #argile_names then
    shutdown_lib(argile)
    shutdown_lib(clay)
    error(("scenario count mismatch clay=%d argile=%d"):format(#clay_names, #argile_names))
end

for i = 1, #clay_names do
    if clay_names[i] ~= argile_names[i] then
        shutdown_lib(argile)
        shutdown_lib(clay)
        error(("scenario name mismatch index=%d clay=%s argile=%s"):format(i - 1, clay_names[i], argile_names[i]))
    end
end

local results = {}
for i = 0, #clay_names - 1 do
    local scenario = clay_names[i + 1]
    local category = scenario_category[scenario] or "Other"
    print(("[%02d/%02d] %-18s (%s)"):format(i + 1, #clay_names, scenario, category))

    reset_lib(clay, "clay")
    local clay_run, clay_err = run_scenario_timed(clay, i)
    if not clay_run then
        shutdown_lib(argile)
        shutdown_lib(clay)
        error("clay: " .. clay_err)
    end
    reset_lib(clay, "clay")
    run_scenario_once(clay, i, "clay")
    local clay_snapshot = collect_probe_snapshot(clay)

    reset_lib(argile, "argile")
    local argile_run, argile_err = run_scenario_timed(argile, i)
    if not argile_run then
        shutdown_lib(argile)
        shutdown_lib(clay)
        error("argile: " .. argile_err)
    end
    reset_lib(argile, "argile")
    run_scenario_once(argile, i, "argile")
    local argile_snapshot = collect_probe_snapshot(argile)
    local cmp = compare_snapshots(clay_snapshot, argile_snapshot)

    results[#results + 1] = {
        scenario = scenario,
        category = category,
        clay_ms = clay_run.avg_ms,
        argile_ms = argile_run.avg_ms,
        speedup = clay_run.avg_ms / math.max(argile_run.avg_ms, 1e-9),
        cmp = cmp,
    }
end

shutdown_lib(argile)
shutdown_lib(clay)

local headers = {
    {"Scenario", 18},
    {"Category", 9},
    {"Clay", 6},
    {"Argile", 6},
    {"Common", 7},
    {"Match%", 7},
    {"MaxErr", 10},
    {"P95", 10},
    {"MissA", 6},
    {"ExtraA", 6},
    {"Clayms", 8},
    {"Argms", 8},
    {"Speed", 7},
    {"Status", 6},
}

print("\nFinal Comparison Table")
local header_cells = {}
for _, h in ipairs(headers) do
    header_cells[#header_cells + 1] = pad(h[1], h[2])
end
print(table.concat(header_cells, " | "))

local line_width = 0
for _, h in ipairs(headers) do
    line_width = line_width + h[2]
end
line_width = line_width + (#headers - 1) * 3
print(string.rep("-", line_width))

local total_common = 0
local total_within = 0
local failed = {}
local worst_ratio = nil
local worst_error = nil

for _, r in ipairs(results) do
    local c = r.cmp
    total_common = total_common + c.common
    total_within = total_within + c.within

    if (not worst_ratio) or (c.within_ratio < worst_ratio.cmp.within_ratio) then
        worst_ratio = r
    end
    if (not worst_error) or (c.max_component_err > worst_error.cmp.max_component_err) then
        worst_error = r
    end

    if not c.pass then
        failed[#failed + 1] = r
    end

    local row = {
        pad(r.scenario, 18),
        pad(r.category, 9),
        pad(c.clay_unique, 6),
        pad(c.argile_unique, 6),
        pad(c.common, 7),
        pad(string.format("%.2f", c.within_ratio * 100.0), 7),
        pad(fmt_err(c.max_component_err), 10),
        pad(fmt_err(c.p95), 10),
        pad(c.missing_in_argile, 6),
        pad(c.extra_in_argile, 6),
        pad(string.format("%.3f", r.clay_ms), 8),
        pad(string.format("%.3f", r.argile_ms), 8),
        pad(string.format("%.2fx", r.speedup), 7),
        pad(c.pass and "PASS" or "FAIL", 6),
    }
    print(table.concat(row, " | "))
end

local weighted_ratio = 0.0
if total_common > 0 then
    weighted_ratio = total_within / total_common
end

print("\nSummary")
print(("  Scenarios: %d total, %d pass, %d fail"):format(#results, #results - #failed, #failed))
print(("  Weighted match ratio: %.4f%% (%d/%d)"):format(weighted_ratio * 100.0, total_within, total_common))
print(("  Worst ratio scenario: %s (%.4f%%)"):format(worst_ratio.scenario, worst_ratio.cmp.within_ratio * 100.0))
print(("  Worst max error scenario: %s (%s px)"):format(worst_error.scenario, fmt_err(worst_error.cmp.max_component_err)))
print(("  Thresholds: min_match=%.4f%% max_component_err=%.3f"):format(cfg.min_within_ratio * 100.0, cfg.max_component_err))

if #failed > 0 then
    print("\nFailure Diagnostics")
    for _, r in ipairs(failed) do
        local c = r.cmp
        print(("- %s: match=%.4f%% max_err=%s missA=%d extraA=%d clayDup=%d argDup=%d clayMissingBox=%d argMissingBox=%d"):format(
            r.scenario,
            c.within_ratio * 100.0,
            fmt_err(c.max_component_err),
            c.missing_in_argile,
            c.extra_in_argile,
            c.clay_duplicates,
            c.argile_duplicates,
            c.clay_missing_boxes,
            c.argile_missing_boxes
        ))

        if #c.missing_samples > 0 then
            print("  missing_in_argile sample ids: " .. table.concat(c.missing_samples, ", "))
        end
        if #c.extra_samples > 0 then
            print("  extra_in_argile sample ids: " .. table.concat(c.extra_samples, ", "))
        end

        if #c.bad_samples > 0 then
            print("  worst mismatch samples:")
            table.sort(c.bad_samples, function(a, b) return a.dmax > b.dmax end)
            for _, s in ipairs(c.bad_samples) do
                print(("    id=%u dmax=%s dx=%s dy=%s dw=%s dh=%s clay=(%.2f,%.2f,%.2f,%.2f) argile=(%.2f,%.2f,%.2f,%.2f)"):format(
                    s.id,
                    fmt_err(s.dmax),
                    fmt_err(s.dx),
                    fmt_err(s.dy),
                    fmt_err(s.dw),
                    fmt_err(s.dh),
                    s.clay.x,
                    s.clay.y,
                    s.clay.w,
                    s.clay.h,
                    s.argile.x,
                    s.argile.y,
                    s.argile.w,
                    s.argile.h
                ))
            end
        end
    end
    os.exit(1)
end

os.exit(0)
