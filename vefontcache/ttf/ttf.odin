
package topdog_font

import "core:mem"
import "core:math"
import "core:math/linalg"
import "core:os"
import "core:log"
import "core:slice"
import "base:intrinsics"

import "../base"

Ttf_ShortFrac :: i16be
Ttf_Fixed :: i32be
Ttf_Fword :: i16be
Ttf_uFword :: u16be
Ttf_F2Dot14 :: i16be
Ttf_longDateTime :: i64be
Ttf_u32 :: u32be
Ttf_u16 :: u16be
Ttf_i32 :: i32be
Ttf_i16 :: i16be

Glyph_Coordinate_Type :: enum u8 {
	new_curve,
	point,
	quadratic,
}

Glyph_Curves :: struct {
	coordinates: [][2]f32,
	type: []Glyph_Coordinate_Type,
}

Ttf_Font :: struct {
	codepoint_to_glyph_index_map: map[rune]u32,
	glyphs: []Ttf_Glyph,
	min_glyph_extent, max_glyph_extent: [2]f32,
	units_per_em: f32,
	ascender: f32,
	descender: f32,
	line_gap: f32,
	arena: ^base.Arena,
}

Ttf_Read_Context :: struct {
	ok: bool
}

Ttf_Glyph_Contour_Point :: struct {
	coord: [2]f32,
	on_curve: bool,
}
Ttf_Glyph :: struct {
	unhinted_curves: Glyph_Curves,

	ordered_contour_lengths: []u16,
	points: #soa[]Ttf_Glyph_Contour_Point,
	min, max: [2]f32,
	hinting_instructions: []byte,
}

Ttf_Reader :: struct {
	ctx: ^Ttf_Read_Context,
	data: []byte,
	offset: i64,
}

Ttf_Table_Blob :: struct {
	directory: ^Ttf_Table_Directory,
	data: []byte,
	valid: bool,
}

Ttf_Offset_Subtable :: struct #packed {
	scalar_type: Ttf_u32,
	num_tables: Ttf_u16,
	search_range: Ttf_u16,
	entry_selector: Ttf_u16,
	range_shift: Ttf_u16,
}

Ttf_Table_Directory :: struct #packed {
	tag: Ttf_u32,
	check_sum: Ttf_u32,
	offset: Ttf_u32,
	length: Ttf_u32,
}

Ttf_Character_Map :: struct {
	codepoint: rune,
	glyph_index: u32,
}

TTF_TABLE_HEAD_MAGIC :: 0x5F0F3CF5
Ttf_Table_Head :: struct #packed {
	version: Ttf_Fixed,
	font_revision: Ttf_Fixed,
	check_sum_adjustment: Ttf_u32,
	magic_number: Ttf_u32,
	flags: Ttf_u16,
	units_per_em: Ttf_u16,
	created: Ttf_longDateTime,
	modified: Ttf_longDateTime,
	x_min: Ttf_Fword,
	y_min: Ttf_Fword,
	x_max: Ttf_Fword,
	y_max: Ttf_Fword,
	mac_style: Ttf_u16,
	lowest_rec_ppem: Ttf_u16,
	font_direction_hint: Ttf_i16,
	index_to_loc_format: Ttf_i16,
	glyph_data_format: Ttf_i16,
}

Ttf_Table_Horizontal_Header :: struct #packed {
	major_version: u16be,
	minor_version: u16be,
	ascender: Ttf_Fword,
	descender: Ttf_Fword,
	line_gap: Ttf_Fword,
	advance_width_max: Ttf_Fword,
	min_left_side_bearing: Ttf_Fword,
	min_right_side_bearing: Ttf_Fword,
	x_max_extent: Ttf_Fword,
	caret_slope_rise: i16be,
	caret_slope_run: i16be,
	caret_offset: i16be,
	_: i16be,
	_: i16be,
	_: i16be,
	_: i16be,
	metric_data_format: i16be,
	number_of_h_metrics: i16be,
}

