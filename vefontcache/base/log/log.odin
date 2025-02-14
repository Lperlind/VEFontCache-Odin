package topdog_base_log

import "core:encoding/ansi"
import "core:fmt"
import "core:strings"
import "core:os"
import "core:os/os2"
import "core:time"
import "core:slice"
import "core:mem"

import "base:runtime"

// NOTE(bill, 2019-12-31): These are defined in `package runtime` as they are used in the `context`. This is to prevent an import definition cycle.

/*
Logger_Level :: enum {
	Debug   = 0,
	Info    = 10,
	Warning = 20,
	Error   = 30,
	Fatal   = 40,
}
*/
Level :: runtime.Logger_Level

/*
Option :: enum {
	Level,
	Date,
	Time,
	Short_File_Path,
	Long_File_Path,
	Line,
	Procedure,
	Terminal_Color
}
*/
Option :: runtime.Logger_Option

/*
Options :: bit_set[Option];
*/
Options :: runtime.Logger_Options

Full_Timestamp_Opts :: Options{
	.Date,
	.Time,
}
Location_Header_Opts :: Options{
	.Short_File_Path,
	.Long_File_Path,
	.Line,
	.Procedure,
}
Location_File_Opts :: Options{
	.Short_File_Path,
	.Long_File_Path,
}


/*
Logger_Proc :: #type proc(data: rawptr, level: Level, text: string, options: Options, location := #caller_location);
*/
Logger_Proc :: runtime.Logger_Proc

/*
Logger :: struct {
	procedure:    Logger_Proc,
	data:         rawptr,
	lowest_level: Level,
	options:      Logger_Options,
}
*/
Logger :: runtime.Logger

nil_logger_proc :: runtime.default_logger_proc

nil_logger :: proc() -> Logger {
	return Logger{nil_logger_proc, nil, Level.Debug, nil}
}

debugf :: proc(fmt_str: string, args: ..any, location := #caller_location) {
	logf(.Debug,   fmt_str, ..args, location=location)
}
infof  :: proc(fmt_str: string, args: ..any, location := #caller_location) {
	logf(.Info,    fmt_str, ..args, location=location)
}
warnf  :: proc(fmt_str: string, args: ..any, location := #caller_location) {
	logf(.Warning, fmt_str, ..args, location=location)
}
errorf :: proc(fmt_str: string, args: ..any, location := #caller_location) {
	logf(.Error,   fmt_str, ..args, location=location)
}
fatalf :: proc(fmt_str: string, args: ..any, location := #caller_location) {
	logf(.Fatal,   fmt_str, ..args, location=location)
}

debug :: proc(args: ..any, sep := " ", location := #caller_location) {
	log(.Debug,   ..args, sep=sep, location=location)
}
info  :: proc(args: ..any, sep := " ", location := #caller_location) {
	log(.Info,    ..args, sep=sep, location=location)
}
warn  :: proc(args: ..any, sep := " ", location := #caller_location) {
	log(.Warning, ..args, sep=sep, location=location)
}
error :: proc(args: ..any, sep := " ", location := #caller_location) {
	log(.Error,   ..args, sep=sep, location=location)
}
fatal :: proc(args: ..any, sep := " ", location := #caller_location) {
	log(.Fatal,   ..args, sep=sep, location=location)
}

panic :: proc(args: ..any, location := #caller_location) -> ! {
	log(.Fatal, ..args, location=location)
	runtime.panic("log.panic", location)
}
panicf :: proc(fmt_str: string, args: ..any, location := #caller_location) -> ! {
	logf(.Fatal, fmt_str, ..args, location=location)
	runtime.panic("log.panicf", location)
}

@(disabled=ODIN_DISABLE_ASSERT)
assert :: proc(condition: bool, message := "", loc := #caller_location) {
	if !condition {
		@(cold)
		internal :: proc(message: string, loc: runtime.Source_Code_Location) {
			p := context.assertion_failure_proc
			if p == nil {
				p = runtime.default_assertion_failure_proc
			}
			log(.Fatal, message, location=loc)
			p("runtime assertion", message, loc)
		}
		internal(message, loc)
	}
}

