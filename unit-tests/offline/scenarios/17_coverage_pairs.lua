local iads=SkynetIADS:create("coverage")
SkynetIADSSamSite.__index=SkynetIADSSamSite
local function element(id)
 local s=setmetatable({id=id,childRadars={},parentRadars={}},SkynetIADSSamSite)
 s.isInRadarDetectionRangeOf=function(self,other)count("range");return self.id<other.id end
 s.informChildrenOfStateChange=function()count("notify")end
 return s
end
for i=1,100 do iads.samSites[i]=element(i) end
iads:buildRadarCoverage()
eq(COUNTS.range,9900);eq(COUNTS.notify,100,"notify once after complete graph")
for i,s in ipairs(iads.samSites) do
 eq(#s.parentRadars,100-i);eq(#s.childRadars,i-1)
end
COUNTS={};iads:buildRadarCoverage();eq(COUNTS.range,9900);eq(COUNTS.notify,100)
COUNTS={};iads:buildRadarCoverageForAbstractRadarElement(iads.samSites[50])
eq(COUNTS.range,198);eq(COUNTS.notify,nil,"duplicate edges do not notify")
local new=element(101);iads.samSites[101]=new
iads:buildRadarCoverageForSAMSite(new)
eq(#new.childRadars,100);eq(#new.parentRadars,0)
for i=1,100 do eq(#iads.samSites[i].parentRadars,101-i) end
local empty=SkynetIADS:create();empty:buildRadarCoverage()
empty.samSites={element(1)};COUNTS={};empty:buildRadarCoverage();eq(COUNTS.range,nil);eq(COUNTS.notify,1)
