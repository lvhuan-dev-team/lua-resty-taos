local ffi = require("ffi")


local ffi_cast   = ffi.cast
local ffi_new    = ffi.new
local ffi_copy   = ffi.copy
local ffi_string = ffi.string

local C = ffi.load("taos")

ffi.cdef[[

    typedef void   TAOS;
    typedef void   TAOS_STMT;
    typedef void   TAOS_RES;
    typedef void   TAOS_STREAM;
    typedef void   TAOS_SUB;
    typedef void **TAOS_ROW;

    typedef enum {
        TSDB_OPTION_LOCALE,
        TSDB_OPTION_CHARSET,
        TSDB_OPTION_TIMEZONE,
        TSDB_OPTION_CONFIGDIR,
        TSDB_OPTION_SHELL_ACTIVITY_TIMER,
        TSDB_MAX_OPTIONS
      } TSDB_OPTION;

    typedef struct taosField {
        char     name[65];
        uint8_t  type;
        int16_t  bytes;
      } TAOS_FIELD;

    void  taos_init();
    void  taos_cleanup(void);
    int   taos_options(TSDB_OPTION option, const void *arg, ...);
    TAOS *taos_connect(const char *ip, const char *user, const char *pass, const char *db, uint16_t port);
    void  taos_close(TAOS *taos);

    typedef struct TAOS_BIND {
        int            buffer_type;
        void *         buffer;
        uintptr_t      buffer_length;
        uintptr_t      *length;
        int *          is_null;
        int            is_unsigned;
        int *          error;
        union {
          int64_t        ts;
          int8_t         b;
          int8_t         v1;
          int16_t        v2;
          int32_t        v4;
          int64_t        v8;
          float          f4;
          double         f8;
          unsigned char *bin;
          char          *nchar;
        } u;
        unsigned int     allocated;
      } TAOS_BIND;

    TAOS_STMT *taos_stmt_init(TAOS *taos);
    int        taos_stmt_prepare(TAOS_STMT *stmt, const char *sql, unsigned long length);
    int        taos_stmt_is_insert(TAOS_STMT *stmt, int *insert);
    int        taos_stmt_num_params(TAOS_STMT *stmt, int *nums);
    int        taos_stmt_get_param(TAOS_STMT *stmt, int idx, int *type, int *bytes);
    int        taos_stmt_bind_param(TAOS_STMT *stmt, TAOS_BIND *bind);
    int        taos_stmt_add_batch(TAOS_STMT *stmt);
    int        taos_stmt_execute(TAOS_STMT *stmt);
    TAOS_RES * taos_stmt_use_result(TAOS_STMT *stmt);
    int        taos_stmt_close(TAOS_STMT *stmt);

    TAOS_RES *taos_query(TAOS *taos, const char *sql);
    TAOS_ROW taos_fetch_row(TAOS_RES *res);
    int taos_result_precision(TAOS_RES *res);
    void taos_free_result(TAOS_RES *res);
    int taos_field_count(TAOS_RES *res);
    int taos_num_fields(TAOS_RES *res);
    int taos_affected_rows(TAOS_RES *res);
    TAOS_FIELD *taos_fetch_fields(TAOS_RES *res);
    int taos_select_db(TAOS *taos, const char *db);
    int taos_print_row(char *str, TAOS_ROW row, TAOS_FIELD *fields, int num_fields);
    void taos_stop_query(TAOS_RES *res);
    bool taos_is_null(TAOS_RES *res, int32_t row, int32_t col);

    int taos_fetch_block(TAOS_RES *res, TAOS_ROW *rows);
    int taos_validate_sql(TAOS *taos, const char *sql);

    int* taos_fetch_lengths(TAOS_RES *res);

    char *taos_get_server_info(TAOS *taos);
    char *taos_get_client_info();
    char *taos_errstr(TAOS_RES *tres);
    int taos_errno(TAOS_RES *tres);
    void taos_query_a(TAOS *taos, const char *sql, void (*fp)(void *param, TAOS_RES *, int code), void *param);
    void taos_fetch_rows_a(TAOS_RES *res, void (*fp)(void *param, TAOS_RES *, int numOfRows), void *param);

    typedef void (*TAOS_SUBSCRIBE_CALLBACK)(TAOS_SUB* tsub, TAOS_RES *res, void* param, int code);
    TAOS_SUB *taos_subscribe(TAOS* taos, int restart, const char* topic, const char *sql, TAOS_SUBSCRIBE_CALLBACK fp, void *param, int interval);
    TAOS_RES *taos_consume(TAOS_SUB *tsub);
    void      taos_unsubscribe(TAOS_SUB *tsub, int keepProgress);

    typedef void (*HANDLEFUNC)(void *param, TAOS_RES *, TAOS_ROW row);
    typedef void (*CALLBACK)(void *);

    typedef struct{
        CALLBACK callback;
        void *stream;
    } cb_param;

    TAOS_STREAM *taos_open_stream(TAOS *taos, const char *sql, HANDLEFUNC handler, int64_t stime, void *param, CALLBACK cb);
    void taos_close_stream(TAOS_STREAM *tstr);
    int taos_load_table_info(TAOS *taos, const char* tableNameList);

]];

