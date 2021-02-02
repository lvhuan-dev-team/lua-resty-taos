
package.path= "/usr/local/lvhuan/lua-resty-taos/lib/?.lua;/usr/local/openresty/luajit/share/lua/5.1/?.lua;;";
package.cpath= "/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;/usr/local/openresty/luajit/lib/lua/5.1/?.so;;";

local taos = require "resty.taos"

local config = {
   host = "127.0.0.1",
   port = 6030,
   database = "",
   user = "root",
   password = "taosdata",
   max_packet_size = 1024 * 1024
}
local driver = taos:new()

local res = driver:connect(config)
if res.code ~=0 then
   print("connect--- failed: "..res.error)
   return
else
   print("connect--- pass.")
end

local res = driver:query("drop database if exists demo")

res = driver:query("create database demo")
if res.code ~=0 then
   print("create db--- failed: "..res.error)
   return
else
   print("create db--- pass.")
end

res = driver:query("use demo")
if res.code ~=0 then
   print("select db--- failed: "..res.error)
   return
else
   print("select db--- pass.")
end

res = driver:query("create table m1 (ts timestamp, speed int,owner binary(20))")
if res.code ~=0 then
   print("create table---failed: "..res.error)
   return
else
   print("create table--- pass.")
end

res = driver:query("insert into m1 values ('2019-09-01 00:00:00.001',0,'robotspace'), ('2019-09-01 00:00:00.002',1,'Hilink'),('2019-09-01 00:00:00.003',2,'Harmony')")
if res.code ~=0 then
   print("insert records failed: "..res.error)
   return
else
   if(res.affected == 3) then
      print("insert records--- pass")
   else
      print("insert records---failed: expect 3 affected records, actually affected "..res.affected)
   end
end

res = driver:query("select * from m1")

if res.code ~=0 then
   print("select failed: "..res.error)
   return
else
    if (#(res.item) == 3) then
	print("select--- pass")
    else
	print("select--- failed: expect 3 affected records, actually received "..#(res.item))
    end

end

res = driver:query("CREATE TABLE thermometer (ts timestamp, degree double) TAGS(location binary(20), type int)")
if res.code ~=0 then
   print(res.error)
   return
else
   print("create super table--- pass")
end
res = driver:query("CREATE TABLE therm1 USING thermometer TAGS ('beijing', 1)")
if res.code ~=0 then
   print(res.error)
   return
else
   print("create table--- pass")
end

res = driver:query("INSERT INTO therm1 VALUES ('2019-09-01 00:00:00.001', 20),('2019-09-01 00:00:00.002', 21)")

if res.code ~=0 then
   print(res.error)
   return
else
   if(res.affected == 2) then
      print("insert records--- pass")
   else
      print("insert records---failed: expect 2 affected records, actually affected "..res.affected)
   end
end

res = driver:query("SELECT COUNT(*) count, AVG(degree) AS av, MAX(degree), MIN(degree) FROM thermometer WHERE location='beijing' or location='tianjin' GROUP BY location, type")
if res.code ~=0 then
   print("select from super table--- failed:"..res.error)
   return
else
   print("select from super table--- pass")
   for i = 1, #(res.item) do
      print("res:"..tostring(res.item[i].count))
   end
end

local function callback(t)
   print("------------------------")
   print("continuous query result:")
   for key, value in pairs(t) do
      print("key:"..key..", value:"..tostring(value))
   end
end

print("==================")
res = driver:open_stream("SELECT COUNT(*) as count, AVG(degree) as avg, MAX(degree) as max, MIN(degree) as min FROM thermometer interval(2s) sliding(2s);)",0,callback)
if res.code ~=0 then
   print("open stream--- failed:"..res.error)
   return
else
   print("open stream--- pass")
end

print("From now on we start continous insert in an definite (infinite if you want) loop.")
local loop_index = 0
while loop_index < 30 do
   local t = os.time()*1000
   local v = loop_index
   res = driver:query(string.format("INSERT INTO therm1 VALUES (%d, %d)",t,v))

   if res.code ~=0 then
      print("continous insertion--- failed:" .. res.error)
      return
   else
      --print("insert successfully, affected:"..res.affected)
   end
   os.execute("sleep " .. 1)
   loop_index = loop_index + 1
end

driver:close_stream()
driver:close()