Ttf_Table_Maxp :: struct #packed {
	version: Ttf_Fixed,
	num_glyphs: Ttf_u16,
	max_points: Ttf_u16,
	max_contours: Ttf_u16,
	max_component_points: Ttf_u16,
	max_component_contours: Ttf_u16,
	max_zones: Ttf_u16,
	max_twilight_points: Ttf_u16,
	max_storage: Ttf_u16,
	max_function_defs: Ttf_u16,
	max_instruction_defs: Ttf_u16,
	max_stack_elements: Ttf_u16,
	max_size_of_instructions: Ttf_u16,
	max_component_elements: Ttf_u16,
	max_component_depth: Ttf_u16,
}

Ttf_Platform_Id :: enum Ttf_u16 {
	unicode = 0,
	macintosh = 1,
	microsoft = 3,
}

Ttf_Table_Cmap_Index :: struct #packed {
	version: Ttf_u16,
	number_subtables: Ttf_u16,
}

Ttf_Table_Cmap_Sub :: struct #packed {
	platform_id: Ttf_Platform_Id,
	platform_specific_id: Ttf_u16,
	offset: Ttf_u32,
}

Ttf_Glyph_Loca :: struct {
	offset: u32,
	length: u32,
}

Ttf_Glyf_Table :: struct #packed {
	number_of_contours: Ttf_i16,
	x_min: Ttf_Fword,
	y_min: Ttf_Fword,
	x_max: Ttf_Fword,
	y_max: Ttf_Fword,
}
Ttf_Glyf_Compound_Flag :: enum {
	args_1_and_2_are_words = 0,
	args_are_xy_values = 1,
	round_xy_to_grid = 2,
	we_have_a_scale = 3,
	more_components = 5,
	we_have_an_x_and_y_scale = 6,
	we_have_a_two_by_two = 7,
	we_have_instructions = 8,
	use_my_metrics = 9,
	overlap_compound = 10,
}
Ttf_Glyf_Compound_Flags :: distinct bit_set[Ttf_Glyf_Compound_Flag; Ttf_u16]

Ttf_Glyf_Single_Flag :: enum {
	on_curve = 0,
	x_short_vector = 1,
	y_short_vector = 2,
	repeat = 3,
	x_is_same = 4,
	y_is_same = 5,
}
Ttf_Glyf_Single_Flags :: distinct bit_set[Ttf_Glyf_Single_Flag; u8]

Ttf_Cmap_Format :: enum {
	_4,
	_12,
}
Ttf_Cmap_Formats :: distinct bit_set[Ttf_Cmap_Format]
TTF_CMAP_FORMATS_ALL :: Ttf_Cmap_Formats { ._4, ._12 }

Ttf_Table_Cmap_Format_4 :: struct #packed {
	format: Ttf_u16,
	length: Ttf_u16,
	language: Ttf_u16,
	seg_count_x2: Ttf_u16,
	search_range: Ttf_u16,
	entry_selector: Ttf_u16,
	range_shift: Ttf_u16,
}

Ttf_Table_Cmap_Format_12 :: struct #packed {
	format: Ttf_u16,
	reserved: Ttf_u16,
	length: Ttf_u32,
	language: Ttf_u32,
	n_groups: Ttf_u32,
}

Ttf_Table_Cmap_Format_12_Group :: struct #packed {
	start_char_code: Ttf_u32,
	end_char_code: Ttf_u32,
	start_glyph_code: Ttf_u32,
}

Ttf_Tag :: enum {
	unknown, // NOTE(lucas): not an actual table 
	cmap,
	glyf,
	head,
	hhea,
	hmtx,
	loca,
	maxp,
	name,
	post,
}
Ttf_Tags :: distinct bit_set[Ttf_Tag]
TTF_REQUIRED_TABLES :: Ttf_Tags {
	.cmap,
	.glyf,
	.head,
	.hhea,
	.hmtx,
	.loca,
	.maxp,
	.name, // NOTE(lucas): technically the spec requires this but some fonts do not have it
	.post
}

ttf_u32_to_tag :: proc(tag: Ttf_u32) -> Ttf_Tag {
	switch tag {
	case 0x636D6170: return .cmap
	case 0x676C7966: return .glyf
	case 0x68656164: return .head
	case 0x68686561: return .hhea
	case 0x686D7478: return .hmtx
	case 0x6C6F6361: return .loca
	case 0x6D617870: return .maxp
	case 0x6E616D65: return .name
	case 0x706F7374: return .post
	}
	return .unknown
}

