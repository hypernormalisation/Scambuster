--=========================================================================================
-- Options tables and config module.
--=========================================================================================
local addon_name, sb = ...
local SB = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local LSM = LibStub("LibSharedMedia-3.0")
local L = sb.L

--=========================================================================================
-- Default database settings
--=========================================================================================
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

	-- The profile table is where the user config options are stored.
	profile = {
		-- general
		welcome_message = true,

		-- alert settings
		alert_lockout_seconds = 900,

		use_chat_alert = true,
		use_group_chat_alert = true,
		
		print_descriptions_in_alerts = true,
		use_gui_alert = true, -- placeholder

		use_alert_sound = true,
		alert_sound_key = "SB Criminal scum",

		-- Scanning settings
		scans = {
			mouseover = {
				enabled = false,
				disable_in_instance = true,
			},
			target = {
				enabled = true,
				disable_in_instance = true,
			},
			whisper = {
				enabled = true,
				disable_in_instance = true,
			},
			trade = {
				enabled = true,
				disable_in_instance = true,
			},
			group = {
				enabled = true,
				disable_in_instance = false,
			},
			invite_confirmation = {
				enabled = true,
				disable_in_instance = false,
			},
		},

		-- Report matching settings
		minimum_level = 2,
		require_guid_match = false,
		match_all_incidents = true,  -- when GUID match, also present name-matched incidents

		-- Offence categories
		categories = {
			dungeon = true,
			raid = true,
			trade = true,
			gdkp = true,
			harassment = true,
			other = true,
		},

		-- Probation list alerts
		probation_alerts = true,
    },
}

