
package.path= "/usr/local/lvhuan/lua-resty-taos/lib/?.lua;/usr/local/openresty/luajit/share/lua/5.1/?.lua;;";
package.cpath= "/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;/usr/local/openresty/luajit/lib/lua/5.1/?.so;;";
local cjson = require "cjson"
local taos = require "resty.taos"
local stream = require "resty.taos.stream"
local taos_subs = require "resty.taos.subscribe"

local ngx = ngx
local ngx_log = ngx.log
local ngx_DEBUG = ngx.DEBUG
local ngx_WARN  = ngx.WARN


local config = {
   host = "127.0.0.1",
   port = 6030,
   database = "",
   user = "root",
   password = "taosdata",
   max_packet_size = 1024 * 1024
}
local driver = taos:new()

print("准备连接, 开始测试...")
local res = driver:connect(config)
if res.code ~=0 then
   print("连接失败: "..res.error)
   return
else
   print("连接成功.")
end

print("---------------------")

print("开始创建数据库测试...")

local res = driver:query("drop database if exists demo")

res = driver:query("create database demo")
local conn = res.conn

if res.code ~=0 then
   print("创建数据库失败: "..res.error)
   return
else
   print("创建数据库成功.")
end

print("---------------------")

print("开始选择数据库测试...")
res = driver:query("use demo")
if res.code ~=0 then
   print("选择数据库查询失败: "..res.error)
   return
else
   print("选择数据库成功.")
end

print("---------------------")

print("开始创建数据表测试...")
res = driver:query("create table m1 (ts timestamp, speed int,owner binary(20))")
if res.code ~=0 then
   print("创建数据表失败: "..res.error)
   return
else
   print("创建数据表成功.")
end

print("---------------------")

print("开始插入数据测试...")
res = driver:query("insert into m1 values ('2019-09-01 00:00:00.001',0,'robotspace'), ('2019-09-01 00:00:00.002',1,'Hilink'),('2019-09-01 00:00:00.003',2,'Harmony')")
if res.code ~=0 then
   print("插入数据失败: "..res.error)
   return
else
   if(res.affected == 3) then
      print("插入记录成功")
   else
      print("插入数据失败: 预计3个受影响的记录，实际受影响 "..res.affected)
   end
end

print("---------------------")

print("开始查询数据表测试...")
res = driver:query("select * from m1")

if res.code ~=0 then
   print("查询数据表失败: "..res.error)
   return
else
    if (#(res.item) == 3) then
	print("查询数据表成功.")
    else
	print("查询数据表失败: 预期3条受影响的记录，实际收到 "..#(res.item))
    end

end

print("---------------------")

print("开始创建超级数据表测试...")
res = driver:query("CREATE TABLE thermometer (ts timestamp, degree double) TAGS(location binary(20), type int)")
if res.code ~=0 then
   print("创建超级数据表失败: ",res.error)
   return
else
   print("创建超级数据表成功.")
end


print("---------------------")

print("开始创建数据表测试...")
res = driver:query("CREATE TABLE therm1 USING thermometer TAGS ('beijing', 1)")
if res.code ~=0 then
   print("创建数据表失败: ",res.error)
   return
else
   print("创建数据表成功.")
end


print("---------------------")

print("开始批量插入数据测试...")
res = driver:query("INSERT INTO therm1 VALUES ('2019-09-01 00:00:00.001', 20),('2019-09-01 00:00:00.002', 21)")

if res.code ~=0 then
   print("批量插入数据失败: ",res.error)
   return
else
   if(res.affected == 2) then
      print("批量插入数据成功.")
   else
      print("批量插入数据失败: 预期2个受影响的记录，实际受影响 "..res.affected)
   end
end

print("---------------------")

print("开始查询超级数据表测试...")
res = driver:query("SELECT COUNT(*) count, AVG(degree) AS av, MAX(degree), MIN(degree) FROM thermometer WHERE location='beijing' or location='tianjin' GROUP BY location, type")
if res.code ~=0 then
   print("查询超级数据表失败: "..res.error)
   return
else
   print("查询超级数据表成功.")
   for i = 1, #(res.item) do
      print("行号:",i, ", 数据: count =",tostring(res.item[i].count))
   end
end

local function callback(t)

   print("+++")
   print("连续查询结果：")
   --for key, value in pairs(t) do
    --  print("key:"..key..", value:"..tostring(value))
   --end
   print(cjson.encode(t))
   print("+++")

end
local function cb(t)
   print("---")
   print("回调")
   print("---")
   print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")

end


print("---------------------")

-- print("流测试开始...")

-- local st = stream:new(driver)

-- res = st:open("SELECT COUNT(*) as count, AVG(degree) as avg, MAX(degree) as max, MIN(degree) as min FROM thermometer interval(2s) sliding(2s);)",0,callback,cb)
-- if res.code ~=0 then
--    print("开启流失败:"..res.error)
--    return
-- else
--    print("开启流成功.")
-- end

local function print_result(t)
   if t then
   print(cjson.encode(t))
   else
      print("空")
   end 
end

local function subscribe_callback(t)
   print("=> 异步订阅回调:")
   print_result(t)
   print("<=")
end


--print("---------------------")
--local tsub1 = taos_subs:new(driver)
-- print("开始异步订阅")
-- local r1 = tsub1:subscribe(true,"test1", "select * from therm1;",subscribe_callback,nil,1000);

-- print("异步订阅结果: ",cjson.encode(r1))

local function ins_data()
   local driver = taos:new()

   print("准备连接, 开始测试...")
   local res = driver:connect(config)
   if res.code ~=0 then
      print("连接失败: "..res.error)
      return
   else
      print("连接成功.")
   end
   
   res = driver:query("use demo")

   print("从现在起，我们开始在一个确定的（无限的，如果你想）循环中连续插入。")
   local loop_index = 0
   while loop_index < 300 do
      ngx.update_time()
      local t = ngx.now()*1000
      local v = loop_index
      res = driver:query(string.format("INSERT INTO therm1 VALUES (%d, %d)",t,v))
      print("执行插入SQL回复结果: ",cjson.encode(res))
      if res and res.code ~=0 then
         print("连续插入---失败: " .. res.error)
         --return
      else

         print("插入成功, 影响行数:"..res.affected .. " " .. loop_index)
      end
      --os.execute("sleep " .. 1)
      --coroutine.yield()
      ngx.sleep(0.1)
      loop_index = loop_index + 1
   end
   print(loop_index)

   driver:close()

end

ngx.thread.spawn(ins_data)

print("开始同步订阅")
local tsub = taos_subs:new(driver)

local r = tsub:subscribe(false,"test", "select * from therm1;",nil,nil,0);
print("订阅结果: ",cjson.encode(r))

local loop_index = 0
while loop_index < 300 do
   
   --local ret  = tsub:consume()
   --print("消费结果: "..cjson.encode(ret))
   ngx.sleep(1)
   loop_index = loop_index + 1
end





local ret  = tsub:consume()
print("消费结果1: "..cjson.encode(ret))

tsub:unsubscribe()
print("同步订阅退订")


--tsub1:unsubscribe()
--print("异步订阅退订")

--st:close()
--print("关闭流.")

driver:close()
print("关闭连接.")