@(disabled=ODIN_DISABLE_ASSERT)
assertf :: proc(condition: bool, fmt_str: string, args: ..any, loc := #caller_location) {
	if !condition {
		// NOTE(dragos): We are using the same trick as in builtin.assert
		// to improve performance to make the CPU not
		// execute speculatively, making it about an order of
		// magnitude faster
		@(cold)
		internal :: proc(loc: runtime.Source_Code_Location, fmt_str: string, args: ..any) {
			p := context.assertion_failure_proc
			if p == nil {
				p = runtime.default_assertion_failure_proc
			}
			message := fmt.tprintf(fmt_str, ..args)
			log(.Fatal, message, location=loc)
			p("Runtime assertion", message, loc)
		}
		internal(loc, fmt_str, ..args)
	}
}



log :: proc(level: Level, args: ..any, sep := " ", location := #caller_location) {
	logger := context.logger
	if logger.procedure == nil || logger.procedure == nil_logger_proc {
		return
	}
	if level < logger.lowest_level {
		return
	}
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	str := fmt.tprint(..args, sep=sep) //NOTE(Hoej): While tprint isn't thread-safe, no logging is.
	logger.procedure(logger.data, level, str, logger.options, location)
}

logf :: proc(level: Level, fmt_str: string, args: ..any, location := #caller_location) {
	logger := context.logger
	if logger.procedure == nil || logger.procedure == nil_logger_proc {
		return
	}
	if level < logger.lowest_level {
		return
	}
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	str := fmt.tprintf(fmt_str, ..args)
	logger.procedure(logger.data, level, str, logger.options, location)
}

Level_Headers := [?]string{
	 0..<10 = "[DEBUG] --- ",
	10..<20 = "[INFO ] --- ",
	20..<30 = "[WARN ] --- ",
	30..<40 = "[ERROR] --- ",
	40..<50 = "[FATAL] --- ",
}

Default_Console_Logger_Opts :: Options{
	.Level,
	.Terminal_Color,
	.Short_File_Path,
	.Line,
	.Procedure,
} | Full_Timestamp_Opts

Default_File_Logger_Opts :: Options{
	.Level,
	.Short_File_Path,
	.Line,
	.Procedure,
} | Full_Timestamp_Opts

@private
File_Type :: enum {
	console,
	os,
	os2,
}

File_Console_Logger_Data :: struct {
	type: File_Type,
	file_handle_os: os.Handle,
	file_handle_os2: ^os2.File,
	ident: string,
	_close_file_on_delete: bool, // Used to retain old create_*_logger behaviour
	allocator: runtime.Allocator,
}

/*
Makes a new logger that will write to the provided `os.Handle`

*Allocates Using Provided Allocator*

Inputs:
- h: An os handle that the logger will write to
- lowest: The lowest level logging to accept
- opt: The wanted logging options
- ident: An identifier that will be written alongside the logged message
- allocator: (default: context.allocator)
- loc: The caller location for debugging purposes (default: `#caller_location`)

Returns:
- res: The new file logger 
- err: An allocator error if one occured, `nil` otherwise 
*/
make_file_logger_os :: proc(
	h: os.Handle,
	lowest := Level.Debug,
	opt := Default_File_Logger_Opts,
	ident := "",
	allocator := context.allocator,
	loc := #caller_location
) -> (
	res: Logger,
	err: runtime.Allocator_Error,
) {
	return _make_file_logger_os(h, lowest, opt, ident, false, allocator, loc)
}

// NOTE(lperlind): this exists just so we can implement old behaviour
@private
_make_file_logger_os :: proc(
	h: os.Handle,
	lowest: Level,
	opt: Options,
	ident: string,
	close_file_on_delete: bool,
	allocator: runtime.Allocator,
	loc := #caller_location
) -> (
	res: Logger,
	err: runtime.Allocator_Error,
) {
	data := new(File_Console_Logger_Data, allocator, loc) or_return
	data.type = .os
	data.file_handle_os = h
	data.ident = ident
	data._close_file_on_delete = close_file_on_delete
	data.allocator = allocator
	return Logger{file_console_logger_proc, data, lowest, opt}, nil
}

