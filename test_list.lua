--=========================================================================================
-- This module contains test lists for debugging and development purposes.
--=========================================================================================
local addon_name, cp = ...
if not cp.add_test_list then return end

local case_data_1 = {
    [0] = {
        name = "Thrall",
        guid = "Player-GDSAKG-53295G",
        reason = "Raid Scam",
        description = "Stole all the gold from a gdkp.",
        evidence = "some_other_url",
        aliases = {"Raegar"},
    },
    [1] = {
        name = "Arthas",
        guid = "Player-GDDFDG-535321",
        reason = "Dungeon Scam",
        description = "Ninja needed an item they could not use.",
        evidence = "some_other_url_again",
    },
    [2] = {
        name = "Swedger",
        guid = "Player-4904-0079C620",
        --guid = "SOME-WRONG-GUID",
        reason = "Raid Scam",
        description = "",
        evidence = "some_other_url",
    },
}
local test_bl_1 = {
    name = "Golemagg EU Discord Blocklist",
    provider = "Golemagg EU Discord",
    description = "Realm discord for the Golemagg EU realm.",
    url = "some_url",
    realm_data = {
        Golemagg = case_data_1,
        ["Classic PTR Realm 1"] = case_data_1,
    }
}

-- Now another list with coincidences to test cross-list case-building
local case_data_2 = {
    [0] = {
        name = "Arthas",
        guid = "Player-GDDFDG-535321",
        reason = "Trade Scam",
        evidence = "some_other_url_yet_again",
    },
    [1] = {
        name = "Thrall",
        guid = "Player-GDSAKG-53295G",
        reason = "Raid Scam",
        evidence = "some_other_url",
        aliases = {"Durotan"},
        previous_guids = {"Player-GJNGDS-2532FHG"},
    },
    [2] = {
        name = "Swedger",
        reason = "Dungeon Scam",
        evidence = "url_to_evidence_here.com",
    }
}
local test_bl_2 = {
    name = "Orcs Anonymous Blocklist",
    provider = "ZugZug",
    description = "List of orcs who didn't zug.",
    url = "zug_url",
    realm_data = {
        Golemagg = case_data_2,
        ["Classic PTR Realm 1"] = case_data_2,
    }
}

-- Register both the lists with Cutpurse, emulating extension addons.
local CP = LibStub("AceAddon-3.0"):GetAddon("Cutpurse")
CP.RegisterCallback(
    CP, "CUTPURSE_LIST_CONSTRUCTION",
    function()
        CP:register_curated_list(test_bl_1)
        CP:register_curated_list(test_bl_2)
    end
)
