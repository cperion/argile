#define _POSIX_C_SOURCE 200809L

#include <dlfcn.h>
#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef int (*bench_init_fn)(int width, int height, int max_elements, int arena_bytes);
typedef int (*bench_shutdown_fn)(void);
typedef int (*bench_fixed_fn)(int child_count);
typedef int (*bench_nested_fn)(int depth, int branch);
typedef int (*bench_text_fn)(int row_count);
typedef int (*bench_dashboard_fn)(int panel_count, int widgets_per_panel);
typedef int (*bench_clip_fn)(int list_count, int rows_per_list);
typedef int (*bench_stress_fn)(int element_count);

typedef struct BenchLib {
    const char *label;
    const char *path;
    void *handle;
    bench_init_fn bench_init;
    bench_shutdown_fn bench_shutdown;
    bench_fixed_fn bench_frame_fixed_children;
    bench_nested_fn bench_frame_nested;
    bench_text_fn bench_frame_text_rows;
    bench_dashboard_fn bench_frame_dashboard;
    bench_clip_fn bench_frame_clip_lists;
    bench_stress_fn bench_frame_stress_mixed;
} BenchLib;

typedef struct ProfileCfg {
    const char *name;
    int width;
    int height;
    int max_elements;
    int arena_bytes;
    double iter_scale;
} ProfileCfg;

typedef enum ScenarioFn {
    SCENARIO_FIXED,
    SCENARIO_NESTED,
    SCENARIO_TEXT,
    SCENARIO_DASHBOARD,
    SCENARIO_CLIP,
    SCENARIO_STRESS
} ScenarioFn;

typedef struct Scenario {
    const char *name;
    const char *category;
    ScenarioFn fn;
    int a;
    int b;
    int iterations;
    int warmup;
} Scenario;

typedef struct RunStats {
    bool ok;
    double total_s;
    double ms_per_frame;
    double fps;
    long long checksum;
} RunStats;

typedef struct ScenarioResult {
    const Scenario *scenario;
    RunStats clay;
    RunStats argile;
    double speedup;
    long long checksum_delta;
} ScenarioResult;

static const ProfileCfg kProfiles[] = {
    { "heavy", 2560, 1440, 70000, 768 * 1024 * 1024, 1.0 },
    { "stress", 3840, 2160, 120000, 1536 * 1024 * 1024, 0.65 },
};

static const Scenario kBaseScenarios[] = {
    { "Flat children", "Layout", SCENARIO_FIXED, 2500, 0, 140, 18 },
    { "Flat children extreme", "Stress", SCENARIO_FIXED, 7000, 0, 60, 10 },
    { "Flat children ultra", "Stress", SCENARIO_FIXED, 12000, 0, 30, 8 },

    { "Nested tree 4x4", "Layout", SCENARIO_NESTED, 4, 4, 180, 16 },
    { "Nested tree 5x4", "Layout", SCENARIO_NESTED, 5, 4, 130, 14 },
    { "Nested tree 5x5", "Stress", SCENARIO_NESTED, 5, 5, 60, 10 },
    { "Nested tree 6x4", "Stress", SCENARIO_NESTED, 6, 4, 45, 8 },

    { "Text feed", "Text", SCENARIO_TEXT, 3000, 0, 110, 14 },
    { "Text feed extreme", "Stress", SCENARIO_TEXT, 7000, 0, 45, 8 },
    { "Text feed ultra", "Stress", SCENARIO_TEXT, 12000, 0, 26, 6 },

    { "Dashboard mixed", "Realistic", SCENARIO_DASHBOARD, 24, 36, 110, 12 },
    { "Dashboard dense", "Realistic", SCENARIO_DASHBOARD, 40, 50, 55, 8 },
    { "Dashboard extreme", "Realistic", SCENARIO_DASHBOARD, 60, 70, 22, 6 },

    { "Clip lists", "Realistic", SCENARIO_CLIP, 18, 120, 90, 10 },
    { "Clip lists extreme", "Stress", SCENARIO_CLIP, 30, 180, 34, 6 },
    { "Clip lists ultra", "Stress", SCENARIO_CLIP, 42, 220, 20, 5 },

    { "Config churn mixed", "Stress", SCENARIO_STRESS, 5000, 0, 60, 10 },
    { "Config churn heavy", "Stress", SCENARIO_STRESS, 12000, 0, 30, 6 },
    { "Config churn ultra", "Stress", SCENARIO_STRESS, 20000, 0, 18, 4 },
};

