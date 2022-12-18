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

-- Load some relevant wow API and lua globals into the local namespace for efficiency
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

local pairs = pairs
local print = print
local select = select
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


--=========================================================================================
-- Helper funcs
--=========================================================================================
local function printtab(t)
	for k, v in pairs(t) do
		print(k, v)
	end
end

function CP:get_opts_db()
	return self.db.global
end

function CP:get_provider_settings()
	return self.db.global.provider_settings
end

function CP:get_PDI()
	return self.db.global.pdi
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
	-- self:RegisterChatCommand("testbl", "slashcommand_testbl")
	self:RegisterChatCommand("dump_local", "dump_local")
	self:RegisterChatCommand("dump_global", "dump_global")
	self:RegisterChatCommand("dump_pdi", "dump_pdi")
	self:RegisterChatCommand("clear_pdi", "clear_pdi")

	-- self:RegisterChatCommand("blocklist_target", "slashcommand_blocklist_target")
	-- self:RegisterChatCommand("blocklist_name", "slashcommand_blocklist_name")
	-- self:RegisterChatCommand("soundcheck", "slashcommand_soundcheck")
	-- self:RegisterChatCommand("dump_config", "slashcommand_dump_config")

	self.raw_curated_lists = {}
	self.ucl_counter = 0
	self.unprocessed_user_lists = {}
	self.curated_db_local = {}
	self.curated_db_global = {}

	if self.db.global.provider_settings == nil then
		self.db.global.provider_settings = {}
	end

	-- Containers for the alerts system.
	self.alert_counter = 0
	self.pending_alerts = {}
	self.locked_players = {}

	-- Ensure player dynamic information table
	if not self.db.global.pdi then
		self.db.global.pdi = {}
	end

	-- Ensure stats tables and counters
	if not self.db.global.stats then
		self.db.global.stats = {}
		self.db.global.stats.n_warnings = 0
	end
	if not self.db.realm.stats then
		self.db.realm.stats = {}
		self.db.realm.stats.n_warnings = 0
	end

	-- -- Construct the central blocklist if one is present.
	-- self.has_cbl = false
	-- self.ignored_players = {}
	-- if self.db.realm.user_blacklist == nil then
	-- 	self.db.realm.user_blacklist = {}
	-- end
	-- self.ubl = self.db.realm.user_blacklist -- shorthand

end

function CP:OnEnable()
	-- some basic post-load info to gather
	self.realm_name = GetRealmName()
	self:Print("realm name = " .. tostring(self.realm_name))
	self.player_faction = UnitFactionGroup("player")

	-- Load necessary data.
	-- We do this here so extensions can init their
	-- provider blocklists before we construct the cbl.
	self.callbacks:Fire("CUTPURSE_LIST_CONSTRUCTION")
	self:construct_dbs()

	-- self:load_dynamic_info()
	-- self:load_ubl()
	-- self:get_valid_providers()
	-- self:load_cbl() -- constructed each time load/setting change

	-- Enable the requisite events here according to settings.
	local opts_db = self:get_opts_db()
	if opts_db.use_mouseover_scan then
		self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
	end
	if opts_db.use_whisper_scan then
		self:RegisterEvent("CHAT_MSG_WHISPER")
	end
	if opts_db.use_target_scan then
		self:RegisterEvent("PLAYER_TARGET_CHANGED")
	end
	-- Welcome message if requested
	if self.conf.welcome_message then
		self:Print('Welcome to version 0.0.1.')
	end
	self:RegisterEvent("GROUP_ROSTER_UPDATE")
	self:RegisterEvent("GROUP_INVITE_CONFIRMATION")
end

--=========================================================================================
-- Funcs to register lists with Cutpurse, for use in addons that extend Cutpurse, and
-- funcs to construct the lists used by the addon.
--=========================================================================================
function CP:register_curated_list(data)
	self:Print("CALL TO REGISTER A LIST")
	self.ucl_counter = self.ucl_counter + 1
	self.raw_curated_lists[self.ucl_counter] = data
end

function CP:register_user_list(data)
	-- Might not need this one
end

function CP:construct_dbs()
	-- This function builds the relevant dbs
	self:Print("GOING TO CONSTRUCT LISTS NOW")
	local pdb = self:get_provider_settings()
	local ucl = self.raw_curated_lists
	self.curated_db_local = {}
	self.curated_db_global = {}

	for _, new_list in pairs(ucl) do
		local n = new_list.name
		if pdb[n] == nil then
			pdb[n] = {enabled = true}
			self:add_curated_list_to_db(new_list)
		else
			if pdb[n].enabled then
				self:add_curated_list_to_db(new_list)
			end
		end
	end
end