/*
Makes a new logger that will write to the provided `^os2.File`

*Allocates Using Provided Allocator*

Inputs:
- f: An os2 file that the logger will write to
- lowest: The lowest level logging to accept
- opt: The wanted logging options
- ident: An identifier that will be written alongside the logged message
- allocator: (default: context.allocator)
- loc: The caller location for debugging purposes (default: `#caller_location`)

Returns:
- res: The new file logger 
- err: An allocator error if one occured, `nil` otherwise 
*/
make_file_logger_os2 :: proc(
	f: ^os2.File,
	lowest := Level.Debug, 
	opt := Default_File_Logger_Opts, 
	ident := "", 
	allocator := context.allocator, 
	loc := #caller_location
) -> (
	res: Logger, 
	err: runtime.Allocator_Error,
) {
	data := new(File_Console_Logger_Data, allocator, loc) or_return
	data.type = .os2
	data.file_handle_os2 = f
	data.ident = ident
	data.allocator = allocator
	return Logger{file_console_logger_proc, data, lowest, opt}, nil
}
make_file_logger :: proc {
	make_file_logger_os,
	make_file_logger_os2,
}

/*
Makes a new logger that will write to `stdout` and `stderr`. `Stdout` will be written to
if the log level is below `Level.Error`, otherwise `stderr` will be written to

*Allocates Using Provided Allocator*

Inputs:
- lowest: The lowest level logging to accept
- opt: The wanted logging options
- ident: An identifier that will be written alongside the logged message
- allocator: (default: context.allocator)
- loc: The caller location for debugging purposes (default: `#caller_location`)

Returns:
- res: The new file logger 
- err: An allocator error if one occured, `nil` otherwise 
*/
make_console_logger :: proc(
	lowest := Level.Debug,
	opt := Default_File_Logger_Opts,
	ident := "",
	allocator := context.allocator,
	loc := #caller_location
) -> (
	res: Logger,
	err: runtime.Allocator_Error,
) {
	data := new(File_Console_Logger_Data, allocator, loc) or_return
	data.type = .console
	data.ident = ident
	data.allocator = allocator
	return Logger{file_console_logger_proc, data, lowest, opt}, nil
}

/*
Deletes a logger made with `make_console_logger` and `make_file_logger`.

Inputs:
- log: The logger to delete
- loc: The caller location for debugging purposes (default: `#caller_location`)
*/
delete_console_logger :: proc(log: Logger, loc := #caller_location) {
	data := cast(^File_Console_Logger_Data)log.data
	// NOTE(lperlind): Old behaviour was to close the file handle on delete.
	// once create_*_logger is removed we can delete this.
	if data._close_file_on_delete {
		switch data.type {
		case .console:
		case .os: os.close(data.file_handle_os)
		case .os2: os2.close(data.file_handle_os2)
		}
	}
	free(data, data.allocator, loc)
}

delete_file_logger :: delete_console_logger

file_console_logger_proc :: proc(logger_data: rawptr, level: Level, text: string, options: Options, location := #caller_location) {
	data := cast(^File_Console_Logger_Data)logger_data
	backing: [1024]byte //NOTE(Hoej): 1024 might be too much for a header backing, unless somebody has really long paths.
	buf := strings.builder_from_bytes(backing[:])

	do_level_header(options, &buf, level)

	when time.IS_SUPPORTED {
		do_time_header(options, &buf, time.now())
	}

	do_location_header(options, &buf, location)

	if .Thread_Id in options {
		// NOTE(Oskar): not using context.thread_id here since that could be
		// incorrect when replacing context for a thread.
		fmt.sbprintf(&buf, "[{}] ", os.current_thread_id())
	}

	if data.ident != "" {
		fmt.sbprintf(&buf, "[%s] ", data.ident)
	}

	//TODO(Hoej): When we have better atomics and such, make this thread-safe
	switch data.type {
	case .console: fmt.fprintf(level < Level.Error ? os.stdout : os.stderr, "%s%s\n", strings.to_string(buf), text)
	case .os: fmt.fprintf(data.file_handle_os, "%s%s\n", strings.to_string(buf), text)
	case .os2: fmt.wprintf(data.file_handle_os2.stream, "%s%s\n", strings.to_string(buf), text)
	}
}

