package topdog_base

import "core:mem"

Virtual_Allocate_Protect_Flag :: enum {
	read,
	write,
	execute
}
Virtual_Allocate_Protect_Flags :: bit_set[Virtual_Allocate_Protect_Flag]
Virtual_Allocate_Type_Flag :: enum {
	reserve,
	commit,
}
Virtual_Allocate_Type_Flags :: bit_set[Virtual_Allocate_Type_Flag]

virtual_allocate :: #force_no_inline proc(base_address: rawptr, size: uint, type_flags: Virtual_Allocate_Type_Flags, protect_flags: Virtual_Allocate_Protect_Flags) -> rawptr {
	return _virtual_allocate(base_address, size, type_flags, protect_flags)
}

virtual_free :: #force_no_inline proc(ptr: rawptr, size: uint, release: bool) -> bool {
	return _virtual_free(ptr, size, release)
}

virtual_allocator_proc :: proc(allocator_data: rawptr, mode: Allocator_Mode,
                             size, alignment: int,
                             old_memory: rawptr, old_size: int,
                             location := #caller_location) -> (data: []byte, err: Allocator_Error) {
	switch mode {
	case .Alloc, .Alloc_Non_Zeroed:
		if alignment > int(page_size()) {
			return {}, .Invalid_Argument
		}
		ptr := virtual_allocate(nil, uint(size), { .commit, .reserve }, { .read, .write })
		if ptr == nil {
			err = .Out_Of_Memory
		} else {
			return mem.slice_ptr(cast(^byte)ptr, size), nil
		}
	case .Free:
		virtual_free(old_memory, 0, true)
	case .Free_All:
		err = .Mode_Not_Implemented
	case .Resize, .Resize_Non_Zeroed:
		err = .Mode_Not_Implemented
	case .Query_Features:
		set := (^Allocator_Mode_Set)(old_memory)
		if set != nil {
			set^ = {.Alloc, .Free}
		}
	case .Query_Info:
		err = .Mode_Not_Implemented
	}

	return
}

virtual_allocator :: proc() -> Allocator {
	return { virtual_allocator_proc, nil }
}
