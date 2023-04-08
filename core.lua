--=========================================================================================
-- Main module for Scambuster
--=========================================================================================
local addon_name, sb = ...
local SB = LibStub("AceAddon-3.0"):NewAddon(addon_name, "AceConsole-3.0", "AceEvent-3.0")
SB.callbacks = SB.callbacks or LibStub("CallbackHandler-1.0"):New(SB)
local LSM = LibStub("LibSharedMedia-3.0")
sb.debug = false
sb.add_test_list = false
local L = sb.L
local version = "@project-version@"
if sb.debug then SB:Print("Parsing core.lua...") end

-- Load some relevant wow API and lua globals into the local namespace.
local CreateTextureMarkup = CreateTextureMarkup
local GetInviteConfirmationInfo = GetInviteConfirmationInfo
local GetNextPendingInviteConfirmation = GetNextPendingInviteConfirmation
local GetUnitName = GetUnitName
local GetServerTime = GetServerTime
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local GetRealmName = GetRealmName
local IsInInstance = IsInInstance
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local PlaySoundFile = PlaySoundFile
local GetNumGroupMembers = GetNumGroupMembers

local UnitFactionGroup = UnitFactionGroup
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitGUID = UnitGUID
local UnitLevel = UnitLevel
local GetGuildInfo = GetGuildInfo
local SendChatMessage = SendChatMessage

local pcall = pcall

local LE_PARTY_CATEGORY_HOME = LE_PARTY_CATEGORY_HOME
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local ipairs = ipairs
local next = next
local pairs = pairs
local print = print
local select = select
local string = string
local type = type
local tostring = tostring

local function tab_dump(o)
	if type(o) == 'table' then
	   local s = '{ '
	   for k,v in pairs(o) do
		  if type(k) ~= 'number' then k = '"'..k..'"' end
		  s = s .. '['..k..'] = ' .. tab_dump(v) .. ','
	   end
	   return s .. '} '
	else
	   return tostring(o)
	end
end
SB.tab_dump = tab_dump

local function formatURL(url)
    url = "|cff".."149bfd".."|Hurl:"..url.."|h["..url.."]|h|r ";
    return url;
end

function SB:colorise_name(name, class)
	local c = RAID_CLASS_COLORS[class]
	local cc = ('c' .. c.colorStr)
	return "|"..cc..name.."|r"
end

local incident_categories = {
	dungeon = "Dungeon Scam",
	raid = "Raid Scam",
	gdkp = "GDKP Scam",
	trade = "Trade Scam",
	harassment = "Harassment",
}
SB.incident_categories = incident_categories

SB.supported_case_data_fields = {
	name = true,
	guid = true,
	category = true,
	level = true,
	description = true,
	url = true,
	players = true,
	aliases = true,
	class = true,
	faction = true,
}

SB.scan_table = {
	mouseover = {
		event = "UPDATE_MOUSEOVER_UNIT",
		pretty = "Mouseover",
	},
	target = {
		event = "PLAYER_TARGET_CHANGED",
		pretty = "Target",
	},
	trade = {
		event = "TRADE_SHOW",
		pretty = "Trade Window",
	},
	whisper = {
		event = "CHAT_MSG_WHISPER",
		pretty = "Whisper",
	},
	group = {
		event = "GROUP_ROSTER_UPDATE",
		pretty = "Group",
		can_broadcast = true,
	},
	invite_confirmation = {
		event = "GROUP_INVITE_CONFIRMATION",
		events = {
			[0] = "GROUP_INVITE_CONFIRMATION",
			[1] = "PARTY_INVITE_REQUEST",
		},
		pretty = "Invite Confirmation",
	},
}

SB.levels = {
	[1] = "Reformed",
	[2] = "Probation",
	[3] = "Scammer",
}

-- Necessary for localization due to the lower case classes being localized.
local english_locale_classes = {
	DEATHKNIGHT = "Death Knight",
	DRUID = "Druid",
	HUNTER = "Hunter",
	MAGE = "Mage",
	PALADIN = "Paladin",
	PRIEST = "Priest",
	ROGUE = "Rogue",
	SHAMAN = "Shaman",
	WARRIOR = "Warrior",
	WARLOCK = "Warlock",
}

SB.unprocessed_case_data = {}
SB.provider_counter = 0

