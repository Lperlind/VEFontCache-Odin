package topdog_base

page_size :: proc() -> i64 {
    @(static)page_size: i64
    if page_size == 0 {
        page_size = _page_size()
    }
    return page_size
}

virtual_reserve_size :: proc() -> i64 {
    @(static)virtual_reserve_size: i64
    if virtual_reserve_size == 0 {
        virtual_reserve_size = _virtual_reserve_size()
    }
    return virtual_reserve_size
}

