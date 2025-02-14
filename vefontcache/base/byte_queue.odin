package topdog_base

import "core:log"
import "core:mem"
import "core:sync"

_ :: mem // NOTE(lucas): mem is used in parapoly so we need to always include it
 
BYTE_QUEUE_MAX_SIZE :: 1 << 30

@(private="file")
Byte_Queue_Cursor :: struct #align(64) {
    value: u32,
    cached_other: u32,
}

Byte_Queue :: struct {
    data: []byte,
    mask: u32,

    tail: Byte_Queue_Cursor,
    head: Byte_Queue_Cursor,
}

@(private)
is_power_of_two :: proc(value: int) -> bool {
    return ((value - 1) & value) == 0
}

byte_queue_make :: proc(size: int, allocator: Allocator) -> (Byte_Queue, bool) {
    if ! is_power_of_two(size) {
        log.errorf("Byte Queue requires a size that is a power of two but got '%v' which is not a power of two", size)
        return {}, false
    }
    if size < 0 || size > BYTE_QUEUE_MAX_SIZE {
        log.errorf("Byte Queue requires a size that is between '0' and '%v', but got '%v'", BYTE_QUEUE_MAX_SIZE, size)
        return {}, false
    }

    data, data_err := make([]byte, size, allocator)
    if data_err != nil {
        log.errorf("Byte Queue failed to allocate data (%v)", data_err)
        return {}, false
    }

    return { data = data, mask = u32(size - 1) }, true
}

byte_queue_delete :: proc(byte_queue: ^Byte_Queue, allocator: Allocator) {
    if byte_queue != nil {
        delete(byte_queue.data, allocator)
        byte_queue^ = {}
    }
}

@(private="file")
byte_queue_byte_distance :: proc(tail: u32, head: u32) -> u32 {
    v := head - tail
    if head < tail {
        v += max(u32)
    }
    return v
}

byte_queue_push_struct :: proc(byte_queue: ^Byte_Queue, t: ^$T, wait_for_space: bool) -> bool {
    return byte_queue_push_raw(byte_queue, mem.ptr_to_bytes(t), wait_for_space)
}

byte_queue_push_raw :: proc(byte_queue: ^Byte_Queue, data: []byte, wait_for_space: bool) -> bool {
    if len(data) > int(max(u32)) || len(data) > len(byte_queue.data) {
        return false
    }
    byte_queue_len := u32(len(byte_queue.data))
    space_left := byte_queue_len - byte_queue_byte_distance(byte_queue.head.cached_other, byte_queue.head.value)
    data_len := u32(len(data))
    if space_left < data_len {
        for {
            byte_queue.head.cached_other = sync.atomic_load(&byte_queue.tail.value)
            space_left = byte_queue_len - byte_queue_byte_distance(byte_queue.head.cached_other, byte_queue.head.value)
            if space_left >= data_len {
                break
            }

            if wait_for_space {
                sync.futex_wait(auto_cast &byte_queue.tail.value, byte_queue.head.cached_other)
            } else {
                return false
            }
        }
    }

    index := byte_queue.head.value & byte_queue.mask
    copy(byte_queue.data[index:], data)
    // NOTE(lucas): copy to end of buffer, we wrapped
    if data_len + index > byte_queue_len {
        copy(byte_queue.data, data[byte_queue_len - index:])
    }
    sync.atomic_add(&byte_queue.head.value, data_len)
    sync.futex_broadcast(auto_cast &byte_queue.head.value)
    return true
}

byte_queue_push :: proc {
    byte_queue_push_raw,
    byte_queue_push_struct,
}

byte_queue_read_n :: proc(byte_queue: ^Byte_Queue, n: u32, allocator: Allocator, wait_if_empty: bool) -> ([]byte, bool) {
    if byte_queue.tail.value == byte_queue.tail.cached_other {
        for {
            byte_queue.tail.cached_other = sync.atomic_load(&byte_queue.head.value)
            if byte_queue.tail.value != byte_queue.tail.cached_other {
                break
            }
            if wait_if_empty {
                sync.futex_wait(auto_cast &byte_queue.head.value, byte_queue.tail.cached_other)
            } else {
                return {}, false
            }
        }
    }

    byte_queue_len := u32(len(byte_queue.data))
    bytes_to_read := min(n, byte_queue_byte_distance(byte_queue.tail.value, byte_queue.tail.cached_other))
    data, err := make([]byte, bytes_to_read, allocator)
    if err != nil {
        return {}, false
    }

    index := byte_queue.tail.value & byte_queue.mask
    copy(data, byte_queue.data[index:min(byte_queue_len, index + bytes_to_read)])
    if index + bytes_to_read > byte_queue_len {
        copy(data[byte_queue_len - index:], byte_queue.data)
    }

    sync.atomic_add(&byte_queue.tail.value, bytes_to_read)
    assert(byte_queue.tail.value <= byte_queue.tail.cached_other)
    sync.futex_broadcast(auto_cast &byte_queue.tail.value)
    return data, true
}

byte_queue_read_all :: proc(byte_queue: ^Byte_Queue, allocator: Allocator, wait_if_empty: bool) -> ([]byte, bool) {
    return byte_queue_read_n(byte_queue, u32(len(byte_queue.data)), allocator, wait_if_empty)
}

byte_queue_read :: proc {
    byte_queue_read_all,
    byte_queue_read_n,
}

