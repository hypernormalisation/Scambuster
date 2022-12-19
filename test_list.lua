--=========================================================================================
-- This module contains test lists for debugging and development purposes.
--=========================================================================================
local addon_name, cp = ...
if not cp.add_test_list then return end

local golemagg_list = {
    [0] = {
        last_known_name = "Thrall",
        last_known_guid = "Player-GDSAKG-53295G",
        reason = "Raid Scam",
        evidence = "some_other_url",
        previous_aliases = {
            Raegar = "Player-GNFDSA-2153FSA",
        },
    },
    [1] = {
        last_known_name = "Arthas",
        last_known_guid = "Player-GDDFDG-535321",
        reason = "Dungeon Scam",
        evidence = "some_other_url_again",
    },
}

local ptr_list_1 = {
    [2] = {
        last_known_name = "Swedger",
        last_known_guid = "Player-4904-0079C620",
        -- last_known_guid = "SOME-WRONG-GUID",
        reason = "Raid Scam",
        evidence = "some_other_url",
    },
}
for k, v in pairs(golemagg_list) do ptr_list_1[k] = v end

local test_bl_1 = {
    name = "Golemagg EU Discord Blocklist",
    provider = "Golemagg EU Discord",
    description = "Realm discord for the Golemagg EU realm.",
    url = "some_url",
    realm_data = {
        Golemagg = golemagg_list,
        ["Classic PTR Realm 1"] = ptr_list_1,
    }
}

-- Now another list with coincidences to test case-building
local golemagg_list2 = {
    [0] = {
        last_known_name = "Arthas",
        last_known_guid = "Player-GDDFDG-535321",
        reason = "Trade Scam",
        evidence = "some_other_url_yet_again",
    },
    [1] = {
        last_known_name = "Thrall",
        last_known_guid = "Player-GDSAKG-53295G",
        reason = "Raid Scam",
        evidence = "some_other_url",
        previous_aliases = {
            Durotan = "Player-GJNGDS-2532FHG",
        },
    },
    [2] = {
        last_known_name = "Swedger",
        reason = "Dungeon Scam",
        evidence = "url_to_evidence_here.com",
        -- last_known_guid = "another-wrong-guid",
        -- last_known_guid = "Player-4904-0079C620",
    }
}
local test_bl_2 = {
    name = "Orcs Anonymous Blocklist",
    provider = "ZugZug",
    description = "List of orcs who didn't zug.",
    url = "zug_url",
    realm_data = {
        Golemagg = golemagg_list2,
        ["Classic PTR Realm 1"] = golemagg_list,
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
