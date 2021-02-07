local ffi = require("ffi")

local ffi_cast   = ffi.cast
local ffi_new    = ffi.new
local ffi_copy   = ffi.copy
local ffi_string = ffi.string

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
        local str = ffi_new("char[?]",25)
        ffi.C.sprintf(str, "%lld", val[0])

        return ffi_string(str)
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
        --local val = ffi_cast("int64_t *", data)
        --return val[0]
        local val = ffi_cast("int64_t *", data)
        local str = ffi_new("char[?]",25)
        ffi.C.sprintf(str, "%lld", val[0])

        return ffi_string(str)
    end

    case[db_type.TSDB_DATA_TYPE_BOOL] = function(data)
        local val = ffi_cast("char *", data)
        return val[0]
    end

return case
