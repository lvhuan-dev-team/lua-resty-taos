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

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

local _M = { _VERSION = '0.1' }

local mt = { __index = _M }

function _M.new(self, result)

    local ct = ffi_typeof("TAOS_RES *")
    if not ffi_istype(ct, result) then
        return nil
    end

    local wrapper = {
        result = ffi_gc(result, C.taos_free_result)
    }
    return setmetatable(wrapper, mt)
end


function _M.precision(self)
    return C.taos_result_precision(self.result)
end

function _M.fetch_row(self)
    local taos_row = ffi_new("TAOS_ROW")
    --local void_type = ffi.typeof("void **")
    taos_row = C.taos_fetch_row(self.result)


    -- if ffi.istype(void_type, taos_row) then
    --     ngx.log(ngx.DEBUG,"taos_fetch_row return data type is bool. value: " , tostring(ffi_cast(void_type, taos_row)) )
    --     return nil
    -- end

    if tostring(taos_row) == "cdata<void **>: NULL" or taos_row == true then
        ngx_log(ngx_DEBUG,"taos_fetch_row return data type is bool. value: " , tostring(taos_row))
        return nil
    end

    if ffi_cast("void *",taos_row) > nil then
        return taos_row
    end

    return nil
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
    local lens = ffi_new("int *")
    lens = C.taos_fetch_lengths(self.result)
    return lens

end

function _M.affected_rows(self)
    return C.taos_affected_rows(self.result)
end

function _M.fetch_fields(self)
    local taos_fields = ffi_new("TAOS_FIELD *")
          taos_fields = C.taos_fetch_fields(self.result)

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
end

function _M.errstr(self)
    local str = ffi_new("char *")

    str = C.taos_errstr(self.result)
    str = ffi_string(str)

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

    local row = self:fetch_row()
    while(row) do
        rows = rows + 1
        local item = {}
        for i = 0, num_fields-1, 1 do
            if ffi_cast("void *",row[i]) > nil then
                local name = fields[i+1].name
                local type = fields[i+1].type
                local func = taos_data[type]
                item[name] = func(row[i])
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