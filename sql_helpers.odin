package src

import "core:fmt"
import "core:strings"
import "core:runtime"
import "core:reflect"
import "core:mem"
import sql "../sqlite3"

Result_Code :: sql.ResultCode
Stmt :: sql.Stmt
db: ^sql.sqlite3
db_cache: map[string]^Stmt

db_init :: proc(name: cstring) -> (err: Result_Code) {
	sql.open(name, &db) or_return
	return
}

db_destroy :: proc() -> (err: Result_Code) {
	sql.close(db) or_return
	return
}

db_check :: proc(err: Result_Code, loc := #caller_location) {
	if err == .ERROR || err == .CONSTRAINT || err == .MISUSE {
		text := fmt.tprintf("%s %v %s", err, sql.errmsg(db), loc)
		panic(text)
	}
}

// does not do caching
db_execute_simple :: proc(cmd: string) -> (err: Result_Code) {
	data := mem.raw_string_data(cmd)
	stmt: ^Stmt
	sql.prepare_v2(db, data, i32(len(cmd)), &stmt, nil) or_return
	db_run(stmt) or_return
	sql.finalize(stmt) or_return
	return
}

// execute cached with args
db_execute :: proc(cmd: string, args: ..any) -> (err: Result_Code) {
	stmt := db_cache_prepare(cmd) or_return
	db_bind(stmt, ..args) or_return
	db_bind_run(stmt) or_return
	return
}

// simple run through statement
db_run :: proc(stmt: ^Stmt) -> (err: Result_Code) {
	for {
		result := sql.step(stmt)

		if result == .DONE {
			break
		} else if result != .ROW {
			return result
		}
	}

	return
}

// set a cap to the cache
db_cache_cap :: proc(cap: int) {
	db_cache = make(map[string]^Stmt, cap)		
}

// return cached stmt or create one
db_cache_prepare :: proc(cmd: string) -> (stmt: ^Stmt, err: Result_Code) {
	if existing_stmt := db_cache[cmd]; existing_stmt != nil {
		stmt = existing_stmt
	} else {
		data := mem.raw_string_data(cmd);
		sql.prepare_v2(db, data, i32(len(cmd)), &stmt, nil); 
		db_cache[cmd] = stmt
	}

	return
}

// strings are not deleted
db_cache_destroy :: proc() {
	for _, stmt in db_cache {
		sql.finalize(stmt)
	}
}

// simple execute -> no cache
// bindings -> maybe cache
// step once	-> 
// struct getters	

db_bind_run :: proc(stmt: ^Stmt) -> (err: Result_Code) {
	db_run(stmt) or_return
	sql.reset(stmt) or_return
	sql.clear_bindings(stmt) or_return
	return
}

// bind primitive arguments to input statement
db_bind :: proc(stmt: ^Stmt, args: ..any) -> (err: Result_Code) {
	for arg, index in args {
		// index starts at 1 in binds
		index := index + 1
		ti := runtime.type_info_base(type_info_of(arg.id))

		if arg == nil {
			sql.bind_null(stmt, i32(index)) or_return
			continue
		}

		// only allow slice of bytes
		if arg.id == []byte {
			slice := cast(^mem.Raw_Slice) arg.data
			sql.bind_blob(
				stmt, 
				i32(index), 
				cast(^u8) arg.data, 
				i32(slice.len), 
				sql.STATIC,
			) or_return
			continue
		}

		#partial switch info in ti.variant {
			case runtime.Type_Info_Integer: {
				// TODO actually use int64 for i64
				value, valid := reflect.as_i64(arg)
				
				if valid {
					sql.bind_int(stmt, i32(index), i32(value)) or_return
				} else {
					return .ERROR
				}
			}

			case runtime.Type_Info_Float: {
				value, valid := reflect.as_f64(arg)
				if valid {
					sql.bind_double(stmt, i32(index), f64(value)) or_return
				} else {
					return .ERROR					
				}
			}

			case runtime.Type_Info_String: {
				text, valid := reflect.as_string(arg)
				
				if valid {
					data := mem.raw_string_data(text)
					sql.bind_text(stmt, i32(index), data, i32(len(text)), sql.STATIC) or_return
				} else {
					return .ERROR
				}
			}
		}

		// fmt.println(stmt, arg, index)
	}

	return
}