ttf_read_bytes_copy :: proc(r: ^Ttf_Reader, size: i64, ptr: rawptr) -> (bool) {
	head, did_overflow := intrinsics.overflow_add(r.offset, size)
	if ! r.ctx.ok || did_overflow || size > i64(max(int)) || head > i64(len(r.data)) {
		if r.ctx.ok {
			log.error("[Ttf parser] Illegal read")
		}
		r.ctx.ok = false
		return false
	}
	if ptr != nil && size > 0 {
		mem.copy_non_overlapping(ptr, &r.data[r.offset], int(size))
	}
	r.offset = head
	return true
}

ttf_read_bytes_ptr :: proc(r: ^Ttf_Reader, size: i64, ptr: ^rawptr) -> (bool) {
	head, did_overflow := intrinsics.overflow_add(r.offset, size)
	if ! r.ctx.ok || did_overflow || size > i64(max(int)) || head > i64(len(r.data)) {
		if r.ctx.ok {
			log.error("[Ttf parser] Illegal read")
		}
		r.ctx.ok = false
		return false
	}
	if ptr != nil && size > 0 {
		ptr^ = &r.data[r.offset]
	}
	r.offset = head
	return true
}

ttf_read_t_copy :: proc($T: typeid, r: ^Ttf_Reader) -> (T, bool) #optional_ok {
	t: T
	ok := ttf_read_bytes_copy(r, size_of(T), &t)
	return t, ok
}

ttf_read_t_ptr :: proc($T: typeid, r: ^Ttf_Reader) -> (^T, bool) #optional_ok {
	@static _dummy: T
	t: ^T = &_dummy
	ok := ttf_read_bytes_ptr(r, size_of(T), auto_cast &t)
	return t, ok
}

ttf_read_t_slice :: proc($T: typeid, r: ^Ttf_Reader, len: i64) -> ([]T, bool) #optional_ok {
	t: ^T
	ok := ttf_read_bytes_ptr(r, size_of(T) * len, auto_cast &t)
	if ok {
		return mem.slice_ptr(t, int(len)), true
	} else {
		return {}, false
	}
}

ttf_get_table_from_directory :: proc(ctx: ^Ttf_Read_Context, offset: i64, length: i64, data: []byte) -> ([]byte, bool) {
	i64_len := i64(len(data))
	table_start := offset
	table_end, did_overflow := intrinsics.overflow_add(offset, length)
	if offset < 0 || length < 0 || table_start > i64_len || table_end > i64_len || did_overflow {
		ctx.ok = false
		return {}, false
	}
	return data[table_start:table_end], true
}

ttf_table_check_sum :: proc(data: []byte) -> Ttf_u32 {
	sum: Ttf_u32
	data_len := len(data)
	for i := 0; i < data_len; i += 4 {
		sum += (cast(^Ttf_u32)(&data[i]))^
	}
	return sum
}

ttf_parse_head_table :: proc(ctx: ^Ttf_Read_Context, table: Ttf_Table_Blob) -> (^Ttf_Table_Head, bool) {
	@(static) _dummy: Ttf_Table_Head
	result: ^Ttf_Table_Head = &_dummy
	if table.valid {
		reader := Ttf_Reader { ctx, table.data, 0 }
		head, _ := ttf_read_t_ptr(Ttf_Table_Head, &reader)
		if head.magic_number != TTF_TABLE_HEAD_MAGIC {
			ctx.ok = false
		}
		result = head
	} else {
		ctx.ok = false
	}
	return result, ctx.ok
}

ttf_parse_maxp_table :: proc(ctx: ^Ttf_Read_Context, table: Ttf_Table_Blob) -> (^Ttf_Table_Maxp, bool) {
	@(static) _dummy: Ttf_Table_Maxp
	result: ^Ttf_Table_Maxp = &_dummy
	if table.valid {
		reader := Ttf_Reader { ctx, table.data, 0 }
		result, _ = ttf_read_t_ptr(Ttf_Table_Maxp, &reader)
	} else {
		ctx.ok = false
	}
	return result, ctx.ok
}

