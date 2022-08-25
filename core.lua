local addon_name, cb = ...
local CBL = LibStub("AceAddon-3.0"):NewAddon(addon_name, "AceConsole-3.0", "AceEvent-3.0")
local LSM = LibStub("LibSharedMedia-3.0")
cb.debug = true

if cb.debug then CBL:Print("Parsing core.lua...") end

------------------------------------------------------------------------------------
-- The basic AceAddon structure
function CBL:OnInitialize()

	local AC = LibStub("AceConfig-3.0")
	local ACD = LibStub("AceConfigDialog-3.0")
	self.db = LibStub("AceDB-3.0"):New(addon_name.."Settings", self.defaults, true)
	AC:RegisterOptionsTable(addon_name.."_Options", self.options)
	local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	AC:RegisterOptionsTable("ClassicBlacklist_Profiles", profiles)
	ACD:AddToBlizOptions("ClassicBlacklist_Profiles", "Profiles", "ClassicBlacklist")

	-- Register the necessary slash commands
	self:RegisterChatCommand("cb", "slashcommand_options")
	self:RegisterChatCommand("blacklist", "slashcommand_options")
	self:RegisterChatCommand("testsound", "slashcommand_soundcheck")

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
	local db = self.db.profile

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
	local db = CBL.db.profile
	local sound_file = LSM:Fetch('sound', db.alert_sound)
	PlaySoundFile(sound_file)
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
	self:Print("Mouseover friendly player called: " .. target_name)
	local on_blacklist = self:check_name_against_blacklist(target_name)

	if on_blacklist then
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

end

function CBL:play_alert_sound()
	local db = CBL.db.profile
	if not db.b_play_alert_sound then return end
	local sound_file = LSM:Fetch('sound', db.alert_sound)
	PlaySoundFile(sound_file)
end


if cb.debug then CBL:Print("Finished parsing core.lua.") end
