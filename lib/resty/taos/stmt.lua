local taos_lib  = require("resty.taos.library")
local taos_data = require("resty.taos.data")

local ffi = require("ffi")
local ffi_gc     = ffi.gc
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

function _M.new(self, conn)

    local stmt = ffi_new("TAOS_STMT *")
          stmt = C.taos_stmt_init(conn)

    local wrapper = {
        stmt = ffi_gc(stmt, C.taos_stmt_close)
    }
    return setmetatable(wrapper, mt)
end

function _M.prepare(self, sql, lenght)
    return C.taos_stmt_prepare(self.stmt, sql, lenght)
end

function _M.bind_param(self, bind)
    return C.taos_stmt_bind_param(self.stmt, bind)
end

function _M.add_batch(self)
    return C.taos_stmt_add_batch(self.stmt)
end


function _M.execute(self)
    return C.taos_stmt_execute(self.stmt)
end


function _M.use_result(self)
    local res = ffi_new("TAOS_RES *")
          res = C.taos_stmt_use_result(self.stmt)
    return res
end

function _M.close(self)
    C.taos_stmt_close(self.stmt)
end
return _M