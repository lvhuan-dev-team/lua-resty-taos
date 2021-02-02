rockspec_format = "3.0"
package = "lua-resty-taos"
version = "0.1-1"
source = {
   url = "git+https://github.com/lvhuan-dev-team/lua-resty-taos.git"
}
description = {
   detailed = "lua-resty-taos - Lua TDengine client driver for the ngx_lua based on the FFI",
   homepage = "https://github.com/lvhuan-dev-team/lua-resty-taos",
   license = "BSD License 2.0",
   labels = { "Taos", "OpenResty", "FFI", "Nginx" }
}
build = {
   type = "builtin",
   modules = {
      ["resty.taos"] = "lib/resty/taos.lua"
   }
}