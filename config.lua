local addon_name, cb = ...
CBL = LibStub("AceAddon-3.0"):GetAddon("ClassicBlacklist")
local LSM = LibStub("LibSharedMedia-3.0")

-- Default addon settings
CBL.defaults = {
	global = {
		welcome_message = true,

        -- alert settings
        b_play_alert_sound = true,
		alert_sound = "CB: Criminal Scum!",
        grace_period_s = 10,

    },
}

CBL.options = {
	type = "group",
	name = "ClassicBlacklist",
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
			get = function(info) return CBL.db.global.alert_sound or LSM.DefaultMedia.sound end,
			set = function(self, key)
				CBL.db.global.alert_sound = key
			end,
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