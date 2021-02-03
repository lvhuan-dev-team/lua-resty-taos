local cjson = require "cjson"

local sfmt = string.format

local ngx = ngx
local ngx_log = ngx.log
local ngx_DEBUG = ngx.DEBUG

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

local ffi, C
local ffi_string
local ffi_sizeof
local ffi_cast
local ffi_new

local _M = { _VERSION = '0.1' }

local mt = { __index = _M }

function _M.new(self, cwrap)

    ffi = cwrap.ffi
    ffi_string = ffi.string
    ffi_sizeof = ffi.sizeof
    ffi_cast   = ffi.cast
    ffi_new    = ffi.new
    C   = cwrap.C

    local wrapper = {
        cwrap = cwrap
    }
    return setmetatable(wrapper, mt)
end

function _M.open(self, sql, stime, handle, callback )
    local taos = self.cwrap.conn
    local code = -1
    local stream = nil
    local stream_handle = ffi_new("HANDLEFUNC",  function(param, result, row)


        local p = ffi_cast("cb_param *", param)
        local fields = C.taos_fetch_fields(result)
        local num_fields = C.taos_num_fields(result);

        local item = {}

        for i = 0, num_fields-1, 1 do

            if ffi_cast("void *",row[i]) > nil then
                local name = ffi_string(fields[i].name)
                local type = fields[i].type
                local func = self.cwrap.case[type]
                item[name] = func(row[i])
            end
        end

        handle(item)
    end)


    local p = ffi_new( "cb_param")
    local cb
    if callback and type(callback) == "function" then
        cb = ffi_new("CALLBACK", callback)
        self.callback = cb
        --ngx_log(ngx_DEBUG, "has callback")
    else
        cb = ffi_new("void *", nil)
        self.callback = nil

        --ngx_log(ngx_DEBUG, "not callback")
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