ttf_parse_hhea_table :: proc(ctx: ^Ttf_Read_Context, table: Ttf_Table_Blob) -> (^Ttf_Table_Horizontal_Header, bool) {
	@(static) _dummy: Ttf_Table_Horizontal_Header
	result: ^Ttf_Table_Horizontal_Header = &_dummy
	if table.valid {
		reader := Ttf_Reader { ctx, table.data, 0 }
		result, _ = ttf_read_t_ptr(Ttf_Table_Horizontal_Header, &reader)
	} else {
		ctx.ok = false
	}
	return result, ctx.ok
}

ttf_parse_cmap_table :: proc(ctx: ^Ttf_Read_Context, table: Ttf_Table_Blob, allowed_formats: Ttf_Cmap_Formats, allocator: mem.Allocator) -> ([]Ttf_Character_Map, bool) {
	mapping: []Ttf_Character_Map
	if table.valid {
		reader := Ttf_Reader { ctx, table.data, 0 }
		loca, _ := ttf_read_t_ptr(Ttf_Table_Cmap_Index, &reader)
		subtables, _ := ttf_read_t_slice(Ttf_Table_Cmap_Sub, &reader, i64(loca.number_subtables))

		subtable_reader: Ttf_Reader
		best_format: int = -1

		// NOTE(lucas): search for the best subtable to use
		for s in subtables {
			supported_platform := false
			switch s.platform_id {
			case .unicode:
				supported_platform = true
			case .microsoft:
				// NOTE(lucas): 1 and 10 map to unicode for microsoft platform, if it ain't unicode we
				// don't support it
				supported_platform = s.platform_specific_id == 1 || s.platform_specific_id == 10
			case .macintosh:
			}

			if supported_platform {
				offset_i64 := i64(s.offset)
				subtable_data, ok := ttf_get_table_from_directory(ctx, offset_i64, i64(len(table.data)) - offset_i64, table.data)
				if ok {
					maybe_subtable_reader := Ttf_Reader { ctx, subtable_data, 0 }
					format, _ := ttf_read_t_copy(Ttf_u16, &maybe_subtable_reader)
					maybe_subtable_reader.offset = 0
					switch {
					case format == 4 && best_format != 12 && ._4 in allowed_formats:
						best_format = 4
						subtable_reader = maybe_subtable_reader
					case format == 12 && ._12 in allowed_formats:
						best_format = 12
						subtable_reader = maybe_subtable_reader
					}
				}
			}
		}

		mapping_i := u32(0)
		// Parse the best subtable if we have one
		switch best_format {
		case 4:
			format_4_header, _ := ttf_read_t_ptr(Ttf_Table_Cmap_Format_4, &subtable_reader)
			seg_count := i64(format_4_header.seg_count_x2 / 2)
			end_codes, _ := ttf_read_t_slice(Ttf_u16, &subtable_reader, seg_count)
			ttf_read_t_copy(Ttf_u16, &subtable_reader)
			start_codes, _ := ttf_read_t_slice(Ttf_u16, &subtable_reader, seg_count)
			id_deltas, _ := ttf_read_t_slice(Ttf_u16, &subtable_reader, seg_count)
			id_range_offset, _ := ttf_read_t_slice(Ttf_u16, &subtable_reader, seg_count)
			if ctx.ok {
				end_of_table := uintptr(&subtable_reader.data[len(subtable_reader.data) - 1])

				sparse_lookup := soa_zip(end = end_codes, start = start_codes, delta = id_deltas, offset = id_range_offset)

				n_maps: u32
				for lookup in sparse_lookup {
					n_maps += u32(lookup.end) - u32(lookup.start) + 1
				}

				mapping = make([]Ttf_Character_Map, n_maps, allocator)

				for lookup, i in sparse_lookup {
					base_offset := lookup.offset
					for c in lookup.start..=lookup.end {
						if lookup.offset == 0 {
							mapping[mapping_i] = { rune(c), u32(c + lookup.delta) }
							mapping_i += 1
						} else {
							index_of_mapping_byte := base_offset + 2 * (c - lookup.start)
							delta_location := uintptr(&id_range_offset[i]) + uintptr(index_of_mapping_byte)
							if delta_location + 1 <= end_of_table {
								glyph_index := (cast(^u16be)delta_location)^
								if glyph_index != 0 {
									glyph_index += lookup.delta
								}
								mapping[mapping_i] = { rune(c), u32(glyph_index) }
								mapping_i += 1
							} else {
								ctx.ok = false
							}
						}
					}
				}
			}
		case 12:
			format_12_header, _ := ttf_read_t_ptr(Ttf_Table_Cmap_Format_12, &subtable_reader)

			subtable_reader_copy := subtable_reader

			n_maps: u32
			for _ in 0..<format_12_header.n_groups {
				group, _ := ttf_read_t_ptr(Ttf_Table_Cmap_Format_12_Group, &subtable_reader)
				n_maps += u32(group.end_char_code - group.start_char_code) + 1
			}

			subtable_reader = subtable_reader_copy

			mapping = make([]Ttf_Character_Map, n_maps, allocator)
			for _ in 0..<format_12_header.n_groups {
				group, _ := ttf_read_t_ptr(Ttf_Table_Cmap_Format_12_Group, &subtable_reader)
				for g in group.start_char_code..=group.end_char_code {
					mapping[mapping_i] = { rune(g), u32(group.start_glyph_code + g - group.start_char_code) }
					mapping_i += 1
				}
			}
		case: ctx.ok = false
		}
	} else {
		ctx.ok = false
	}
	return mapping, ctx.ok
}