function CP:add_curated_list_to_db(l)
	local list_name = l.name
	local provider = l.provider
	for realm, realm_dict in pairs(l.realm_data) do
		for _, case_data in pairs(realm_dict) do
			local player_name = case_data.last_known_name
			local full_name = string.format("%s-%s", player_name, realm)
			-- Always add to the global db regardless of realm.
			self:add_to_target_db(
				self.curated_db_global,
				full_name,
				case_data,
				list_name
			)
			-- Add to the local db if the realm matches the player's home realm.
			if realm == self.realm_name then
				self:add_to_target_db(
					self.curated_db_local,
					player_name,
					case_data,
					list_name
				)
			end
		end
	end
end

function CP:add_to_target_db(target, key, case_data, list_name)
	-- key is name or name-realm
	-- If no provider has given data on this player yet, make a new entry
	if target[key] == nil then
		local pa = case_data.previous_aliases or {}
		self:Print(pa)
		target[key] = {
			guid = case_data.last_known_guid,
			previous_aliases = pa,
			reports = {
				provider = {
					reason = case_data.reason,
					evidence = case_data.evidence,
				}
			}
		}
	-- If there is already data, add the relevant fields
	else
		print("already got data for name:" .. key)
		local current_data = target[key]
		-- First previous aliases, if there are any.
		-- if case_data.previous_aliases then
		local current_aliases = current_data.previous_aliases
		self:Print(current_aliases)
		if case_data.previous_aliases ~= nil then
			for alias, old_guid in pairs(case_data.previous_aliases) do
				if current_aliases[alias] == nil then
					current_aliases[alias] = old_guid
				elseif old_guid ~= 0 then
					current_aliases[alias] = old_guid
				end
			end
		end
		-- end
		-- Now report data
		current_data.reports[list_name] = {
			reason = case_data.reason,
			evidence = case_data.evidence
		}
	end
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
	--  If it is not given, as for whispers or invite
	--  confirmations, it should be passed manually.

	-- Internally set a scan context and the target guid
	-- to avoid multiple API calls and passing lots of arguments
	unit_guid = unit_guid or UnitGUID(unit_token)
	self.current_unit_guid = unit_guid
	self.current_scan_context = scan_context or unit_token
	self.in_bg = UnitInBattleground("player")

	-- First check against curated lists
	local result = self:check_against_CLs()
	if result then
		self:raise_alert()
		return
	end
	-- Then check against user lists
	-- result = self:check_against_ULs()
	-- if result then
	-- 	self:raise_alert()
	-- 	return
	-- end

	CP:clear_scan_vars()

end

function CP:check_against_CLs()
	-- This function checks against the curated lists.
	local name, realm = select(6, GetPlayerInfoByGUID(self.current_unit_guid))
	if realm == "" then
		realm = self.realm_name
	end
	self.current_unit_name = name
	self.current_realm_name = realm
	self.current_full_name = name.."-"..realm

	-- We make provisions for either just the name being recorded, or both the name
	-- and the guid being recorded.
	if self.in_bg then
		return -- maybe we have some option to disable in BG
	end

	if self.curated_db_local[name] == nil then
		return false
	end

	local t = self.curated_db_local[name]
	self.partial_match = true
	if self.current_unit_guid == t.guid then
		self.partial_match = false
	end
	self.current_alert_privilege = "curated"
	return true
end

function CP:check_against_ULs()
	-- This function checks against the user lists.
end

function CP:raise_alert()
	self:update_pdi()

	-- Figure out if we're still on lockout for this player
	local pdi = self:get_PDI()
	local last_alerted = pdi[self.current_full_name]["last_alerted"]
	local d = self:get_opts_db().alert_lockout_seconds
	if last_alerted then
		if GetTime() < d + last_alerted then
			local time_until = d + last_alerted - GetTime()
			self:Print(string.format("locked out for another %f seconds", time_until))
			return
		end
	end
	pdi[self.current_full_name]["last_alerted"] = GetTime()

	-- Construct and push the alert
	self:Print("-- Listed player detected: "..tostring(self.current_unit_name))
	self:Print("--   Scan Context  : "..tostring(self.current_scan_context))
	self:Print("--   Partial match : "..tostring(self.partial_match))

	local t = self.curated_db_global[self.current_full_name]
	local reason = nil
	local new_t = {
		name = self.current_full_name,
	}
end

function CP:update_pdi()
	-- Function to update the player dynamic information table.
	-- when we encounter a scammer in-game and can access their information.
	local name = self.current_unit_name
	local realm = self.current_realm_name
	local index = self.current_full_name
	local t = self:get_PDI()

	if t[index] == nil then
		self:Print(string.format('Registering new info for %s', index))
		t[index] = {}
	else
		self:Print(string.format('Updating info for %s', index))
	end
	local token = self.current_scan_context
	local class = UnitClass(token)
	local level = UnitLevel(token)
	local race = UnitRace(token)
	local guild = GetGuildInfo(token)
	local guid = UnitGUID(token)

	local last_alerted = t[index]["last_alerted"] or false

	t[index] = {
		class = class,
		level = level,
		guild = guild,
		race = race,
		guid = guid,
		last_seen = time(),
		last_alerted = last_alerted
	}
end