--=========================================================================================
-- Helper funcs
--=========================================================================================
function SB:get_opts_db()
	return self.db.profile
end

function SB:get_provider_settings()
	return self.db.global.provider_settings
end

function SB:get_UDI()
	return self.db.global.udi
end

--=========================================================================================
-- The basic AceAddon structure
--=========================================================================================
function SB:OnInitialize()

	-- Register our custom sound alerts with LibSharedMedia
	LSM:Register(
		"sound", "SB Criminal scum",
		string.format([[Interface\Addons\%s\media\criminal_scum.mp3]], addon_name)
	)
	LSM:Register(
		"sound", "SB Not on my watch",
		string.format([[Interface\Addons\%s\media\nobody_breaks_the_law.mp3]], addon_name)
	)
	LSM:Register(
		"sound", "SB Violated the law",
		string.format([[Interface\Addons\%s\media\youve_violated_the_law.mp3]], addon_name)
	)

	-- Make the addon database
	self.db = LibStub("AceDB-3.0"):New(addon_name.."DB", self.defaults, true)
	self.conf = self.db.global --shorthand

	-- Register the options table
	local AC = LibStub("AceConfig-3.0")
	local ACD = LibStub("AceConfigDialog-3.0")
	local options_name = addon_name.."_Options"
	AC:RegisterOptionsTable(options_name, self.options)
	self.optionsFrame = ACD:AddToBlizOptions(options_name, addon_name)

	-- Register the necessary slash commands
	self:RegisterChatCommand("sb", "slashcommand_options")
	self:RegisterChatCommand("scambuster", "slashcommand_options")
	self:RegisterChatCommand("cutpurse", "slashcommand_options")
	self:RegisterChatCommand("dump_users", "dump_users")
	self:RegisterChatCommand("dump_incidents", "dump_incidents")
	self:RegisterChatCommand("dump_name_lookup", "dump_name_lookup")
	self:RegisterChatCommand("dump_udi", "dump_udi")
	self:RegisterChatCommand("clear_udi", "clear_udi")
	self:RegisterChatCommand("clear_fps", "clear_fps")
	self:RegisterChatCommand("show_stats", "show_stats")

	-- Containers for the alerts system.
	self.alert_counter = 0  -- just for index handling on temp alerts list
	self.pending_alerts = {}
	self.first_enter_world = true

end

function SB:OnEnable()
	local conf = self:get_opts_db()
	self.realm_name = GetRealmName()
	self.player_faction = UnitFactionGroup("player")

	-- Alert the extension addons to register their case data.
	self.callbacks:Fire("SCAMBUSTER_LIST_CONSTRUCTION")
	-- Then build the database.
	self:build_database()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")

	-- Welcome message if requested
	if conf.welcome_message then
		self:Print('Welcome to version ' .. tostring(version))
	end

end

--=========================================================================================
-- Funcs to register lists with Scambuster, for use in addons that extend Scambuster, and
-- funcs to construct the lists used by the addon.
--=========================================================================================
function SB:register_case_data(data)
	-- Function to be called in provider extentions
	self.provider_counter = self.provider_counter + 1
	self.unprocessed_case_data[self.provider_counter] = data
end

function SB:validate_provider(t)
	-- Does basic data validation on the given provider table
	if not t.name or t.name == "" then
		self:Print("ERROR: Missing provider name on provider, aborting import.")
		return false
	end
	self:Print(string.format("INFO: Parsing provider list %s...", t.name))
	for _, field_name in pairs({"provider", "description", "url"}) do
		if t[field_name] == nil then
			self:Print(string.format("ERROR: Missing field \"%s\", aborting import.", field_name))
			return false
		end
		if not type(t[field_name]) or t[field_name] == "" then
			self:Print(string.format("ERROR: Invalid field \"%s\", aborting import.", field_name))
			return false
		end
	end
	if not t.realm_data or t.realm_data == {} then
		self:Print("ERROR: Missing or empty realm data, aborting import:")
		return false
	end
	for realm, realm_table in pairs(t.realm_data) do
		if not realm_table or type(realm_table) ~= "table" then
			self:Print(string.format("ERROR: realm table for realm %s not valid, aborting import.", realm))
			return false
		end
	end
	local valid_fields = {
		realm_data = true,
		name = true,
		provider = true,
		url = true,
		description = true,
	}
	for field, _ in pairs(t) do
		if not valid_fields[field] then
			self:Print(
				string.format(
					"WARNING: provider packages field \"%s\" which is not recognised and will be ignored.",
					field
				)
			)
		end
	end
	return true
