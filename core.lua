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
	self:RegisterChatCommand("cb", "OptionsSlashcommand")
	self:RegisterChatCommand("blacklist", "OptionsSlashcommand")
	self:RegisterChatCommand("testsound", "TestSoundSlashcommand")

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
	local db = CBL.db.profile
	
	self.realm_name = GetRealmName()

	-- Enable the requisite events here
	

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
function CBL:OptionsSlashcommand(input, editbox)
	-- PlaySoundFile([[Interface\Addons\ClassicBlacklist\media\criminal_scum.mp3]])
	local ACD = LibStub("AceConfigDialog-3.0")
	ACD:Open(addon_name.."_Options")
end

function CBL:TestSoundSlashcommand()
	local db = CBL.db.profile
	local sound_file = LSM:Fetch('sound', db.alert_sound)
	PlaySoundFile(sound_file)
end

------------------------------------------------------------------------------------
-- Callback functions for events
cb.mouseover_event_handler = function()

end

if cb.debug then CBL:Print("Finished parsing core.lua.") end
