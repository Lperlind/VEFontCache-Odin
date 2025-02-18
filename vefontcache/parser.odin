package vefontcache

/*
Notes:
This is a minimal wrapper I originally did incase a font parser other than stb_truetype is introduced in the future.
Otherwise, its essentially 1:1 with it.

Freetype isn't really supported and its not a high priority.
~~Freetype will do memory allocations and has an interface the user can implement.~~
~~That interface is not exposed from this parser but could be added to parser_init.~~

STB_Truetype:
* Added ability to set the stb_truetype allocator for STBTT_MALLOC and STBTT_FREE.
* Changed procedure signatures to pass the font_info struct by immutable ptr (#by_ptr) 
  when the C equivalent has their parameter as `const*`.
*/

import "core:c"
import stbtt    "thirdparty:stb/truetype"
import ttf    "./ttf"

Parser_Kind :: enum u32 {
	STB_TrueType,
	Odin,
}

Parser_Font_Info :: struct {
	label : string,
	kind  : Parser_Kind,
	stbtt_info : stbtt.fontinfo,
	odin_info: ttf.Ttf_Font,
	// freetype_info : freetype.Face
	data : []byte,
}

Glyph_Vert_Type :: enum u8 {
	None,
	Move = 1,
	Line,
	Curve,
	Cubic,
}

// Based directly off of stb_truetype's vertex
Parser_Glyph_Vertex :: struct {
	x,          y          : i16,
	contour_x0, contour_y0 : i16,
	contour_x1, contour_y1 : i16,
	type    : Glyph_Vert_Type,
	padding : u8,
}
// A shape can be a dynamic array free_type or an opaque set of data handled by stb_truetype
Parser_Glyph_Shape :: ttf.Glyph_Curves

Parser_Context :: struct {
	lib_backing : Allocator,
	kind        : Parser_Kind,
	// ft_library : freetype.Library,
}

parser_stbtt_allocator_proc :: proc(
	allocator_data : rawptr, 
	type           : stbtt.zpl_allocator_type, 
	size           : c.ssize_t, 
	alignment      : c.ssize_t, 
	old_memory     : rawptr, 
	old_size       : c.ssize_t, 
	flags          : c.ulonglong
) -> rawptr
{
	allocator := transmute(^Allocator) allocator_data
	result, error := allocator.procedure( allocator.data, cast(Allocator_Mode) type, cast(int) size, cast(int) alignment, old_memory, cast(int) old_size )
	assert(error == .None)

	if type == .Alloc || type == .Resize {
		raw := transmute(Raw_Slice) result
		// assert(raw.len > 0, "Allocation is 0 bytes?")
		return transmute(rawptr) raw.data
	}
	else do return nil
}

parser_init :: proc( ctx : ^Parser_Context, kind : Parser_Kind, allocator := context.allocator )
{
	switch kind {
	case .Odin:
	case .STB_TrueType:
		ctx.lib_backing = allocator
		stbtt_allocator := stbtt.zpl_allocator { parser_stbtt_allocator_proc, & ctx.lib_backing }
		stbtt.SetAllocator( stbtt_allocator )
	}
	ctx.kind        = kind
}

parser_reload :: proc( ctx : ^Parser_Context, allocator := context.allocator) {
	switch ctx.kind {
	case .STB_TrueType:
		ctx.lib_backing = allocator
		stbtt_allocator := stbtt.zpl_allocator { parser_stbtt_allocator_proc, & ctx.lib_backing }
		stbtt.SetAllocator( stbtt_allocator )
	case .Odin:
	}
}

parser_shutdown :: proc( ctx : ^Parser_Context ) {
	// Note: Not necesssary for stb_truetype
}

parser_load_font :: proc( ctx : ^Parser_Context, label : string, data : []byte ) -> (font : Parser_Font_Info, error : b32)
{
	switch ctx.kind {
	case .STB_TrueType:
		error = ! stbtt.InitFont( & font.stbtt_info, raw_data(data), 0 )
	case .Odin:
		ok: bool
		font.odin_info, ok = ttf.ttf_from_data(data, context.allocator)
		error = ! ok
	}

	font.label = label
	font.data  = data
	font.kind  = ctx.kind
	return
}

parser_unload_font :: proc( font : ^Parser_Font_Info )
{
	switch font.kind {
	case .Odin: ttf.ttf_delete(&font.odin_info)
	case .STB_TrueType:
	}
}

