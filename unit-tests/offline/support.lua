-- Deliberately small DCS/MIST doubles. Tests cover Lua semantics, not DCS physics.
NOW = 100
COUNTS = {}
function count(key) COUNTS[key] = (COUNTS[key] or 0) + 1 end
function eq(actual, expected, label)
    assert(actual == expected, (label or "value")..": expected "..tostring(expected)..", got "..tostring(actual))
end
function instance(class, values) return setmetatable(values or {}, {__index = class}) end
function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end
env = {info = function() end}
timer = {getTime = function() return NOW end, getAbsTime = function() return NOW end}
Group = {}
Unit = {Category = {AIRPLANE=0, HELICOPTER=1, GROUND_UNIT=2, SHIP=3, STRUCTURE=4}, SensorType={RADAR=1}}
Weapon = {Category = {MISSILE=1, ROCKET=2, BOMB=3, SHELL=0}}
Object = {Category={UNIT=1, WEAPON=2}, getCategory=function(o) return o.category end}
Controller = {Detection={RADAR=1}}
AI = {Option={Air={id={ROE=1},val={ROE={WEAPON_FREE=2,WEAPON_HOLD=3}}},
    Ground={id={ALARM_STATE=4},val={ALARM_STATE={RED=5,GREEN=6}}}}}
coalition = {side={BLUE=2,RED=1,NEUTRAL=0}}
world = {handlers={},event={S_EVENT_SHOT=1,S_EVENT_DEAD=2,S_EVENT_BIRTH=3}}
function world.addEventHandler(h) world.handlers[h]=true end
function world.removeEventHandler(h) world.handlers[h]=nil end
function emit(event)
    local handlers={}
    for h in pairs(world.handlers) do handlers[#handlers+1]=h end
    for _,h in ipairs(handlers) do if world.handlers[h] then h:onEvent(event) end end
end
mist = {utils={},vec={},tasks={},nextID=0}
function mist.scheduleFunction(f,args,t,rep)
    mist.nextID=mist.nextID+1
    mist.tasks[mist.nextID]={f=f,args=args,t=t,rep=rep}
    return mist.nextID
end
function mist.removeFunction(id)
    if id == nil then return false end
    local existed=mist.tasks[id]~=nil; mist.tasks[id]=nil; return existed
end
function tick(seconds)
    NOW=NOW+seconds
    local due={}
    for id,t in pairs(mist.tasks) do if t.t<=NOW then due[#due+1]=id end end
    table.sort(due)
    for _,id in ipairs(due) do
        local t=mist.tasks[id]
        if t then
            if t.rep then t.t=NOW+t.rep else mist.tasks[id]=nil end
            t.f(unpack(t.args))
        end
    end
end
function mist.utils.round(n, p) local m=10^(p or 0); return math.floor(n*m+0.5)/m end
function mist.utils.metersToNM(m) return m/1852 end
function mist.utils.metersToFeet(m) return m/0.3048 end
function mist.utils.toDegree(a) return a*180/math.pi end
function mist.utils.get2DDist(a,b) return ((a.x-b.x)^2+((a.z or a.y)-(b.z or b.y))^2)^0.5 end
function mist.utils.get3DDist(a,b) return ((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)^0.5 end
function mist.utils.getHeadingPoints(a,b)
    count("bearing"); local h=math.atan2(b.z-a.z,b.x-a.x); if h<0 then h=h+2*math.pi end; return h
end
function mist.getHeading(unit)
    count("heading"); local p=unit:getPosition(); local h=math.atan2(p.x.z,p.x.x)
    if h<0 then h=h+2*math.pi end; return h
end
mist.random=math.random
land = {isVisible=function() count("LOS"); return true end}
function dcsUnit(name, position)
    local u={name=name,alive=true,position={p=position or {x=0,y=0,z=0},x={x=1,y=0,z=0}},
        category=Object.Category.UNIT,ammo={},sensors={{}},units={},targets={}}
    u.controller={options={}}
    function u.controller:getDetectedTargets() count("detections"); return u.targets end
    function u.controller:setOption(k,v) self.options[k]=v end
    function u.controller:setOnOff(v) self.enabled=v end
    function u.controller:knowTarget(t) self.known=t end
    function u:getName() return self.name end
    function u:getTypeName() return "test-unit" end
    function u:isExist() return self.alive end
    function u:getPosition() count("position:"..name); return copy(self.position) end
    function u:getAmmo() count("ammo:"..name); return copy(self.ammo) end
    function u:getSensors() count("sensors:"..name); return self.sensors end
    function u:getDesc() return {category=Unit.Category.AIRPLANE} end
    function u:getCategory() return self.category end
    function u:getController() return self.controller end
    function u:enableEmission(v) self.emitting=v end
    function u:getUnits() return self.units end
    function u:getGroup() return self end
    function u:getCoalition() return 1 end
    return u
end
function siteFixture()
    local iads=SkynetIADS:create("test")
    local unit=dcsUnit("radar")
    local site=SkynetIADSAbstractRadarElement:create(unit,iads)
    return site,unit,iads
end

