local addon_name, cb = ...
local ClassicBlacklist = LibStub("AceAddon-3.0"):NewAddon(addon_name, "AceConsole-3.0", "AceEvent-3.0")
local LSM = LibStub("LibSharedMedia-3.0")
cb.debug = true


if cb.debug then ClassicBlacklist:Print("Parsing core.lua...") end

function ClassicBlacklist:OnInitialize()

	local AC = LibStub("AceConfig-3.0")
	local ACD = LibStub("AceConfigDialog-3.0")
	local ClassicBlacklistDB = LibStub("AceDB-3.0"):New("ClassicBlacklist", self.defaults, true)
	self.db = ClassicBlacklistDB
	AC:RegisterOptionsTable("ClassicBlacklist_Options", self.options)
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

function ClassicBlacklist:OnEnable()
	local db = ClassicBlacklist.db.profile
	
	-- Enable the requisite events here
	

	-- Welcome message if requested
	if db.welcome_message then
		ClassicBlacklist:Print('Loaded version 0.0.1.')
	end
end

function ClassicBlacklist:OnDisable()
	
end

function ClassicBlacklist:OptionsSlashcommand(input, editbox)
	-- PlaySoundFile([[Interface\Addons\ClassicBlacklist\media\criminal_scum.mp3]])
	local ACD = LibStub("AceConfigDialog-3.0")
	ACD:Open("ClassicBlacklist_Options")
end

function ClassicBlacklist:TestSoundSlashcommand()
	local db = ClassicBlacklist.db.profile
	local sound_file = LSM:Fetch('sound', db.alert_sound)
	PlaySoundFile(sound_file)
end


if cb.debug then ClassicBlacklist:Print("Finished parsing core.lua.") end
