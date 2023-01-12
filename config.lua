--=========================================================================================
-- Options tables and config module.
--=========================================================================================
local addon_name, sb = ...
SB = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local LSM = LibStub("LibSharedMedia-3.0")
local L = sb.L

-- Default addon settings
SB.defaults = {
	global = {
		n_alerts = 0,
		udi = {},
		provider_settings = {},
		false_positive_table = {},
	},
	realm = {
		n_alerts = 0,
	},
	profile = {
		-- general
		welcome_message = true,

		-- alert settings
		alert_lockout_seconds = 900,

		use_chat_alert = true,
		use_group_chat_alert = true,
		show_chat_descriptions = true,

		use_gui_alert = true, -- placeholder

		use_alert_sound = true,
		alert_sound = "Scambuster: Criminal Scum!",
        

		-- Scanning settings
		use_mouseover_scan = false,
		use_whisper_scan = true,
		use_target_scan = true,
		use_group_scan = true,
		use_group_request_scan = true,
		use_trade_scan = true,

		-- Report matching settings
		minimum_level = 1,
		require_guid_match = false,
		match_all_incidents = true,  -- when GUID match, also present name-matched incidents

		-- Offence category exclusions
		exclusions = {
			dungeon = false,
			raid = false,
			trade = false,
			dkp = false,
			harassment = false,
		},

		-- Probation list alerts
		probation_alerts = true,
    },
}

-- The options table
SB.options = {
	type = "group",
	name = "Scambuster",
	handler = SB,
	args = {

		-- General
		welcome_message = {
			type = "toggle",
			order = 1.1,
			name = "Welcome message",
			desc = "Displays a login message showing the addon version on player login or reload.",
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
			name = "Scambuster can protect you from scammers by running various scans on players you interact with."..
				" This section allows you to control in what ways Scambuster will do this."
		},
		use_mouseover_scan = {
			order = 3.2,
			type = "toggle",
			name = "Mouseover",
			desc = "If enabled, will check any mouseover players against the database.",
			get = "opts_getter",
			set = function(_, value)
				SB.db.profile.use_mouseover_scan = value
				if value then
					SB:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
				else
					SB:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
				end
			end,		},
		use_whisper_scan = {
			order = 3.3,
			type = "toggle",
			name = "Whispers",
			desc = "If enabled, will check any players whispering you against the database.",
			get = "opts_getter",
			set = function(_, value)
				SB.db.profile.use_whisper_scan = value
				if value then
					SB:RegisterEvent("CHAT_MSG_WHISPER")
				else
					SB:UnregisterEvent("CHAT_MSG_WHISPER")
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
				SB.db.profile.use_target_scan = value
				if value then
					SB:RegisterEvent("PLAYER_TARGET_CHANGED")
				else
					SB:UnregisterEvent("PLAYER_TARGET_CHANGED")
				end
			end
		},
		use_group_scan = {
			order = 3.5,
			type = "toggle",
			name = "Party/Raid",
			desc = "If enabled, will check any players in your party or raid agaist the database.",
			get = "opts_getter",
			set = function(_, value)
				SB.db.profile.use_group_scan = value
				if value then
					SB:RegisterEvent("GROUP_ROSTER_UPDATE")
				else
					SB:UnregisterEvent("GROUP_ROSTER_UPDATE")
				end
			end
		},
		use_group_request_scan = {
			order = 3.6,
			type = "toggle",
			name = "Invite Confirmations",
			desc = "If enabled, will check any players suggested to join your party or raid by another "..
				"group member or via the group finder tool.",
			get = "opts_getter",
			set = function(_, value)
				SB.db.profile.use_group_request_scan = value
				if value then
					SB:RegisterEvent("GROUP_INVITE_CONFIRMATION")
				else
					SB:UnregisterEvent("GROUP_INVITE_CONFIRMATION")
				end
			end
		},
		use_trade_scan = {
			order = 3.7,
			type = "toggle",
			name = "Trade",
			desc = "If enabled, will check any trade partners against the database.",
			get = "opts_getter",
			set = function(_, value)
				SB.db.profile.use_trade_scan = value
				if value then
					SB:RegisterEvent("TRADE_SHOW")
				else
					SB:UnregisterEvent("TRADE_SHOW")
				end
			end
		},


		-- Alerts settings
		alerts_header = {
			order = 4.0,
			type = "header",
			name = "Alerts Behaviour",
		},
		lb1 = {
			order = 4.1,
			type = "description",
			name = "To avoid spam, Scambuster will only generate warnings for a given scammer once per a lockout period, configurable below.",
		},
		alert_lockout_seconds = {
			order = 4.2,
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
		alerts_desc = {
			order = 4.1,
			type = "description",
			name = "Scambuster can alert you when you encounter a scammer in a number of ways."
		},
		use_chat_alert = {
			order = 4.2,
			type = "toggle",
			name = "Chat panel",
			desc = "If enabled, Scambuster will print a summary of the scanner's information to the chat panel when an alert is raised.",
			get = "opts_getter",
			set = "opts_setter,"
		},
		use_alert_sound = {
			order = 4.3,
			type = "toggle",
			name = "Audio Alert",
			desc = "If enabled, Scambuster will play an audio cue when an alert is raised.",
			get = "opts_getter",
			set = "opts_setter",
		},
		alert_sound = {
			order = 4.4,
			type = "select",
			name = "Sound Alert",
			desc = "The sound to play when a scammer is detected.",
			dialogControl = "LSM30_Sound",
			values = LSM:HashTable("sound"),
			get = "opts_getter",
			set = "opts_setter",
			disabled = function() return not SB.db.profile.use_alert_sound end,
		},
	}
}

-- Generic getters and setters
function SB:opts_getter(info)
	return self.db.profile[info[#info]]
end

function SB:opts_setter(info, value)
	self.db.profile[info[#info]] = value
end

if sb.debug then SB:Print("Finished parsing config.lua.") end