static const char *dl_error_or_default(void) {
    const char *err = dlerror();
    return err != NULL ? err : "unknown dlerror";
}

static void close_bench_lib(BenchLib *lib) {
    if (lib->handle != NULL) {
        dlclose(lib->handle);
        lib->handle = NULL;
    }
}

static bool load_bench_lib(BenchLib *lib, const char *path, const char *label) {
    memset(lib, 0, sizeof(*lib));
    lib->label = label;
    lib->path = path;

    lib->handle = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (lib->handle == NULL) {
        fprintf(stderr, "[%s] dlopen failed for %s: %s\n", label, path, dl_error_or_default());
        return false;
    }

    dlerror();
#define LOAD_SYM(name, type) do { \
    lib->name = (type)dlsym(lib->handle, #name); \
    if (lib->name == NULL) { \
        fprintf(stderr, "[%s] missing symbol %s in %s: %s\n", label, #name, path, dl_error_or_default()); \
        close_bench_lib(lib); \
        return false; \
    } \
} while (0)

    LOAD_SYM(bench_init, bench_init_fn);
    LOAD_SYM(bench_shutdown, bench_shutdown_fn);
    LOAD_SYM(bench_frame_fixed_children, bench_fixed_fn);
    LOAD_SYM(bench_frame_nested, bench_nested_fn);
    LOAD_SYM(bench_frame_text_rows, bench_text_fn);
    LOAD_SYM(bench_frame_dashboard, bench_dashboard_fn);
    LOAD_SYM(bench_frame_clip_lists, bench_clip_fn);
    LOAD_SYM(bench_frame_stress_mixed, bench_stress_fn);
#undef LOAD_SYM

    return true;
}

static double now_seconds(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1000000000.0;
}

static int scenario_call(const BenchLib *lib, const Scenario *s) {
    switch (s->fn) {
        case SCENARIO_FIXED:
            return lib->bench_frame_fixed_children(s->a);
        case SCENARIO_NESTED:
            return lib->bench_frame_nested(s->a, s->b);
        case SCENARIO_TEXT:
            return lib->bench_frame_text_rows(s->a);
        case SCENARIO_DASHBOARD:
            return lib->bench_frame_dashboard(s->a, s->b);
        case SCENARIO_CLIP:
            return lib->bench_frame_clip_lists(s->a, s->b);
        case SCENARIO_STRESS:
            return lib->bench_frame_stress_mixed(s->a);
    }
    return -1;
}

static const char *scenario_fn_name(const Scenario *s) {
    switch (s->fn) {
        case SCENARIO_FIXED: return "bench_frame_fixed_children";
        case SCENARIO_NESTED: return "bench_frame_nested";
        case SCENARIO_TEXT: return "bench_frame_text_rows";
        case SCENARIO_DASHBOARD: return "bench_frame_dashboard";
        case SCENARIO_CLIP: return "bench_frame_clip_lists";
        case SCENARIO_STRESS: return "bench_frame_stress_mixed";
    }
    return "unknown";
}

static void scenario_args_string(const Scenario *s, char *out, size_t out_size) {
    if (s->fn == SCENARIO_FIXED || s->fn == SCENARIO_TEXT || s->fn == SCENARIO_STRESS) {
        snprintf(out, out_size, "%d", s->a);
        return;
    }
    snprintf(out, out_size, "%d,%d", s->a, s->b);
}

static int scaled_count(int base, double scale) {
    int out = (int)floor((double)base * scale + 0.5);
    return out < 1 ? 1 : out;
}

static RunStats run_scenario(const BenchLib *lib, const ProfileCfg *cfg, const Scenario *s) {
    RunStats out;
    memset(&out, 0, sizeof(out));

    if (lib->bench_init(cfg->width, cfg->height, cfg->max_elements, cfg->arena_bytes) != 1) {
        fprintf(stderr, "[%s] bench_init failed for scenario '%s'\n", lib->label, s->name);
        return out;
    }

    for (int i = 0; i < s->warmup; ++i) {
        int rc = scenario_call(lib, s);
        if (rc < 0) {
            fprintf(stderr, "[%s] warmup run failed for scenario '%s'\n", lib->label, s->name);
            lib->bench_shutdown();
            return out;
        }
    }

    long long checksum = 0;
    double t0 = now_seconds();
    for (int i = 0; i < s->iterations; ++i) {
        int rc = scenario_call(lib, s);
        if (rc < 0) {
            fprintf(stderr, "[%s] timed run failed for scenario '%s'\n", lib->label, s->name);
            lib->bench_shutdown();
            return out;
        }
        checksum += rc;
    }
    double dt = now_seconds() - t0;
    lib->bench_shutdown();

    out.ok = true;
    out.total_s = dt;
    out.ms_per_frame = (dt * 1000.0) / (double)s->iterations;
    out.fps = (double)s->iterations / dt;
    out.checksum = checksum;
    return out;
}

static const ProfileCfg *find_profile(const char *name) {
    size_t n = sizeof(kProfiles) / sizeof(kProfiles[0]);
    for (size_t i = 0; i < n; ++i) {
        if (strcmp(kProfiles[i].name, name) == 0) {
            return &kProfiles[i];
        }
    }
    return NULL;
}

int main(int argc, char **argv) {
    const char *profile_name = argc > 1 ? argv[1] : "heavy";
    const char *argile_path = argc > 2 ? argv[2] : "build/libargile_bench.so";
    const char *clay_path = argc > 3 ? argv[3] : "build/libclay_bench.so";

    const ProfileCfg *cfg = find_profile(profile_name);
    if (cfg == NULL) {
        fprintf(stderr, "Usage: %s [heavy|stress] [argile_lib_path] [clay_lib_path]\n", argv[0]);
        return 2;
    }

    BenchLib argile;
    BenchLib clay;
    if (!load_bench_lib(&argile, argile_path, "Argile")) {
        return 1;
    }
    if (!load_bench_lib(&clay, clay_path, "Clay")) {
        close_bench_lib(&argile);
        return 1;
    }

    size_t scenario_count = sizeof(kBaseScenarios) / sizeof(kBaseScenarios[0]);
    Scenario *scenarios = (Scenario *)malloc(sizeof(Scenario) * scenario_count);
    ScenarioResult *results = (ScenarioResult *)malloc(sizeof(ScenarioResult) * scenario_count);
    if (scenarios == NULL || results == NULL) {
        fprintf(stderr, "Allocation failure for scenario tables\n");
        free(scenarios);
        free(results);
        close_bench_lib(&argile);
        close_bench_lib(&clay);
        return 1;
    }

    for (size_t i = 0; i < scenario_count; ++i) {
        scenarios[i] = kBaseScenarios[i];
        scenarios[i].iterations = scaled_count(kBaseScenarios[i].iterations, cfg->iter_scale);
        scenarios[i].warmup = scaled_count(kBaseScenarios[i].warmup, cfg->iter_scale);
    }

    printf("Argile vs Clay Benchmark Suite (pure C, %s profile)\n", cfg->name);
    printf("Resolution=%dx%d max_elements=%d arena=%.1fMB\n",
           cfg->width, cfg->height, cfg->max_elements, (double)cfg->arena_bytes / 1024.0 / 1024.0);
    printf("Fair mode: strict (culling disabled in both backends)\n");
    printf("Order policy: alternating backend order by scenario\n");
    printf("Scenarios=%zu\n", scenario_count);
    fflush(stdout);

    bool all_ok = true;
    for (size_t i = 0; i < scenario_count; ++i) {
        Scenario *s = &scenarios[i];
        char args_buf[64];
        scenario_args_string(s, args_buf, sizeof(args_buf));
        printf("[%02zu/%02zu] %-24s (%s) fn=%s(%s) iters=%d warmup=%d\n",
               i + 1, scenario_count, s->name, s->category, scenario_fn_name(s), args_buf, s->iterations, s->warmup);
        fflush(stdout);

        RunStats clay_stats;
        RunStats argile_stats;
        if ((i % 2) == 0) {
            clay_stats = run_scenario(&clay, cfg, s);
            argile_stats = run_scenario(&argile, cfg, s);
        } else {
            argile_stats = run_scenario(&argile, cfg, s);
            clay_stats = run_scenario(&clay, cfg, s);
        }

        ScenarioResult *r = &results[i];
        r->scenario = s;
        r->clay = clay_stats;
        r->argile = argile_stats;
        r->checksum_delta = argile_stats.checksum - clay_stats.checksum;
        r->speedup = (argile_stats.ok && clay_stats.ok && argile_stats.total_s > 0.0)
            ? (clay_stats.total_s / argile_stats.total_s)
            : 0.0;

        if (!clay_stats.ok || !argile_stats.ok) {
            all_ok = false;
        }
    }

    if (!all_ok) {
        fprintf(stderr, "One or more scenarios failed to execute\n");
        free(scenarios);
        free(results);
        close_bench_lib(&argile);
        close_bench_lib(&clay);
        return 1;
    }

    printf("\nFinal Comparison Table\n");
    printf("%-24s | %-10s | %-10s | %-11s | %-10s | %-10s | %-8s | %-10s | %-10s | %-8s\n",
           "Scenario", "Category", "Clay ms/f", "Argile ms/f", "Clay FPS", "Argile FPS", "Speedup", "Clay Sum", "Argile Sum", "Delta");
    printf("-----------------------------------------------------------------------------------------------------------------------------------------------\n");

    double sum_speedup = 0.0;
    double product_speedup = 1.0;
    size_t speedup_count = 0;
    const ScenarioResult *best = NULL;
    const ScenarioResult *worst = NULL;

    for (size_t i = 0; i < scenario_count; ++i) {
        const ScenarioResult *r = &results[i];
        printf("%-24s | %-10s | %-10.3f | %-11.3f | %-10.0f | %-10.0f | %7.2fx | %-10lld | %-10lld | %-8lld\n",
               r->scenario->name,
               r->scenario->category,
               r->clay.ms_per_frame,
               r->argile.ms_per_frame,
               r->clay.fps,
               r->argile.fps,
               r->speedup,
               r->clay.checksum,
               r->argile.checksum,
               r->checksum_delta);

        if (r->speedup > 0.0) {
            sum_speedup += r->speedup;
            product_speedup *= r->speedup;
            speedup_count++;
            if (best == NULL || r->speedup > best->speedup) {
                best = r;
            }
            if (worst == NULL || r->speedup < worst->speedup) {
                worst = r;
            }
        }
    }

    double avg_speedup = speedup_count > 0 ? sum_speedup / (double)speedup_count : 0.0;
    double geo_speedup = speedup_count > 0 ? pow(product_speedup, 1.0 / (double)speedup_count) : 0.0;

    printf("\nSummary\n");
    printf("  Average speedup (arithmetic): %.2fx\n", avg_speedup);
    printf("  Average speedup (geometric):  %.2fx\n", geo_speedup);
    if (best != NULL && worst != NULL) {
        printf("  Best scenario:  %s (%.2fx)\n", best->scenario->name, best->speedup);
        printf("  Worst scenario: %s (%.2fx)\n", worst->scenario->name, worst->speedup);
    }

    size_t parity_mismatches = 0;
    for (size_t i = 0; i < scenario_count; ++i) {
        if (results[i].checksum_delta != 0) {
            parity_mismatches++;
        }
    }
    printf("  Parity mismatches: %zu\n", parity_mismatches);

    int exit_code = 0;
    if (parity_mismatches > 0) {
        printf("\nStrict parity failure: checksum mismatch detected\n");
        for (size_t i = 0; i < scenario_count; ++i) {
            const ScenarioResult *r = &results[i];
            if (r->checksum_delta != 0) {
                printf("  - %s: clay=%lld argile=%lld delta=%lld\n",
                       r->scenario->name, r->clay.checksum, r->argile.checksum, r->checksum_delta);
            }
        }
        exit_code = 1;
    }

    free(scenarios);
    free(results);
    close_bench_lib(&argile);
    close_bench_lib(&clay);
    return exit_code;
}
