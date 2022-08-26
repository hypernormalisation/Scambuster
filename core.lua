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

	self:RegisterChatCommand("testsound", "slashcommand_soundcheck")
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
	


end

function CBL:OnEnable()
	local db = self.db.global

	self.realm_name = GetRealmName()
	self.player_faction = UnitFactionGroup("player")
	self.time_last_alert = GetTime()

	print("player_faction says")
	print(self.player_faction)

	-- Enable the requisite events here
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")

	-- Welcome message if requested
	if db.welcome_message then
		self:Print('Welcome to version 0.0.1.')
		self:Print('Loading blacklist data for ' .. CBL.realm_name .. '...')
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
	local db = self.db.global
	local sound_file = LSM:Fetch('sound', db.alert_sound)
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
	if db[name] ~= nil then
		self:Print("Target already on blacklist, updating info.")
		db[name] = {
			class = class,
			level = level,
			guild = guild,
			race = race,
			reason = reason,
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

	db[name] = {
		class = class,
		level = level,
		guild = guild,
		race = race,
		reason = reason,
	}
	self:Print('Added to blacklist!')

end


function CBL:slashcommand_testbl()
	local realm_db = self.db.realm
	self:Print(realm_db)

	if realm_db['Maarss'] == nil then
		realm_db['Maarss'] = {
			reason = 'Testing the addon',
			class = 'Shaman',
			level = 70,
			guild = 'GrimSoul Legion',
		}
	end
	for i, v in pairs(realm_db) do
		print(i, v)
	end
end

function CBL:slashcommand_dump_config()
	self:Print('Dumping options table:')
	local t = self.db.global
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
	local is_same_faction = self.player_faction == UnitFactionGroup("mouseover")
	if not is_same_faction or not UnitIsPlayer("mouseover") or 
		UnitIsUnit("player", "mouseover") then return end
	
	-- Check the player against blacklist
	local target_name = UnitName("mouseover")
	-- self:Print("Mouseover friendly player called: " .. target_name)
	local on_blacklist = self:check_name_against_blacklist(target_name)

	if on_blacklist then
		self:create_alert()
	end
end

------------------------------------------------------------------------------------
-- helper funcs
function CBL:is_unit_eligible(unit_id)
	-- Function to get info using the specified unit_id and
	-- verify the target is another same-faction player
	if not UnitIsPlayer(unit_id) and UnitIsUnit("player", unit_id) then
		return false
	end
	local is_same_faction = self.player_faction == UnitFactionGroup(unit_id)
	if not is_same_faction then
		return false
	end
	return true
end

function CBL:check_name_against_blacklist(player_name)
	if type(self.db.realm[player_name]) == nil then
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

	local db = self.db.global
	local time_now = GetTime()
	print('time_now = ' .. time_now)
	print('Time of last alert = ' .. self.time_last_alert)
	local time_since_last = time_now - self.time_last_alert
	print('Time since last alert = ' .. time_since_last)
	-- print('grace period = ', db.grace_period_s)
	if time_since_last < db.grace_period_s then
		print('locked out of alert')
		return true
	end

	-- else set the new time and return false
	self.time_last_alert = time_now
	return false
end

function CBL:play_alert_sound()
	self:Print('playing alert')
	local db = self.db.global
	-- if not db.b_play_alert_sound then return end
	local sound_file = LSM:Fetch('sound', db.alert_sound)
	PlaySoundFile(sound_file)
end


if cb.debug then CBL:Print("Finished parsing core.lua.") end
