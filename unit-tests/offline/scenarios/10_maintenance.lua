for _, mode in ipairs({{false,0},{true,100},{false,100}}) do
    local site,unit=siteFixture()
    site:setIsAPointDefence(mode[1]);site:setHARMDetectionChance(mode[2])
    site.missilesInFlight={{isExist=function()return false end}}
    site.objectsIdentifiedAsHarms={{getAge=function()return 61 end}}
    site.lastJammerUpdate=NOW-11
    unit.controller.options[AI.Option.Air.id.ROE]=AI.Option.Air.val.ROE.WEAPON_HOLD
    site:scanForHarms()
    assert(site:isScanningForHARMs(),"maintenance must run for every live element")
    tick(2)
    eq(site:hasMissilesInFlight(),false);eq(#site.objectsIdentifiedAsHarms,0)
    eq(unit.controller.options[AI.Option.Air.id.ROE],AI.Option.Air.val.ROE.WEAPON_FREE)
    eq(site.lastJammerUpdate,0)
    local id=site.harmScanID;site:stopScanningForHARMs();eq(mist.tasks[id],nil)
    site:cleanUp()
end
local site=siteFixture()
local missile={alive=true,isExist=function(self)return self.alive end}
site.missilesInFlight={missile};site:scanForHarms();tick(2)
eq(site:hasMissilesInFlight(),true)
missile.alive=false;tick(2);eq(site:hasMissilesInFlight(),false)
site:cleanUp()

