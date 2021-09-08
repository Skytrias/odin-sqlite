package sqlite3

import "core:c"
import "core:os"

when os.OS == "linux" do foreign import sqlite { "sqlite3.a", "system:pthread", "system:dl" }

callback :: proc"c"(data: rawptr, a: c.int, b: [^]cstring, c: [^]cstring) -> ResultCode;

@(default_calling_convention="c", link_prefix="sqlite3_")
foreign sqlite {
	open :: proc(filename: cstring, ppDb: ^^sqlite3) -> ResultCode ---;
	close :: proc(db: ^sqlite3) -> ResultCode ---;
	
	prepare_v2 :: proc(db: ^sqlite3, zSql: ^c.char, nByte: c.int, ppStmt: ^^Stmt, pzTail: ^cstring) -> ResultCode ---;
	
	step :: proc(stmt: ^Stmt) -> ResultCode ---;
	finalize :: proc(stmt: ^Stmt) -> ResultCode ---;
	
	// column_text :: proc(stmt: ^Stmt, i_col: c.int) -> cstring ---;
	column_text :: proc(stmt: ^Stmt, i_col: c.int) -> ^c.char ---;
	column_bytes :: proc(stmt: ^Stmt, i_col: c.int) -> c.int ---;
	
	column_int :: proc(stmt: ^Stmt, i_col: c.int) -> c.int ---;
	column_double :: proc(stmt: ^Stmt, i_col: c.int) -> c.double ---;
	column_type :: proc(stmt: ^Stmt, i_col: c.int) -> c.int ---;
	
	errcode :: proc(db: ^sqlite3) -> c.int ---;
	extended_errcode :: proc(db: ^sqlite3) -> c.int ---;
	errmsg :: proc(db: ^sqlite3) -> cstring ---;
	// exec :: proc(db: ^sqlite3, sql: cstring, call: callback, arg: rawptr, errmsg: [^]c.char) -> ResultCode ---;

	reset :: proc(stmt: ^Stmt) -> ResultCode ---;
	clear_bindings :: proc(stmt: ^Stmt) -> ResultCode ---;

	bind_int :: proc(stmt: ^Stmt, index: c.int, value: c.int) -> ResultCode ---;
	bind_text :: proc(
		stmt: ^Stmt, 
		index: c.int, 
		first: ^c.char, 
		byte_count: int, 
		lifetime: proc "c" (data: rawptr),
	) -> ResultCode ---;

	trace_v2 :: proc(
		db: ^sqlite3, 
		mask: TraceFlags,
		call: proc "c" (mask: TraceFlag, x, y, z: rawptr) -> c.int,
		ctx: rawptr,
	) -> ResultCode ---;

	sql :: proc(stmt: ^Stmt) -> cstring ---;
	expanded_sql :: proc(stmt: ^Stmt) -> cstring ---;
}

STATIC :: uintptr(0);
TRANSIENT :: ~uintptr(0);

TraceFlag :: enum u8 {
	STMT = 0x01,
	PROFILE = 0x02,
	ROW = 0x04,
	CLOSE = 0x08,
}
TraceFlags :: bit_set[TraceFlag];

// seems to be only a HANDLE
Stmt :: struct {}

LIMIT_LENGTH :: 0;
LIMIT_SQL_LENGTH :: 1;
LIMIT_COLUMN :: 2;
LIMIT_EXPR_DEPTH :: 3;
LIMIT_COMPOUND_SELECT :: 4;
LIMIT_VDBE_OP :: 5;
LIMIT_FUNCTION_ARG :: 6;
LIMIT_ATTACHED :: 7;
LIMIT_LIKE_PATTERN_LENGTH :: 8;
LIMIT_VARIABLE_NUMBER :: 9;
LIMIT_TRIGGER_DEPTH :: 10;
LIMIT_WORKER_THREADS :: 11;
N_LIMIT :: LIMIT_WORKER_THREADS + 1;

Vfs :: struct {
	
};

Vdbe :: struct {
	
}

CollSeq :: struct {
	
}

Mutex :: struct {
	
}

Db :: struct {
	
}

