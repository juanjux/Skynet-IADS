local iads=SkynetIADS:create("jam")
local sites={}
iads.getActiveSAMSites=function()return sites end
local jammer=SkynetIADSJammer:create(dcsUnit("emitter"),iads)
local function site(name,distance)
 return {getNatoName=function()return name end,
 getRadars=function()count("radar-lists");return{dcsUnit("r1",{x=distance*1852,y=0,z=0}),dcsUnit("r2",{x=distance*1852,y=0,z=0})}end,
 jam=function()count("jam")end}
end
eq(jammer:isKnownRadarEmitter(nil),false);eq(jammer:isKnownRadarEmitter("unknown"),false)
sites={site("unknown",1)};jammer:runCycle();eq(COUNTS["radar-lists"],nil)
jammer:disableFor("SA-2");sites={site("SA-2",1)};jammer:runCycle();eq(COUNTS["radar-lists"],nil)
sites={site("SA-3",201)};jammer:runCycle();eq(COUNTS.LOS,nil);eq(COUNTS.jam,nil)
sites={site("SA-3",200)};jammer:runCycle();eq(COUNTS.LOS,2);eq(COUNTS.jam,2)
land.isVisible=function()count("LOS");return false end
jammer:runCycle();eq(COUNTS.LOS,4);eq(COUNTS.jam,2)
jammer:addFunction("custom",function()return 100 end);eq(jammer:isKnownRadarEmitter("custom"),true)
jammer:masterArmOn();local id=jammer.jammerTaskID
jammer.emitter.alive=false;jammer:runCycle();eq(mist.tasks[id],nil)