end

function SB:build_database()
	-- This function builds (or rebuilds) the database from the registered
	-- raw lists from the provider extensions.
	if sb.debug then
		self:Print("Building Scambuster database...")
	end
	-- A table mapping GUIDs to User info tables.
	self.user_table = {}
	self.user_counter = 0

	-- A table recording individual incidents.
	self.incident_table = {}
	self.incident_counter = 0
	self.name_to_incident_table = {}

	-- Tables for sanity checks on old aliases and guids.
	self.previous_guid_table = {}
	self.alias_table = {}

	-- Now iterate over the unprocessed case data and build up the db.
	local pdb = self:get_provider_settings()
	for _, l in pairs(self.unprocessed_case_data) do
		if self:validate_provider(l) then
			local n = l.name
			-- If no setting for this provider, assume enabled.
			if pdb[n] == nil then
				pdb[n] = {enabled = true}
				self:protected_process_provider(l)
			-- Else check for disabled lists and skip
			else
				if pdb[n].enabled then
					self:protected_process_provider(l)
				end
			end
		end
	end
end

function SB:protected_process_provider(l)
	-- Wraps the parse of the unprocessed provider data in a pcall
	-- to catch errors.
	local result, return_value = pcall(self.process_provider, self, l)
	if not result then
		local name = l.name or l.provider or "UNIDENTIFIED LIST"
		self:Print(string.format("ERROR: the provider list %s could not be properly processed.", name))
		print(
			string.format(" Error was in case index [%.0f] in realm [%s]:",
			self.provider_case_counter, tostring(self.current_provider_realm)
			)
		)
		print(return_value)
	end
end

function SB:check_case_fields(c)
	-- Function to check for unrecognised case fields and alert the user.
	-- Particularly useful for providers to catch typos and other errors.
	for field, _ in pairs(c) do
		if not self.supported_case_data_fields[field] then
			self:Print(
				string.format("WARNING: in case index [%.0f] in realm [%s]:",
				self.provider_case_counter, tostring(self.current_provider_realm)
				)
			)
			print(" Unrecognised input field " .. field)
		end
	end
end

function SB:process_provider(l)
	-- Takes the given case data for a single provider and adds
	-- it to the database.
	for realm, realm_dict in pairs(l.realm_data) do
		self.current_provider_realm = realm
		self.provider_case_counter = 1
		for case_index, case_data in pairs(realm_dict) do
			self.provider_case_counter = case_index
			self:check_case_fields(case_data)
			case_data.realm = realm
			case_data.provider = l.provider
			if case_data.name then
				case_data.full_name = case_data.name .. "-" .. realm
			end
			-- If "players" field given, we have multiple players on
			-- this incident, so process them all.
			if case_data.players then
				self:process_players(case_data)
			-- Else if we have a GUID, we ensure the case is linked
			-- to a discrete user.
			elseif case_data.guid then
				self:process_player_by_guid(case_data)
			end
			self:process_incident(case_data)
		end
	end
end

function SB:process_players(case_data)
	-- This function handles parsing of incidents with multiple players.
	for _, player_info in pairs(case_data.players) do
		if player_info.guid then
			player_info.realm = case_data.realm
			player_info.provider = case_data.provider
			self:process_player_by_guid(player_info)
		end
	end
end

function SB:process_player_by_guid(input)
	-- This function processes an individual case where a guid
	-- is given in the case data. If a user entry already exists for this
	-- guid, it merges the information. Else, it creates a new user entry.
	-- print(tab_dump(input))
	local exists = not (self.user_table[input.guid] == nil)
	local t = {}
	if exists then
		t = self.user_table[input.guid]
		if input.realm ~= t.realm then
			self:Print(
				"WARNING: two lists have the same player matched by current guid, but "..
				"listed on different servers, which is impossible. "..
				string.format("Player name: %s", input.name .. "-" .. input.realm)
			)
		end
	else
		t.realm = input.realm
		t.names = {}
		t.previous_names = {}
		t.incidents = {}
	end

	-- Add name if not present to possible current names.
	if not t.names[input.provider] then
		t.names[input.provider] = input.name
	end
	-- Possible previous names
	if input.previous_names then
		for _, alias in ipairs(input.previous_names) do
			if not t.aliases[alias] then
				t.aliases[alias] = true
				self.alias_table[alias] = input.name
			end
		end
	end
	self.user_table[input.guid] = t