ttf_parse_loca_table :: proc(ctx: ^Ttf_Read_Context, table: Ttf_Table_Blob, head: ^Ttf_Table_Head, maxp: ^Ttf_Table_Maxp, allocator: mem.Allocator) -> ([]Ttf_Glyph_Loca, bool) {
	result := make([]Ttf_Glyph_Loca, maxp.num_glyphs, allocator)
	reader := Ttf_Reader { ctx, table.data, 0 }
	if head.index_to_loc_format == 0 {
		shorts, shorts_ok := ttf_read_t_slice(Ttf_u16, &reader, i64(len(result) + 1))
		if shorts_ok {
			for _, i in result {
				result[i] = {
					u32(shorts[i]) * 2,
					u32(shorts[i + 1] - shorts[i]) * 2
				}
			}
		}
	} else {
		longs, longs_ok := ttf_read_t_slice(Ttf_u32, &reader, i64(len(result) + 1))
		if longs_ok {
			for _, i in result {
				 result[i] = {
					u32(longs[i]),
					u32((longs[i + 1] - longs[i]))
				}
			}
		}
	}

	return result, ctx.ok
}

Ttf_Parse_Glyf_Table_Result :: struct {
	glyphs: []Ttf_Glyph,
	global_min: [2]f32,
	global_max: [2]f32,
}

