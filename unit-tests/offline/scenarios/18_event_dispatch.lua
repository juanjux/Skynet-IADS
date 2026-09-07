local iads=SkynetIADS:create("events")
local elements={}
for i=1,100 do
 local u=dcsUnit("element"..i);u.id_=i
 local e=SkynetIADSAbstractElement:create(u,iads)
 e.weaponFired=function()count("shot")end
 e.goDark=function()count("dark")end
 e.informChildrenOfStateChange=function()count("notify")end
 elements[i]=e;iads.samSites[i]=e
end
local handlers=0;for _ in pairs(world.handlers)do handlers=handlers+1 end;eq(handlers,1)
emit({id=world.event.S_EVENT_SHOT,initiator={id_=7}})
eq(COUNTS.shot,1,"route by engine identity, not wrapper identity")
emit({id=world.event.S_EVENT_SHOT,initiator=dcsUnit("unrelated")});eq(COUNTS.shot,1)
local power=dcsUnit("shared power");power.id_=1001
elements[1]:addPowerSource(power);elements[2]:addPowerSource(power)
COUNTS={};power.alive=false;emit({id=world.event.S_EVENT_DEAD,initiator={id_=1001}})
eq(COUNTS.dark,2);eq(COUNTS.notify,2)
elements[1]:cleanUp();COUNTS={}
emit({id=world.event.S_EVENT_DEAD,initiator=power});eq(COUNTS.dark,1)
local connection=dcsUnit("connection");elements[3]:addConnectionNode(connection)
connection.alive=false;COUNTS={};emit({id=world.event.S_EVENT_DEAD,initiator=connection})
eq(COUNTS.dark,nil);eq(COUNTS.notify,1)
-- Groups, later births, reassignment and cleanup.
local group=setmetatable(dcsUnit("group"),Group);local member=dcsUnit("member")
group.units={member}
local e=SkynetIADSAbstractElement:create(group,iads);e.weaponFired=function()count("group shot")end
emit({id=world.event.S_EVENT_SHOT,initiator=member});eq(COUNTS["group shot"],1)
local born=dcsUnit("new member");born.getGroup=function()return group end
emit({id=world.event.S_EVENT_BIRTH,initiator=born})
emit({id=world.event.S_EVENT_SHOT,initiator=born});eq(COUNTS["group shot"],2)
local replacement=dcsUnit("replacement");e:setDCSRepresentation(replacement)
emit({id=world.event.S_EVENT_SHOT,initiator=born});eq(COUNTS["group shot"],2)
emit({id=world.event.S_EVENT_SHOT,initiator=replacement});eq(COUNTS["group shot"],3)
e:cleanUp();e:cleanUp();emit({id=world.event.S_EVENT_SHOT,initiator=replacement});eq(COUNTS["group shot"],3)
-- Independent IADS on the same source receive their own event.
local other=SkynetIADS:create("other")
local oe=SkynetIADSAbstractElement:create(elements[7]:getDCSRepresentation(),other)
oe.weaponFired=function()count("other shot")end
emit({id=world.event.S_EVENT_SHOT,initiator={id_=7}});eq(COUNTS["other shot"],1)
iads:deactivate();eq(next(iads.eventElements),nil);eq(world.handlers[iads],nil)
-- Avoid tactical coverage fixtures here; exercise activation registration.
iads.buildRadarCoverage=function()end;iads:activate()
COUNTS={};emit({id=world.event.S_EVENT_SHOT,initiator={id_=7}})
eq(COUNTS.shot,1);eq(COUNTS["other shot"],1)
-- Removal during dispatch must not invalidate iteration or call a removed recipient.
local a=SkynetIADSAbstractElement:create(power,iads)
local b=SkynetIADSAbstractElement:create(power,iads)
a.onEvent=function()a:cleanUp();b:cleanUp()end
b.onEvent=function()a:cleanUp();b:cleanUp()end
emit({id=world.event.S_EVENT_DEAD,initiator=power})
eq(iads.eventElements[a],nil);eq(iads.eventElements[b],nil)

-- Real radar/launcher callback, including group-member death and dead-group activation.
local runtime=SkynetIADS:create("real radar callback")
local launcherUnit=dcsUnit("actual launcher")
local radarGroup=setmetatable(dcsUnit("actual SAM group"),Group)
radarGroup.units={launcherUnit}
local radarSite=SkynetIADSAbstractRadarElement:create(radarGroup,runtime)
radarSite.launchers={SkynetIADSSAMLauncher:create(launcherUnit)}
runtime.samSites={radarSite}
local missile={isExist=function()return true end}
emit({id=world.event.S_EVENT_SHOT,initiator=launcherUnit,weapon=missile})
eq(radarSite:getNumberOfMissilesInFlight(),1)
radarGroup.alive=false;launcherUnit.alive=false
radarGroup.getUnits=function()error("must not query a destroyed group")end
radarGroup.getName=function()error("must not query a destroyed group")end
runtime:deactivate();runtime.buildRadarCoverage=function()end;runtime:activate()
emit({id=world.event.S_EVENT_DEAD}) -- legacy no-initiator event still accepted