--=========================================================================================
-- Opts group for scanning
--=========================================================================================
local scan_opts_group = {
	type = "group",
	order = 2.0,
	name = "Scanning",
	handler = SB,
	args = {
		--
		h1 = {
			order = 1.0,
			type = "header",
			name = "Scanning enable/disable"
		},
		d1 = {
			order = 1.1,
			type = "description",
			name = "Scambuster protects you by running various scans on players you interact with"..
			" and cross-checking them against its database."
			-- " This section allows you to specify the types of scans Scambuster will run, and when to run them."
		},
		-- 
		use_group_scan = {
			order = 2.1,
			type = "toggle",
			name = "Party/Raid",
			desc = "If enabled, will check any players in your party or raid agaist the database.",
			get = function()
				return SB.db.profile.scans.group.enabled
			end,
			set = function(_, value)
				SB.db.profile.scans.group.enabled = value
				SB:set_scan_events()
			end
		},
		use_group_request_scan = {
			order = 2.2,
			type = "toggle",
			name = "Invite Confirmations",
			desc = "If enabled, will check any players suggested to join your party or raid by another "..
				"group member or via the group finder tool.",
			get = function()
				return SB.db.profile.scans.invite_confirmation.enabled
			end,
			set = function(_, value)
				SB.db.profile.scans.invite_confirmation.enabled = value
				SB:set_scan_events()
			end
		},
		use_whisper_scan = {
			order = 2.3,
			type = "toggle",
			name = "Whispers",
			desc = "If enabled, will check any players whispering you against the database.",
			get = function()
				return SB.db.profile.scans.whisper.enabled
			end,
			set = function(_, value)
				SB.db.profile.scans.whisper.enabled = value
				SB:set_scan_events()
			end,
		},
		use_trade_scan = {
			order = 2.4,
			type = "toggle",
			name = "Trade",
			desc = "If enabled, will check any trade partners against the database.",
			get = function()
				return SB.db.profile.scans.trade.enabled
			end,
			set = function(_, value)
				SB.db.profile.scans.trade.enabled = value
				SB:set_scan_events()
			end
		},
		use_target_scan = {
			order = 2.5,
			type = "toggle",
			name = "Target",
			desc = "If enabled, will check any players you target against the database.",
			get = function()
				return SB.db.profile.scans.target.enabled
			end,
			set = function(_, value)
				SB.db.profile.scans.target.enabled = value
				SB:set_scan_events()
			end
		},
		use_mouseover_scan = {
			order = 2.6,
			type = "toggle",
			name = "Mouseover",
			desc = "If enabled, will check any mouseover players against the database.",
			get = function()
				return SB.db.profile.scans.mouseover.enabled
			end,
			set = function(_, value)
				SB.db.profile.scans.mouseover.enabled = value
				SB:set_scan_events()
			end,
		},
		--
		h2 = {
			order = 3.0,
			type = "header",
			name = "Suspend scanning in instance",
		},
		d2 = {
			order = 3.01,
			type = "description",
			name = "Scambuster can suspend some of its scanning operations while you are in a dungeon "..
			"or raid instance to use fewer resources. Group and Invite Confirmation scans cannot be suspended."
		},
		disable_whispers_in_instance = {
			order = 3.1,
			type = "toggle",
			name = "Whispers",
			desc = "If checked, Scambuster will suspend whisper message scans while you are in an instance.",
			get = function()
				return SB.db.profile.scans.whisper.disable_in_instance
			end,
			set = function(_, value)
				SB.db.profile.scans.whisper.disable_in_instance = value
				SB:set_scan_events()
			end,
			disabled = function()
				return SB.db.profile.scans.whisper.enabled == false
			end
		},
		disable_trade_in_instance = {
			order = 3.2,
			type = "toggle",
			name = "Trade",
			desc = "If checked, Scambuster will suspend trade partner scans while you are in an instance.",
			get = function()
				return SB.db.profile.scans.trade.disable_in_instance
			end,
			set = function(_, value)
				SB.db.profile.scans.trade.disable_in_instance = value
				SB:set_scan_events()
			end,
			disabled = function()
				return SB.db.profile.scans.trade.enabled == false
			end
		},
		disable_target_in_instance = {
			order = 3.3,
			type = "toggle",
			name = "Target",
			desc = "If checked, Scambuster will suspend target scans while you are in an instance.",
			get = function()
				return SB.db.profile.scans.target.disable_in_instance
			end,
			set = function(_, value)
				SB.db.profile.scans.target.disable_in_instance = value
				SB:set_scan_events()
			end,
			disabled = function()
				return SB.db.profile.scans.target.enabled == false
			end
		},
		disable_mmouseover_in_instance = {
			order = 3.4,
			type = "toggle",
			name = "Mouseover",
			desc = "If checked, Scambuster will suspend mouseover scans while you are in an instance.",
			get = function()
				return SB.db.profile.scans.mouseover.disable_in_instance
			end,
			set = function(_, value)
				SB.db.profile.scans.mouseover.disable_in_instance = value
				SB:set_scan_events()
			end,
			disabled = function()
				return SB.db.profile.scans.mouseover.enabled == false
			end
		},
	}
}
--=========================================================================================
-- Opts group for reporting preferences
--=========================================================================================
local reports_group = {
	type = "group",
	order = 3.0,
	name = "Report Matching",
	handler = SB,
	args = {
		h1 = {
			order = 1.0,
			type = "header",
			name = "Report Preferences",
		},
		d1 = {
			order = 1.1,
			type = "description",
			name = "Scambuster allows you to specify the kinds of reports that will trigger an alert, if your list provider supports this functionality.",
		},
		h2 = {
			order = 2.0,
			type = "header",
			name = "Categories",
		},
		-- d2 = {
		-- 	order = 2.01,
		-- 	type = "description",
		-- 	name = "Check any of the below to not be alerted of cases matching that category. Note that if a player is reported under multiple"..
		-- 	"categories, excluding one category will still allow for the generation of alerts for that player on the other category.",
		-- }
		raid = {
			order = 2.1,
			type = "toggle",
			name = "Raid Scams",
			desc = "Ninja looting/loot pooling/etc in raids.",
			get = function ()
				return SB.db.profile.categories.raid
			end,
			set = function(_, value)
				SB.db.profile.categories.raid = value
			end,
		},
		dungeon = {
			order = 2.2,
			type = "toggle",
			name = "Dungeon Scams",
			desc = "Ninja looting/loot pooling in dungeons.",
			get = function ()
				return SB.db.profile.categories.dungeon
			end,
			set = function(_, value)
				SB.db.profile.categories.dungeon = value
			end,
		},
		gdkp = {
			order = 2.3,
			type = "toggle",
			name = "GDKP/Gbid Scams",
			desc = "Gold stealing etc. in GDKP/Gbid runs.",
			get = function ()
				return SB.db.profile.categories.gdkp
			end,
			set = function(_, value)
				SB.db.profile.categories.gdkp = value
			end,
		},
		trade = {
			order = 2.4,
			type = "toggle",
			name = "Trade Scams",
			desc = "Stealing gold in transactions, not paying for services, gambling scams etc.",
			get = function ()
				return SB.db.profile.categories.trade
			end,
			set = function(_, value)
				SB.db.profile.categories.trade = value
			end,
		},
		harassment = {
			order = 2.5,
			type = "toggle",
			name = "Harassment",
			desc = "Harassing other users, hate speech etc.",
			get = function ()
				return SB.db.profile.categories.harassment
			end,
			set = function(_, value)
				SB.db.profile.categories.harassment = value
			end,
		},
		other = {
			order = 2.6,
			type = "toggle",
			name = "Other",
			desc = "Any reports with non-standard categories.",
			get = function ()
				return SB.db.profile.categories.other
			end,
			set = function(_, value)
				SB.db.profile.categories.other = value
			end,
		},
		h3 = {
			order = 3.0,
			type = "header",
			name = "Severity",
		},
		d3 = {
			order = 3.01,
			type = "description",
			name = "Scambuster supports different severities of report. A minimum severity can be specified below.",
		},
		minimum_level = {
			order = 3.1,
			type = "select",
			name = "Severity",
			values = SB.levels,
			get = "opts_getter",
			set = "opts_setter",
		},
		h4 = {
			order = 4.0,
			type = "header",
			name = "GUID and name matching",
		},
		d4 = {
			order = 4.01,
			type = "description",
			name = "Scambuster's lists support both player names and Globally Unique Identifiers (GUIDs). Player names can be changed,"..
			" resulting in false positives if a new player takes a listed name after a scammer changes name, "..
			"while most easy ways to rename a toon maintain the same GUID. As such, Scambuster prefers GUIDs in its matching, but will fall "..
			"back on names. This can be configured below.",
		},
		require_guid_match = {
			order = 4.1,
			type = "toggle",
			name = "Require GUID Match",
			desc = "If enabled, Scambuster will ignore cases for which only a player name is supplied, and not a GUID.",
			get = "opts_getter",
			set = "opts_setter",
		},
		match_all_incidents = {
			order = 4.2,
			type = "toggle",
			name = "Add Name-only Matches",
			desc = "If Require GUID Match is enabled, enabling this option will also print name-only case matches corresponding "..
			"to the same name as the GUID-matched case.",
			get = "opts_getter",
			set = "opts_setter",
			disabled = function()
				return SB.db.profile.require_guid_match == false
			end
		}
	},
}

