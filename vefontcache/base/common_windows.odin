package topdog_base

import "core:sys/windows"
import "core:reflect"

_show_dialogue_box :: proc(caption: string, msg: string) {
    scratch := arena_scratch({})
    w_msg := windows.utf8_to_wstring(msg, scratch.arena)
    w_caption := windows.utf8_to_wstring(caption, scratch.arena)
    windows.MessageBoxW(nil, w_msg, w_caption, windows.MB_OK)
}

_show_scratch_died :: proc() {
    message := windows.L("A fatal error has occured and the application will be shutdown:\nFailed to allocate arena for the scratch pool (out of memory)")
    caption := windows.L("Fatal Error")
    windows.MessageBoxW(nil, message, caption, windows.MB_OK)
}

_get_last_os_error_string :: proc() -> string {
	err := windows.System_Error(windows.GetLastError())
	err_msg := reflect.enum_string(err)
	return "unknown" if err_msg == "" else err_msg
}
