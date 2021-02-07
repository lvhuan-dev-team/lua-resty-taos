local ffi      = require "ffi"
local ffi_cdef = ffi.cdef
local ffi_load = ffi.load

ffi_cdef[[
    int sprintf(char *buf, const char *fmt, ...);

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

return ffi_load "taos"