ttf_parse_glyf_table :: proc(ctx: ^Ttf_Read_Context, table: Ttf_Table_Blob, locas: []Ttf_Glyph_Loca, maxp: ^Ttf_Table_Maxp, allocator: mem.Allocator, scratch: ^base.Arena) -> (Ttf_Parse_Glyf_Table_Result, bool) {
	glyphs := make([]Ttf_Glyph, len(locas), allocator)
	global_min: [2]f32 = math.INF_F32
	global_max: [2]f32 = math.NEG_INF_F32
	glyphs_i := 0
	// NOTE(lucas): we use u64 here because loca contains u32's
	table_len := u64(len(table.data))
	for loca in locas[:] {
		defer glyphs_i += 1
		// This is equivalent to an empty single glyph
		if loca.length == 0 {
			continue
		}
		start_offset := u64(loca.offset)
		end_offset := u64(loca.offset) + u64(loca.length)
		if start_offset > table_len || end_offset > table_len {
			ctx.ok = false
			continue
		}
		reader_data := table.data[start_offset:end_offset]
		reader := Ttf_Reader { ctx, reader_data, 0 }
		head, _ := ttf_read_t_copy(Ttf_Glyf_Table, &reader)
		if head.number_of_contours < 0 { // Compound glpyh
			has_instructions := false
			flags := Ttf_Glyf_Compound_Flags { .more_components }
			for ctx.ok && (.more_components in flags) {
				flags = ttf_read_t_copy(Ttf_Glyf_Compound_Flags, &reader)
				glyph_index := ttf_read_t_copy(Ttf_u16, &reader)
				_ = glyph_index

				arg_1, arg_2: u16
				if .args_1_and_2_are_words in flags {
					arg_1 = u16(ttf_read_t_copy(Ttf_u16, &reader))
					arg_2 = u16(ttf_read_t_copy(Ttf_u16, &reader))
				} else {
					arg_1 = u16(ttf_read_t_copy(u8, &reader))
					arg_2 = u16(ttf_read_t_copy(u8, &reader))
				}
				if .we_have_a_scale in flags {
					ttf_read_t_copy(Ttf_F2Dot14, &reader)
				}
				if .we_have_an_x_and_y_scale in flags {
					ttf_read_t_copy(Ttf_F2Dot14, &reader)
					ttf_read_t_copy(Ttf_F2Dot14, &reader)
				}
				if .we_have_a_two_by_two in flags {
					ttf_read_t_copy(Ttf_F2Dot14, &reader)
					ttf_read_t_copy(Ttf_F2Dot14, &reader)
					ttf_read_t_copy(Ttf_F2Dot14, &reader)
					ttf_read_t_copy(Ttf_F2Dot14, &reader)
				}
				has_instructions |= .we_have_instructions in flags
			}

			glyphs[glyphs_i] = {}
		} else {
			end_pt_of_contours := ttf_read_t_slice(Ttf_u16, &reader, i64(head.number_of_contours))
			number_of_points := len(end_pt_of_contours) == 0 ? 0 : int(end_pt_of_contours[len(end_pt_of_contours) - 1]) + 1
			instruction_length := ttf_read_t_copy(Ttf_u16, &reader)
			instructions := ttf_read_t_slice(u8, &reader, i64(instruction_length))
			flags: []Ttf_Glyf_Single_Flags
			// NOTE(lucas): parse flags
			{
				reader_copy := reader
				flags_parsed := 0
				flags_bytes_parsed := 0
				for flags_parsed < number_of_points {
					flag := ttf_read_t_copy(Ttf_Glyf_Single_Flags, &reader)
					flags_bytes_parsed += 1
					flags_parsed += 1
					if .repeat in flag {
						flags_parsed += int(ttf_read_t_copy(u8, &reader))
						flags_bytes_parsed += 1
					}
				}
				reader = reader_copy
				flags = ttf_read_t_slice(Ttf_Glyf_Single_Flags, &reader, i64(flags_bytes_parsed))
			}
			// NOTE(lucas): parse coordinates
			_parse_coordinate :: proc(short_vec_flag: Ttf_Glyf_Single_Flag, is_same_flag: Ttf_Glyf_Single_Flag, number_of_points: int, flags: []Ttf_Glyf_Single_Flags, reader: ^Ttf_Reader, write_coordinate: [][2]f32, coord_index: int, write_on_curve_points: []bool) {
				flags_parsed := 0
				coordinates_added := 0
				prev_coordinate: i16
				for flags_parsed < len(flags) {
					flag := flags[flags_parsed]
					flags_parsed += 1
					repeat_count := 1
					if .repeat in flag {
						repeat_count = int((transmute(u8)flags[flags_parsed])) + 1
						flags_parsed += 1
					}
					is_short := short_vec_flag in flag
					is_same := is_same_flag in flag
					for _ in 0..<repeat_count {
						coordinate: i16
						switch {
						case is_short && is_same:
							coordinate = i16(ttf_read_t_copy(u8, reader))
						case is_short && ! is_same:
							coordinate = -i16(ttf_read_t_copy(u8, reader))
						case ! is_short && ! is_same:
							coordinate = i16(ttf_read_t_copy(Ttf_i16, reader))
						}
						coordinate += prev_coordinate
						prev_coordinate = coordinate
						write_coordinate[coordinates_added][coord_index] = f32(coordinate)
						write_on_curve_points[coordinates_added] = .on_curve in flag
						coordinates_added += 1
					}
				}
			}
			glyph: Ttf_Glyph
			glyph.points = make(#soa[]Ttf_Glyph_Contour_Point, number_of_points, allocator)
			glyph.ordered_contour_lengths = make([]u16, len(end_pt_of_contours), allocator)
			max_potential_length := i64(0)
			for contour, i in end_pt_of_contours {
				glyph.ordered_contour_lengths[i] = u16(contour) + 1
				// NOTE(lucas): we add 1 again to account for the unhinted curves having the last
				// point set to the first point
				max_potential_length += i64(glyph.ordered_contour_lengths[i]) + 1
				if (i > 0 && glyph.ordered_contour_lengths[i - 1] >= glyph.ordered_contour_lengths[i]) {
					ctx.ok = false
				}
			}
			coord, on_curve := soa_unzip(glyph.points)
			_parse_coordinate(.x_short_vector, .x_is_same, number_of_points, flags, &reader, coord, 0, on_curve)
			_parse_coordinate(.y_short_vector, .y_is_same, number_of_points, flags, &reader, coord, 1, on_curve)
			{
				base.arena_temp_scope(scratch)
				types := make([dynamic]Glyph_Coordinate_Type, 0, max_potential_length * 2, scratch)
				points := make([dynamic][2]f32, 0, max_potential_length * 2, scratch)
				types_i := 0

				start := 0
				for contour_end_index in glyph.ordered_contour_lengths {
					actual_length := int(contour_end_index) - start
					if actual_length > 0 {
						append(&types, Glyph_Coordinate_Type.new_curve)
					}
					quadratic_patch_point := 0
					for i := 0; i < actual_length; i += 1 {
						p0 := glyph.points[i + start]
						if p0.on_curve {
							// NOTE(lucas): p0 is on the curve so we just commit it as a point
							append(&points, p0.coord)
							append(&types, Glyph_Coordinate_Type.point)
						} else {
							// NOTE(lucas) p0 is not on the curve so we have some quadratic curve to solve
							append(&points, p0.coord)
							if i != 0 {
								p1 := glyph.points[(i + 1) % actual_length + start]
								new_point: [2]f32
								if p1.on_curve {
									new_point = p1.coord
									i += 1 // NOTE(lucas): don't double count this coordinate
								} else {
									// NOTE(lucas): implied point between p0 and p1
									new_point = (p0.coord + p1.coord) * 0.5
								}
								append(&points, new_point)
								append(&types, Glyph_Coordinate_Type.quadratic)
							} else {
								// NOTE(lucas): we do not have a on curve point yet! That means we'll need
								// to patch in the 0th element later.
								append(&types, Glyph_Coordinate_Type.point)
								quadratic_patch_point = len(points) - 1
							}
						}
					}
					p0 := glyph.points[start]
					if p0.on_curve {
						append(&points, p0.coord)
						append(&types, Glyph_Coordinate_Type.point)
					} else if actual_length > 0 {
						// NOTE(lucas): patch the quadratic
						points[quadratic_patch_point] = points[len(points) - 1]
					}
					start = actual_length
				}

				glyph.unhinted_curves = { slice.clone(points[:], allocator), slice.clone(types[:]) }
			}
			glyph.min = { f32(i16(head.x_min)), f32(i16(head.y_min)) }
			glyph.max = { f32(i16(head.x_max)), f32(i16(head.y_max)) }
			global_min = linalg.min(glyph.min, global_min)
			global_max = linalg.max(glyph.max, global_max)
			glyph.hinting_instructions = slice.clone(instructions, allocator)
			glyphs[glyphs_i] = glyph
		}
	}

	result := Ttf_Parse_Glyf_Table_Result {
		glyphs,
		global_min,
		global_max,
	}

	return result, ctx.ok
}

ttf_from_data :: proc(data: []byte, allocator: mem.Allocator) -> (_result: Ttf_Font, _ok: bool) {
	context.logger = log.create_console_logger()

	allocator := allocator
	arena, arena_err := base.arena_make(backing_allocator = allocator)
	if arena_err != nil {
		return {}, false
	}
	allocator = arena

	ctx: Ttf_Read_Context = { ok = true }
	defer if ! ctx.ok {
		base.arena_delete(arena)
	}

	reader := Ttf_Reader { &ctx, data, 0 }

	ttf_offset_subtable, _ := ttf_read_t_ptr(Ttf_Offset_Subtable, &reader)
	switch ttf_offset_subtable.scalar_type {
	case 0x74727565, 0x00010000:
	case 0x4F54544F: fallthrough
	case:
		log.error("[Ttf parser] Unsupported table font type")
		ctx.ok = false
		// HACK(lucas): just to get around post script tables
		return {}, true
	}
	ttf_tables, _ := ttf_read_t_slice(Ttf_Table_Directory, &reader, i64(ttf_offset_subtable.num_tables))

	parsed_table_tags: Ttf_Tags
	parsed_table_data: [Ttf_Tag]Ttf_Table_Blob

	// NOTE(lucas): gather tables
	for &table in ttf_tables {
		tag := ttf_u32_to_tag(table.tag)
		table_data, table_ok := ttf_get_table_from_directory(&ctx, i64(table.offset), i64(table.length), data); if table_ok {
			parsed_table_tags += { tag }
			parsed_table_data[tag] = { &table, table_data, true }
		}
	}

	if TTF_REQUIRED_TABLES - parsed_table_tags != {} {
		ctx.ok = false
		log.errorf("[Ttf parser] Some required tables are missing: %v", TTF_REQUIRED_TABLES - parsed_table_tags)
	}

	// NOTE(lucas): validate checksums
	for tag in parsed_table_tags {
		if tag == .unknown {
			continue
		}

		parsed_info := parsed_table_data[tag]
		if ! parsed_info.valid {
			ctx.ok = false
		}
		if tag == .head {
			checksum := ttf_table_check_sum(data)
			if 0xB1B0AFBA - checksum != 0 {
				log.errorf("[Ttf parser] table %v has a bad checksum", tag)
				ctx.ok = false
			}
		} else {
			if ttf_table_check_sum(parsed_info.data) != parsed_info.directory.check_sum {
				log.errorf("[Ttf parser] table %v has a bad checksum", tag)
				ctx.ok = false
			}
		}
	}

	scratch := base.arena_scratch({ allocator })

	head := ttf_parse_head_table(&ctx, parsed_table_data[.head]) or_return
	hhea := ttf_parse_hhea_table(&ctx, parsed_table_data[.hhea]) or_return
	maxp := ttf_parse_maxp_table(&ctx, parsed_table_data[.maxp]) or_return
	locas := ttf_parse_loca_table(&ctx, parsed_table_data[.loca], head, maxp, scratch.arena) or_return
	mapping := ttf_parse_cmap_table(&ctx, parsed_table_data[.cmap], TTF_CMAP_FORMATS_ALL, scratch.arena) or_return
	glyf_result := ttf_parse_glyf_table(&ctx, parsed_table_data[.glyf], locas, maxp, allocator, scratch.arena) or_return
	codepoint_to_glyph_index_map := make(map[rune]u32, len(mapping) * 2, allocator)
	for m in mapping {
		if m.glyph_index != 0 {
			codepoint_to_glyph_index_map[m.codepoint] = m.glyph_index
		}
	}

	result := Ttf_Font {
		codepoint_to_glyph_index_map,
		glyf_result.glyphs,
		glyf_result.global_min, glyf_result.global_max,
		f32(head.units_per_em),
		f32(hhea.ascender),
		f32(hhea.descender),
		f32(hhea.line_gap),
		arena,
	}
	return result, ctx.ok
}

ttf_from_file_path :: proc(path: string, allocator: mem.Allocator) -> (_result: Ttf_Font, _ok: bool) {
	scratch := base.arena_scratch({ allocator })
	data := os.read_entire_file(path, scratch.arena) or_return
	defer delete(data, scratch.arena)
	return ttf_from_data(data, allocator)
}

ttf_delete :: proc(f: ^Ttf_Font) {
	if f != nil {
		base.arena_delete(f.arena)
		f^ = {}
	}
}


