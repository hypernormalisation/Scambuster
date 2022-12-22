--=========================================================================================
-- Main module for Cutpurse
--=========================================================================================
local addon_name, cp = ...
local CP = LibStub("AceAddon-3.0"):NewAddon(addon_name, "AceConsole-3.0", "AceEvent-3.0")
CP.callbacks = CP.callbacks or LibStub("CallbackHandler-1.0"):New(CP) 
local LSM = LibStub("LibSharedMedia-3.0")
cp.debug = true
cp.add_test_list = true
local L = cp.L
if cp.debug then CP:Print("Parsing core.lua...") end

-- Load some relevant wow API and lua globals into the local namespace.
local GetInviteConfirmationInfo = GetInviteConfirmationInfo
local GetNextPendingInviteConfirmation = GetNextPendingInviteConfirmation
local GetUnitName = GetUnitName
local GetTime = GetTime
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local GetRealmName = GetRealmName
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local PlaySoundFile = PlaySoundFile
local GetNumGroupMembers = GetNumGroupMembers

local UnitInBattleground = UnitInBattleground
local UnitFactionGroup = UnitFactionGroup
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitLevel = UnitLevel
local UnitRace = UnitRace
local UnitClass = UnitClass
local GetGuildInfo = GetGuildInfo

local pcall = pcall

local LE_PARTY_CATEGORY_HOME = LE_PARTY_CATEGORY_HOME

local ipairs = ipairs
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

function CP:colorise_name(name, class)
	local c = RAID_CLASS_COLORS[class]
	local cc = ('c' .. c.colorStr)
	return "|"..cc..name.."|r"
end


local context_pretty_table = {
	mouseover = "Mouseover",
	target = "Target",
	group = "Group",
	invite_confirmation = "Invite Confirmation",
	trade = "Trade Window",
	whisper = "Whisper",
}

--=========================================================================================
-- Helper funcs
--=========================================================================================
function CP:get_opts_db()
	return self.db.profile
end

function CP:get_provider_settings()
	return self.db.global.provider_settings
end

function CP:get_UDI()
	return self.db.global.udi
end