end

function SB:process_incident(case_data)
	-- Adds the incident to the db, ensuring it's linked
	-- to either a guid or name in the lookup.
	self.incident_counter = self.incident_counter + 1
	local c = {}
	c.case_id = self.incident_counter
	c.description = case_data.description or false
	c.url = case_data.url
	c.category = case_data.category or false
	c.level = case_data.level or 3
	c.provider = case_data.provider
	c.class = case_data.class or false
	c.players = case_data.players or false
	self.incident_table[self.incident_counter] = c

	-- Now we need to reference the incident.
	if case_data.players then
		for _, player_info in pairs(case_data.players) do
			if player_info.name then
				player_info.full_name = player_info.name .. "-" .. case_data.realm
			end
			self:reference_incident_to_player(player_info)
		end
	else
		self:reference_incident_to_player(case_data)
	end
end

function SB:reference_incident_to_player(input)
	-- Creates a reference between a single player and the incident in question.
	-- input will either be the table for the whole case for a single player,
	-- or alternately a player_info table for each player in the case.
	if input.guid then
		self.user_table[input.guid].incidents[self.incident_counter] = true
	else
		if not self.name_to_incident_table[input.full_name] then
			self.name_to_incident_table[input.full_name] = {}
			self.name_to_incident_table[input.full_name].incidents = {}
		end
		self.name_to_incident_table[input.full_name].incidents[self.incident_counter] = true
	end
end

--=========================================================================================
-- Unit checking functionality.
--=========================================================================================
function SB:is_unit_eligible(unit_token)
	-- Function to get info using the specified unit_token and
	-- verify the unit in question is another same-faction player.
	if not UnitIsPlayer(unit_token) then
		return false
	end
	if UnitIsUnit("player", unit_token) then
		return false
	end
	local is_same_faction = self.player_faction == UnitFactionGroup(unit_token)
	if not is_same_faction then
		return false
	end
	return true
end

function SB:check_unit(unit_token, unit_guid, scan_context)
	-- Checks a unit against the lists.
	-- Requires one of unit_token or unit_guid.
	-- The scan_context is required to tell the alerts system what scan
	-- registered the unit. If a unit_token is given, it defaults to that.
	-- If a unit token does not exist, as for whispers or invite
	-- confirmations, it should be passed manually.
	-- First check for a guid match.
	self.db.global.n_scans = self.db.global.n_scans + 1
	self.db.realm.n_scans = self.db.realm.n_scans + 1
	local conf = self:get_opts_db()
	unit_guid = unit_guid or UnitGUID(unit_token)
	local guid_match = false
	if self.user_table[unit_guid] then
		guid_match = true
	end
	local name, realm = select(6, GetPlayerInfoByGUID(unit_guid))
	-- self:Print(realm, type(realm))

	if name == nil then return end  -- Temp fix to catch cases when name is returned nil by 
									-- the asynchronous GetPlayerInfoByGUID func. Needs a rework
									-- to the overall structure to support delayed retries.
	if realm == "" or realm == nil then
		realm = self.realm_name
	end
	local full_name = name .. "-" .. realm
	-- self:Print(full_name)

	-- If not a guid match, check for name match. If also no name match, unit
	-- is not listed, so return.
	-- self:Print("GUID match: " .. tostring(guid_match))
	if not guid_match then
		if conf.require_guid_match then return end
		if not self.name_to_incident_table[full_name] then
			return
		end
	end
	-- By now we know the person is listed. So populate the query table
	-- and update the dynamic info for the unit.
	self.db.global.n_detections = self.db.global.n_detections + 1
	self.db.realm.n_detections = self.db.realm.n_detections + 1
	unit_token = unit_token or false
	scan_context = scan_context or unit_token
	self.query = {}  -- internal container to avoid passing args everywhere.
	self.query.unit_token = unit_token
	self.query.scan_context = scan_context
	self.query.guid_match = guid_match
	self.query.guid = unit_guid
	self.query.full_name = full_name
	self.query.short_name = name
	self:update_UDI()


	-- Check we're not on report lockout for this unit.
	if not self:is_off_alert_lockout() then return end

	-- Fetch incidents that meet addon user's requirements.
	-- conf.match_all_incidents
	local guid_match_incidents = nil
	local name_match_incidents = nil
	if guid_match then
		guid_match_incidents = self:return_viable_incidents()
	end
	if (not guid_match) or conf.match_all_incidents then
		name_match_incidents = self:return_viable_incidents(true)
	end
	if (not guid_match_incidents) and (not name_match_incidents) then
		-- self:Print("No viable matches")
		return
	end
	-- self:Print("Found some matching incidents.")
	self.query.guid_match_incidents = guid_match_incidents
	self.query.name_match_incidents = name_match_incidents
	self:raise_alert()

