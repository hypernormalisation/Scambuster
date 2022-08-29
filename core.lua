local addon_name, cb = ...
local CBL = LibStub("AceAddon-3.0"):NewAddon(addon_name, "AceConsole-3.0", "AceEvent-3.0")
local LSM = LibStub("LibSharedMedia-3.0")
cb.debug = true

if cb.debug then CBL:Print("Parsing core.lua...") end

------------------------------------------------------------------------------------
-- The basic AceAddon structure
function CBL:OnInitialize()

	-- Make the addon database
	self.db = LibStub("AceDB-3.0"):New(addon_name.."DB", self.defaults, true)
	self.conf = self.db.global --shorthand

	-- Register the options table
	local AC = LibStub("AceConfig-3.0")
	local ACD = LibStub("AceConfigDialog-3.0")
	local options_name = addon_name.."_Options"
	AC:RegisterOptionsTable(options_name, self.options)
	self.optionsFrame = ACD:AddToBlizOptions(options_name, addon_name)

	-- Register the necessary slash commands
	self:RegisterChatCommand("cb", "slashcommand_options")
	self:RegisterChatCommand("blacklist", "slashcommand_options")
	self:RegisterChatCommand("testbl", "slashcommand_testbl")
	self:RegisterChatCommand("blacklist_target", "slashcommand_blacklist_target")

	self:RegisterChatCommand("soundcheck", "slashcommand_soundcheck")
	self:RegisterChatCommand("dump_config", "slashcommand_dump_config")

	-- Register our custom sound alerts with LibSharedMedia
	LSM:Register(
		"sound", "Cutpurse: Criminal scum!",
		string.format([[Interface\Addons\%s\media\criminal_scum.mp3]], addon_name)
	)
	LSM:Register(
		"sound", "Cutpurse: Not on my watch!",
		string.format([[Interface\Addons\%s\media\nobody_breaks_the_law.mp3]], addon_name)
	)
	LSM:Register(
		"sound", "Cutpurse: You've violated the law!",
		string.format([[Interface\Addons\%s\media\youve_violated_the_law.mp3]], addon_name)
	)

	-- Central blocklist
	self.has_cbl = false
	self.ignored_players = {}
	if self.db.realm.user_blacklist == nil then
		self.db.realm.user_blacklist = {}
	end
	self.ubl = self.db.realm.user_blacklist -- shorthand

end

function CBL:OnEnable()
	-- some basic post-load info to gather
	self.realm_name = GetRealmName()
	self.player_faction = UnitFactionGroup("player")

	-- Load necessary data.
	-- We do this here so extensions can init their
	-- provider blocklists before we construct the cbl.
	self:load_dynamic_info()
	self:load_ubl()
	self:get_valid_providers()
	self:load_cbl() -- constructed each time load/setting change

	-- Enable the requisite events here
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")

	-- Welcome message if requested
	if self.conf.welcome_message then
		self:Print('Welcome to version 0.0.1.')
	end
end

function CBL:OnDisable()
	-- might not need this'un
end

------------------------------------------------------------------------------------
-- funcs to load info
function CBL:load_ubl()
	-- Loads the user blocklist data.
	if self.db.realm.user_blacklist == nil then
		self.db.realm.user_blacklist = {}
	end
	self.ubl = self.db.realm.user_blacklist -- shorthand
end

function CBL:load_dynamic_info()
	-- Loads the dynamic information on scammers the player's client 
	-- has gathered from the realm db.
	if self.db.realm.player_dynamic_info == nil then
		self.db.realm.player_dynamic_info = {}
	end
	-- if self.db.player_dynamic_info[self.realm_name] == nil then
	-- 	self.db.player_dynamic_info.realm_name = {}
	-- end
	-- finally a shorthand for this realm's dynamic player data.
	self.pdi = self.db.realm.player_dynamic_info
end

