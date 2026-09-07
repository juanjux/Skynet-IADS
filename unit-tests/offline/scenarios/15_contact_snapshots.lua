local unit=dcsUnit("moving",{x=0,y=100,z=0})
local c=SkynetIADSContact:create({object=unit})
c:refresh(c:getPosition());eq(COUNTS["position:moving"],1)
unit.position.p={x=1852,y=200,z=0};NOW=NOW+3600
c:refresh();eq(COUNTS["position:moving"],2);eq(c:getGroundSpeedInKnots(),1)
eq(c.simpleAltitudeProfile[1],SkynetIADSContact.CLIMB);eq(c.position.p.y,200)
c:refresh();eq(COUNTS["position:moving"],2,"same instant does not resample")
unit.alive=false;NOW=NOW+1;c:refresh();eq(COUNTS["position:moving"],2)
local site,radar=siteFixture()
for i=1,20 do radar.targets[i]={object=dcsUnit("target"..i)} end
site.isTargetInRange=function()return true end
site.hasRemainingAmmo=function()return true end
site.aiState=true;site.goLiveTime=NOW
COUNTS={};site:goDark()
eq(site.aiState,true);eq(COUNTS.detections,1)
for i=1,20 do eq(COUNTS["position:target"..i],1) end
-- Separate calls during startup must still observe fresh detections.
local a=site:getDetectedTargets();local b=site:getDetectedTargets();assert(a~=b)
NOW=NOW+10;a=site:getDetectedTargets();b=site:getDetectedTargets();eq(a,b)
-- Power failure and HARM silence do not need any detection query.
COUNTS={};site.hasWorkingPowerSource=function()return false end
site:goDark();eq(COUNTS.detections,nil);eq(site.aiState,false)
site.hasWorkingPowerSource=function()return true end;site.aiState=true;site.harmSilenceID=1
site:goDark();eq(COUNTS.detections,nil);eq(site.aiState,false)