end

function SB:is_off_alert_lockout()
	-- This function determines if a given unit is on alert lockout.
	-- Also sets the last_alerted variables if off lockout. Returns true or false.
	local udi = self:get_UDI()
	local q = self.query
	local index = q.guid
	local timeNow = GetServerTime()
	if not q.guid_match then
		index = q.full_name
	end
	if not udi[index].last_alerted then
		udi[index].last_alerted = timeNow
		return true
	end

	local delta = self:get_opts_db().alert_lockout_seconds
	if timeNow < delta + udi[index].last_alerted then
		local time_until = delta + udi[index].last_alerted - timeNow
		-- self:Print(string.format("locked out for another %f seconds", time_until))
		return false
	end
	udi[index].last_alerted = timeNow
	return true
end

function SB:return_viable_incidents(force_name_match)
	-- Function to parse the incidents and return
	-- a list of ones meeting the player's requirements for alerts.
	-- Returns a table of incidents if any match.
	-- Returns false if none match.
	force_name_match = force_name_match or false
	local incident_table = {}
	local counter = 0
	local incident_matches = nil
	if not force_name_match then
		incident_matches = self.user_table[self.query.guid].incidents
	else
		-- print(self.query.full_name)
		if self.name_to_incident_table[self.query.full_name] == nil then
			-- print('no table')
			return false
		end
		incident_matches = self.name_to_incident_table[self.query.full_name].incidents
	end
	-- print(tab_dump(incident_matches))
	for i, _ in pairs(incident_matches) do
		local incident = self.incident_table[i]
		-- print(i)
		-- print(incident.description)
		if self:should_add_incident(incident) then
			counter = counter + 1
			incident_table[counter] = incident
		end
	end
	if next(incident_table) == nil then
		return false
	end
	return incident_table
end

function SB:should_add_incident(incident)
	-- Checks the given incident meets the user's requirements
	-- for generating an alert.
	local conf = self:get_opts_db()

	-- First alert level.
	if incident.level < conf.minimum_level then
		-- self:Print("Incident too low level")
		return false
	end

	-- Then category. If no category given by provider then proceed.
	if incident.category == false then
		return true
	end
	-- If category is given wrongly by provider, ignore it.
	if not incident_categories[incident.category] then
		return true

	-- If category exists, check it's not excluded.
	else
		for category, enabled in pairs(conf.categories) do
			if category == incident.category then
				if enabled then
					return true
				else
					return false
				end
			end
		end
		-- if we get to here, category not recognised, so check against "other".
		if conf.categories.other then
			return true
		else
			return false
		end
	end
	return false
end

function SB:update_UDI()
	-- This function runs when we interact with a scammer and records some of their
	-- information to persistant storage (User Dynamic Information table).
	local udi = self:get_UDI()
	local q = self.query
	local index = q.guid
	if not q.guid_match then
		index = q.full_name
	end

	-- If the entry doesn't exist, create it and populate the static fields.
	if not udi[index] then
		local p = {}
		local loc_class, english_class, race, _, _, name = GetPlayerInfoByGUID(
			q.guid
		)
		p.class = loc_class
		p.class_english_locale = english_locale_classes[english_class]
		p.english_class = english_class
		p.race = race
		p.guid = q.guid
		p.short_name = name
		p.full_name = q.full_name
		-- And placeholders for the dynamic fields.
		p.guild = false
		p.level = false
		p.last_alerted = false
		p.name_mismatches = {}
		udi[index] = p
	end
	local p = udi[index]

	-- Always update last seen
	p.last_seen = GetServerTime()

	-- At this point can also check the provider names against the actual name of
	-- any GUID-matched player in-game.
	if q.guid_match then
		for provider, name in pairs(self.user_table[index].names) do
			if p.short_name ~= name and p.name_mismatches[provider] ~= name then
				p.name_mismatches[provider] = name
				local s = string.format(
					"Warning: the list provider %s has an outdated name listed for the "..
					"player %s. They are listed as %s in the provider list, please contact "..
					"the list provider to remedy this.",
					provider, p.short_name, name
				)
				self:Print(s)
			end
		end
	end

	-- If we have a unit token, we can check current guild and level.
	if q.unit_token then
		local token = q.unit_token
		p.level = UnitLevel(token)
		p.guild = GetGuildInfo(token) or false
	end
