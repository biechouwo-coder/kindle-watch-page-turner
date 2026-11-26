from pathlib import Path
import sys, json, xml.etree.ElementTree as ET
from lupa.lua51 import LuaRuntime

root=Path(__file__).resolve().parents[1]/'extension/kindle-watch-keys'
lua=LuaRuntime(unpack_returned_tuples=True)
check=lua.eval('function(s,n) local f,e=loadstring(s,n); return f~=nil,e end')
for path in root.glob('*.lua'):
    valid,error=check(path.read_text(),str(path)); assert valid,(path,error)
print('PASS Lua 5.1 syntax for all modules')
json.loads((root/'menu.json').read_text()); ET.parse(root/'config.xml')
lua.globals().wire=lua.execute((root/'x11_wire.lua').read_text())
lua.execute('''
local w=wire
local function z(n) return string.rep(string.char(0),n) end
local function at(s,offset,value) return s:sub(1,offset)..value..s:sub(offset+#value+1) end
READER='L:A_N:application_ID:com.lab126.booklet.reader_M:false_WT:true_S:-2'
function mock(mode)
 local t={buffer='',seq=0,keys=0,writes={}}
 local setup=z(72)
 setup=at(setup,20,string.char(1,0))
 setup=at(setup,32,w.u32(256))
 function t:header(format,body,extra)
  local h=string.char(1,format)..w.u16(self.seq)..w.u32(#body/4)..z(24)
  if extra then h=at(h,16,extra) end
  self.buffer=self.buffer..h..body
 end
 function t:write(s)
  self.writes[#self.writes+1]=s
  if #s==12 and s:byte(1)==108 then
   assert(s==string.char(108,0,11)..z(9))
   self.buffer=string.char(mode=='refuse' and 0 or 1,0)..w.u16(11)..w.u16(0)..w.u16(#setup/4)..setup
  elseif s:byte(1)==15 then
   self.seq=self.seq+1
   assert(#s==8 and w.read16(s,2)==2)
   local parent=w.read32(s,4)
   local body=parent==256 and (w.u32(512)..(mode=='duplicate' and w.u32(513) or '')) or ''
   self:header(0,body,w.u16(#body/4))
  elseif s:byte(1)==20 then
   self.seq=self.seq+1
   assert(#s==24 and w.read32(s,8)==39 and w.read32(s,12)==0 and w.read32(s,20)==128)
   local name=mode=='no-reader' and 'L:A_N:application_ID:com.lab126.booklet.home_M:false' or READER
   local body=name..z((4-#name%4)%4)
   self:header(8,body,w.u32(#name))
  elseif s:byte(1)==25 then
   assert(#s==92)
   for _,offset in ipairs({0,44}) do
    local p=s:sub(offset+1,offset+44)
    assert(p:byte(1)==25 and w.read16(p,2)==11)
    assert(w.read32(p,4)==512 and w.read32(p,8)==0)
    assert(p:byte(13)==(offset==0 and 2 or 3))
    assert(p:byte(14)==(mode=='prev' and 112 or 117))
    assert(w.read32(p,20)==256 and w.read32(p,24)==512)
    assert(p:byte(43)==1)
   end
   assert(s:sub(89)==string.char(43,0,1,0))
   self.keys=self.keys+1; self.seq=self.seq+3
   if mode=='x-error' then self.buffer=string.char(0,3)..z(30)
   elseif mode=='disconnect' then self.buffer=''
   else self:header(0,'') end
  else error('Unexpected request opcode '..s:byte(1)) end
 end
 function t:read(n)
  assert(#self.buffer>=n,'simulated short read')
  local s=self.buffer:sub(1,n); self.buffer=self.buffer:sub(n+1); return s
 end
 return t
end
for _,direction in ipairs({true,false}) do
 local io=mock(direction and 'next' or 'prev')
 local x=w.connect(io); local window=x:find_reader(READER)
 assert(window==512 and io.keys==0,'probe must not emit key events')
 x:send_page(window,direction); assert(io.keys==1)
end
for _,mode in ipairs({'refuse','duplicate','no-reader'}) do
 local io=mock(mode)
 assert(not pcall(function() local x=w.connect(io); x:find_reader(READER) end))
 assert(io.keys==0)
end
for _,mode in ipairs({'x-error','disconnect'}) do
 local io=mock(mode); local x=w.connect(io); local window=x:find_reader(READER)
 assert(not pcall(function() x:send_page(window,true) end))
 assert(io.keys==1,'must not retry a possibly delivered key')
end
for _,title in ipairs({'mesquite','ID:com.lab126.booklet.reader',
 'L:A_N:application_ID:com.lab126.booklet.reader2_M:false',
 'L:C_N:footerBar_ID:com.lab126.booklet.reader_M:false',
 'L:A_N:application_ID:com.lab126.KPPMainApp_M:false'}) do
 assert(not w.title_parts(title),'must reject non-reader foreground')
end
assert(not pcall(w.read32,'xx',0))
''')
print('PASS X11 handshake, window targeting, both key packets, read-only probe, refusal paths, disconnect without retry')
lua.globals().gate_module=lua.execute((root/'gate.lua').read_text())
lua.execute('''
local time=100; local g=gate_module.new(function() return time end)
assert(not g:take()); g:arm(1); assert(g:take()); assert(not g:take())
time=time+2; g:arm(5); assert(g:take()); assert(not g:take()); assert(g.remaining==4)
time=time+121; assert(not g:take()); assert(g.remaining==0)
g:arm(1); g:fail(); assert(not g:take()); assert(not pcall(function() g:arm(1) end))
''')
print('PASS disarmed default, single-action quota, rate limit, expiry, sticky failure')
lua.execute('''
local time=100; local g=gate_module.new(function() return time end)
g:start_reading(7200); assert(g:take()); assert(not g:take())
time=250; assert(g:take()); assert(g:status():find('mode=reading',1,true))
assert(not pcall(function() g:arm(5) end))
time=7301; assert(not g:take()); assert(not g.reading)
local h=gate_module.new(function() return time end)
assert(not pcall(function() h:start_reading(10000) end))
h:start_reading(7200); h:fail(); assert(not h:take())
''')
print('PASS reading mode: no manual quota, 2-hour expiry, rate limit, sticky backend failure')