parser_find_glyph_index :: #force_inline proc "contextless" ( font : Parser_Font_Info, codepoint : rune ) -> (glyph_index : Glyph)
{
	profile(#procedure)
	switch font.kind {
	case .STB_TrueType:
		glyph_index = transmute(Glyph) stbtt.FindGlyphIndex( font.stbtt_info, codepoint )
	case .Odin:
		glyph_index = Glyph(font.odin_info.codepoint_to_glyph_index_map[codepoint])
	}
	return
}

parser_free_shape :: #force_inline proc( font : Parser_Font_Info, shape : Parser_Glyph_Shape )
{
	switch font.kind {
	case .STB_TrueType:
		shape     := shape
		shape_raw := transmute( ^Raw_Dynamic_Array) & shape
		stbtt.FreeShape( font.stbtt_info, transmute( [^]stbtt.vertex) shape_raw.data )
	case .Odin:
	}
}

parser_get_codepoint_horizontal_metrics :: #force_inline proc "contextless" ( font : Parser_Font_Info, codepoint : rune ) -> ( advance, to_left_side_glyph : i32 )
{
	switch font.kind {
	case .STB_TrueType:
		stbtt.GetCodepointHMetrics( font.stbtt_info, codepoint, & advance, & to_left_side_glyph )
	case .Odin:
		glyph_index := font.odin_info.codepoint_to_glyph_index_map[codepoint]
		if len(font.odin_info.glyphs) > 0 {
			glyph := font.odin_info.glyphs[glyph_index]
			advance = i32(glyph.advance)
			to_left_side_glyph = i32(glyph.lsb)
		}
	}
	return
}

parser_get_codepoint_kern_advance :: #force_inline proc "contextless" ( font : Parser_Font_Info, prev_codepoint, codepoint : rune ) -> i32
{
	profile(#procedure)
	kern: i32
	switch font.kind {
	case .STB_TrueType:
			kern = stbtt.GetCodepointKernAdvance( font.stbtt_info, prev_codepoint, codepoint )
	case .Odin:
		prev_index := font.odin_info.codepoint_to_glyph_index_map[prev_codepoint]
		kern_index := font.odin_info.codepoint_to_glyph_index_map[codepoint]
		if len(font.odin_info.glyphs) > 0 {
			kern = i32(font.odin_info.glyphs[prev_index].kerning[kern_index])
		}
	}
	return kern
}

parser_get_font_vertical_metrics :: #force_inline proc "contextless" ( font : Parser_Font_Info ) -> (ascent, descent, line_gap : i32 )
{
	switch font.kind {
	case .STB_TrueType:
		stbtt.GetFontVMetrics( font.stbtt_info, & ascent, & descent, & line_gap )
	case .Odin:
		return i32(font.odin_info.ascender), i32(font.odin_info.descender), i32(font.odin_info.line_gap)
	}
	return
}

parser_get_bounds :: #force_inline proc "contextless" ( font : Parser_Font_Info, glyph_index : Glyph ) -> (bounds : Range2)
{
	profile(#procedure)
	glyph_index := glyph_index
	switch font.kind {
	case .STB_TrueType:
		// profile(#procedure)
		bounds_0, bounds_1 : Vec2i

		x0, y0, x1, y1 : i32
		success := cast(bool) stbtt.GetGlyphBox( font.stbtt_info, i32(glyph_index), & x0, & y0, & x1, & y1 )

		bounds_0 = { x0, y0 }
		bounds_1 = { x1, y1 }
		bounds = { vec2(bounds_0), vec2(bounds_1) }
	case .Odin:
		if glyph_index < 0 || int(glyph_index) >= len(font.odin_info.glyphs) {
			glyph_index = 0
		}
		if len(font.odin_info.glyphs) > 0 {
			glyph_info := font.odin_info.glyphs[glyph_index]
			bounds = { glyph_info.min, glyph_info.max }
		}
	}

	return
}

parser_get_glyph_shape :: #force_inline proc ( font : Parser_Font_Info, glyph_index : Glyph ) -> (shape : Parser_Glyph_Shape, error : Allocator_Error)
{
	profile(#procedure)
	glyph_index := glyph_index
	switch font.kind {
	case .STB_TrueType:
		/*
		stb_shape : [^]stbtt.vertex
		nverts    := stbtt.GetGlyphShape( font.stbtt_info, cast(i32) glyph_index, & stb_shape )

		shape_raw          := transmute( ^Raw_Dynamic_Array) & shape
		shape_raw.data      = stb_shape
		shape_raw.len       = int(nverts)
		shape_raw.cap       = int(nverts)
		shape_raw.allocator = nil_allocator()
		error = Allocator_Error.None
		*/
	case .Odin:
		if glyph_index < 0 || int(glyph_index) >= len(font.odin_info.glyphs) {
			glyph_index = 0
		}
		if len(font.odin_info.glyphs) > 0 {
			glyph := font.odin_info.glyphs[glyph_index]
			shape = glyph.unhinted_curves

			/*
			point_i := 0
			for type_i := 0; type_i < len(glyph.unhinted_curves.type); type_i += 1 {
				t := glyph.unhinted_curves.type[type_i]
				switch t {
				case .new_curve:
					on_curve := glyph.unhinted_curves.coordinates[point_i]
					// NOTE(lucas): grabbing the next point here is just to replicate STB truetype behaviour and is not
					// strictly necessary
					type_i += 1
					point_i += 1
					append(&shape, Parser_Glyph_Vertex { i16(on_curve.x), i16(on_curve.y), 0, 0, 0, 0, .Move, 0 })
				case .point:
					on_curve := glyph.unhinted_curves.coordinates[point_i]
					point_i += 1
					append(&shape, Parser_Glyph_Vertex { i16(on_curve.x), i16(on_curve.y), 0, 0, 0, 0, .Line, 0 })
				case .quadratic:
					off_curve := glyph.unhinted_curves.coordinates[point_i]
					on_curve := glyph.unhinted_curves.coordinates[point_i + 1]
					point_i += 2
					append(&shape, Parser_Glyph_Vertex { i16(on_curve.x), i16(on_curve.y), i16(off_curve.x), i16(off_curve.y), 0, 0, .Curve, 0 })
				case .cubic:
					c1 := glyph.unhinted_curves.coordinates[point_i]
					c2 := glyph.unhinted_curves.coordinates[point_i + 1]
					c3 := glyph.unhinted_curves.coordinates[point_i + 2]
					point_i += 3
					append(&shape, Parser_Glyph_Vertex { i16(c3.x), i16(c3.y), i16(c2.x), i16(c2.y), i16(c1.x), i16(c1.y), .Cubic, 0 })
				}
			}
			*/
		}
		error = Allocator_Error.None
	}
	return
}

parser_is_glyph_empty :: #force_inline proc "contextless" ( font : Parser_Font_Info, glyph_index : Glyph ) -> b32
{
	profile(#procedure)
	glyph_index := glyph_index
	switch font.kind {
	case .STB_TrueType:
		return stbtt.IsGlyphEmpty( font.stbtt_info, cast(c.int) glyph_index )
	case .Odin:
		if glyph_index < 0 || int(glyph_index) >= len(font.odin_info.glyphs) {
			glyph_index = 0
		}
		if len(font.odin_info.glyphs) > 0 {
			glyph := font.odin_info.glyphs[glyph_index]
			return len(glyph.unhinted_curves.coordinates) == 0
		}
	}
	return true
}

parser_scale :: #force_inline proc "contextless" ( font : Parser_Font_Info, size : f32 ) -> f32
{
	size_scale := size > 0.0 ? parser_scale_for_mapping_em_to_pixels( font, size ) :  parser_scale_for_pixel_height( font, -size )
	return size_scale
}

parser_scale_for_pixel_height :: #force_inline proc "contextless" ( font : Parser_Font_Info, size : f32 ) -> f32
{
	profile(#procedure)
	switch font.kind {
	case .STB_TrueType:
		return stbtt.ScaleForPixelHeight( font.stbtt_info, size )
	case .Odin:
		return size / (font.odin_info.ascender - font.odin_info.descender)
	}
	return 0
}

parser_scale_for_mapping_em_to_pixels :: #force_inline proc "contextless" ( font : Parser_Font_Info, size : f32 ) -> f32
{
	profile(#procedure)
	switch font.kind {
	case .STB_TrueType:
		return stbtt.ScaleForMappingEmToPixels( font.stbtt_info, size )
	case .Odin:
		if font.odin_info.units_per_em == 0 {
			return 0
		} else {
			return size / font.odin_info.units_per_em
		}
	}
	return 0
}
