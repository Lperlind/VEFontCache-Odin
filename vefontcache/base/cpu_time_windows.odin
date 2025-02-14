package topdog_base

import "base:intrinsics"
import "core:sys/windows"

_get_os_freq :: proc() -> i64 {
    freq: windows.LARGE_INTEGER
    if windows.QueryPerformanceFrequency(&freq) {
        return i64(freq)
    } else {
        panic("Could not get OS time")
    }
}

_get_os_time :: #force_inline proc() -> i64 {
    t: windows.LARGE_INTEGER
    if windows.QueryPerformanceCounter(&t) {
        return i64(t)
    } else {
        return 0
    }
}

_high_res_sleep :: proc(sleep_ns: i64) {
    if sleep_ns <= 0 {
        return
    }
    sleep_start := get_os_time()
    _spin_until_done :: proc(start: i64, sleep_ns: i64) {
        freq := get_os_freq()
        sleep_ns := sleep_ns
        sleep_ns = sleep_ns
        mul := (1000_000_000 / freq)
        for ((get_os_time() - start) * mul) < sleep_ns {
            // NOTE(lucas): tell cpu to chill a bit
            intrinsics.cpu_relax()
        }
    }

    SLEEP_SPIN_BUDGET :: 500_000
    if sleep_ns < SLEEP_SPIN_BUDGET {
        _spin_until_done(sleep_start, sleep_ns)
        return
    }

    timer := windows.CreateWaitableTimerExW(nil, nil, windows.CREATE_WAITABLE_TIMER_HIGH_RESOLUTION, windows.TIMER_ALL_ACCESS)
    if timer == nil {
        // NOTE(lucas): could not create a high res timer, so we just spin because we are cruel cruel people
        _spin_until_done(sleep_start, sleep_ns)
        return
    }
    defer windows.CloseHandle(timer)
    // NOTE(lucas): Negative values indicate relative time https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-setwaitabletimerex
    // sleep time is also in 100ns chunks so divide by 100

    // NOTE(lucas): reduce how long we need to sleep by SLEEP_SPIN_BUDGET to get a bit of buffer room with the scheduler
    // we will spin after to hit our timing better
    // TODO(lucas): we probably want to dynamically change this value based on measured margin of error
    // at runtime
    reduced_sleep_ns := max(sleep_ns - SLEEP_SPIN_BUDGET, 0)
    if reduced_sleep_ns > 0 {
        sleep_time := -windows.LARGE_INTEGER(reduced_sleep_ns / 100)
        if windows.SetWaitableTimerEx(timer, &sleep_time, 0, nil, nil, nil, 0) {
            windows.WaitForSingleObject(timer, windows.INFINITE)
        }
    }
    _spin_until_done(sleep_start, sleep_ns)
}