# Test the actual native-reader wrapper, including normal context refusals and
# refusing keys after Xorg changes, without accessing any device.
lua.execute('''
local actual_require=require
local values={}; local opens=0; local peer=4242; local last_io
require=function(name)
 if name=='x11_wire' then return wire end
 if name=='x11_transport' then return {open=function()
  opens=opens+1; last_io=mock('next'); last_io.peer_pid=peer
  function last_io:close() self.closed=true end
  return last_io
 end} end
 return actual_require(name)
end
io.popen=function() return {read=function() return table.remove(values,1) end,close=function() end} end
function set_props(v) values=v end
function number_of_opens() return opens end
function transport_peer(p) peer=p end
function last_transport() return last_io end
''')
lua.globals().native=lua.execute((root/'native_keys.lua').read_text())
lua.execute('''
set_props({'Powerd state: Screen Saver'})
local ok,_,kind=native.turn(true); assert(not ok and kind=='blocked' and number_of_opens()==0)
set_props({'Powerd state: Active','L:A_N:application_ID:com.lab126.booklet.home_M:false'})
ok,_,kind=native.turn(true); assert(not ok and kind=='blocked' and number_of_opens()==0)
set_props({'Powerd state: Active',READER})
assert(native.probe()); assert(last_transport().keys==0 and last_transport().closed)
set_props({'Powerd state: Active',READER,'Powerd state: Active',READER})
assert(native.turn(true)); assert(last_transport().keys==1 and last_transport().closed)
set_props({'Powerd state: Active',READER,'Powerd state: Active','L:A_N:application_ID:com.lab126.booklet.home_M:false'})
ok,_,kind=native.turn(true); assert(not ok and kind=='blocked' and last_transport().keys==0 and last_transport().closed)
transport_peer(9999); set_props({'Powerd state: Active',READER})
ok,_,kind=native.turn(true); assert(not ok and kind=='error' and last_transport().keys==0 and last_transport().closed)
''')
print('PASS native wrapper: sleep/home refusal, foreground change cancellation, socket closure, Xorg restart detection')