// data from the struct has to match wanted column names
// changes the cmd string to the arg which should be a struct
db_select :: proc(cmd_end: string, struct_arg: any, args: ..any) -> (err: Result_Code) {
	b := strings.builder_make_len_cap(0, 128)
	defer strings.builder_destroy(&b)

	strings.write_string(&b, "SELECT ")

	ti := runtime.type_info_base(type_info_of(struct_arg.id))
	struct_info := ti.variant.(runtime.Type_Info_Struct)
	for name, i in struct_info.names {
		strings.write_string(&b, name)

		if i != len(struct_info.names) - 1 {
			strings.write_byte(&b, ',')
		} else {
			strings.write_byte(&b, ' ')
		}
	}

	strings.write_string(&b, cmd_end)

	full_cmd := strings.to_string(b)
	// fmt.println(full_cmd)
	stmt := db_cache_prepare(full_cmd) or_return
	db_bind(stmt, ..args) or_return

	for {
		result := sql.step(stmt)

		if result == .DONE {
			break
		} else if result != .ROW {
			return result
		}

		// get column data per struct field
		for i in 0..<len(struct_info.names) {
			type := struct_info.types[i].id
			offset := struct_info.offsets[i]
			struct_value := any { rawptr(uintptr(struct_arg.data) + offset), type }
			db_any_column(stmt, i32(i), struct_value) or_return
		}
	}

	return
}

db_any_column :: proc(stmt: ^Stmt, column_index: i32, arg: any) -> (err: Result_Code) {
	ti := runtime.type_info_base(type_info_of(arg.id))
	#partial switch info in ti.variant {
		case runtime.Type_Info_Integer: {
			value := sql.column_int(stmt, column_index)
			// TODO proper i64

			switch arg.id {
				case i8: (cast(^i8) arg.data)^ = i8(value)
				case i16: (cast(^i16) arg.data)^ = i16(value)
				case i32: (cast(^i32) arg.data)^ = value
				case i64: (cast(^i64) arg.data)^ = i64(value)
			}
		}	

		case runtime.Type_Info_Float: {
			value := sql.column_double(stmt, column_index)

			switch arg.id {
				case f32: (cast(^f32) arg.data)^ = f32(value)
				case f64: (cast(^f64) arg.data)^ = value
			}			
		}

		case runtime.Type_Info_String: {
			value := sql.column_text(stmt, column_index)

			switch arg.id {
				case string: {
					(cast(^string) arg.data)^ = strings.clone(
						string(value), 
						context.temp_allocator,
					)
				}

				case cstring: {
					(cast(^cstring) arg.data)^ = strings.clone_to_cstring(
						string(value), 
						context.temp_allocator,
					)
				}
			}
		}
	}

	return
}

// auto insert INSERT INTO cmd_names VALUES (...)
db_insert :: proc(cmd_names: string, args: ..any) -> (err: Result_Code) {
	b := strings.builder_make_len_cap(0, 128)
	defer strings.builder_destroy(&b)

	strings.write_string(&b, "INSERT INTO ")
	strings.write_string(&b, cmd_names)
	strings.write_string(&b, " VALUES ")

	strings.write_byte(&b, '(')
	for arg, i in args {
			fmt.sbprintf(&b, "?%d", i + 1)

		if i != len(args) - 1 {
			strings.write_byte(&b, ',')
		}
	}
	strings.write_byte(&b, ')')

	full_cmd := strings.to_string(b)
	// fmt.println(full_cmd)

	stmt := db_cache_prepare(full_cmd) or_return
	db_bind(stmt, ..args) or_return
	db_bind_run(stmt) or_return
	return
}