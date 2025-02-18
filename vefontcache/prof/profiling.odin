package vefontcache_prof

// Add profiling hookup here

import "core:prof/spall"
import "core:os"

spall_ctx: spall.Context
spall_buffer: spall.Buffer

DISABLE_PROFILING :: true

@(disabled = DISABLE_PROFILING)
profile_init :: proc() {
	spall_ctx = spall.context_create("trace_test.spall")
	buffer_backing := make([]u8, spall.BUFFER_DEFAULT_SIZE, os.heap_allocator())
	spall_buffer = spall.buffer_create(buffer_backing, 0)
}

@(disabled = DISABLE_PROFILING)
profile_fini :: proc() {
	spall.buffer_destroy(&spall_ctx, &spall_buffer)
	spall.context_destroy(&spall_ctx)
}

@(deferred_none = profile_end, disabled = DISABLE_PROFILING)
profile :: #force_inline proc "contextless" ( name : string, loc := #caller_location ) {
	profile_begin(name, loc)
}

@(disabled = DISABLE_PROFILING)
profile_begin :: #force_inline proc "contextless" ( name : string, loc := #caller_location ) {
	spall._buffer_begin(&spall_ctx, &spall_buffer, name, "", loc)
}

@(disabled = DISABLE_PROFILING)
profile_end :: #force_inline proc "contextless" () {
	spall._buffer_end(&spall_ctx, &spall_buffer)
}
