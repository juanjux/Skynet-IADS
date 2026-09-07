local site=siteFixture()
local function members(state,kind)
 if state==0 then return{} end
 return{{isInRange=function()count(kind);return state==2 end}}
end
for search=0,2 do for launcher=0,2 do for tracking=0,2 do
 for _,working in ipairs({true,false}) do for _,kill in ipairs({true,false}) do
  site.searchRadars=members(search,"search");site.launchers=members(launcher,"launcher")
  site.trackingRadars=members(tracking,"tracking")
  site.hasWorkingSearchRadars=function()count("working");return working end
  site.goLiveRange=kill and SkynetIADSAbstractRadarElement.GO_LIVE_WHEN_IN_KILL_ZONE or -1
  local expected=search~=1 and ((working and not kill) or (launcher~=1 and tracking~=1))
  COUNTS={};eq(site:isTargetInRange({}),expected)
  if kill or search==1 then eq(COUNTS.working,nil) end
  if search==1 then eq(COUNTS.launcher,nil);eq(COUNTS.tracking,nil) end
  if launcher==1 and (kill or not working) then eq(COUNTS.tracking,nil) end
 end end
end end end
-- Multiple members still use any-in-range rather than all-in-range.
site.searchRadars={members(1,"search")[1],members(2,"search")[1]}
site.launchers={};site.trackingRadars={}
eq(site:isTargetInRange({}),true)
