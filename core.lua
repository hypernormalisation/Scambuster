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
	self.optionsFrame = ACD:AddToBlizOptions(options_name, "ClassicBlacklist")

	-- Register the necessary slash commands
	self:RegisterChatCommand("cb", "slashcommand_options")
	self:RegisterChatCommand("blacklist", "slashcommand_options")
	self:RegisterChatCommand("testbl", "slashcommand_testbl")
	self:RegisterChatCommand("blacklist_target", "slashcommand_blacklist_target")

	self:RegisterChatCommand("soundcheck", "slashcommand_soundcheck")
	self:RegisterChatCommand("dump_config", "slashcommand_dump_config")

	-- Register our custom sound alerts with LibSharedMedia
	LSM:Register(
		"sound", "CB: Criminal scum!",
		[[Interface\Addons\ClassicBlacklist\media\criminal_scum.mp3]]
	)
	LSM:Register(
		"sound", "CB: Not on my watch!",
		[[Interface\Addons\ClassicBlacklist\media\nobody_breaks_the_law.mp3]]
	)
	LSM:Register(
		"sound", "CB: You've violated the law!",
		[[Interface\Addons\ClassicBlacklist\media\youve_violated_the_law.mp3]]
	)

	-- Handle realm databases.
	if self.db.realm.central_blacklist == nil then
		self.db.realm.central_blacklist = {}
	end
	self.has_cbl = false
	self.cbl = self.db.realm.central_blacklist -- shorthand
	if self.db.realm.user_blacklist == nil then
		self.db.realm.user_blacklist = {}
	end
	self.ubl = self.db.realm.user_blacklist -- shorthand

end

function CBL:OnEnable()
	-- some basic post-load info to gather
	self.realm_name = GetRealmName()
	self.player_faction = UnitFactionGroup("player")


	self:load_cbl()


	print("player_faction says")
	print(self.player_faction)

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
	local db = self.db.realm

	if not self:is_unit_eligible("target") then
		self:Print("Target is not a same-faction player and cannot be blacklisted!")
		return
	end

	if reason == nil then
		self:Print("Error: need a reason to blacklist target")
		return
	end
	local name = UnitName("target")
	local class = UnitClass("target")
	local level = UnitLevel("target")
	local race = UnitRace("target")
	local guild = GetGuildInfo("target")
	
	-- check if on blacklist already
	if self.ubl[name] ~= nil then
		self:Print("Target already on blacklist, updating info.")
		self.ubl[name] = {
			class = class,
			level = level,
			guild = guild,
			race = race,
			reason = reason,
			last_seen = time(),
		}
		return
	end
	local str1 = ""
	if guild == nil then
		str1 = string.format("%s is a lvl %i %s %s", name, level, race, class)
	
	else
		str1 = string.format("%s is a lvl %i %s %s with the guild %s", name, level, race, class, guild)
	end
	self:Print(str1)
	self:Print('Reason to blacklist: ' .. reason)

	self.ubl[name] = {
		class = class,
		level = level,
		guild = guild,
		race = race,
		reason = reason,
	}
	self:Print('Added to blacklist!')

end


function CBL:slashcommand_testbl()
	self:Print(self.cbl)
	local t = self.cbl
	for name, bl_data in pairs(t) do
		print('------------------------')
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

	-- Check the player against blacklist
	local target_name = UnitName(context)
	-- self:Print("Mouseover friendly player called: " .. target_name)
	
	local on_blacklist = self:check_against_cbl(target_name)
	if on_blacklist then
		self:create_alert()
		self:update_cbl_dynamic(context)
	end
end

function CBL:CHAT_MSG_WHISPER(event_name, msg, player_name_realm,
	_, _, player_name, _, _, _, _, _, line_id, player_guid)
	local time_now = GetTime()
	local on_ubl = self:check_against_ubl(player_name)
end

------------------------------------------------------------------------------------
-- helper funcs for loading and altering blacklists
function CBL:load_cbl()
	-- Function to load the central blacklist for the server

	-- Verify we have realm data and if so fetch it
	if self.all_realms_cbl[self.realm_name] == nil then
		self:Print(string.format("INFO: no central realm data exists on %s.", self.realm_name))
		return
	end
	self:Print('Loading blacklist data for ' .. CBL.realm_name .. '...')
	local module_table = self.all_realms_cbl[self.realm_name]
	self.has_cbl = true

	-- First check the central blacklist module table against the realm data
	-- and remove anyone who is no longer on the module table.
	local names_to_remove = {}
	for name, _ in pairs(self.cbl) do
		if module_table[name] == nil then
			self:Print(string.format("Player %s is no longer on the blacklist, removing...", name))
			names_to_remove[name] = true
		end
	end
	for name, _ in pairs(names_to_remove) do
		self.cbl[name] = nil
	end

	-- Now update the table entries that are immutable to the player
	-- in case of an addon update.
	for name, bl_data in pairs(module_table) do
		self:Print(name, bl_data)
		-- Create necessary tables and don't overwrite any existing ignore preferences
		if self.cbl[name] == nil then
			self.cbl[name] = {}
			self.cbl[name]["ignore"] = false
		end
		self.cbl[name]["reason"] = bl_data.reason
		self.cbl[name]["evidence"] = bl_data.evidence
	end
end

function CBL:update_cbl_dynamic(unitId)
	-- Function to update the dynamic information on the cbl
	-- when we encounter a scammer in-game and can access their information.
	-- unitId is the unit token e.g. "target", "mouseover", "partyN" etc
	
	-- Only update non last_seen data once every 10 mins
	local name = UnitName(unitId)
	local last_seen = self.cbl[name]["last_seen"]
	if last_seen ~= nil and (time() - last_seen < 600) then
		self:Print('locking update, too recent')
		self.cbl[name]["last_seen"] = time()
		return
	end
	
	local class = UnitClass(unitId)
	local level = UnitLevel(unitId)
	local race = UnitRace(unitId)
	local guild = GetGuildInfo(unitId)
	if self.cbl[name] ~= nil then
		self:Print("Unit on cbl, updating info.")
		self.cbl[name]["class"] = class
		self.cbl[name]["level"] = level
		self.cbl[name]["guild"] = guild
		self.cbl[name]["race"] = race
		self.cbl[name]["last_seen"] = time()
	end
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
