local site=siteFixture()
local units={}
for i=1,8 do
 local u=dcsUnit("launcher"..i);units[i]=u
 u.ammo={{count=100,desc={category=Weapon.Category.SHELL}}}
 site.launchers[i]=SkynetIADSSAMLauncher:create(u)
end
COUNTS={}
for i=1,4 do eq(site:hasRemainingAmmo(),true) end
for i=1,8 do eq(COUNTS["ammo:launcher"..i],1) end
local l=site.launchers[1]
units[1].ammo={{count=3,desc={category=Weapon.Category.MISSILE,
 rangeMaxAltMin=10000,rangeMaxAltMax=12000,altMax=4000}}}
NOW=NOW+0.1;eq(l:getRemainingNumberOfMissiles(),3);eq(l:getRange(),12000)
eq(l:getRemainingNumberOfShells(),0)
units[1].ammo[1].count=2
site:weaponFired({id=world.event.S_EVENT_SHOT,initiator=units[1],weapon={}})
eq(l:getRemainingNumberOfMissiles(),2,"shot invalidates within same instant")
units[1].ammo[1].count=5;l:setupRangeData();eq(l:getRemainingNumberOfMissiles(),5)
units[1].alive=false;eq(l:getRemainingNumberOfMissiles(),0)
NOW=NOW+1;units[1].alive=true;eq(l:getRemainingNumberOfMissiles(),5,"rearm after time advancement")
units[1].ammo=nil;NOW=NOW+1;eq(l:getRemainingNumberOfMissiles(),0);eq(l:getRemainingNumberOfShells(),0)
