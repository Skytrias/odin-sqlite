# odin-sqlite
Unfinished Sqlite3 bindings for [Odin](https://odin-lang.org/)

`helpers.odin` contains my old usage code, with a global database `db`, to aid at creating SQL statements.

## Short examples using my helpers

### Initialization
```go
package main

import "sql" // <--- from somehwere

// global
db: ^sql.sqlite3

main :: proc() {
    db_scoped_init(&db, "example.db")
    // db_enable_tracing({ .STMT })
}
```

### Prepare a `Stmt` through a SQL string, step through, cleanup automatically (at proc scope end!)
```go
{
    db_execute(`CREATE TABLE colors
        id INTEGER PRIMARY KEY AUTOINCREMENT,
    	name TINYTEXT,
    	r DOUBLE,
    	g DOUBLE,
    	b DOUBLE,
    	a DOUBLE`)
}
```

### Prepare a `Stmt` prior with [bindable parameters](https://sqlite.org/c3ref/bind_blob.html), cleanup only once
```go
prepared_stmt: ^sql.Stmt
db_prepare_bind(&prepared_stmt, "INSERT INTO colors (r, g, b, a) VALUES (?1, ?2, ?3, ?4)")
defer sql.finalize(prepared_stmt)

{
    // insert red = 1 0 0 1
    sql.bind_double(prepared_stmt, 1, 1)
    sql.bind_double(prepared_stmt, 2, 0)
    sql.bind_double(prepared_stmt, 3, 0)
    sql.bind_double(prepared_stmt, 4, 1)
    db_execute_bound(prepared_stmt)
}
```

### Use `db_execute_custom` / `db_execute_bound_custom` which inclues a context `rawptr` and will be called each `.ROW`
```go 
Color :: [4]f32

get_color :: proc(id: int) -> (result: Color) {
    // insert your wanted id at runtime
    cmd := fmt.tprintf("SELECT r, g, b, a FROM colors WHERE colors.id = %d", id)
    
    db_execute_custom(cmd, &result, proc(stmt: ^sql.Stmt, data: rawptr) {
        modify := cast(^Color) data
        modify.r = sql.column_int(stmt, 0)
        modify.g = sql.column_int(stmt, 1)
        modify.b = sql.column_int(stmt, 2)
        modify.a = sql.column_int(stmt, 3)
    })
    
    return
}
```

### Use `db_step_once` when you know the `Stmt` only evaluates once, letting you avoid the closure like code.
```go
prepared_stmt: ^sql.Stmt
db_prepare_bind(&prepared_stmt, "SELECT r, g, b, a FROM colors WHERE colors.id = 1")
defer sql.finalize(prepared_stmt)

{
    db_step_once(prepared_stmt) // stmt stays valid till scope end!
    r := sql.column_double(prepared_stmt, 0)
    g := sql.column_double(prepared_stmt, 1)
    b := sql.column_double(prepared_stmt, 2)
    a := sql.column_double(prepared_stmt, 3)
}
```