do_level_header :: proc(opts: Options, str: ^strings.Builder, level: Level) {

	RESET     :: ansi.CSI + ansi.RESET           + ansi.SGR
	RED       :: ansi.CSI + ansi.FG_RED          + ansi.SGR
	YELLOW    :: ansi.CSI + ansi.FG_YELLOW       + ansi.SGR
	DARK_GREY :: ansi.CSI + ansi.FG_BRIGHT_BLACK + ansi.SGR

	col := RESET
	switch level {
	case .Debug:   col = DARK_GREY
	case .Info:    col = RESET
	case .Warning: col = YELLOW
	case .Error, .Fatal: col = RED
	}

	if .Level in opts {
		if .Terminal_Color in opts {
			fmt.sbprint(str, col)
		}
		fmt.sbprint(str, Level_Headers[level])
		if .Terminal_Color in opts {
			fmt.sbprint(str, RESET)
		}
	}
}

do_time_header :: proc(opts: Options, buf: ^strings.Builder, t: time.Time) {
	when time.IS_SUPPORTED {
		if Full_Timestamp_Opts & opts != nil {
			fmt.sbprint(buf, "[")
			y, m, d := time.date(t)
			h, min, s := time.clock(t)
			if .Date in opts {
				fmt.sbprintf(buf, "%d-%02d-%02d", y, m, d)
				if .Time in opts {
					fmt.sbprint(buf, " ")
				}
			}
			if .Time in opts { fmt.sbprintf(buf, "%02d:%02d:%02d", h, min, s) }
			fmt.sbprint(buf, "] ")
		}
	}
}

do_location_header :: proc(opts: Options, buf: ^strings.Builder, location := #caller_location) {
	if Location_Header_Opts & opts == nil {
		return
	}
	fmt.sbprint(buf, "[")

	file := location.file_path
	if .Short_File_Path in opts {
		last := 0
		for r, i in location.file_path {
			if r == '/' {
				last = i+1
			}
		}
		file = location.file_path[last:]
	}

	if Location_File_Opts & opts != nil {
		fmt.sbprint(buf, file)
	}
	if .Line in opts {
		if Location_File_Opts & opts != nil {
			fmt.sbprint(buf, ":")
		}
		fmt.sbprint(buf, location.line)
	}

	if .Procedure in opts {
		if (Location_File_Opts | {.Line}) & opts != nil {
			fmt.sbprint(buf, ":")
		}
		fmt.sbprintf(buf, "%s()", location.procedure)
	}

	fmt.sbprint(buf, "] ")
}

Multi_Logger_Data :: struct {
	loggers: []Logger,
	allocator: runtime.Allocator,
}

/*
Makes a new logger that will write to several other loggers.

*Allocates Using Provided Allocator*

Inputs:
- logs: The loggers this logger will write to
- allocator: (default: context.allocator)
- loc: The caller location for debugging purposes (default: `#caller_location`)

Returns:
- res: The new multi logger 
- err: An allocator error if one occured, `nil` otherwise 
*/
make_multi_logger :: proc(logs: ..Logger, allocator := context.allocator, loc := #caller_location) -> (res: Logger, err: runtime.Allocator_Error) {
	// NOTE(lperlind): we allocate the entire logger in a single allocation so we have only one
	// allocation error to be handled. This is NOT for performance
	logger_size := mem.align_forward_int(size_of(Multi_Logger_Data), align_of(Logger))
	content_size := len(mem.slice_to_bytes(logs))

	data_bytes := make([]byte, logger_size + content_size, allocator, loc) or_return
	data := cast(^Multi_Logger_Data)raw_data(data_bytes)
	data.loggers = slice.reinterpret([]Logger, data_bytes[logger_size:])
	assert(len(data.loggers) == len(logs))
	copy(data.loggers, logs)
	data.allocator = allocator

	return Logger{multi_logger_proc, data, Level.Debug, nil}, nil
}

/*
Deletes a logger made with `make_multi_logger`.

Inputs:
- log: The logger to delete
- loc: The caller location for debugging purposes (default: `#caller_location`)
*/
delete_multi_logger :: proc(log: Logger, loc := #caller_location) {
	data := (^Multi_Logger_Data)(log.data)
	free(data, data.allocator, loc)
}

multi_logger_proc :: proc(logger_data: rawptr, level: Level, text: string,
                          options: Options, location := #caller_location) {
	data := cast(^Multi_Logger_Data)logger_data
	for log in data.loggers {
		if level < log.lowest_level {
			return
		}
		log.procedure(log.data, level, text, log.options, location)
	}
}
