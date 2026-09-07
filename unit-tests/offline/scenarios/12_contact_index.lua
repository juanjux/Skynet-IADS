local iads=SkynetIADS:create("index")
local names=0
local function contact(name,radar)
 local c=SkynetIADSContact:create({object=dcsUnit(name)},radar)
 c.getName=function(self)names=names+1;return self.dcsName end
 return c
end
local radars={};for i=1,50 do radars[i]={} end
for r=1,50 do for c=1,200 do iads:mergeContact(contact("c"..c,radars[r])) end end
eq(#iads:getContacts(),200);eq(names,10000,"one name lookup per merge")
for _,c in ipairs(iads.contacts) do eq(#c:getAbstractRadarElementsDetected(),50) end
local first=iads.contacts[1];first:setHARMState(SkynetIADSContact.HARM)
local incoming=contact("c1",radars[1]);iads:mergeContact(incoming)
eq(incoming:getHARMState(),SkynetIADSContact.HARM);eq(iads.contacts[1],first)
local detector=iads.harmDetection
eq(#detector:getNewRadarsThatHaveDetectedContact(first),50)
eq(#detector:getNewRadarsThatHaveDetectedContact(first),0)
first:addAbstractRadarElementDetected({});eq(#detector:getNewRadarsThatHaveDetectedContact(first),1)
eq(#first:getAbstractRadarElementsDetected(),51)
NOW=NOW+33;iads:cleanAgedTargets();detector:cleanAgedContacts()
eq(#iads.contacts,0);eq(next(iads.contactsByName),nil)
eq(next(detector.contactRadarsEvaluated),nil)
local replacement=contact("c1",radars[2]);iads:mergeContact(replacement);eq(iads.contacts[1],replacement)
iads.contacts={first};iads:mergeContact(incoming);eq(#iads.contacts,1);eq(iads.contacts[1],first)
