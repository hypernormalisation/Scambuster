local addon_name, cb = ...
ClassicBlacklist = LibStub("AceAddon-3.0"):GetAddon("ClassicBlacklist")
local LSM = LibStub("LibSharedMedia-3.0")

-- Default addon settings
ClassicBlacklist.defaults = {
	global = {
		welcome_message = true,
		alert_sound = "CB: You've violated the law!",
        grace_period_s = 10,


        -- alert settings
        b_play_alert_sound = true,
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
			get = function(info) return ClassicBlacklist.db.global.alert_sound or LSM.DefaultMedia.sound end,
			set = function(self, key)
				ClassicBlacklist.db.global.alert_sound = key
			end,
		},
	}
}


function ClassicBlacklist:GetValue(info)
	return self.db.global[info[#info]]
end

function ClassicBlacklist:SetValue(info, value)
	self.db.global[info[#info]] = value
end

if cb.debug then ClassicBlacklist:Print("Finished parsing config.lua.") end