--=========================================================================================
-- Opts group for alerts preferences
--=========================================================================================
local alerts_opts_group = {
	type = "group",
	name = "Alerts",
	handler = SB,
	args = {
		-- Alerts settings
		h1 = {
			order = 1.0,
			type = "header",
			name = "Alert Lockout",
		},
		d1 = {
			order = 1.01,
			type = "description",
			name = "To avoid spam, Scambuster will only generate warnings for a given scammer once per a lockout period, configurable below.",
		},
		alert_lockout_seconds = {
			order = 1.1,
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
		--
		h2 = {
			order = 2.00,
			type = "header",
			name = "Chat Alerts",
		},
		alerts_desc = {
			order = 2.01,
			type = "description",
			name = "Scambuster can alert you when you encounter a scammer in a number of ways."
		},
		use_chat_alert = {
			order = 2.1,
			type = "toggle",
			name = "System Message",
			desc = "If enabled, Scambuster will print a summary of the scammer's information to the chat panel when an alert is raised.",
			get = "opts_getter",
			set = "opts_setter"
		},
		use_group_chat_alert = {
			order = 2.2,
			type = "toggle",
			name = "Group/Raid chat",
			desc = "If enabled and in an instance group, Scambuster will broadcast a summary of the scammer's information to the"..
			" group or raid channel, depending on the group type. This will happen instead of the system message personal alert.",
			get = "opts_getter",
			set = "opts_setter",
		},
		lb1 = {
			name = "",
			order = 2.5,
			type = "description",
		},
		print_descriptions_in_alerts = {
			order = 2.6,
			type = "toggle",
			name = "Print Descriptions",
			desc = "If enabled, the description of the scam incident will also be printed in text alerts, if one is given by the provider.",
			get = "opts_getter",
			set = "opts_setter",
		},
		h3 = {
			name = "Sound Alerts",
			order = 3.1,
			type = "header",
		},
		use_alert_sound = {
			order = 3.11,
			type = "toggle",
			name = "Audio Alert",
			desc = "If enabled, Scambuster will play an audio cue when an alert is raised.",
			get = "opts_getter",
			set = "opts_setter",
		},
		alert_sound_key = {
			order = 3.2,
			type = "select",
			name = "Sound Alert",
			desc = "The sound to play when a scammer is detected.",
			dialogControl = "LSM30_Sound",
			values = LSM:HashTable("sound"),
			get = "opts_getter",
			set = "opts_setter",
			disabled = function() return not SB.db.profile.use_alert_sound end,
		}
	},
}

--=========================================================================================
-- The top-level options table
--=========================================================================================
SB.options = {
	type = "group",
	name = "Scambuster",
	handler = SB,
	args = {
		d1 = {
			type = "description",
			order = 1.0,
			name = "From this menu you can configure the behaviour of Scambuster."
		},
		-- General
		welcome_message = {
			type = "toggle",
			order = 1.1,
			name = "Welcome message",
			desc = "Displays a login message showing the addon version on player login or reload.",
			get = "opts_getter",
			set = "opts_setter",
		},

		scanning = scan_opts_group,
		reports = reports_group,
		alerts = alerts_opts_group,
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
