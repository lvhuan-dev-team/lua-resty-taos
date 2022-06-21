local taos_lib  = require("resty.taos.library")
local taos_data = require("resty.taos.data")

local ffi = require("ffi")
local ffi_cast   = ffi.cast
local ffi_new    = ffi.new
local ffi_copy   = ffi.copy
local ffi_string = ffi.string

local ffi_cdef   = ffi.cdef

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

ffi_cdef([[
    typedef struct {
        CALLBACK callback;
      } async_query_callback_param;
]])

function _M.new(self, cwrap)

    local wrapper = {
        cwrap = cwrap
    }
    return setmetatable(wrapper, mt)
end

function _M.query(self, sql, callback)

    if not callback or type(callback) ~= "function" then
        return nil, "callback set error!"
    end

    local handle = ffi_new("TAOS_QUERY_CALLBACK",
                            function(param, res, code)
                                local p = ffi_cast("async_query_callback_param *", param)
                                local cb = p.callback
                                if code < 0 then
                                    return cb({
                                            code  = nil,
                                            error = self.cwrap:get_error_string(res)
                                        })
                                end

                                local affect_rows = C.taos_affected_rows(res)
                                return cb({
                                    code = 0,
                                    error = "ok",
                                    affected = affect_rows,
                                    res = res
                                })
                            end)

    local p = ffi_new("async_query_callback_param")
    local cb
    if callback and type(callback) == "function" then
        cb = ffi_new("CALLBACK", callback)
    else
        cb = ffi_new("void *", nil)
    end

    p.callback = cb

    local param = ffi_new("void *", p)

    local taos = self.cwrap.conn
    C.taos_query_a(taos, sql, handle, param)

    handle:free()

    return true

end

function _M.fetch_rows(self, res, callback)
    if not callback or type(callback) ~= "function" then
        return nil, "callback set error!"
    end

    local handle = ffi_new("TAOS_QUERY_CALLBACK",
                            function(param, res, num_of_rows)
                                local p = ffi_cast("async_query_callback_param *", param)
                                local cb = p.callback
                                return cb({
                                    num_of_rows = num_of_rows,
                                    res = res
                                })
                            end)

    local p = ffi_new("async_query_callback_param")
    local cb
    if callback and type(callback) == "function" then
        cb = ffi_new("CALLBACK", callback)
    else
        cb = ffi_new("void *", nil)
    end

    p.callback = cb

    local param = ffi_new("void *", p)

    local taos = self.cwrap.conn
    C.taos_fetch_rows_a(res, handle, param)

    handle:free()

    return true
end

return _M