sqlite3 :: struct {
	pVfs: ^Vfs,            /* OS Interface */
  pVdbe: ^Vdbe,           /* List of active virtual machines */
  pDfltColl: ^CollSeq,           /* BINARY collseq for the database encoding */
  mutex: ^Mutex,         /* Connection mutex */
  aDb: ^Db,                      /* All backends */
  nDb: c.int,                      /* Number of backends currently in use */
  mDbFlags: u32,                 /* flags recording c.internal state */
  flags: u64,                    /* flags settable by pragmas. See below */
  lastRowid: i64,                /* ROWID of most recent insert (see above) */
  szMmap: i64,                   /* Default mmap_size setting */
  nSchemaLock: u32,              /* Do not reset the schema when non-zero */
  openFlags: c.uint,       /* Flags passed to sqlite3_vfs.xOpen() */
  errCode: c.int,                  /* Most recent error code (SQLITE_*) */
  errMask: c.int,                  /* & result codes with this before returning */
  iSysErrno: c.int,                /* Errno value from last system error */
  dbOptFlags: u32,               /* Flags to enable/disable optimizations */
  enc: u8,                       /* Text encoding */
  autoCommit: u8,                /* The auto-commit flag. */
  temp_store: u8,                /* 1: file 2: memory 0: default */
  mallocFailed: u8,              /* True if we have seen a malloc failure */
  bBenignMalloc: u8,             /* Do not require OOMs if true */
  dfltLockMode: u8,              /* Default locking-mode for attached dbs */
  nextAutovac: c.schar,      /* Autovac setting after VACUUM if >=0 */
  suppressErr: u8,               /* Do not issue error messages if true */
  vtabOnConflict: u8,            /* Value to return for s3_vtab_on_conflict() */
  isTransactionSavepoint: u8,    /* True if the outermost savepoc.int is a TS */
  mTrace: u8,                    /* zero or more SQLITE_TRACE flags */
  noSharedCache: u8,             /* True if no shared-cache backends */
  nSqlExec: u8,                  /* Number of pending OP_SqlExec opcodes */
  nextPagesize: c.int,             /* Pagesize after VACUUM if >0 */
  magic: u32,                    /* Magic number for detect library misuse */
  nChange: c.int,                  /* Value returned by sqlite3_changes() */
  nTotalChange: c.int,             /* Value returned by sqlite3_total_changes() */
  aLimit: [N_LIMIT]c.int,   /* Limits */
  nMaxSorterMmap: c.int,           /* Maximum size of regions mapped by sorter */
  init: struct {      /* Information used during initialization */
    newTnum: Pgno,               /* Rootpage of table being initialized */
    iDb: u8,                     /* Which db file is being initialized */
    busy: u8,                    /* TRUE if currently initializing */
    orphanTrigger: u8, /* Last statement is orphaned TEMP trigger */
    imposterTable: u8, /* Building an imposter table */
    reopenMemdb: u8,   /* ATTACH is really a reopen using MemDB */
    azInit: ^^u8,              /* "type", "name", and "tbl_name" columns */
  },
  nVdbeActive: c.int,              /* Number of VDBEs currently running */
  nVdbeRead: c.int,                /* Number of active VDBEs that read or write */
  nVdbeWrite: c.int,               /* Number of active VDBEs that read and write */
  nVdbeExec: c.int,                /* Number of nested calls to VdbeExec() */
  nVDestroy: c.int,                /* Number of active OP_VDestroy operations */
  nExtension: c.int,               /* Number of loaded extensions */
  aExtension: ^^rawptr,            /* Array of shared library handles */
  //union {
	//void (*xLegacy)(void*,const char*),     /* Legacy trace function */
	//c.int (*xV2)(u32,void*,void*,void*),      /* V2 Trace function */
  //} trace,
}

Pgno :: struct {
	
}

ResultCode :: enum c.int {
	OK = 0,   /* Successful result */
	ERROR = 1,   /* Generic error */
	INTERNAL = 2,   /* Internal logic error in SQLite */
	PERM = 3,   /* Access permission denied */
	ABORT = 4,   /* Callback routine requested an abort */
	BUSY = 5,   /* The database file is locked */
	LOCKED = 6,   /* A table in the database is locked */
	NOMEM = 7,   /* A malloc() failed */
	READONLY = 8,   /* Attempt to write a readonly database */
	INTERRUPT = 9,   /* Operation terminated by sqlite3_interrupt()*/
	IOERR = 10,   /* Some kind of disk I/O error occurred */
	CORRUPT = 11,   /* The database disk image is malformed */
	NOTFOUND = 12,   /* Unknown opcode in sqlite3_file_control() */
	FULL = 13,   /* Insertion failed because database is full */
	CANTOPEN = 14,   /* Unable to open the database file */
	PROTOCOL = 15,   /* Database lock protocol error */
	EMPTY = 16,   /* Internal use only */
	SCHEMA = 17,   /* The database schema changed */
	TOOBIG = 18,   /* String or BLOB exceeds size limit */
	CONSTRAINT = 19,   /* Abort due to constraint violation */
	MISMATCH = 20,   /* Data type mismatch */
	MISUSE = 21,   /* Library used incorrectly */
	NOLFS = 22,   /* Uses OS features not supported on host */
	AUTH = 23,   /* Authorization denied */
	FORMAT = 24,   /* Not used */
	RANGE = 25,   /* 2nd parameter to sqlite3_bind out of range */
	NOTADB = 26,   /* File opened that is not a database file */
	NOTICE = 27,   /* Notifications from sqlite3_log() */
	WARNING = 28,   /* Warnings from sqlite3_log() */
	ROW = 100,  /* sqlite3_step() has another row ready */
	DONE = 101,  /* sqlite3_step() has finished executing */
}
