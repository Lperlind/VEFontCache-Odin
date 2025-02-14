package topdog_base

import "core:sys/windows"

_set_thread_name :: proc(name: string) {
	scratch := arena_scratch({})
	windows.SetThreadDescription(windows.GetCurrentThread(), windows.utf8_to_wstring(name, scratch.arena))
}

