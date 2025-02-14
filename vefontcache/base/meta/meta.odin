package topdog_base_meta

import "../log"
import os "core:os/os2"
import parser "core:odin/parser"
import ast "core:odin/ast"

Parsed_File :: struct {
    parser: parser.Parser,
    using file: ast.File,
}

parse_file :: proc(path: string, allocator: Allocator) -> (Parsed_File, bool) {
    file_contents, err := os.read_entire_file_from_path(path, context.allocator)
    if err != nil {
        log.errorf("Failed to read the file '%v', (%v)", path, err)
        return {}, false
    }
    file: ast.File
    file.fullpath = path
    file.src = string(file_contents)
    p := parser.default_parser()
    if ! parser.parse_file(&p, &file) {
        return {}, false
    }
    return { p , file }, true
}

visit_all_procedures :: proc(file: Parsed_File, data: ^$T, visit_proc: proc(data: ^T, identifier: string, type: string)) {
    visit_all_procedures_raw(file, data, auto_cast visit_proc)
}

visit_all_procedures_raw :: proc(file: Parsed_File, data: rawptr, visit_proc: proc(data: rawptr, identifier: string, type: string)) {
    if visit_proc == nil {
        return
    }

    Visitor_Context :: struct {
        file: Parsed_File,
        last_ident: string,
        callback: proc(data: rawptr, identifier: string, type: string),
        data: rawptr
    }
    ctx := Visitor_Context { file, "", visit_proc, data }
    v: ast.Visitor
    v.data = &ctx
    v.visit = proc(visitor: ^ast.Visitor, node: ^ast.Node) -> ^ast.Visitor {
        ctx := cast(^Visitor_Context)visitor.data
        if node != nil {
            #partial switch d in node.derived {
            case ^ast.Ident: ctx.last_ident = d.name
            case ^ast.Proc_Type: ctx.callback(ctx.data, ctx.last_ident, ctx.file.src[node.pos.offset:node.end.offset])
            }
        }
        return visitor
    }

    for d in file.decls {
        ast.walk(&v, d)
    }
}