end

--=========================================================================================
-- String construction for alerts
--=========================================================================================
function SB:construct_printout_headline()
	-- Constructs a summary string for the pinged unit.
	local q = self.query
	local udi = self:get_UDI()
	local u = udi[q.guid]
	if not u then
		u = udi[q.full_name]
	end
	local name = self:colorise_name(u.short_name, u.english_class)
	if u == nil then
		u = udi[q.full_name]
	end
	local player_hl = string.format("|Hplayer:%s|h[%s]|h", q.full_name, name)
	q.player_hl = player_hl
	local s1 = "Encountered "
	if u.level and u.guild then
		s1 = s1 .. string.format("lvl %0.f %s %s from %s", u.level, u.class_english_locale, player_hl, u.guild)
	elseif u.level then
		s1 = s1 .. string.format("lvl %0.f %s %s", u.level, u.class_english_locale, player_hl)
	elseif u.guild then
		s1 = s1 .. string.format("%s %s from [%s]", u.class_english_locale, player_hl, u.guild)
	else
		s1 = s1 .. string.format("%s %s", u.class_english_locale, player_hl)
	end
	local pretty = self.scan_table[q.scan_context].pretty
	s1 = s1 .. string.format(", detected via %s scan.", pretty)
	q.headline = s1
end

function SB:construct_chat_strings()
	-- Constructs the necessary strings for channel alerts.
	local q = self.query
	local conf = self:get_opts_db()
	-- The headline
	q.chat_headline = string.format("Warning! %s is a known scammer.", q.short_name)
	-- The guid-matched incidents
	q.chat_incidents = {}
	-- local coins = "|TInterface\\Icons\\INV_Misc_Coin_01:16:16:0:0:64:64:4:60:4:60|t"
	local note_icon = CreateTextureMarkup("Interface/Icons/Inv_misc_note_02",  64, 64, 16, 16, 0, 1, 0, 1)
	local diamond = "{rt3}"
	if q.guid_match_incidents then
		for _, incident in pairs(q.guid_match_incidents) do
			if not q.chat_incidents[incident.provider] then
				q.chat_incidents[incident.provider] = {}
			end
			q.chat_incidents[incident.provider][incident.case_id] = {
				guid = true,
				incident=incident,
				chat_lines = {},
			}
		end
	end
	-- The name-matched incidents
	if q.name_match_incidents then
		for _, incident in pairs(q.name_match_incidents) do
			if not q.chat_incidents[incident.provider] then
				q.chat_incidents[incident.provider] = {}
			end
			q.chat_incidents[incident.provider][incident.case_id] = {
				guid = false,
				incident=incident,
				chat_lines = {},
			}
		end
	end

	-- Now build up personal printout messages. These can use all the wow formatting/escape codes.
	-- Also build up chat printouts that can use the target icons but nothing else.
	for _, t1 in pairs(q.chat_incidents) do
		-- print(tab_dump(t1))
		for _, t in pairs(t1) do
			local line_counter = 0
			local sp = note_icon .. " " .. t.incident.provider
			local sc = diamond .. " " .. t.incident.provider
			if t.incident.category then
				if t.guid then
					sp = sp .. string.format(" for %s:\n", incident_categories[t.incident.category])
					sc = sc .. string.format(" for %s:\n", incident_categories[t.incident.category])
				else
					sp = sp .. string.format(" for %s (name match only):\n", incident_categories[t.incident.category])
					sc = sc .. string.format(" for %s (name match only):\n", incident_categories[t.incident.category])
				end
			else
				if t.guid then
					sp = sp .. ":\n"
					sc = sc .. ":\n"
				else
					sp = sp .. " (name match only):\n"
					sc = sc .. " (name match only):\n"
				end
			end
			t.chat_lines[line_counter] = sc
			line_counter = line_counter + 1
			if t.incident.description and conf.print_descriptions_in_alerts then
				sp = sp .. "---> " .. t.incident.description .. '\n'
				sc = "---> " .. t.incident.description .. '\n'
				t.chat_lines[line_counter] = sc
				line_counter = line_counter + 1
			end

			local sc2 = "---> " .. t.incident.url
			local sp = sp .. "---> " .. formatURL(t.incident.url) .. '\n'
			t.chat_lines[line_counter] = sc2
			line_counter = line_counter + 1
			t.personal_string = sp
		end
	end