local ngx = ngx
local ngx_log = ngx.log
local ngx_DEBUG = ngx.DEBUG
local ngx_WARN  = ngx.WARN

local sfmt = string.format

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end


local _M = { _VERSION = '0.1' }


local mt = { __index = _M }

_M.C = C

--Data type definition
local db_type = {
TSDB_DATA_TYPE_NULL       = 0 ,    -- 1 bytes
TSDB_DATA_TYPE_BOOL       = 1 ,    -- 1 bytes
TSDB_DATA_TYPE_TINYINT    = 2 ,    -- 1 byte
TSDB_DATA_TYPE_SMALLINT   = 3 ,    -- 2 bytes
TSDB_DATA_TYPE_INT        = 4 ,    -- 4 bytes
TSDB_DATA_TYPE_BIGINT     = 5 ,    -- 8 bytes
TSDB_DATA_TYPE_FLOAT      = 6 ,    -- 4 bytes
TSDB_DATA_TYPE_DOUBLE     = 7 ,    -- 8 bytes
TSDB_DATA_TYPE_BINARY     = 8 ,    -- string
TSDB_DATA_TYPE_TIMESTAMP  = 9 ,    -- 8 bytes
TSDB_DATA_TYPE_NCHAR      = 10,    -- unicode string
TSDB_DATA_TYPE_UTINYINT   = 11,    -- 1 byte
TSDB_DATA_TYPE_USMALLINT  = 12,    -- 2 bytes
TSDB_DATA_TYPE_UINT       = 13,    -- 4 bytes
TSDB_DATA_TYPE_UBIGINT    = 14,    -- 8 bytes
}

function _M.new(self)
    local cwrap = {
        ffi    = ffi,
        conn   = nil,
        stream = nil
    }
    return setmetatable(cwrap, mt)
end

local function get_error_string(res)

    local str = ffi_new("char *")
    str = C.taos_errstr(res)
    str = ffi_string(str)

    return  str
end

function _M.get_error_string(self, res)
    if not res then
        return  get_error_string(self.conn)
    else
        return  get_error_string(res)
    end
end

local function get_error_no(res)
    return C.taos_errno(res)
end

function _M.get_error_no(self, res)
    if not res then
        return get_error_no(self.conn)
    else
        return get_error_no(res)
    end
end

function _M.connect(self, conf)
    local code = 0
    local err_msg = nil
    C.taos_init()
    local taos = ffi_new("TAOS *")

    local port      = ffi_cast("uint16_t",      conf.port)
    local user      = ffi_cast("const char *",  conf.user)
    local password  = ffi_cast("const char *",  conf.password)
    local host      = ffi_cast("const char *",  conf.host)
    local db        = ffi_cast("const char *",  conf.database)

    taos = C.taos_connect(host, user, password, db, port)

    if ffi_cast("void *",taos) <= nil then
        code = -1
        err_msg = "failed to connect server, reason: " .. self:get_error_string()
    end

    self.conn = taos

    return {
        code = code,
        conn = taos,
        error = err_msg
    }
