local site=siteFixture()
site:setIsAPointDefence(true)
local heading=0
local contact={getPosition=function()return{p={x=0,y=0,z=0}}end,
 getMagneticHeading=function()count("contact-heading");return heading end,
 getGroundSpeedInKnots=function()count("contact-speed");return 1000 end,
 getAge=function()return 0 end}
local units={}
for i=1,100 do units[i]=dcsUnit("far"..i,{x=50000+i,y=0,z=0}) end
site.searchRadars=units;site:informOfHARM(contact)
eq(COUNTS.bearing,nil);eq(COUNTS["contact-heading"],nil)
for i=1,100 do eq(COUNTS["position:far"..i],1) end
eq(#site.objectsIdentifiedAsHarms,0)
for i=1,100 do units[i].position.p.x=10000+i end
site:informOfHARM(contact)
eq(COUNTS["contact-heading"],1);eq(COUNTS["contact-speed"],1);eq(COUNTS.bearing,100)
eq(#site.objectsIdentifiedAsHarms,1)
-- Strict distance and aspect boundaries; no change to the existing heading convention.
site.objectsIdentifiedAsHarms={};site.searchRadars={units[1]}
units[1].position.p.x=20*1852;site:informOfHARM(contact);eq(#site.objectsIdentifiedAsHarms,0)
units[1].position.p.x=10000;heading=15;site:informOfHARM(contact);eq(#site.objectsIdentifiedAsHarms,0)
heading=14;site:informOfHARM(contact);eq(#site.objectsIdentifiedAsHarms,1)
site:setIsAPointDefence(false);heading=0
site.shallIgnoreHARMShutdown=function()return false end
local tti
site.goSilentToEvadeHARM=function(self,t)tti=t end
site:informOfHARM(contact);assert(tti and tti>0)
units[1].alive=false;local old=COUNTS.bearing;site:informOfHARM(contact);eq(COUNTS.bearing,old)
