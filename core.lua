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
	-- self:RegisterChatCommand("test1", "test1")
	-- self:RegisterChatCommand("blocklist_target", "slashcommand_blocklist_target")
	-- self:RegisterChatCommand("blocklist_name", "slashcommand_blocklist_name")
	-- self:RegisterChatCommand("soundcheck", "slashcommand_soundcheck")
	-- self:RegisterChatCommand("dump_config", "slashcommand_dump_config")

	self.unprocessed_curated_lists = {}
	self.ucl_counter = 0
	self.unprocessed_user_lists = {}
	self.curated_db_local = {}
	self.curated_db_global = {}

	if self.db.global.provider_settings == nil then
		self.db.global.provider_settings = {}
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
	self.unprocessed_curated_lists[self.ucl_counter] = data
end

function CP:register_user_list(data)
end

function CP:construct_dbs()
	-- This function builds the relevant dbs
	self:Print("GOING TO CONSTRUCT LISTS NOW")
	local pdb = self:get_provider_settings()
	local ucl = self.unprocessed_curated_lists
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
		target[key] = {
			guid = case_data.last_known_guid,
			previous_aliases = case_data.previous_aliases,
			reports = {
				provider = {
					reason = case_data.reason,
					evidence = case_data.evidence,
				}
			}
		}
	-- If there is already data, add the relevant fields
	else
		local current_data = target[key]
		-- First aliases
		for alias, old_guid in pairs(case_data.previous_aliases) do
			if target[alias] == nil then
				target[alias] = old_guid
			elseif old_guid ~= 0 then
				current_data.previous_aliases[alias] = old_guid
			end
		end
		-- Now report data
		current_data.reports[list_name] = {
			reason = case_data.reason,
			evidence = case_data.evidence
		}
	end
end



--=========================================================================================
-- Scanning and checking helper funcs.
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

	-- First check against curated lists
	local result = self:check_against_CLs()
	if result then
		self:raise_alert("curated")
		return
	end
	-- Then check against user lists
	result = self:check_against_ULs()
	if result then
		self:raise_alert("user")
		return
	end
end

function CP:check_against_CLs()
	-- This function checks against the curated lists.
	local name, realm = select(6, GetPlayerInfoByGUID(self.current_unit_guid))
	if realm == nil then
		realm = self.realm_name
	end
	self.current_unit_name = name
	self.current_realm_name = realm
	
	-- We make provisions for either just the name being recorded, or both the name
	-- and the guid being recorded.

end

function CP:check_against_ULs()
	-- This function checks against the user lists.
end

function CP:raise_alert(list_type)
	-- First update the player dynamic info.
	-- self:update_pdi(scan_context)
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
	if not self:is_unit_eligible("target") then return end
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

function CP:test1()
	-- print('running')
	-- local invite_guid = GetNextPendingInviteConfirmation()
	-- RespondToInviteConfirmation(invite_guid, false)
	-- local f = _G["StaticPopup1Button1"]
	-- self:Print(f.GetName())
	-- f:Click()
end

--=========================================================================================
-- funcs to load info
--=========================================================================================
-- function CP:load_ubl()
-- 	-- Loads the user blocklist data.
-- 	if self.db.realm.user_blacklist == nil then
-- 		self.db.realm.user_blacklist = {}
-- 	end
-- 	self.ubl = self.db.realm.user_blacklist -- shorthand
-- end

-- function CP:load_dynamic_info()
-- 	-- Sets up the dynamic information on scammers the player's client 
-- 	-- has gathered from the realm db.
-- 	if self.db.realm.player_dynamic_info == nil then
-- 		self.db.realm.player_dynamic_info = {}
-- 	end
-- 	-- A shorthand for this realm's dynamic player data.
-- 	self.pdi = self.db.realm.player_dynamic_info
-- end

-- function CP:get_valid_providers()
-- 	-- Verifies the format of providers and gets any valid realm data
-- 	self.valid_providers = {}
-- 	for provider, data in pairs(self.providers) do
-- 		if data == nil or data.realms == nil then
-- 			self:Print(
-- 				string.format("Provider %s is not properly configured!")
-- 			)
-- 		else
-- 			local r = data.realms[self.realm_name]
-- 			if r ~= nil and next(r) ~= nil then
-- 				self.valid_providers[provider] = r
-- 			end
-- 		end
-- 	end
-- end

