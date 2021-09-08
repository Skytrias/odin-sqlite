// package yours

import "core:fmt"
import "core:mem"
import "core:strings"
import "core:runtime"
import "sql"

Stmt :: sql.Stmt;
db: ^sql.sqlite3;

// helper to bind odin string to stmt
db_bind_text :: proc(stmt: ^sql.Stmt, index: int, text: string) {
	data := mem.raw_string_data(text);
	db_check(sql.bind_text(
		stmt, 
		i32(index), 
		data, 
		len(text), 
		// len(text) + size_of(byte), NOTE DOESNT WORK
		// auto_cast sql.STATIC,
		// auto_cast sql.TRANSIENT,

		proc "c" (input: rawptr) { 
			input := input;
			input = cast(rawptr) sql.STATIC;
			// input = cast(rawptr) sql.TRANSIENT;
		},
	));
}

// error checker
db_check :: proc(result: sql.ResultCode, loc := #caller_location) {
	if result == .ERROR || result == .CONSTRAINT || result == .MISUSE {
		text := fmt.tprintf("%s %v %s", result, sql.errmsg(db), loc);
		panic(text);
	}
}

@(deferred_out=db_destroy)
db_scoped_init :: proc(db: ^^sql.sqlite3, name: cstring) -> ^sql.sqlite3 {
	db_check(sql.open(name, db));
	return db^;
}

db_destroy :: proc(db: ^sql.sqlite3) {
	db_check(sql.close(db));
}

// prepare sql persistent sql statement
db_prepare_bind :: proc(stmt: ^^sql.Stmt, cmd: string, loc := #caller_location) {
	data := mem.raw_string_data(cmd);
	result := sql.prepare_v2(db, data, i32(len(cmd)), stmt, nil); 
	db_check(result, loc);
}

// prepare sql stmt through string, return initialized stmt, deferred cleanup
@(deferred_out=db_finalize)
db_prepare_scoped :: proc(cmd: string, loc := #caller_location) -> (stmt: ^sql.Stmt) {
	data := mem.raw_string_data(cmd);
	result := sql.prepare_v2(db, data, i32(len(cmd)), &stmt, nil); 
	db_check(result, loc);
	return stmt;
}

db_finalize :: proc(stmt: ^sql.Stmt) {
	db_check(sql.finalize(stmt));
}

// prepares sql cmd, calls the stmt, cleans up memory at end, with procedure 
db_execute :: proc(cmd: string, loc := #caller_location) {
	stmt := db_prepare_scoped(cmd, loc);
	db_step_simple(stmt);
}

// prepares sql cmd, calls the stmt, cleans up memory at end, with procedure 
db_execute_custom :: proc(cmd: string, data: rawptr, call: proc(stmt: ^sql.Stmt, data: rawptr), loc := #caller_location) {
	stmt := db_prepare_scoped(cmd, loc);
	db_step_custom(stmt, data, call, loc);
}

// calls sql statement, without removing the compiled stmt, only resets it
db_execute_bound :: proc(stmt: ^sql.Stmt, loc := #caller_location) {
	db_step_simple(stmt);
	db_check(sql.reset(stmt));
	db_check(sql.clear_bindings(stmt));
}

// prepares sql cmd, calls the stmt, cleans up memory at end, with procedure 
db_execute_bound_custom :: proc(stmt: ^sql.Stmt, data: rawptr, call: proc(stmt: ^sql.Stmt, data: rawptr), loc := #caller_location) {
	db_step_custom(stmt, data, call, loc);
	db_check(sql.reset(stmt));
	db_check(sql.clear_bindings(stmt));
}

// simple stepping through sql stmt
db_step_simple :: proc(stmt: ^sql.Stmt, loc := #caller_location) {
	result: sql.ResultCode;

	for {
		result = sql.step(stmt);

		if result == .DONE {
			return;
		} else if result != .ROW {
			text := fmt.tprintf("%s %v %s", loc, result, sql.errmsg(db));
			panic(text);
		}
	}
}

// stepping through sql stmt closure and custom data
db_step_custom :: proc(stmt: ^sql.Stmt, data: rawptr, call: proc(stmt: ^sql.Stmt, data: rawptr), loc := #caller_location) {
	result: sql.ResultCode;
	assert(call != nil);

	for {
		result = sql.step(stmt);

		#partial switch result {
			case .ROW: {
				call(stmt, data);
			}
			case .DONE: {
				return;
			}
			case: {
				text := fmt.tprintf("%s %v %s", loc, result, sql.errmsg(db));
				panic(text);
			}
		}
	}			
}

// NOTE: use only when you know the sql statement will run once
// runs only one step and asserts for safety
// deferred reset on stmt 
@(deferred_in=db_step_once_end)
db_step_once :: proc(stmt: ^sql.Stmt) {
	result := sql.step(stmt);
	assert(result == .ROW || result == .DONE);
}

db_step_once_end :: proc(stmt: ^sql.Stmt) {
	assert(sql.step(stmt) == .DONE);
	db_check(sql.reset(stmt));
	db_check(sql.clear_bindings(stmt));
}

// helper to get an odin string valid till next sql.step
db_column_string :: proc(stmt: ^sql.Stmt, column: i32) -> string {
	byte_start := sql.column_text(stmt, column);	
	length := cast(int) sql.column_bytes(stmt, column);
	return strings.string_from_ptr(byte_start, length);
}

db_enable_tracing :: proc(flags: sql.TraceFlags) {
	db_check(sql.trace_v2(
		db, 
		flags,
		proc "c" (mask: sql.TraceFlag, x, y, z: rawptr) -> i32 {
			context = runtime.default_context();

			switch mask {
				case .STMT: {
					text := cstring(z);
					// fmt.printf("STMT %d stmt: %x text: %s \n", mask, y, text);
					fmt.println("STMT", sql.expanded_sql(cast(^Stmt) y));
				}
				case .PROFILE: {
					estimated := (cast(^i64) z)^;
					fmt.printf("PROFILE %d stmt: %x time: %dns \n", mask, y, estimated);
				}
				case .ROW: {
					fmt.printf("ROW %d stmt: %x\n", mask, y);
				}
				case .CLOSE: {
					fmt.printf("CLOSE %d stmt: %x\n", mask, y);
				}
			}

			return 0;
		},
		nil,
	));
}