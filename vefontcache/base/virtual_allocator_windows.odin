package topdog_base

import "core:sys/windows"

_virtual_allocate :: proc(base_address: rawptr, size: uint, type_flags: Virtual_Allocate_Type_Flags, protect_flags: Virtual_Allocate_Protect_Flags) -> rawptr {
	size := size
	windows_protect_flags := u32(windows.PAGE_NOACCESS)
	windows_type_flags: u32

	if .commit in type_flags {
		windows_type_flags |= windows.MEM_COMMIT
	}
	if .reserve in type_flags {
		windows_type_flags |= windows.MEM_RESERVE
		if .commit not_in type_flags {
			assert(size == align_forward(size, uint(virtual_reserve_size())))
		}
	}
	if .read in protect_flags {
		if .write in protect_flags {
			windows_protect_flags = windows.PAGE_READWRITE
		} else {
			windows_protect_flags = windows.PAGE_READONLY
		}
	}
	if .execute in protect_flags {
		windows_protect_flags = windows_protect_flags << 4
	}
	return windows.VirtualAlloc(base_address, windows.SIZE_T(size), windows_type_flags, windows_protect_flags)
}

_virtual_free :: proc(ptr: rawptr, size: uint, release: bool) -> bool {
    return bool(windows.VirtualFree(ptr, release ? 0 : size, release ? windows.MEM_RELEASE : windows.MEM_DECOMMIT));
}