--=========================================================================================
-- The basic AceAddon structure
--=========================================================================================
function CP:OnInitialize()

	-- Register our custom sound alerts with LibSharedMedia
	LSM:Register(
		"sound", "Cutpurse: Criminal scum!",
		string.format([[Interface\Addons\%s\media\criminal_scum.mp3]], addon_name)
	)
	LSM:Register(
		"sound", "Cutpurse: Not on my watch!",
		string.format([[Interface\Addons\%s\media\nobody_breaks_the_law.mp3]], addon_name)
	)
	LSM:Register(
		"sound", "Cutpurse: You've violated the law!",
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
	self:RegisterChatCommand("cp", "slashcommand_options")
	self:RegisterChatCommand("cutpurse", "slashcommand_options")
	self:RegisterChatCommand("dump_users", "dump_users")
	self:RegisterChatCommand("dump_incidents", "dump_incidents")
	self:RegisterChatCommand("dump_name_lookup", "dump_name_lookup")
	self:RegisterChatCommand("dump_guid_lookup", "dump_guid_lookup")

	self:RegisterChatCommand("dump_udi", "dump_udi")
	self:RegisterChatCommand("clear_udi", "clear_udi")
	self:RegisterChatCommand("clear_fps", "clear_fps")
	self:RegisterChatCommand("test1", "test1")

	-- Temporary 
	self.unprocessed_case_data = {}
	self.provider_counter = 0

	-- Containers for the alerts system.
	self.alert_counter = 0  -- just for index handling on temp alerts list
	self.pending_alerts = {}

end

function CP:OnEnable()
	self.realm_name = GetRealmName()
	self.player_faction = UnitFactionGroup("player")

	-- Alert the extension addons to register their case data.
	self.callbacks:Fire("CUTPURSE_LIST_CONSTRUCTION")
	-- Then build the database.
	self:build_database()

	-- Enable the requisite events here according to settings.
	local opts_db = self:get_opts_db()
	-- if opts_db.use_mouseover_scan then
	-- 	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
	-- end
	-- if opts_db.use_whisper_scan then
	-- 	self:RegisterEvent("CHAT_MSG_WHISPER")
	-- end
	-- if opts_db.use_target_scan then
	-- 	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	-- end
	-- if opts_db.use_trade_scan then
	-- 	self:RegisterEvent("TRADE_SHOW")
	-- end
	-- if opts_db.use_group_scan then
	-- 	self:RegisterEvent("GROUP_ROSTER_UPDATE")
	-- end
	-- if opts_db.use_group_request_scan then
	-- 	self:RegisterEvent("GROUP_INVITE_CONFIRMATION")
	-- end
	-- -- Only if in a group, run the group scan callback.
	-- if opts_db.use_group_scan and IsInGroup(LE_PARTY_CATEGORY_HOME) then
	-- 	self:GROUP_ROSTER_UPDATE()
	-- end

	-- Welcome message if requested
	if opts_db.welcome_message then
		self:Print('Welcome to version 0.0.1.')
	end

end

--=========================================================================================
-- Funcs to register lists with Cutpurse, for use in addons that extend Cutpurse, and
-- funcs to construct the lists used by the addon.
--=========================================================================================
function CP:register_case_data(data)
	-- Function to be called in provider extentions upon receiving
	-- the CUTPURSE_LIST_CONSTRUCTION callback.
	-- This function takes a table of case data vars with integer keys.
	self:Print("CALL TO REGISTER A LIST")
	self.provider_counter = self.provider_counter + 1
	self.unprocessed_case_data[self.provider_counter] = data
end

function CP:build_database()
	-- This function builds (or rebuilds) the database from the registered
	-- raw lists from the provider extensions.
	self:Print("Building Cutpurse database...")
	-- This is the table containing the flagged users.
	self.user_counter = 0
	self.user_table = {}
	-- This is the table containing the processed case data and its counter.
	self.case_data_counter = 0
	self.incident_table = {}
	-- These are the lookup tables for guid and name lookups.
	self.guid_lookup = {}
	self.name_lookup = {}
	-- Tables for sanity checks on old aliases and guids.
	self.previous_guid_table = {}
	self.alias_table = {}

	-- Now iterate over the unprocessed case data and build up the db.
	local pdb = self:get_provider_settings()
	for _, l in pairs(self.unprocessed_case_data) do
		local n = l.name
		-- If no setting for this provider, assume enabled.
		if pdb[n] == nil then
			pdb[n] = {enabled = true}
			self:process_case_data(l)
		-- Else check for disabled lists and skip
		else
			if pdb[n].enabled then
				self:process_case_data(l)
			end
		end
	end
end

function CP:protected_process_case_data(l)
	-- Wrap the parse of the unprocessed case data in a pcall.
	local result = pcall(self.process_case_data, l)
	if not result then
		local name = l.name or l.provider or "UNIDENTIFIED LIST"
		self:Print(
			string.format(
				"ERROR: the provider list %s could not be properly processed. "..
				"Please contact the distributer of this list and disable the extension "..
				"module until a fix is provided by the distributer, as this list may "..
				"corrupt Cutpurse's internal databases.",
				name
			)
		)
	end
end

function CP:process_case_data(l)
	-- Takes the given case data for a single provider and adds
	-- it to the database.
	for realm, realm_dict in pairs(l.realm_data) do
		for _, case_data in pairs(realm_dict) do
			case_data.realm = realm
			if case_data.guid then
				self:process_case_by_guid(case_data)
			else
				self:process_case_by_name(case_data)
			end
		end
	end
end

function CP:process_case_by_guid(case_data)
	-- This function processes an individual case where a guid
	-- is given in the case data. If a user entry already exists for this
	-- guid, it merges the information. Else, it creates a new entry.
	local user_index = self.guid_lookup[case_data.guid]
	local t = {}

	if user_index then
		t = self.user_table[user_index]
		if case_data.realm ~= t.realm then
			self:Print(
				"Warning: two lists have the same player matched by current guid, but "..
				"listed on different servers, which is impossible. "..
				string.format("Player name: %s", case_data.name .. "-" .. case_data.realm)
			)
		end
	else
		t.realm = case_data.realm
		t.names = {}
		t.previous_names = {}
		t.previous_guids = {}
		t.incidents = {}
	end

	-- Add name if not present to possible current names.
	if not t.names[case_data.name] then
		t.names[case_data.name] = true
		-- Also add the lookup entry if we don't have it
		self.name_lookup[case_data.name] = user_index
	end
	-- Possible previous names
	if case_data.previous_names then
		for _, alias in ipairs(case_data.previous_names) do
			if not t.aliases[alias] then
				t.aliases[alias] = true
				self.alias_table[alias] = case_data.name
			end
		end
	end
	-- Possible previous guids
	if case_data.previous_guids then
		for _, g in ipairs(case_data.previous_guids) do
			if not t.previous_guids[g] then
				t.previous_guids[g] = true
				self.previous_guid_table[g] = {guid = case_data.guid}
			end
		end
	end

	-- If no user index, increment and add.
	self.user_counter = self.user_counter + 1
	user_index = self.user_counter
	self.user_table[user_index] = t

	-- If necessary, add to the guid lookup table.
	if not self.guid_lookup[case_data.guid] then
		self.guid_lookup[case_data.guid] = user_index
	end

	-- Now process the incident details.
	self:process_incident(user_index, case_data)
end

function CP:process_case_by_name(case_data)
	-- This function processes an individual case where a name
	-- and no GUID is given. Because we cannot guarantee two cases
	-- with two names are the same person, we always generate a new user
	-- table entry for each case.
	-- Name lookups can point to multiple users.
	self.user_counter = self.user_counter + 1
	local user_index = self.user_counter
	local full_name = case_data.name .. "-" .. case_data.realm
	local t = {}
	t.names = {}
	t.realm = case_data.realm
	t.names[case_data.name] = true

	t.previous_names = {}
	if case_data.previous_names then
		for _, alias in ipairs(case_data.previous_names) do
			t.aliases[alias] = true
			self.alias_table[alias] = case_data.name
		end
	end

	if case_data.previous_guids then
		for _, g in ipairs(case_data.previous_guids) do
			t.previous_guids[g] = true
			self.previous_guid_table[g] = {guid = case_data.guid}
		end
	end
	t.previous_guids = {}
	t.incidents = {}

	-- Add to user table
	self.user_table[user_index] = t

	-- Now check if the name exists in the name_lookup table, and if so append.
	-- Else create new table and fill entry.
	if not self.name_lookup[full_name] then
		self.name_lookup[full_name] = {}
	end
	self.name_lookup[full_name][user_index] = true

	-- Now process the incident details.
	self:process_incident(user_index, case_data)

end

function CP:process_incident(user_index, case_data)
	-- Function to add the specific details of the case_data
	-- that refer to a given incident to the incident_table.
	self.case_data_counter = self.case_data_counter + 1
	local c = {}
	c.description = case_data.description
	c.url = case_data.url
	c.category = case_data.category or false
	c.level = case_data.level or 1
	c.user = user_index
	self.incident_table[self.case_data_counter] = c
	-- Record a reference for this case in the user table.
	self.user_table[user_index].incidents[self.case_data_counter] = true
end

--=========================================================================================
-- Scanning and checking functionality.
--=========================================================================================
function CP:is_unit_eligible(unit_token)
	-- Function to get info using the specified unit_token and
	-- verify the unit in question is another same-faction player
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

function CP:check_unit(unit_token, unit_guid, scan_context)
	-- Checks a unit against the lists.
	-- Should only be called after we've confirmed the unit is a 
	--  same-side faction unit who is not the player.
	-- Requires one of unit_token or unit_guid.
	-- The scan_context is required to tell the alerts system what scan
	--  registered the unit. If a unit_token is given, it defaults to that.
	--  If a unit token does not exist, as for whispers or invite
	--  confirmations, it should be passed manually.

	-- Internally set the scan vars
	-- to avoid multiple API calls and passing lots of arguments
	self.current_unit_guid = unit_guid or UnitGUID(unit_token)
	self.current_unit_token = unit_token or false
	self.current_scan_context = scan_context or unit_token
	self.in_bg = UnitInBattleground("player")
	local name, realm = select(6, GetPlayerInfoByGUID(self.current_unit_guid))
	if realm == "" then
		realm = self.realm_name
	end
	self.current_unit_name = name
	self.current_realm_name = realm
	self.current_full_name = name.."-"..realm

	-- Check against curated lists
	local result = self:check_against_CLs()
	if result then
		self:raise_alert()
		return
	end
	CP:clear_scan_vars()
end

function CP:check_against_CLs()
	-- This function checks against the curated lists.
	if self.in_bg then
		return -- maybe we have some option to disable in BG
	end

	if self.curated_db_local[self.current_unit_name] == nil then
		return false
	end

	-- Else we've found a match on the name.
	-- Now check if any reported GUIDs from providers match the unit's GUID.
	local t = self.curated_db_local[self.current_unit_name]
	local guid_match = false
	local guid_mismatch = false
	local guid_ambiguous = false
	local mismatch_table = {}
	for provider, report in pairs(t.reports) do
		if report.last_known_guid then
			if report.last_known_guid == self.current_unit_guid then
				guid_match = true
			else
				guid_mismatch = true
				mismatch_table[provider] = report.last_known_guid
			end
		else
			guid_ambiguous = true
		end
	end

	-- Handle conditions where the reported guid from the provider does
	-- not match the unit's guid. This indicates a likely mistake or false-positive.
	if guid_mismatch then
		for provider, guid in pairs(mismatch_table) do
			local key = string.format(
				"%s - %s - %s", self.current_full_name, provider, guid
			)
			-- Only do this once per unit mismatch so as not to spam the user.
			if not self.db.global.false_positive_table[key] then
				self:Print(
					string.format(
						"Warning: player %s is listed by %s, but with "..
						"a mismatched GUID (%s recorded, %s in-game). This may imply a false "..
						"positive where a scammer has renamed their toon, and someone new "..
						"has taken their old name."..
						" Please contact the provider of this list with this message's contents.",
						self.current_full_name, provider, guid, self.current_unit_guid
					)
				)
				self.db.global.false_positive_table[key] = true
			end
		end
	end
	-- If *only* a mismatch, return false
	if guid_mismatch and (not guid_match) and (not guid_ambiguous) then
		return false
	end
	-- If ambiguous, i.e. no definite guid match on any provider, set a 
	-- partial_match flag.
	if guid_ambiguous and not guid_match then
		self.partial_match = true
	end
	self.current_alert_privilege = "curated"
	return true
end

function CP:clear_scan_vars()
	-- Clear the internal containers
	-- not strictly necessary but if we assign one only 
	-- in a conditional by accident it might be hard to debug.
	self.current_unit_name = nil
	self.current_realm_name = nil
	self.current_full_name = nil
	self.partial_match = nil
	self.current_unit_guid = nil
	self.current_scan_context = nil
	self.current_alert_privilege = nil
end

--=========================================================================================
-- Alert functionality
--=========================================================================================
function CP:raise_alert()
	self:update_udi()
	-- Figure out if we're still on lockout for this player
	local udi = self:get_UDI()
	local last_alerted = udi[self.current_full_name]["last_alerted"]
	local d = self:get_opts_db().alert_lockout_seconds
	if last_alerted then
		if GetTime() < d + last_alerted then
			local time_until = d + last_alerted - GetTime()
			-- self:Print(string.format("locked out for another %f seconds", time_until))
			return
		end
	end
	udi[self.current_full_name]["last_alerted"] = GetTime()
	local c_db = self.curated_db_global[self.current_full_name]

	-- Parse reports to eliminate guid mismatches
	local reports = c_db['reports']
	local reports_parsed = {}
	for provider, report in pairs(reports) do
		-- Catch mismatched guids and prevent printing.		
		if report.last_known_guid ~= false and report.last_known_guid ~= self.current_unit_guid then
			-- do nothing
		else
			reports_parsed[provider] = report
		end
	end
	local context_pretty = context_pretty_table[self.current_scan_context]
	local u = self:get_UDI()[self.current_full_name]

	local t = {
		name = self.current_full_name,
		name_short = self.current_unit_name,
		guid = self.current_unit_guid,
		context = self.current_scan_context,
		context_pretty = context_pretty,
		partial = self.partial_match,
		reports = reports_parsed,
		udi = u,
	}

	-- Generate a summary message for the scan	
	local s1 = ""
	if u.level and u.guild then
		s1 = "Flagged player " .. self:colorise_name(t.name_short, u.english_class)..
		string.format(", lvl %.0f %s %s", u.level, u.race, u.class) ..
		string.format(" from the guild %s detected via ", u.guild)..
		t.context_pretty .. " scan."
	elseif t.udi.level then
		s1 = "Flagged player " .. self:colorise_name(t.name_short, u.english_class)..
		string.format(", lvl %.0f %s %s", u.level, u.race, u.class) ..
		" detected via ".. t.context_pretty .. " scan."
	elseif t.udi.guild then
		s1 = "Flagged player " .. self:colorise_name(t.name_short, u.english_class)..
		string.format(", %s %s", u.race, u.class) ..
		string.format(" from the guild %s detected via ", u.guild)..
		t.context .. " scan."
	else
		s1 = "Flagged player " .. self:colorise_name(t.name_short, u.english_class)..
		string.format(", %s %s", u.race, u.class) ..
		" detected via ".. t.context .. " scan."
	end
	t.summary = s1

	-- Generate guid match summary
	local s2 = ""

	-- Handle stats counters
	self.db.global.n_alerts = self.db.global.n_alerts + 1
	self.db.realm.n_alerts = self.db.realm.n_alerts + 1
	self:post_alert(t)
end

function CP:post_alert(t)
	-- Func to take a generated alert and post it, triggering the configured
	-- alerts behaviour.
	self.pending_alerts[self.alert_counter] = t
	self.alert_counter = self.alert_counter + 1
	local db = self:get_opts_db()
	if db.use_alert_sound then
		self:play_alert_sound()
	end
	if db.use_chat_alert then
		self:display_chat_alert(t)
	end
end

function CP:display_chat_alert(t)
	-- Function to generate and print an alert.
	self:Print(t.summary)
	for provider, report in pairs(t.reports) do
		local reason = report.reason
		local evidence = report.evidence
		local last_known_guid = report.last_known_guid
		self:Print(string.format("%s has listed this player for:", provider))
		print(" - reason : " .. reason)
		print(" - case url : " .. evidence)
		if not report.last_known_guid then
			print(" - partial match, no guid supplied by provider.")
		elseif last_known_guid == self.current_unit_guid then
			print(" - full match with provider's guid: " .. last_known_guid)
		end
	end
end

function CP:play_alert_sound()
	local k = self:get_opts_db().alert_sound
	-- self:Print('playing alert, sound key = '..tostring(k))
	local sound_file = LSM:Fetch('sound', k)
	PlaySoundFile(sound_file)
end

--=========================================================================================
-- User Dynamic Information funcs
--=========================================================================================
function CP:update_udi()
	-- Function to update the user dynamic information table.
	-- when we encounter a scammer in-game and can access their information.
	local index = self.current_full_name
	local t = self:get_UDI()
	if t[index] == nil then
		-- self:Print(string.format('Registering new info for %s', index))
		t[index] = {}
	else
		-- self:Print(string.format('Updating info for %s', index))
	end
	local p = t[index]

	-- If we have a unit token we can access finer info from, use that.
	if self.current_unit_token then
		local token = self.current_unit_token
		p.class, p.english_class = UnitClass(token)
		p.level = UnitLevel(token)
		p.guild = GetGuildInfo(token) or false
		p.race = UnitRace(token)
		p.guid = self.current_unit_guid
		p.last_seen = GetTime()
		p.last_alerted = p.last_alerted or false
		p.name_short = self.current_unit_name

	-- Else we're accessing the unit's details via a GUID, which means less available
	-- info via the API.
	else
		local loc_class, english_class, race, _, _, name = GetPlayerInfoByGUID(
			self.current_unit_guid
		)
		p.class = loc_class
		p.english_class = english_class
		p.race = race
		p.name_short = self.current_unit_name
		p.last_seen = GetTime()
		p.last_alerted = p.last_alerted or false
		p.name_short = self.current_unit_name
		-- Now the info we don't have access to, fall back on old info 
		-- or if new entry put false.
		p.guild = p.guild or false
		p.level = p.level or false
	end
end

--=========================================================================================
-- WoW API callbacks
--=========================================================================================
function CP:UPDATE_MOUSEOVER_UNIT()
	if not self:get_opts_db().use_mouseover_scan then return end
	if not self:is_unit_eligible("mouseover") then return end
	self:check_unit("mouseover")
end

function CP:CHAT_MSG_WHISPER(
		event_name, msg, player_name_realm,
		_, _, player_name, _, _, _, _, _, line_id, player_guid
	)
	if not self:get_opts_db().use_whisper_scan then return end
	self:check_unit(nil, player_guid, "whisper")
end

function CP:PLAYER_TARGET_CHANGED()
	if not self:get_opts_db().use_target_scan then return end
	if not self:is_unit_eligible("target") then return end
	self:check_unit("target")
end

function CP:GROUP_ROSTER_UPDATE()
	local members = {}
	if not IsInGroup(LE_PARTY_CATEGORY_HOME) then
		-- print("not in a group")
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

function CP:GROUP_INVITE_CONFIRMATION()
	-- This event is called when another player requests to join the group, either
	-- via interacting with the player directly or through the group finder, or when a party member
	-- suggests an invite. We can use the API funcs in this callback to programatically get the info
	-- we need on the player who is requesting/being requested to join.
	local invite_guid = GetNextPendingInviteConfirmation()
	local _, name, guid = GetInviteConfirmationInfo(invite_guid)
	self:Print(name, guid)
	self:check_unit(nil, guid, "invite_confirmation")
end

function CP:TRADE_SHOW()
	-- This event is called when the trade window is opened.
	-- We can use the special "NPC" unit to get info we need on the
	-- character. See
	-- https://github.com/Gethe/wow-ui-source/blob/f0084386950fe3dc31a1d61de33b364e268cf66b/Interface/FrameXML/TradeFrame.lua#L68
	-- The other relevant event for the trade is "TRADE_REQUEST", however we cannot
	-- use it, because the "NPC" unit is only valid when the trade window is open.
	self:check_unit("NPC", nil, "trade")
end

--=========================================================================================
-- Register slashcommands
--=========================================================================================
function CP:slashcommand_options(input, editbox)
	local ACD = LibStub("AceConfigDialog-3.0")
	ACD:Open(addon_name.."_Options")
end

function CP:dump_users()
	print(tab_dump(self.user_table))
end

function CP:dump_incidents()
	print(tab_dump(self.incident_table))
end

function CP:dump_name_lookup()
	print(tab_dump(self.name_lookup))
end

function CP:dump_guid_lookup()
	print(tab_dump(self.guid_lookup))
end

function CP:dump_udi()
	print(tab_dump(self:get_UDI()))
end

function CP:clear_udi()
	self.db.global.udi = {}
end

function CP:clear_fps()
	-- Clear false positive table
	self.db.global.false_positive_table = {}
end

function CP:slashcommand_soundcheck()
	local sound_file = LSM:Fetch('sound', self.conf.alert_sound)
	PlaySoundFile(sound_file)
end

function CP:test1()
	self:Print("N alerts global = " .. tostring(self.db.global.n_alerts))
	self:Print("N alerts realm  = " .. tostring(self.db.realm.n_alerts))
end

--=========================================================================================
-- helper funcs for loading and altering lists
--=========================================================================================
function CP:add_to_ubl(t)
	-- Function to add to the ubl. t should be a table with at least one 
	-- of unitID or name, and always with reason.
	local unitId = t.unitId
	local name = t.name
	local reason = t.reason
	CP:Print(name, unitId, reason)
	if reason == nil then
		self:Print("Error: need a reason to blacklist target")
		return
	end
	if unitId ~= nil then
		if not self:is_unit_eligible(unitId) then
			self:Print("Unit is not a same-faction player and cannot be blacklisted!")
			return
		end
		name = UnitName(unitId)
		if name == nil then
			self:Print("ERROR: name from API not valid.")
			return
		end
		-- Record player's dynamic information.
		self:update_udi(unitId)
	end
	-- check if on blacklist already
	if self.ubl[name] ~= nil then
		self:Print(string.format("%s is already on user blocklist, updating info.", name))
	else
		self:Print(string.format("%s will be placed on the user blocklist.", name))
	end
	self:Print("Reason: " .. reason)
	self.ubl[name] = {
		reason = reason,
		ignore = false -- override any ignore settings
	}
end




if cp.debug then CP:Print("Finished parsing core.lua.") end
