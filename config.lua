--=========================================================================================
-- Options tables and config module.
--=========================================================================================
local addon_name, cb = ...
CBL = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local LSM = LibStub("LibSharedMedia-3.0")

-- Default addon settings
CBL.defaults = {
	global = {
		welcome_message = true,

        -- alert settings
        b_play_alert_sound = true,
		alert_sound = "Cutpurse: Criminal Scum!",
        grace_period_s = 10,

    },
}

CBL.options = {
	type = "group",
	name = "Cutpurse",
	handler = CBL,

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
			get = "GetValue",
			set = "SetValue",
		},
	}
}


function CBL:GetValue(info)
	return self.db.global[info[#info]]
end

function CBL:SetValue(info, value)
	self.db.global[info[#info]] = value
end

if cb.debug then CBL:Print("Finished parsing config.lua.") end
