package topdog_base

import "base:intrinsics"

get_os_freq :: proc() -> i64 {
    return _get_os_freq()
}

get_os_time :: #force_inline proc() -> i64 {
    return _get_os_time()
}

estimate_cpu_freq :: #force_no_inline proc(ms_to_wait: i64 = 1000) -> i64 {
    assert(ms_to_wait > 0)
    os_freq := get_os_freq()

    cpu_start := get_cpu_time()
    os_start := get_os_time()

    os_target := ms_to_wait * os_freq / 1000
    os_elapsed := i64(0)
    for os_elapsed < os_target {
        os_elapsed = get_os_time() - os_start
    }
    cpu_end := get_cpu_time()
    assert(os_elapsed > 0)
    return os_freq * (cpu_end - cpu_start) / os_elapsed
}

high_res_sleep :: proc(sleep_ns: i64) {
    _high_res_sleep(sleep_ns)
}
get_cpu_time :: intrinsics.read_cycle_counter