# Exercise actual server dispatch with a scripted socket; no device access.
for action_fails in [False, True]:
    test=LuaRuntime(unpack_returned_tuples=True)
    test.globals().gate_module=test.execute((root/'gate.lua').read_text())
    test.globals().action_fails=action_fails
    test.execute('''
clock=100; turns=0; probes=0; responses={}
local targets={'/health','/next?token=abcdef','/arm-once?token=wrong',
 '/arm-once?token=abcdef','/next?token=abcdef','/next?token=abcdef','/stop?token=abcdef'}
local server={settimeout=function() end,close=function() end}
function server:accept()
 clock=clock+2; local target=table.remove(targets,1)
 if not target then return nil end
 local lines={'GET '..target..' HTTP/1.1','Host: kindle',''}
 return {settimeout=function() end,receive=function() return table.remove(lines,1) end,
 send=function(_,response) responses[#responses+1]=response; return #response end,close=function() end}
end
require=function(name)
 if name=='socket' then return {gettime=function() return clock end,bind=function() return server end} end
 if name=='x11_transport' then return {pid=function() return 1234 end} end
 if name=='gate' then return gate_module end
 if name=='native_keys' then return {
  probe=function() probes=probes+1; return true,'probe ok' end,
  turn=function() turns=turns+1; return not action_fails,action_fails and 'simulated X failure' or 'acknowledged' end} end
 error('Unexpected module')
end
dofile=function() return {port=8888,duration=900,token='abcdef'} end
io.open=function() return {write=function() end,close=function() end} end
''')
    test.execute((root/'server.lua').read_text())
    test.execute('''
assert(turns==1 and probes==1)
assert(responses[1]:find('200 OK',1,true))
assert(responses[2]:find('409 Conflict',1,true))
assert(responses[3]:find('403 Forbidden',1,true))
assert(responses[4]:find('200 OK',1,true))
assert(responses[5]:find(action_fails and '503 Service Unavailable' or '200 OK',1,true))
assert(responses[6]:find('409 Conflict',1,true))
''')
print('PASS HTTP integration: no unarmed key action, authenticated arming, exactly one action, error lockout')

test=LuaRuntime(unpack_returned_tuples=True)
test.globals().gate_module=test.execute((root/'gate.lua').read_text())
test.execute('''
clock=100; turns=0; responses={}; arg={[1]='reading'}
local targets={'/health','/next?token=abcdef','/status?token=abcdef','/next?token=abcdef',
 '/arm-once?token=abcdef','/prev?token=abcdef','/next?token=abcdef','/stop?token=abcdef'}
local server={settimeout=function() end,close=function() end}
function server:accept()
 clock=clock+2; local target=table.remove(targets,1)
 if target=='/status?token=abcdef' then clock=clock+150 end
 if not target then return nil end
 local lines={'GET '..target..' HTTP/1.1','Host: kindle',''}
 return {settimeout=function() end,receive=function() return table.remove(lines,1) end,
 send=function(_,response) responses[#responses+1]=response; return #response end,close=function() end}
end
require=function(name)
 if name=='socket' then return {gettime=function() return clock end,bind=function() return server end} end
 if name=='x11_transport' then return {pid=function() return 1234 end} end
 if name=='gate' then return gate_module end
 if name=='native_keys' then return {
  probe=function() return true,'probe ok' end,
  turn=function()
   turns=turns+1
   if turns==1 then return false,'asleep','blocked' end
   if turns==2 then return true,'acknowledged','ok' end
   return false,'X11 connection changed','error'
  end} end
 error('Unexpected module')
end
dofile=function() return {port=8888,duration=900,reading_duration=7200,token='abcdef'} end
io.open=function() return {write=function() end,close=function() end} end
''')
test.execute((root/'server.lua').read_text())
test.execute('''
assert(turns==3)
assert(responses[1]:find('mode=reading',1,true))
assert(responses[2]:find('409 Conflict',1,true))
assert(responses[3]:find('mode=reading',1,true))
assert(responses[4]:find('200 OK',1,true))
assert(responses[5]:find('409 Conflict',1,true))
assert(responses[6]:find('503 Service Unavailable',1,true))
assert(responses[7]:find('409 Conflict',1,true))
''')
print('PASS reading HTTP integration: ready after 120 seconds, recoverable sleep refusal, backend-error lockout')
