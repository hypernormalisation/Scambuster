--=========================================================================================
-- Options tables and config module.
--=========================================================================================
local addon_name, cp = ...
CP = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local LSM = LibStub("LibSharedMedia-3.0")
local L = cp.L

-- Default addon settings
CP.defaults = {
	global = {
		n_alerts = 0,
		udi = {},
		provider_settings = {},
	},
	realm = {
		n_alerts = 0,
	},
	profile = {
		welcome_message = true,
        -- alert settings
        use_chat_alert = true,
		use_gui_alert = true,
		b_play_alert_sound = true,
		alert_sound = "Cutpurse: Criminal Scum!",

        grace_period_s = 10,
		-- Scanning settings
		use_mouseover_scan = true,
		use_whisper_scan = true,
		use_target_scan = true,
		use_group_request_scan = true,
		alert_lockout_seconds = 900,
    },
}

-- The options table
CP.options = {
	type = "group",
	name = "Cutpurse",
	handler = CP,
	args = {
		welcome_message = {
			type = "toggle",
			order = 1.1,
			name = "Welcome message",
			desc = "Displays a login message showing the addon version on player login or reload.",
			get = "opts_getter",
			set = "opts_setter",
		},
		alert_sound = {
			order = 2,
			type = "select",
			name = "Sound Alert",
			desc = "The sound to play when a scammer is detected.",
			dialogControl = "LSM30_Sound",
			values = LSM:HashTable("sound"),
			get = "opts_getter",
			set = "opts_setter",
		},

		-- Scanning settings
		scan_header = {
			order = 3.0,
			type = "header",
			name = "Scanning Behaviour"
		},
		scan_desc = {
			order = 3.01,
			type = "description",
			name = "Cutpurse can detect your interactions with scammers by running various scans on players you interact with."..
				" This section allows you to control in what ways Cutpurse will do this."
		},
		use_mouseover_scan = {
			order = 3.2,
			type = "toggle",
			name = "Mouseover",
			desc = "If enabled, will check any mouseover players against the blocklists.",
			get = "opts_getter",
			set = function(_, value)
				CP.db.profile.use_mouseover_scan = value
				if value then
					CP:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
				else
					CP:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
				end
			end,		},
		use_whisper_scan = {
			order = 3.3,
			type = "toggle",
			name = "Whispers",
			desc = "If enabled, will check any players whispering you against the blocklists.",
			get = "opts_getter",
			set = function(_, value)
				CP.db.profile.use_whisper_scan = value
				if value then
					CP:RegisterEvent("CHAT_MSG_WHISPER")
				else
					CP:UnregisterEvent("CHAT_MSG_WHISPER")
				end
			end,
		},
		use_target_scan = {
			order = 3.4,
			type = "toggle",
			name = "Target",
			desc = "If enabled, will check any players you target against the database.",
			get = "opts_getter",
			set = function(_, value)
				CP.db.profile.use_target_scan = value
				if value then
					CP:RegisterEvent("PLAYER_TARGET_CHANGED")
				else
					CP:UnregisterEvent("PLAYER_TARGET_CHANGED")
				end
			end
		},

		alert_lockout_seconds = {
			order = 4.0,
			type = "range",
			name = "Alert Lockout (s)",
			desc = "The period during which the addon will not generate alerts for "..
			"a given player after one has been generated.",
			min = 0,
			max = 10000,
			softMin = 0,
			softMax = 3600,
			bigStep = 10,
			get = "opts_getter",
			set = "opts_setter",
		},

	}
}

-- Generic getters and setters
function CP:opts_getter(info)
	return self.db.profile[info[#info]]
end

function CP:opts_setter(info, value)
	self.db.profile[info[#info]] = value
end

if cp.debug then CP:Print("Finished parsing config.lua.") end
