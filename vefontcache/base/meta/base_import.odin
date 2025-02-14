package topdog_base_meta

import base ".."

Allocator :: base.Allocator
Allocator_Error :: base.Allocator_Error
Allocator_Mode :: base.Allocator_Mode
Allocator_Mode_Set :: base.Allocator_Mode_Set

make_aligned :: base.make_aligned
mem_alloc_non_zeroed :: base.mem_alloc_non_zeroed

Arena :: base.Arena
arena_make :: base.arena_make
arena_virtual_make :: base.arena_virtual_make
arena_allocator :: base.arena_allocator
arena_alloc :: base.arena_alloc
arena_realloc :: base.arena_realloc
arena_scratch :: base.arena_scratch
arena_delete :: base.arena_delete
arena_free_all :: base.arena_free_all
arena_temp_scope :: base.arena_temp_scope
arena_temp_make :: base.arena_temp_make
arena_temp_delete :: base.arena_temp_delete
virtual_allocate :: base.virtual_allocate
virtual_free :: base.virtual_free
virtual_allocator :: base.virtual_allocator

fatal_error :: base.fatal_error
get_last_os_error_string :: base.get_last_os_error_string

Generational_Pointer :: base.Generational_Pointer
generational_pointer_to_t :: base.generational_pointer_to_t
t_to_generational_pointer :: base.t_to_generational_pointer

pack_2_i32_to_u64 :: base.pack_2_i32_to_u64
unpack_u64_to_2_i32 :: base.unpack_u64_to_2_i32
array_cast :: base.array_cast

map_freeze :: base.map_freeze

Bad_Handle :: base.Bad_Handle

Byte_Queue :: base.Byte_Queue
byte_queue_make :: base.byte_queue_make
byte_queue_delete :: base.byte_queue_delete
byte_queue_push :: base.byte_queue_push
byte_queue_push_struct :: base.byte_queue_push_struct
byte_queue_push_raw :: base.byte_queue_push_raw
byte_queue_read :: base.byte_queue_read_n
byte_queue_read_n :: base.byte_queue_read_n
byte_queue_read_all :: base.byte_queue_read_all

