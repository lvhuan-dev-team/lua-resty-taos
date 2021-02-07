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

function _M.new(self, cwrap)

    local wrapper = {
        cwrap = cwrap
    }
    return setmetatable(wrapper, mt)
end

function _M.open(self, sql, stime, handle, callback )
    local taos = self.cwrap.conn
    local code = -1
    local stream = nil
    local stream_handle = ffi_new("HANDLEFUNC",  function(param, res, row)


        local result = taos_result:new(res)

        local p = ffi_cast("cb_param *", param)
        local fields = result:fetch_fields()
        local num_fields = result:field_count()

        local item = {}

        for i = 0, num_fields-1, 1 do

            if ffi_cast("void *",row[i]) > nil then
                local name = fields[i+1].name
                local type = fields[i+1].type
                local func = taos_data[type]
                item[name] = func(row[i])
            end
        end

        result = nil

        handle(item)
    end)


    local p = ffi_new( "cb_param")
    local cb
    if callback and type(callback) == "function" then
        cb = ffi_new("CALLBACK", callback)
        self.callback = cb
        ngx_log(ngx_DEBUG, "has callback")
    else
        cb = ffi_new("void *", nil)
        self.callback = nil

        ngx_log(ngx_DEBUG, "not callback")
    end
    p.callback = cb
    local param = ffi_new( "void *", p)

    local s = ffi_new("void *")
          s = C.taos_open_stream(taos, sql, stream_handle, stime, param, cb)

    if ffi_cast("void *", s) > nil then
        code = 0
	    local sp = ffi_cast("void *",s)
        p.stream = sp
        stream = p
    end

    self.stream = stream
    self.handle = stream_handle

    return {
        code = code,
        error = self.cwrap:get_error_string(),
        stream = stream
    }
end

function _M.close(self)
    C.taos_close_stream(self.stream)
    self.stream = nil
    self.handle:free()
    if self.callback then
        self.callback:free()
    end
    return true
end

return _M