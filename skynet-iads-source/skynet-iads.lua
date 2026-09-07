do

SkynetIADS = {}
SkynetIADS.__index = SkynetIADS

SkynetIADS.database = samTypesDB

function SkynetIADS:create(name)
	local iads = {}
	setmetatable(iads, SkynetIADS)
	iads.radioMenu = nil
	iads.earlyWarningRadars = {}
	iads.samSites = {}
	iads.commandCenters = {}
	iads.ewRadarScanMistTaskID = nil
	iads.coalition = nil
	iads.contacts = {}
	iads.contactsByName = {}
	iads.indexedContacts = iads.contacts
	iads.indexedContactCount = 0
	iads.maxTargetAge = 32
	iads.name = name
	iads.harmDetection = SkynetIADSHARMDetection:create(iads)
	iads.logger = SkynetIADSLogger:create(iads)
	if iads.name == nil then
		iads.name = ""
	end
	iads.contactUpdateInterval = 5
	iads.eventElements = {}
	iads.eventObjectSubscribers = {}
	iads.eventGroupSubscribers = {}
	iads.eventHandlerRegistered = true
	world.addEventHandler(iads)
	return iads
end

-- DCS may hand out a new Lua wrapper for the same engine object.
-- id_ also remains readable when an event's initiator has already died.
local function eventObjectKey(object)
	return object and (object.id_ or object)
end

function SkynetIADS:registerEventObject(element, object)
	if not object then return end
	local key = eventObjectKey(object)
	local subscribers = self.eventObjectSubscribers[key]
	if not subscribers then
		subscribers = {}
		self.eventObjectSubscribers[key] = subscribers
	end
	subscribers[element] = true
	self.eventElements[element][key] = true
	-- A group itself does not fire weapons: subscribe to all current members.
	if getmetatable(object) == Group and object:isExist() then
		local name = object:getName()
		self.eventGroupSubscribers[name] = self.eventGroupSubscribers[name] or {}
		self.eventGroupSubscribers[name][element] = true
		local units = object:getUnits() or {}
		for i = 1, #units do
			self:registerEventObject(element, units[i])
		end
	end
end

function SkynetIADS:registerElementEvents(element)
	self:unregisterElementEvents(element)
	self.eventElements[element] = {}
	self:registerEventObject(element, element:getDCSRepresentation())
	for _, object in ipairs(element:getPowerSources()) do
		self:registerEventObject(element, object)
	end
	for _, object in ipairs(element:getConnectionNodes()) do
		self:registerEventObject(element, object)
	end
	if not self.eventHandlerRegistered then
		world.addEventHandler(self)
		self.eventHandlerRegistered = true
	end
end

function SkynetIADS:unregisterElementEvents(element)
	local keys = self.eventElements[element]
	if keys then
		for key in pairs(keys) do
			local subscribers = self.eventObjectSubscribers[key]
			subscribers[element] = nil
			if next(subscribers) == nil then
				self.eventObjectSubscribers[key] = nil
			end
		end
		self.eventElements[element] = nil
		for name, subscribers in pairs(self.eventGroupSubscribers) do
			subscribers[element] = nil
			if next(subscribers) == nil then self.eventGroupSubscribers[name] = nil end
		end
	end
end

