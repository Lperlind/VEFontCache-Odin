package topdog_base

/*
    NOTE(lucas): like assert except we return the value when we build the program without
    asserts. This is useful where we are not 100% sure that v is true but 99% sure.
*/
expect :: #force_inline proc(v: bool, loc := #caller_location) -> bool {
    assert(v, loc = loc)
    return v
}

