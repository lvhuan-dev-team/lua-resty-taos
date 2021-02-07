local taos_lib  = require("resty.taos.library")
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

function _M.new(self, cwrap)

    local wrapper = {
        cwrap = cwrap
    }
    return setmetatable(wrapper, mt)
end

function _M.subscribe(self, restart, topic, sql, callback, param, interval)
    local reset = restart and 1 or 0
    local cb = ffi_new("void *", nil)
    local subs, code = nil, -1
    local subs_handle =  ffi_new("void *", nil)
    param = param or ffi_new("void *", nil)
    if callback and type(callback) == "function" then
        cb = ffi_new("CALLBACK", callback)

        subs_handle = ffi_new("TAOS_SUBSCRIBE_CALLBACK", function(tsub, res, param, code)

            local result = taos_result:new(res)

            if code ~= 0 then
                local ret = {
                    code = code,
                    error = result:errstr()
                }
                return callback(ret)
            end

            local ret = result:totable()

            return callback(ret)
        end)
    end

    local taos =self.cwrap.conn
    local s = ffi_new("TAOS_SUB *")
          s = C.taos_subscribe(taos, reset , topic, sql , subs_handle, param, interval)

    if ffi_cast("void *", s) > nil then
            code = 0
            subs = s
    end
    self.handle = subs_handle
    self.subs = subs

    return {
        code = code,
        error = ffi_string(C.taos_errstr(taos)),
        --subs = subs
    }
end

function _M.consume(self)
    local res = ffi_new("TAOS_RES *")
          res = C.taos_consume(self.subs)

    local result = taos_result:new(res)

    local ret = result:totable()
    return ret
end

function _M.unsubscribe(self, keep_progress)
    local keep = keep_progress and 1 or 0
    C.taos_unsubscribe(self.subs, keep)

    if self.handle then
        self.handle:free()
    end

    if self.callback then
        self.callback:free()
    end

    return true
end

return _M