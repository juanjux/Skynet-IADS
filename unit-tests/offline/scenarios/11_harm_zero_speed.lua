local iads=SkynetIADS:create("HARM")
local detector=iads.harmDetection
local calls={}
detector.informRadarsOfHARM=function(self,c) calls[#calls+1]=c end
local function contact(speed,state)
    return {getGroundSpeedInKnots=function()return speed end,
        getSimpleAltitudeProfile=function()return{}end,
        getAbstractRadarElementsDetected=function()return{}end,
        isIdentifiedAsHARM=function()return state end,getAge=function()return 0 end}
end
local fresh=contact(0,false);local harm=contact(1000,true);local slow=contact(300,false)
for _,list in ipairs({{fresh,harm},{harm,fresh},{fresh,slow,harm},{fresh,fresh,harm}}) do
    calls={};detector:setContacts(list);detector:evaluateContacts()
    eq(#calls,1);eq(calls[1],harm)
end
calls={};detector:setContacts({fresh});detector:evaluateContacts();eq(#calls,0)