end

local case = {}

    case[db_type.TSDB_DATA_TYPE_TINYINT] = function(data)
        local val = ffi_cast("char *", data)
        return val[0]
    end

    case[db_type.TSDB_DATA_TYPE_SMALLINT] = function(data)
        local val = ffi_cast("short *", data)
        return val[0]
    end

    case[db_type.TSDB_DATA_TYPE_INT] = function(data)
        local val = ffi_cast("int *", data)
        return val[0]
    end

    case[db_type.TSDB_DATA_TYPE_BIGINT] = function(data)
        local val = ffi_cast("int64_t *", data)
        return val[0]
    end

    case[db_type.TSDB_DATA_TYPE_FLOAT] = function(data)
        local val = ffi_cast("float *", data)
        return val[0]
    end

    case[db_type.TSDB_DATA_TYPE_DOUBLE] = function(data)
        local val = ffi_cast("double *", data)
        return val[0]
    end

    case[db_type.TSDB_DATA_TYPE_BINARY] = function(data)
        local val = ffi_string(data)
        return val
    end

    case[db_type.TSDB_DATA_TYPE_NCHAR] = function(data)
        local val = ffi_string(data)
        return val
    end

    case[db_type.TSDB_DATA_TYPE_TIMESTAMP] = function(data)
        local val = ffi_cast("int64_t *", data)
        return val[0]
    end

    case[db_type.TSDB_DATA_TYPE_BOOL] = function(data)
        local val = ffi_cast("char *", data)
        return val[0]
    end

_M.case = case

function _M.query(self, sql)
    local taos = self.conn

    local result = ffi_new("TAOS_RES *")
          result = C.taos_query(taos, sql)
    local code = self:get_error_no(result)

    if code ~= 0 then
        return {
            code = code,
            error = self:get_error_string()
        }
    end

    local row = ffi_new("TAOS_ROW")
    local rows = 0
    local num_fields = C.taos_field_count(result)
    local fields = ffi_new("const TAOS_FIELD *")
          fields = C.taos_fetch_fields(result)
    local affect_rows = C.taos_affected_rows(result)
    local items = {}

    row = C.taos_fetch_row(result)
    while(ffi_cast("void *",row) > nil) do
        rows = rows + 1
        local item = {}
        for i = 0, num_fields-1, 1 do
	    if ffi_cast("void *",row[i]) > nil then
                local name = ffi_string(fields[i].name)
                local type = fields[i].type
                local func = case[type]
                item[name] = func(row[i])
            end
        end
        table.insert(items, item)
        row = C.taos_fetch_row(result)
    end

    C.taos_free_result(result)

    return {
        code = code,
        affected = affect_rows,
        item = items
    }

end

function _M.query_async(self, sql, callback, param)
end

function _M.fetch_rows_async(self, res, callback, param)
end

function _M.close(self)
    local taos = self.conn
    local code = -1
    local err_msg = "null pointer."

    if ffi_cast("void *", taos) > nil then
        C.taos_close(taos)
        code = 0
        err_msg = "done."
    end

    self.conn = nil
    return {
        code = code,
        error = err_msg
    }
end

function _M.get_server_info(self)
    if self.conn then
        local ver = ffi_new("char *")
        ver = C.taos_get_server_info(self.conn)
        ver = ffi_string(ver)
        return ver
    end
    return nil, "not connected."
end

function _M.select_db(self, db)
    if self.conn and db then
        local recode = C.taos_select_db(self.conn, db)
        if recode < 0 then
            return nil, self:get_error_string()
        elseif recode == 0 then
            return true, nil
        end
    end
    return nil, "param error"
end

function _M.subscribe(self, restart, topic, sql, callback, param, interval)
end

function _M.consume(self, tsub)
end

function _M.unsubscribe(self, keep_progress)
end

return _M