function SkynetIADS:onEvent(event)
	if event.id == world.event.S_EVENT_BIRTH then
		local unit = event.initiator
		if unit and unit.getGroup then
			local group = unit:getGroup()
			local subscribers = group and self.eventGroupSubscribers[group:getName()]
			if subscribers then
				for element in pairs(subscribers) do self:registerEventObject(element, unit) end
			end
		end
		return
	end
	if event.id ~= world.event.S_EVENT_SHOT and event.id ~= world.event.S_EVENT_DEAD then return end
	local subscribers = self.eventObjectSubscribers[eventObjectKey(event.initiator)]
	-- Retain legacy synthetic DEAD events without an initiator.
	if event.id == world.event.S_EVENT_DEAD and not event.initiator then subscribers = self.eventElements end
	if not subscribers then return end
	-- Callbacks may clean up elements; don't iterate a table they can mutate.
	local pending = {}
	for element in pairs(subscribers) do pending[#pending + 1] = element end
	for i = 1, #pending do
		local element = pending[i]
		if self.eventElements[element] then element:onEvent(event) end
	end
end

function SkynetIADS:setUpdateInterval(interval)
	self.contactUpdateInterval = interval
end

function SkynetIADS:setCoalition(item)
	if item then
		local coalitionID = item:getCoalition()
		if self.coalitionID == nil then
			self.coalitionID = coalitionID
		end
		if self.coalitionID ~= coalitionID then
			self:printOutputToLog("element: "..item:getName().." has a different coalition than the IADS", true)
		end
	end
end

function SkynetIADS:addJammer(jammer)
	table.insert(self.jammers, jammer)
end

function SkynetIADS:getCoalition()
	return self.coalitionID
end

function SkynetIADS:getDestroyedEarlyWarningRadars()
	local destroyedSites = {}
	for i = 1, #self.earlyWarningRadars do
		local ewSite = self.earlyWarningRadars[i]
		if ewSite:isDestroyed() then
			table.insert(destroyedSites, ewSite)
		end
	end
	return destroyedSites
end

function SkynetIADS:getUsableAbstractRadarElemtentsOfTable(abstractRadarTable)
	local usable = {}
	for i = 1, #abstractRadarTable do
		local abstractRadarElement = abstractRadarTable[i]
		if abstractRadarElement:hasActiveConnectionNode() and abstractRadarElement:hasWorkingPowerSource() and abstractRadarElement:isDestroyed() == false then
			table.insert(usable, abstractRadarElement)
		end
	end
	return usable
end

function SkynetIADS:getUsableEarlyWarningRadars()
	return self:getUsableAbstractRadarElemtentsOfTable(self.earlyWarningRadars)
end

function SkynetIADS:createTableDelegator(units) 
	local sites = SkynetIADSTableDelegator:create()
	for i = 1, #units do
		local site = units[i]
		table.insert(sites, site)
	end
	return sites
end

function SkynetIADS:addEarlyWarningRadarsByPrefix(prefix)
	self:deactivateEarlyWarningRadars()
	self.earlyWarningRadars = {}
	for unitName, unit in pairs(mist.DBs.unitsByName) do
		local pos = self:findSubString(unitName, prefix)
		--somehow the MIST unit db contains StaticObject, we check to see we only add Units
		local unit = Unit.getByName(unitName)
		if pos and pos == 1 and unit then
			self:addEarlyWarningRadar(unitName)
		end
	end
	return self:createTableDelegator(self.earlyWarningRadars)
end

function SkynetIADS:addEarlyWarningRadar(earlyWarningRadarUnitName)
	local earlyWarningRadarUnit = Unit.getByName(earlyWarningRadarUnitName)
	if earlyWarningRadarUnit == nil then
		self:printOutputToLog("you have added an EW Radar that does not exist, check name of Unit in Setup and Mission editor: "..earlyWarningRadarUnitName, true)
		return
	end
	self:setCoalition(earlyWarningRadarUnit)
	local ewRadar = nil
	local category = earlyWarningRadarUnit:getDesc().category
	if category == Unit.Category.AIRPLANE or category == Unit.Category.SHIP then
		ewRadar = SkynetIADSAWACSRadar:create(earlyWarningRadarUnit, self)
	else
		ewRadar = SkynetIADSEWRadar:create(earlyWarningRadarUnit, self)
	end
	ewRadar:setupElements()
	ewRadar:setCachedTargetsMaxAge(self:getCachedTargetsMaxAge())	
	-- for performance improvement, if iads is not scanning no update coverage update needs to be done, will be executed once when iads activates
	if self.ewRadarScanMistTaskID ~= nil then
		self:buildRadarCoverageForEarlyWarningRadar(ewRadar)
	end
	ewRadar:setActAsEW(true)
	ewRadar:setToCorrectAutonomousState()
	ewRadar:goLive()
	table.insert(self.earlyWarningRadars, ewRadar)
	if self:getDebugSettings().addedEWRadar then
			self:printOutputToLog("ADDED: "..ewRadar:getDescription())
	end
	return ewRadar
end

function SkynetIADS:getCachedTargetsMaxAge()
	return self.contactUpdateInterval
end

function SkynetIADS:getEarlyWarningRadars()
	return self:createTableDelegator(self.earlyWarningRadars)
end

function SkynetIADS:getEarlyWarningRadarByUnitName(unitName)
	for i = 1, #self.earlyWarningRadars do
		local ewRadar = self.earlyWarningRadars[i]
		if ewRadar:getDCSName() == unitName then
			return ewRadar
		end
	end
end

function SkynetIADS:findSubString(haystack, needle)
	return string.find(haystack, needle, 1, true)
end

function SkynetIADS:addSAMSitesByPrefix(prefix)
	self:deativateSAMSites()
	self.samSites = {}
	for groupName, groupData in pairs(mist.DBs.groupsByName) do
		local pos = self:findSubString(groupName, prefix)
		if pos and pos == 1 then
			--mist returns groups, units and, StaticObjects
			local dcsObject = Group.getByName(groupName)
			if dcsObject and dcsObject:getUnits()[1]:isActive() then
				self:addSAMSite(groupName)
			end
		end
	end
	return self:createTableDelegator(self.samSites)
end

function SkynetIADS:getSAMSitesByPrefix(prefix)
	local returnSams = {}
	for i = 1, #self.samSites do
		local samSite = self.samSites[i]
		local groupName = samSite:getDCSName()
		local pos = self:findSubString(groupName, prefix)
		if pos and pos == 1 then
			table.insert(returnSams, samSite)
		end
	end
	return self:createTableDelegator(returnSams)
end

function SkynetIADS:addSAMSite(samSiteName)
	local samSiteDCS = Group.getByName(samSiteName)
	if samSiteDCS == nil then
		self:printOutputToLog("you have added an SAM Site that does not exist, check name of Group in Setup and Mission editor: "..tostring(samSiteName), true)
		return
	end
	self:setCoalition(samSiteDCS)
	local samSite = SkynetIADSSamSite:create(samSiteDCS, self)
	samSite:setupElements()
	samSite:setCanEngageAirWeapons(true)
	samSite:goLive()
	samSite:setCachedTargetsMaxAge(self:getCachedTargetsMaxAge())
	if samSite:getNatoName() == "UNKNOWN" then
		self:printOutputToLog("you have added an SAM site that Skynet IADS can not handle: "..samSite:getDCSName(), true)
		samSite:cleanUp()
	else
		samSite:goDark()
		table.insert(self.samSites, samSite)
		if self:getDebugSettings().addedSAMSite then
			self:printOutputToLog("ADDED: "..samSite:getDescription())
		end
		-- for performance improvement, if iads is not scanning no update coverage update needs to be done, will be executed once when iads activates
		if self.ewRadarScanMistTaskID ~= nil then
			self:buildRadarCoverageForSAMSite(samSite)
		end
		return samSite
	end 
end

function SkynetIADS:getUsableSAMSites()
	return self:getUsableAbstractRadarElemtentsOfTable(self.samSites)
end

function SkynetIADS:getDestroyedSAMSites()
	local destroyedSites = {}
	for i = 1, #self.samSites do
		local samSite = self.samSites[i]
		if samSite:isDestroyed() then
			table.insert(destroyedSites, samSite)
		end
	end
	return destroyedSites
end

function SkynetIADS:getSAMSites()
	return self:createTableDelegator(self.samSites)
end

function SkynetIADS:getActiveSAMSites()
	local activeSAMSites = {}
	for i = 1, #self.samSites do
		if self.samSites[i]:isActive() then
			table.insert(activeSAMSites, self.samSites[i])
		end
	end
	return activeSAMSites
end

function SkynetIADS:getSAMSiteByGroupName(groupName)
	for i = 1, #self.samSites do
		local samSite = self.samSites[i]
		if samSite:getDCSName() == groupName then
			return samSite
		end
	end
end

function SkynetIADS:getSAMSitesByNatoName(natoName)
	local selectedSAMSites = SkynetIADSTableDelegator:create()
	for i = 1, #self.samSites do
		local samSite = self.samSites[i]
		if samSite:getNatoName() == natoName then
			table.insert(selectedSAMSites, samSite)
		end
	end
	return selectedSAMSites
end

function SkynetIADS:addCommandCenter(commandCenter)
	self:setCoalition(commandCenter)
	local comCenter = SkynetIADSCommandCenter:create(commandCenter, self)
	table.insert(self.commandCenters, comCenter)
	-- when IADS is active the radars will be added to the new command center. If it not active this will happen when radar coverage is built
	if self.ewRadarScanMistTaskID ~= nil then
		self:addRadarsToCommandCenters()
	end
	return comCenter
end

function SkynetIADS:isCommandCenterUsable()
	if #self:getCommandCenters() == 0 then
		return true
	end
	local usableComCenters = self:getUsableAbstractRadarElemtentsOfTable(self:getCommandCenters())
	return (#usableComCenters > 0)
end

function SkynetIADS:getCommandCenters()
	return self.commandCenters
end


function SkynetIADS.evaluateContacts(self)

	local ewRadars = self:getUsableEarlyWarningRadars()
	local samSites = self:getUsableSAMSites()
	
	--will add SAM Sites acting as EW Rardars to the ewRadars array:
	for i = 1, #samSites do
		local samSite = samSites[i]
		--We inform SAM sites that a target update is about to happen. If they have no targets in range after the cycle they go dark
		samSite:targetCycleUpdateStart()
		if samSite:getActAsEW() then
			table.insert(ewRadars, samSite)
		end
		--if the sam site is not in ew mode and active we grab the detected targets right here
		if samSite:isActive() and samSite:getActAsEW() == false then
			local contacts = samSite:getDetectedTargets()
			for j = 1, #contacts do
				local contact = contacts[j]
				self:mergeContact(contact)
			end
		end
	end

	local samSitesToTrigger = {}
	
	for i = 1, #ewRadars do
		local ewRadar = ewRadars[i]
		--call go live in case ewRadar had to shut down (HARM attack)
		ewRadar:goLive()
		-- if an awacs has traveled more than a predeterminded distance we update the autonomous state of the SAMs
		if getmetatable(ewRadar) == SkynetIADSAWACSRadar and ewRadar:isUpdateOfAutonomousStateOfSAMSitesRequired() then
			self:buildRadarCoverageForEarlyWarningRadar(ewRadar)
		end
		local ewContacts = ewRadar:getDetectedTargets()
		if #ewContacts > 0 then
			local samSitesUnderCoverage = ewRadar:getUsableChildRadars()
			for j = 1, #samSitesUnderCoverage do
				local samSiteUnterCoverage = samSitesUnderCoverage[j]
				-- only if a SAM site is not active we add it to the hash of SAM sites to be iterated later on
				if samSiteUnterCoverage:isActive() == false then
					--we add them to a hash to make sure each SAM site is in the collection only once, reducing the number of loops we conduct later on
					samSitesToTrigger[samSiteUnterCoverage:getDCSName()] = samSiteUnterCoverage
				end
			end
			for j = 1, #ewContacts do
				local contact = ewContacts[j]
				self:mergeContact(contact)
			end
		end
	end

	self:cleanAgedTargets()
	
	-- Worked out once per contact rather than once per site-and-contact pair: this used
	-- to call getDesc() for every combination, which on a busy map is thousands of calls
	-- a cycle for an answer that cannot differ between sites.
	local airborneContacts = {}
	for j = 1, #self.contacts do
		local contact = self.contacts[j]
		if SkynetIADS.isAirborneContact(contact) then
			table.insert(airborneContacts, contact)
		end
	end

	for samName, samToTrigger in pairs(samSitesToTrigger) do
		for j = 1, #airborneContacts do
			samToTrigger:informOfContact(airborneContacts[j])
		end
	end
	
	for i = 1, #samSites do
		local samSite = samSites[i]
		samSite:targetCycleUpdateEnd()
	end
	
	self.harmDetection:setContacts(self:getContacts())
	self.harmDetection:evaluateContacts()
	
	self.logger:printSystemStatus()
end

--- Is this contact something in the air a SAM site should be told about?
--
-- A contact is a unit OR a weapon, and the two use different category enumerations
-- whose values collide: Weapon.Category.BOMB is 3, the same as Unit.Category.SHIP, and
-- Weapon.Category.MISSILE is 1, the same as Unit.Category.HELICOPTER. Reading every
-- contact as a unit therefore threw bombs away as if they were ships and let missiles
-- through by coincidence. See walder/Skynet-IADS#107.
function SkynetIADS.isAirborneContact(contact)
	local description = contact:getDesc()
	if description == nil then
		return false
	end
	local category = description.category
	if category == nil then
		return false
	end
	local object = contact:getDCSRepresentation()
	local isWeapon = false
	if object ~= nil and object.getCategory ~= nil then
		local ok, objectCategory = pcall(function() return object:getCategory() end)
		isWeapon = ( ok and objectCategory == Object.Category.WEAPON )
	end
	if isWeapon then
		-- everything a weapon can be is worth knowing about except a shell
		return category ~= Weapon.Category.SHELL
	end
	return category ~= Unit.Category.GROUND_UNIT
		and category ~= Unit.Category.SHIP
		and category ~= Unit.Category.STRUCTURE
end

function SkynetIADS:cleanAgedTargets()
	local contactsToKeep = {}
	local byName = {}
	for i = 1, #self.contacts do
		local contact = self.contacts[i]
		if contact:getAge() < self.maxTargetAge then
			table.insert(contactsToKeep, contact)
			byName[contact:getName()] = contact
		end
	end
	self.contacts = contactsToKeep
	self.contactsByName = byName
	self.indexedContacts = contactsToKeep
	self.indexedContactCount = #contactsToKeep
end

--TODO unit test this method:
function SkynetIADS:getAbstracRadarElements()
	local abstractRadarElements = {}
	local ewRadars = self:getEarlyWarningRadars()
	local samSites = self:getSAMSites()
	
	for i = 1, #ewRadars do
		local ewRadar = ewRadars[i]
		table.insert(abstractRadarElements, ewRadar)
	end
	
	for i = 1, #samSites do
		local samSite = samSites[i]
		table.insert(abstractRadarElements, samSite)
	end
	return abstractRadarElements
end


function SkynetIADS:addRadarsToCommandCenters()

	--we clear any existing radars that may have been added earlier
	local comCenters = self:getCommandCenters()
	for i = 1, #comCenters do
		local comCenter = comCenters[i]
		comCenter:clearChildRadars()
	end	
	
	-- then we add child radars to the command centers
	local abstractRadarElements = self:getAbstracRadarElements()
		for i = 1, #abstractRadarElements do
			local abstractRadar = abstractRadarElements[i]
			self:addSingleRadarToCommandCenters(abstractRadar)
		end
end

function SkynetIADS:addSingleRadarToCommandCenters(abstractRadarElement)
	local comCenters = self:getCommandCenters()
	for i = 1, #comCenters do
		local comCenter = comCenters[i]
		comCenter:addChildRadar(abstractRadarElement)
	end	
end

-- this method rebuilds the radar coverage of the IADS, a complete rebuild is only required the first time the IADS is activated
-- during runtime it is sufficient to call buildRadarCoverageForSAMSite or buildRadarCoverageForEarlyWarningRadar method that just updates the IADS for one unit, this saves script execution time
function SkynetIADS:buildRadarCoverage()	
	
	--to build the basic radar coverage we use all SAM sites. Checks if SAM site has power or a connection node is done when using the SAM site later on
	local samSites = self:getSAMSites()
	
	--first we clear all child and parent radars that may have been added previously
	for i = 1, #samSites do
		local samSite = samSites[i]
		samSite:clearChildRadars()
		samSite:clearParentRadars()
	end
	
	local ewRadars = self:getEarlyWarningRadars()
	
	for i = 1, #ewRadars do
		local ewRadar = ewRadars[i]
		ewRadar:clearChildRadars()
	end	
	
	--then we rebuild the radar coverage
	local abstractRadarElements = self:getAbstracRadarElements()
	for i = 1, #abstractRadarElements - 1 do
		local first = abstractRadarElements[i]
		for j = i + 1, #abstractRadarElements do
			local second = abstractRadarElements[j]
			-- Each unordered pair needs exactly two directional range checks.
			if first:isInRadarDetectionRangeOf(second) then
				self:buildRadarAssociation(second, first, true)
			end
			if second:isInRadarDetectionRangeOf(first) then
				self:buildRadarAssociation(first, second, true)
			end
		end
	end
	
	self:addRadarsToCommandCenters()
	
	--we call this once on all sam sites, to make sure autonomous sites go live when IADS activates
	for i = 1, #samSites do
		local samSite = samSites[i]
		samSite:informChildrenOfStateChange()
	end

end

function SkynetIADS:buildRadarCoverageForAbstractRadarElement(abstractRadarElement)
	local abstractRadarElements = self:getAbstracRadarElements()
	for i = 1, #abstractRadarElements do
		local aElementToCompare = abstractRadarElements[i]
		if aElementToCompare ~= abstractRadarElement then
			if abstractRadarElement:isInRadarDetectionRangeOf(aElementToCompare) then
				self:buildRadarAssociation(aElementToCompare, abstractRadarElement)
			end
			if aElementToCompare:isInRadarDetectionRangeOf(abstractRadarElement) then
				self:buildRadarAssociation(abstractRadarElement, aElementToCompare)
			end
		end
	end
end

function SkynetIADS:buildRadarAssociation(parent, child, deferStateUpdate)
	--chilren should only be SAM sites not EW radars
	if ( getmetatable(child) == SkynetIADSSamSite ) then
		parent:addChildRadar(child)
	end
	--Only SAM Sites should have parent Radars, not EW Radars
	if ( getmetatable(child) == SkynetIADSSamSite ) then
		child:addParentRadar(parent, deferStateUpdate)
	end
end

function SkynetIADS:buildRadarCoverageForSAMSite(samSite)
	self:buildRadarCoverageForAbstractRadarElement(samSite)
	self:addSingleRadarToCommandCenters(samSite)
end

function SkynetIADS:buildRadarCoverageForEarlyWarningRadar(ewRadar)
	self:buildRadarCoverageForAbstractRadarElement(ewRadar)
	self:addSingleRadarToCommandCenters(ewRadar)
end

function SkynetIADS:mergeContact(contact)
	-- Keep the ordered public array; rebuild if a caller replaced/resized it.
	if self.indexedContacts ~= self.contacts or self.indexedContactCount ~= #self.contacts then
		self.contactsByName = {}
		for i = 1, #self.contacts do
			local known = self.contacts[i]
			self.contactsByName[known:getName()] = known
		end
		self.indexedContacts = self.contacts
		self.indexedContactCount = #self.contacts
	end
	local name = contact:getName()
	local existing = self.contactsByName[name]
	if existing then
		existing:refresh()
		-- The logger also uses the incoming per-radar contact.
		contact:setHARMState(existing:getHARMState())
		local radars = contact:getAbstractRadarElementsDetected()
		for i = 1, #radars do
			existing:addAbstractRadarElementDetected(radars[i])
		end
	else
		table.insert(self.contacts, contact)
		self.contactsByName[name] = contact
		self.indexedContactCount = #self.contacts
	end
end


function SkynetIADS:getContacts()
	return self.contacts
end

function SkynetIADS:getDebugSettings()
	return self.logger.debugOutput
end

function SkynetIADS:printOutput(output, typeWarning)
	self.logger:printOutput(output, typeWarning)
end

function SkynetIADS:printOutputToLog(output)
	self.logger:printOutputToLog(output)
end

-- will start going through the Early Warning Radars and SAM sites to check what targets they have detected
function SkynetIADS.activate(self)
	-- cleanUp removes subscriptions; activation must restore them.
	for _, element in ipairs(self:getAbstracRadarElements()) do self:registerElementEvents(element) end
	for _, element in ipairs(self.commandCenters) do self:registerElementEvents(element) end
	if not self.eventHandlerRegistered then
		world.addEventHandler(self)
		self.eventHandlerRegistered = true
	end
	mist.removeFunction(self.ewRadarScanMistTaskID)
	self.ewRadarScanMistTaskID = mist.scheduleFunction(SkynetIADS.evaluateContacts, {self}, 1, self.contactUpdateInterval)
	self:buildRadarCoverage()
end

function SkynetIADS:setupSAMSitesAndThenActivate(setupTime)
	self:activate()
	self.logger:printOutputToLog("DEPRECATED: setupSAMSitesAndThenActivate, no longer needed since using enableEmission instead of AI on / off allows for the Ground units to setup with their radars turned off")
end

function SkynetIADS:deactivate()
	world.removeEventHandler(self)
	self.eventHandlerRegistered = false
	mist.removeFunction(self.ewRadarScanMistTaskID)
	mist.removeFunction(self.samSetupMistTaskID)
	self:deativateSAMSites()
	self:deactivateEarlyWarningRadars()
	self:deactivateCommandCenters()
end

function SkynetIADS:deactivateCommandCenters()
	for i = 1, #self.commandCenters do
		local comCenter = self.commandCenters[i]
		comCenter:cleanUp()
	end
end

function SkynetIADS:deativateSAMSites()
	for i = 1, #self.samSites do
		local samSite = self.samSites[i]
		samSite:cleanUp()
	end
end

function SkynetIADS:deactivateEarlyWarningRadars()
	for i = 1, #self.earlyWarningRadars do
		local ewRadar = self.earlyWarningRadars[i]
		ewRadar:cleanUp()
	end
end	

--- The menu that shows this IADS's status, for the side that owns it.
--
-- It used to be added with missionCommands.addSubMenu, which has no coalition and so
-- gives the menu to everybody: an enemy pilot could open F10 and read "show IADS
-- Status" and "show contacts" for the network he was flying against -- its whole state,
-- and every contact it was tracking. Upstream walder/Skynet-IADS#88.
function SkynetIADS:addRadioMenu()
	local side = self:getCoalition()
	self.radioMenu = missionCommands.addSubMenuForCoalition(side, 'SKYNET IADS '..self:getCoalitionString())
	missionCommands.addCommandForCoalition(side, 'show IADS Status', self.radioMenu, SkynetIADS.updateDisplay, {self = self, value = true, option = 'IADSStatus'})
	missionCommands.addCommandForCoalition(side, 'hide IADS Status', self.radioMenu, SkynetIADS.updateDisplay, {self = self, value = false, option = 'IADSStatus'})
	missionCommands.addCommandForCoalition(side, 'show contacts', self.radioMenu, SkynetIADS.updateDisplay, {self = self, value = true, option = 'contacts'})
	missionCommands.addCommandForCoalition(side, 'hide contacts', self.radioMenu, SkynetIADS.updateDisplay, {self = self, value = false, option = 'contacts'})
end

function SkynetIADS:removeRadioMenu()
	missionCommands.removeItemForCoalition(self:getCoalition(), self.radioMenu)
end

function SkynetIADS.updateDisplay(params)
	local option = params.option
	local self = params.self
	local value = params.value
	if option == 'IADSStatus' then
		self:getDebugSettings()[option] = value
	elseif option == 'contacts' then
		self:getDebugSettings()[option] = value
	end
end

function SkynetIADS:getCoalitionString()
	local coalitionStr = "RED"
	if self.coalitionID == coalition.side.BLUE then
		coalitionStr = "BLUE"
	elseif self.coalitionID == coalition.side.NEUTRAL then
		coalitionStr = "NEUTRAL"
	end
		
	if self.name then
		coalitionStr = "COALITION: "..coalitionStr.." | NAME: "..self.name
	end
	
	return coalitionStr
end

function SkynetIADS:getMooseConnector()
	if self.mooseConnector == nil then
		self.mooseConnector = SkynetMooseA2ADispatcherConnector:create(self)
	end
	return self.mooseConnector
end

function SkynetIADS:addMooseSetGroup(mooseSetGroup)
	self:getMooseConnector():addMooseSetGroup(mooseSetGroup)
end

end
