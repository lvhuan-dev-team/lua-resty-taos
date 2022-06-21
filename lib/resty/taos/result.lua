local taos_lib  = require("resty.taos.library")
local taos_data = require("resty.taos.data")

local ffi = require("ffi")
local ffi_gc     = ffi.gc
local ffi_cast   = ffi.cast
local ffi_new    = ffi.new
local ffi_copy   = ffi.copy
local ffi_string = ffi.string
local ffi_typeof = ffi.typeof
local ffi_istype = ffi.istype
local C = taos_lib

local ngx = ngx
local ngx_log = ngx.log
local ngx_DEBUG = ngx.DEBUG
local ngx_WARN  = ngx.WARN

local sfmt = string.format

local cdata_null_point = ffi.new("void**", nil)

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

local _M = { _VERSION = '0.1' }

local mt = { __index = _M }

local ct = ffi_typeof("TAOS_RES *")

function _M.new(self, result)

    if not ffi_istype(ct, result) then
        return nil
    end

    local wrapper = {
        result = result
    }
    return setmetatable(wrapper, mt)
end

function _M.precision(self)
    return C.taos_result_precision(self.result)
end

function _M.fetch_row(self)
    local taos_row = C.taos_fetch_row(self.result)

    if taos_row == cdata_null_point or taos_row == true then
        -- ngx_log(ngx_DEBUG,"taos_fetch_row return data type is bool. value: " , tostring(taos_row))
        return nil
    end

    return taos_row

end

function _M.fetch_block(self)
    local rows  = ffi_new("TAOS_ROW *")
    local count = C.taos_fetch_block(self.result, rows)
    return count, rows
end

function _M.num_fields(self)
    return C.taos_num_fields(self.result)
end

function _M.field_count(self)
    return C.taos_field_count(self.result)
end

function _M.fetch_lengths(self)
    local lens = C.taos_fetch_lengths(self.result)
    return lens

end

function _M.affected_rows(self)
    return C.taos_affected_rows(self.result)
end

function _M.fetch_fields(self)
    local taos_fields = C.taos_fetch_fields(self.result)

    local num    = C.taos_field_count(self.result)
    local fields = {}

    for i = 0, num -1, 1 do
        local field = {
                name = ffi_string(taos_fields[i].name),
                type = taos_fields[i].type,
                len  = taos_fields[i].bytes}
        table.insert(fields, field)
    end

    return fields
end

function _M.stop(self)
    C.taos_stop_query(self.result)
end

function _M.free(self)
    C.taos_free_result(self.result)
    self.result = nil
    self = nil
end

function _M.errstr(self)
    local str = ffi_new("char *")

    if self.result then
        str = C.taos_errstr(self.result)
        str = ffi_string(str)
    end

    return  str
end

function _M.errno(self)
    return C.taos_errno(self.result)
end

function _M.totable(self)

    local code   = self:errno()
    if code ~= 0 then
        return {
            code = code,
            error = self:errstr(),
            item = nil
        }
    end

    local rows = 0
    local num_fields = self:field_count()
    local fields = self:fetch_fields()
    local affect_rows = self:affected_rows()
    local items = {}

    ngx.log(ngx.DEBUG,"num_fileds: ", num_fields, " affect_rows: ", affect_rows)
    local row = self:fetch_row()
    while(row) do
        rows = rows + 1
        local item = {}
        for i = 0, num_fields-1, 1 do
            if ffi_cast("void *",row[i]) > nil then
                local name = fields[i+1].name
                local type = fields[i+1].type
                local func = taos_data[type]
                if func then
                    item[name] = func(row[i])
                else
                    ngx.log(ngx.ERROR, "data type: ", type, " not match!!!", "item name: ", name, "data value: ", row[i])
                end
            end
        end
        table.insert(items, item)
        row = self:fetch_row()
    end

    return {
        code = code,
        affected = affect_rows,
        item = items
    }
end

return _M