function CBL:get_valid_providers()
	-- Verifies the format of providers and gets any valid realm data
	self.valid_providers = {}
	for provider, data in pairs(self.providers) do
		if data == nil or data.realms == nil then
			self:Print(
				string.format("Provider %s is not properly configured!")
			)
		else
			local r = data.realms[self.realm_name]
			if r ~= nil and next(r) ~= nil then
				self.valid_providers[provider] = r
			end
		end
	end
end

function CBL:load_cbl()
	-- Constructs the central blocklist from the valid providers.
	self.cbl = {}
	if self.valid_providers == nil or next(self.valid_providers) == nil then
		self:Print(string.format("INFO: no central realm data exists on %s.", self.realm_name))
		return
	end
	self.has_cbl = true

	-- TO-DO: options for enabled/disabled providers, handle provider precedence here.

	-- Assemble cbl, append provider to info.
	for provider, data in pairs(self.valid_providers) do
		for player, pdata in pairs(data) do
			self.cbl[player] = {
				provider = provider,
				reason = pdata.reason,
				evidence = pdata.evidence,
				ignore = false, -- TO-DO: load this from settings
			}
		end
	end
end

------------------------------------------------------------------------------------
-- Register slashcommands 
function CBL:slashcommand_options(input, editbox)
	local ACD = LibStub("AceConfigDialog-3.0")
	ACD:Open(addon_name.."_Options")
end

function CBL:slashcommand_soundcheck()
	local sound_file = LSM:Fetch('sound', self.conf.alert_sound)
	PlaySoundFile(sound_file)
end

function CBL:slashcommand_blacklist_target(reason)
	-- Places the current target on the user blocklist for the provided reason.
	-- Must provide a reason!
	local t = {
		unitID = "target",
		reason = reason,
	}
	self:add_to_ubl("target", t)
end

function CBL:slashcommand_testbl()
	self:Print(self.cbl)
	local t = self.cbl
	for name, bl_data in pairs(t) do
		self:Print("cbl:")
		print('------------------------')
		self:Print(name, bl_data)
		for k, v in pairs(bl_data) do
			self:Print(k, v)
		end
	end
	local t = self.ubl
	for name, bl_data in pairs(t) do
		print('------------------------')
		self:Print("ubl:")
		self:Print(name, bl_data)
		for k, v in pairs(bl_data) do
			self:Print(k, v)
		end
	end
	self:Print(self.pdi)
	local t = self.pdi
	for name, bl_data in pairs(t) do
		print('------------------------')
		self:Print("pdi:")
		self:Print(name, bl_data)
		for k, v in pairs(bl_data) do
			self:Print(k, v)
		end
	end
end

function CBL:slashcommand_dump_config()
	self:Print('Dumping options table:')
	local t = self.conf
	if type(t) == "table" then
		for i, v in pairs(t) do
			print(i, v)
		end
	end
end

------------------------------------------------------------------------------------
-- Callback functions for events
function CBL:UPDATE_MOUSEOVER_UNIT()

	-- First check the mouseover is another player on same faction
	local context = "mouseover"
	local is_same_faction = self.player_faction == UnitFactionGroup(context)
	if not is_same_faction or not UnitIsPlayer(context) or
		UnitIsUnit("player", context) then return end

	-- Check the player against cbl and update as necessary.
	local name = UnitName(context)
	if self:check_against_bls(name) then
		self:update_pdi(context)
	end

	if self.has_cbl and self:check_against_cbl(name) then
		self:create_alert()
	end
end

function CBL:CHAT_MSG_WHISPER(event_name, msg, player_name_realm,
	_, _, player_name, _, _, _, _, _, line_id, player_guid)
	local time_now = GetTime()
	local on_ubl = self:check_against_ubl(player_name)
end