end

--=========================================================================================
-- Alert functionality.
--=========================================================================================
function SB:play_alert_sound()
	-- Plays the configured alert sound in the client.
	local k = self:get_opts_db().alert_sound_key
	-- self:Print('playing alert, sound key = '..tostring(k))
	local sound_file = LSM:Fetch('sound', k)
	PlaySoundFile(sound_file)
end

function SB:print_chat_alert()
	-- Prints an alert to the chatbox, just to the player.
	local q = self.query
	local s = q.headline .. '\n'
	for _, provider_table in pairs(q.chat_incidents) do
		for _, t in pairs(provider_table) do
			s = s .. t.personal_string
		end
	end
	self:Print(s)
end

function SB:send_channel_alert(channel)
	-- Sends a chat alert to the requested channel.
	local conf = self:get_opts_db()
	local q = self.query
	SendChatMessage(q.chat_headline, channel)
	for _, provider_table in pairs(q.chat_incidents) do
		for _, t in pairs(provider_table) do
			local i = 0
			while t.chat_lines[i] do
				SendChatMessage(t.chat_lines[i], channel)
				i = i + 1
			end
		end
	end
end

function SB:raise_alert()
	-- This function acts upon the internal query object to produce
	-- a report on the unit that has been flagged, and alerts the user
	-- using the configured methods.
	-- First construct the relevant messages etc.
	self:construct_printout_headline()
	self:construct_chat_strings()

	local conf = self:get_opts_db()
	if conf.use_alert_sound then
		self:play_alert_sound()
	end

	-- If the scan is broadcastable, figure out if it should be broadcast
	-- according to group status and config.
	if self.scan_table[self.query.scan_context].can_broadcast and IsInGroup(LE_PARTY_CATEGORY_HOME)
	and conf.use_group_chat_alert then
		local channel = "PARTY"
		if IsInRaid() then
			channel = "RAID"
		end
		self:send_channel_alert(channel)
	-- Else print a system message as required.
	else
		if conf.use_system_alert then
			self:print_chat_alert()
		end
	end

	-- Handle stats counters
	self.db.global.n_alerts = self.db.global.n_alerts + 1
	self.db.realm.n_alerts = self.db.realm.n_alerts + 1
end

--=========================================================================================
-- WoW API callbacks
--=========================================================================================
function SB:UPDATE_MOUSEOVER_UNIT()
	if not self:is_unit_eligible("mouseover") then return end
	self:check_unit("mouseover")
end

function SB:CHAT_MSG_WHISPER(
		event_name, msg, player_name_realm,
		_, _, player_name, _, _, _, _, _, line_id, player_guid
	)
	self:check_unit(nil, player_guid, "whisper")
end

function SB:PLAYER_TARGET_CHANGED()
	-- self:Print("Scambuster doing target scan")
	if not self:is_unit_eligible("target") then return end
	self:check_unit("target")
end

function SB:GROUP_ROSTER_UPDATE()
	local members = {}
	if not IsInGroup(LE_PARTY_CATEGORY_HOME) then
		return
	end
	-- Based on reading online, might need a short C_Timer in here if the unit info
	-- isn't available 
	local n, unit = GetNumGroupMembers(), "raid"
	if not IsInRaid(LE_PARTY_CATEGORY_HOME) then
		n, unit = n - 1, "party"
	end
	for i = 1, n do
		local name = GetUnitName(unit..i, true)
		local guid = UnitGUID(unit..i)
		if name and name ~= "UNKNOWN" then
			members[name] = guid
		end
	end
	self.members = members
	for name, guid in pairs(members) do
		-- self:Print(name, guid)
		self:check_unit(nil, guid, "group")
	end
