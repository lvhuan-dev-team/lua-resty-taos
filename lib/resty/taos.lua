local taos_lib    = require("resty.taos.library")
local taos_data   = require("resty.taos.data")
local taos_result = require("resty.taos.result")
local ffi = require("ffi")


local ffi_cast   = ffi.cast
local ffi_new    = ffi.new
local ffi_copy   = ffi.copy
local ffi_string = ffi.string

local C = taos_lib

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

function _M.new(self)
    local cwrap = {
        conn   = nil
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

function _M.init(self)
    C.taos_init()
end

function _M.cleanup(self)
    C.taos_cleanup()
end

function _M.get_client_info(self)
    local client_info = ffi_new("char *")
          client_info = C.taos_get_client_info()
          client_info = ffi_string(client_info)
    return client_info
end

--[[ opts = {
        charset  = "UTF-8",
        locale   = "en_US.UTF-8",
        timezone = "UTC-8" }
--]]
function _M.options(self, opts)
    local match = {
        locale    = ffi.C.TSDB_OPTION_LOCALE,
        charset   = ffi.C.TSDB_OPTION_CHARSET,
        timezone  = ffi.C.TSDB_OPTION_TIMEZONE,
        cfgdir    = ffi.C.TSDB_OPTION_CONFIGDIR,
        -- shell_activity_timer = ffi.C.TSDB_OPTION_SHELL_ACTIVITY_TIMER,
        -- max_otpions  = ffi.C.TSDB_MAX_OPTIONS,
    }

    for k, v in ipairs(opts) do
        local option = match[k]
        if option then
            C.taos_options(option, v )
        end
    end

    return true
end

function _M.connect(self, conf)
    local code = 0
    local err_msg = nil
    self:init()
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

function _M.query(self, sql)
    local taos = self.conn
    local res = ffi_new("TAOS_RES *")
          res = C.taos_query(taos, sql)

    local result = taos_result:new(res)
    local ret = result:totable()

    result:free()
    return ret

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

function _M.validate_sql(self, sql)
    local code = C.taos_validate_sql(self.conn, sql)
    return code
end

return _M
