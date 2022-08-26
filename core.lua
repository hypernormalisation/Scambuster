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

	-- local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	-- self.optionsFrame = ACD:AddToBlizOptions("ClassicBlacklist_Profiles", "Profiles", addon_name)

	-- Register the necessary slash commands
	self:RegisterChatCommand("cb", "slashcommand_options")
	self:RegisterChatCommand("blacklist", "slashcommand_options")
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
	local db = CBL.db.global
	local sound_file = LSM:Fetch('sound', db.alert_sound)
	PlaySoundFile(sound_file)
end

function CBL:slashcommand_dump_config()
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

	if true then
		self:create_alert()
	end
end

------------------------------------------------------------------------------------
-- helper funcs
function CBL:check_name_against_blacklist(player_name)
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