-- function CP:load_cbl()
-- 	-- Constructs the central blocklist from the valid providers.
-- 	self.cbl = {}
-- 	if self.valid_providers == nil or next(self.valid_providers) == nil then
-- 		self:Print(string.format("INFO: no central realm data exists on %s.", self.realm_name))
-- 		return
-- 	end
-- 	self.has_cbl = true

-- 	-- TO-DO: options for enabled/disabled providers, handle provider precedence here.

-- 	-- Assemble cbl, append provider to info.
-- 	for provider, data in pairs(self.valid_providers) do
-- 		for player, pdata in pairs(data) do
-- 			self.cbl[player] = {
-- 				provider = provider,
-- 				reason = pdata.reason,
-- 				evidence = pdata.evidence,
-- 				ignore = false, -- TO-DO: load this from settings
-- 			}
-- 		end
-- 	end
-- end

--=========================================================================================
-- Register slashcommands
--=========================================================================================
function CP:slashcommand_options(input, editbox)
	local ACD = LibStub("AceConfigDialog-3.0")
	ACD:Open(addon_name.."_Options")
end

-- function CP:slashcommand_soundcheck()
-- 	local sound_file = LSM:Fetch('sound', self.conf.alert_sound)
-- 	PlaySoundFile(sound_file)
-- end

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

-- function CP:slashcommand_testbl()
-- 	self:Print(self.cbl)
-- 	local t = self.cbl
-- 	for name, bl_data in pairs(t) do
-- 		self:Print("cbl:")
-- 		print('------------------------')
-- 		self:Print(name, bl_data)
-- 		for k, v in pairs(bl_data) do
-- 			self:Print(k, v)
-- 		end
-- 	end
-- 	local t = self.ubl
-- 	for name, bl_data in pairs(t) do
-- 		print('------------------------')
-- 		self:Print("ubl:")
-- 		self:Print(name, bl_data)
-- 		for k, v in pairs(bl_data) do
-- 			self:Print(k, v)
-- 		end
-- 	end
-- 	self:Print(self.pdi)
-- 	local t = self.pdi
-- 	for name, bl_data in pairs(t) do
-- 		print('------------------------')
-- 		self:Print("pdi:")
-- 		self:Print(name, bl_data)
-- 		for k, v in pairs(bl_data) do
-- 			self:Print(k, v)
-- 		end
-- 	end
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
function CP:update_pdi(unitId)
	-- Function to update the player dynamic information table.
	-- when we encounter a scammer in-game and can access their information.
	-- unitId is the unit token e.g. "target", "mouseover", "partyN" etc
	local name = UnitName(unitId)
	if name == nil then
		self:Print("ERROR: name from API not valid.")
		return
	end
	if self.pdi[name] == nil then
		self.pdi[name] = {}
	end
	local last_seen = self.pdi[name]["last_seen"]
	-- -- Only update non last_seen data once every 10 mins
	-- if last_seen ~= nil and (time() - last_seen < 600) then
	-- 	self:Print('locking update, too recent')
	-- 	self.pdi[name]["last_seen"] = time()
	-- 	return
	-- end

	local class = UnitClass(unitId)
	local level = UnitLevel(unitId)
	local race = UnitRace(unitId)
	local guild = GetGuildInfo(unitId)
	local guid = UnitGUID(unitId)
	if self.pdi[name] == nil then
		self:Print(string.format('Registering new info for %s', name))
	else
		self:Print(string.format('Updating info for %s', name))
	end
	self.pdi[name] = {
		class = class,
		level = level,
		guild = guild,
		race = race,
		guid = guid,
		last_seen = time()
	}
end

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

-- function CP:check_against_ubl(player_name)
-- 	if self.ubl[player_name] == nil then
-- 		return false
-- 	end
-- 	return true
-- end

-- function CP:check_against_cbl(player_name)
-- 	if self.cbl[player_name] == nil then
-- 		return false
-- 	end
-- 	return true
-- end

-- function CP:check_against_bls(player_name)
-- 	return self:check_against_ubl(player_name) or self:check_against_cbl(player_name)
-- end

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
