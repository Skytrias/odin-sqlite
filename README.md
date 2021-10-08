# odin-sqlite
Simple Sqlite3 bindings for [Odin](https://odin-lang.org/)

Requires built static lib from the [sqlite3 Source Code](https://sqlite.org/download.html)

# New helpers
I realized my old helper code was not on par with what other languages deliver, i.e. go / rust
So i made some adjustments:
1. simple cache system `map[string]^sql.Stmt` that holds prepared statements for reusing
2. use bind system from `sqlite` itself instead of using `core:fmt`
3. `SELECT` helper to allow structs to be filled automatically ~ when column names match the struct field name
4. use `or_return` on `sql.ResultCode` since a lot can fail
5. bind helper to insert `args: ..any` into increasing `sql.bind_*(stmt, arg_index, arg)`

```go
package main

import "core:fmt"
import "src" // <--- my helpers live in my src, up to you

run :: proc() -> (err: src.Result_Code) {
	using src
	db_execute_simple(`DROP TABLE IF EXISTS people`) or_return

	db_execute_simple(`CREATE TABLE IF NOT EXISTS people(
		id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
		number INTEGER DEFAULT 0,
		big_number DECIMAL DEFAULT 0,
		name VARCHAR(30)
	)`) or_return

	db_insert("people (number, name, big_number)", 4, "test", 1.24) or_return

	// above turns into
	// stmt := db_cache_prepare(`INSERT INTO people (number, name, big_number) 
	// 		VALUES (?1, ?2, ?3)
	// 	`) or_return
	// db_bind(stmt, 4, "test", 1.23) or_return
	// db_bind_run(stmt) or_return

	db_execute("UPDATE people SET number = ?1", 3) or_return

	People :: struct {
		id: i32,
		number: i32,
		big_number: f64,
		name: string,
	}

	p1: People
	db_select("FROM people WHERE id = ?1", p1, 1) or_return
	fmt.println(p1)
	
	return
}

main :: proc() {
	using src

	db_check(db_init("testing.db"))
	defer db_check(db_destroy())

	db_cache_cap(64)
	defer db_cache_destroy()

	err := run()
	fmt.println(err)
}
```

prints

```go
People{id = 1, number = 3, big_number = 1.240, name = test}
OK
```

`db_select` & `db_inser` are obviously very opinionated, main call is `db_execute :: proc(cmd: string, args: ..any)` which does cmd preparing and bind argument insertion for you

still need to test multiple row result usage out