------------------------------------------------------------------------------------
-- helper funcs for loading and altering blacklists
function CBL:update_pdi(unitId)
	-- Function to update the player dynamic information table.
	-- when we encounter a scammer in-game and can access their information.
	-- unitId is the unit token e.g. "target", "mouseover", "partyN" etc
	local name = UnitName(unitId)
	if name == nil then
		self:Print("ERROR: name from API not valid.")
		return
	end
	if self.pdi[name] == nil then
		self.pdi[name] = {}
	end
	local last_seen = self.pdi[name]["last_seen"]
	-- Only update non last_seen data once every 10 mins
	if last_seen ~= nil and (time() - last_seen < 600) then
		self:Print('locking update, too recent')
		self.pdi[name]["last_seen"] = time()
		return
	end

	local class = UnitClass(unitId)
	local level = UnitLevel(unitId)
	local race = UnitRace(unitId)
	local guild = GetGuildInfo(unitId)
	if self.pdi[name] == nil then
		self:Print(string.format('Registering new info for %s', name))
	else
		self:Print(string.format('Updating info for %s', name))
	end
	self.pdi[name] = {
		class = class,
		level = level,
		guild = guild,
		race = race,
		last_seen = time()
	}
end

function CBL:add_to_ubl(t)
	-- Function to add to the ubl. t should be a table with at least one 
	-- of unitID or name, and always with reason.
	local unitID = t.unitId
	local name = t.name
	local reason = t.reason
	if reason == nil then
		self:Print("Error: need a reason to blacklist target")
		return
	end
	if unitID ~= nil then
		if not self:is_unit_eligible(unitID) then
			self:Print("Unit is not a same-faction player and cannot be blacklisted!")
			return
		end
		name = UnitName(unitID)
		if name == nil then
			self:Print("ERROR: name from API not valid.")
			return
		end
		-- Record player's dynamic information.
		self:update_pdi(unitID)
	end
	-- check if on blacklist already
	if self.ubl[name] ~= nil then
		self:Print(string.format("%s is already on user blocklist, updating info.", name))
	else
		self:Print(string.format("%s will be placed on the user blocklist.", name))
	end
	self.ubl[name] = {
		reason = reason,
		ignore = false -- override any ignore settings
	}
end

function CBL:is_unit_eligible(unitId)
	-- Function to get info using the specified unit_id and
	-- verify the unit in question is another same-faction player
	if not UnitIsPlayer(unitId) and UnitIsUnit("player", unitId) then
		return false
	end
	local is_same_faction = self.player_faction == UnitFactionGroup(unitId)
	if not is_same_faction then
		return false
	end
	return true
end

function CBL:check_against_ubl(player_name)
	if self.ubl[player_name] == nil then
		return false
	end
	return true
end

function CBL:check_against_cbl(player_name)
	if self.cbl[player_name] == nil then
		return false
	end
	return true
end

function CBL:check_against_bls(player_name)
	return self:check_against_ubl(player_name) or self:check_against_cbl(player_name)
end

-- alert funcs
function CBL:create_alert()

	-- Figure out if we're locked out.
	if self:is_time_locked() then return end

	-- Notify with the required methods.
	self:play_alert_sound()

end

function CBL:is_time_locked()
	-- func to tell if we're time locked on alerts

	local time_now = GetTime()
	if self.time_since_laste == nil then
		self.time_last_alert = time_now
		return true
	end
	print('time_now = ' .. time_now)
	print('Time of last alert = ' .. self.time_last_alert)
	local time_since_last = time_now - self.time_last_alert
	print('Time since last alert = ' .. time_since_last)
	-- print('grace period = ', db.grace_period_s)
	if time_since_last < self.conf.grace_period_s then
		print('locked out of alert')
		return true
	end

	-- else set the new time and return false
	self.time_last_alert = time_now
	return false
end

function CBL:play_alert_sound()
	self:Print('playing alert')
	-- if not db.b_play_alert_sound then return end
	local sound_file = LSM:Fetch('sound', self.conf.alert_sound)
	PlaySoundFile(sound_file)
end


if cb.debug then CBL:Print("Finished parsing core.lua.") end