function CP:clear_scan_vars()
	-- reset the internal containers
	-- not strictly necessary but if we assign one only 
	-- in a conditional it might be hard to debug
	self.current_unit_name = nil
	self.current_realm_name = nil
	self.current_full_name = nil
	self.partial_match = nil
	self.current_unit_guid = nil
	self.current_scan_context = nil
	self.current_alert_privilege = nil
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

end

function CP:PLAYER_TARGET_CHANGED()
	if not self:get_opts_db().use_target_scan then return end
	if not self:is_unit_eligible("target") then return end
	-- self:Print("Target name: "..tostring(UnitName("target")))
	self:check_unit("target")
end

function CP:GROUP_ROSTER_UPDATE()
	local members = {}
	if not IsInGroup() then
		print("not in a group")
		return
	end
	-- Based on reading online, might need a short C_Timer in here if the unit info
	-- isn't available 
	local n, unit = GetNumGroupMembers(), "raid"
	if not IsInRaid() then
		n, unit = n - 1, "party"
	end
	for i = 1, n do
		local name = GetUnitName(unit..i, true)
		if name and name ~= "UNKNOWN" then
			members[name] = i
		end
	end
	self.members = members
	for k, v in pairs(members) do
		self:Print(k, v)
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
end

--=========================================================================================
-- Register slashcommands
--=========================================================================================
function CP:slashcommand_options(input, editbox)
	local ACD = LibStub("AceConfigDialog-3.0")
	ACD:Open(addon_name.."_Options")
end

function CP:dump_local()
	print(tab_dump(self.curated_db_local))
end

function CP:dump_global()
	print(tab_dump(self.curated_db_global))
end

function CP:dump_pdi()
	print(tab_dump(self:get_PDI()))
end

function CP:clear_pdi()
	self.db.global.pdi = {}
end

function CP:slashcommand_soundcheck()
	local sound_file = LSM:Fetch('sound', self.conf.alert_sound)
	PlaySoundFile(sound_file)
end

-- function CP:slashcommand_blocklist_target(reason)
-- 	-- Places the current target on the user blocklist for the provided reason.
-- 	-- Must provide a reason!
-- 	if not self.is_unit_eligible("target") then
-- 		self:Print("Error: command needs a target to function!")
-- 		return
-- 	end
-- 	local t = {
-- 		unitId = "target",
-- 		reason = reason,
-- 	}
-- 	print(t.unitId, "<"..t.reason..">")
-- 	self:add_to_ubl(t)
-- end

-- function CP:slashcommand_blocklist_name(args)
-- 	-- Places the name given on the ubl for the provided reason.
-- 	if args == "" then
-- 		self:Print("ERROR: command needs a name and a reason to list!")
-- 		self:Print("e.g: /blocklist_name Player Some reason to list")
-- 		return
-- 	end
-- 	local name, next_pos = self:GetArgs(args, 1)
-- 	name = name:gsub("^%l", string.upper)
-- 	if next_pos == 1e9 then
-- 		self:Print("ERROR: you gave only a name, give name and reason to list.")
-- 		self:Print("e.g: /blocklist_name Player Some reason to list")
-- 		return
-- 	end
-- 	local reason = args:sub(next_pos)
-- 	local t = {
-- 		name = name,
-- 		reason = reason
-- 	}
-- 	self:add_to_ubl(t)
-- end

-- function CP:slashcommand_dump_config()
-- 	self:Print('Dumping options table:')
-- 	local t = self.conf
-- 	if type(t) == "table" then
-- 		for i, v in pairs(t) do
-- 			print(i, v)
-- 		end
-- 	end
-- end

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
		self:update_pdi(unitId)
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

--=========================================================================================
-- Alert functionality
--=========================================================================================
-- function CP:create_alert()

-- 	-- Figure out if we're locked out.
-- 	if self:is_time_locked() then return end

-- 	-- Notify with the required methods.
-- 	self:play_alert_sound()

-- end

-- function CP:is_time_locked()
-- 	-- func to tell if we're time locked on alerts

-- 	local time_now = GetTime()
-- 	if self.time_since_laste == nil then
-- 		self.time_last_alert = time_now
-- 		return true
-- 	end
-- 	print('time_now = ' .. time_now)
-- 	print('Time of last alert = ' .. self.time_last_alert)
-- 	local time_since_last = time_now - self.time_last_alert
-- 	print('Time since last alert = ' .. time_since_last)
-- 	-- print('grace period = ', db.grace_period_s)
-- 	if time_since_last < self.conf.grace_period_s then
-- 		print('locked out of alert')
-- 		return true
-- 	end

-- 	-- else set the new time and return false
-- 	self.time_last_alert = time_now
-- 	return false
-- end

-- function CP:play_alert_sound()
-- 	self:Print('playing alert')
-- 	-- if not db.b_play_alert_sound then return end
-- 	local sound_file = LSM:Fetch('sound', self.conf.alert_sound)
-- 	PlaySoundFile(sound_file)
-- end


if cp.debug then CP:Print("Finished parsing core.lua.") end
