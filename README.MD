# lua-resty-taos
Nonblocking Lua TDengine driver library for ngx_lua or OpenResty

# install
```bash
cd lua-resty-taos
luarocks build
```

# test samples
```bash
docker-compose up --build

docker exec -it {id} /bin/bash

resty --errlog-level debug ./test.lua
```