end

function SB:GROUP_INVITE_CONFIRMATION()
	-- This event is called when another player requests to join the group, either
	-- via interacting with the player directly or through the group finder, or when a party member
	-- suggests an invite. We can use the API funcs in this callback to programatically get the info
	-- we need on the player who is requesting/being requested to join.
	local invite_guid = GetNextPendingInviteConfirmation()
	local _, name, guid = GetInviteConfirmationInfo(invite_guid)
	self:check_unit(nil, guid, "invite_confirmation")
end

function SB:PARTY_INVITE_REQUEST(
	event_name, name, isTank, isHealer, isDamage, isNativeRealm, allowMultipleRoles, inviterGUID, questSessionActive
	)
	self:check_unit(nil, inviterGUID, "invite_confirmation")
end

function SB:TRADE_SHOW()
	-- This event is called when the trade window is opened.
	-- We can use the special "NPC" unit to get info we need on the
	-- character. See
	-- https://github.com/Gethe/wow-ui-source/blob/f0084386950fe3dc31a1d61de33b364e268cf66b/Interface/FrameXML/TradeFrame.lua#L68
	-- The other relevant event for the trade is "TRADE_REQUEST", however we cannot
	-- use it, because the "NPC" unit is only valid when the trade window is open.
	self:check_unit("NPC", nil, "trade")
end


function SB:PLAYER_ENTERING_WORLD()
	-- Determine if the player is in an instance and appropriately
	-- register or unregister scanning events.
	local conf = self:get_opts_db()
	local b, code = IsInInstance()
	local old_in_instance = self.in_instance
	local old_instance_code = self.instance_code
	self.in_instance = b
	self.instance_code = code
	if b ~= old_in_instance or code ~= old_instance_code then
		self:set_scan_events()
	end

	if self.first_enter_world then
		-- Only if in a home group, run the group scan callback.
		if conf.scans.group.enabled and IsInGroup(LE_PARTY_CATEGORY_HOME) then
			self:GROUP_ROSTER_UPDATE()
		end
		self.first_enter_world = false
	end

end

function SB:set_scan_events()
	-- Called whenever game loads, enter/leave instance, or 
	-- setting change.
	-- self:Print("Setting scan events")
	local conf = self:get_opts_db()
	for scan, t in pairs(self.scan_table) do
		if conf.scans[scan].enabled then
			if t.events then
				for _, event_name in pairs(t.events) do
					self:RegisterEvent(event_name)
				end
			else
				self:RegisterEvent(t.event)
			end
		end
	end
	-- In instance
	if self.in_instance then
		for scan, t in pairs(self.scan_table) do
			if conf.scans[scan].disable_in_instance then
				self:UnregisterEvent(t.event)
			end
		end
	end
end

--=========================================================================================
-- Register slashcommands
--=========================================================================================
function SB:slashcommand_options(input, editbox)
	local ACD = LibStub("AceConfigDialog-3.0")
	ACD:Open(addon_name.."_Options")
end

function SB:dump_users()
	print(tab_dump(self.user_table))
end

function SB:dump_incidents()
	print(tab_dump(self.incident_table))
end

function SB:dump_name_lookup()
	print(tab_dump(self.name_to_incident_table))
end

function SB:dump_udi()
	print(tab_dump(self:get_UDI()))
end

function SB:clear_udi()
	self.db.global.udi = {}
end

function SB:clear_fps()
	-- Clear false positive table
	self.db.global.false_positive_table = {}
end

function SB:slashcommand_soundcheck()
	local sound_file = LSM:Fetch('sound', self.conf.alert_sound)
	PlaySoundFile(sound_file)
end

function SB:show_stats()
	self:Print("N scans global = " .. tostring(self.db.global.n_scans))
	self:Print("N detections global = " .. tostring(self.db.global.n_detections))
	self:Print("N alerts global = " .. tostring(self.db.global.n_alerts))

	self:Print("N scans realm = " .. tostring(self.db.realm.n_scans))
	self:Print("N detections realm = " .. tostring(self.db.realm.n_detections))
	self:Print("N alerts realm = " .. tostring(self.db.realm.n_alerts))
end

--=========================================================================================
-- Debug for lua parsing
--=========================================================================================
if sb.debug then SB:Print("Finished parsing core.lua.") end
