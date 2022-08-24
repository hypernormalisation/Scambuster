local addon_name, st = ...
local CB = LibStub("AceAddon-3.0"):NewAddon(addon_name, "AceConsole-3.0")
local SML = LibStub("LibSharedMedia-3.0")

function CB:OnInitialize()

	local AC = LibStub("AceConfig-3.0")
	local ACD = LibStub("AceConfigDialog-3.0")

	local CBDB = LibStub("AceDB-3.0"):New("CBDB", self.defaults, true)
	self.db = CBDB

	AC:RegisterOptionsTable("ClassicBlacklist_Options", self.options)

	local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)

	AC:RegisterOptionsTable("ClassicBlacklist_Profiles", profiles)

	ACD:AddToBlizOptions("ClassicBlacklist_Profiles", "Profiles", "ClassicBlacklist")

	self:RegisterChatCommand("cb", "OptionsSlashcommand")
	self:RegisterChatCommand("blacklist", "OptionsSlashcommand")

function CB:OnEnable()
	-- post-instanstiation stuff goes here
end

function CB:OptionsSlashcommand(input, editbox)
	local ACD = LibStub("AceConfigDialog-3.0")
	ACD:Open("ClassicBlacklist_Options")
end


-- Default addon settings
CB.defaults = {

	{
		welcome_message = true,
	},
}



function CB:GetValue(info)
	return self.db.profile[info[#info]]
end

function CB:SetValue(info, value)
	self.db.profile[info[#info]] = value
end
