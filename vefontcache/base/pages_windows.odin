package topdog_base

import "core:sys/windows"

_page_size :: proc() -> i64 {
    sys_info: windows.SYSTEM_INFO
    windows.GetSystemInfo(&sys_info)
    return i64(sys_info.dwPageSize)
}

_virtual_reserve_size :: proc() -> i64 {
    sys_info: windows.SYSTEM_INFO
    windows.GetSystemInfo(&sys_info)
    return i64(sys_info.dwAllocationGranularity)
}
