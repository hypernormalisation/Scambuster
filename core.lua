local addon_name, cb = ...
local ClassicBlacklist = LibStub("AceAddon-3.0"):NewAddon(addon_name, "AceConsole-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

ClassicBlacklist:Print("ClassicBlacklist says Hello World!")

function ClassicBlacklist:OnInitialize()

	local AC = LibStub("AceConfig-3.0")
	local ACD = LibStub("AceConfigDialog-3.0")

	local ClassicBlacklistDB = LibStub("AceDB-3.0"):New("ClassicBlacklist", self.defaults, true)
	self.db = ClassicBlacklistDB

	AC:RegisterOptionsTable("ClassicBlacklist_Options", self.options)

	local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)

	AC:RegisterOptionsTable("ClassicBlacklist_Profiles", profiles)

	ACD:AddToBlizOptions("ClassicBlacklist_Profiles", "Profiles", "ClassicBlacklist")

	self:RegisterChatCommand("cb", "OptionsSlashcommand")
	self:RegisterChatCommand("blacklist", "OptionsSlashcommand")
	self:RegisterChatCommand("testsound", "TestSoundSlashcommand")

	LSM:Register("sound", "CB: Criminal scum!", [[Interface\Addons\ClassicBlacklist\media\criminal_scum.mp3]])
	LSM:Register("sound", "CB: Not on my watch!", [[Interface\Addons\ClassicBlacklist\media\nobody_breaks_the_law.mp3]])
	LSM:Register("sound", "CB: You've violated the law!", [[Interface\Addons\ClassicBlacklist\media\youve_violated_the_law.mp3]])

end

function ClassicBlacklist:OnEnable()
	-- post-instanstiation stuff goes here
	-- PlaySoundFile([[Interface\Addons\ClassicBlacklist\media\criminal_scum.mp3]])
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

-- Default addon settings
ClassicBlacklist.defaults = {
	profile = {
		welcome_message = true,
		alert_sound = "CB: Criminal Scum!",
	},
}

ClassicBlacklist.options = {
	type = "group",
	name = "ClassicBlacklist",
	handler = ClassicBlacklist,

	args = {
		welcome_message = {
			type = "toggle",
			order = 1.1,
			name = "Welcome message",
			desc = "Displays a login message showing the addon version on player login or reload.",
			get = "GetValue",
			set = "SetValue",
		},

		alert_sound = {
			order = 2,
			type = "select",
			name = "Sound Alert",
			desc = "The sound to play when a scammer is detected.",
			dialogControl = "LSM30_Sound",
			values = LSM:HashTable("sound"),
			get = function(info) return ClassicBlacklist.db.profile.alert_sound or LSM.DefaultMedia.sound end,
			set = function(self, key)
				ClassicBlacklist.db.profile.alert_sound = key
			end,
		},
	}
}


function ClassicBlacklist:GetValue(info)
	return self.db.profile[info[#info]]
end

function ClassicBlacklist:SetValue(info, value)
	self.db.profile[info[#info]] = value
end

ClassicBlacklist:Print("Finished parsing core.lua.")
