--=========================================================================================
-- This module contains test lists for debugging and development purposes.
--=========================================================================================
local _, cp = ...
if not cp.add_test_list then return end
local realm = GetRealmName()

local case_data_1 = {
    [0] = {
        name = "Thrall",
        guid = "Player-GDSAKG-53295G",
        category = "gdkp",
        description = "Stole all the gold from a gdkp.",
        url = "some_other_url.com",
        aliases = {"Raegar"},
    },
    [1] = {
        name = "Arthas",
        guid = "Player-GDDFDG-535321",
        category = "dungeon",
        description = "Ninja needed an item they could not use.",
        url = "some_other_url_again.com",
    },
    [2] = {
        name = "Swedger",
        -- guid = "Player-4904-0079C620",
        --guid = "SOME-WRONG-GUID",
        category = "raid",
        description = "Some description.",
        url = "some_other_url.com",
    },
    [3] = {
        name = "Swodger",
        category = "raid",
        description = "Some description for incident with Swodger.",
        url = "yet_another_url.com",
    },
    [4] = {
        players = {
            [0] = {
                name = "Swedger",
                guid = "Player-4904-0079C620",
            },
            [1] = {
                name = "Accomplice",
                class = "DRUID",
            }
        },
        category = "trade",
        url = "some_url_with_two_players.com",
    },
}

local test_bl_1 = {
    name = "Golemagg Discord Blocklist",
    provider = "Golemagg Discord",
    description = "Realm discord for the Golemagg EU realm.",
    url = "some_url",
    realm_data = {
        [realm] = case_data_1,
    }
}

-- Now another list with coincidences to test cross-list case-building
local case_data_2 = {
    [0] = {
        name = "Arthas",
        guid = "Player-GDDFDG-535321",
        reason = "Trade Scam",
        url = "some_other_url_yet_again.com",
    },
    [1] = {
        name = "Thrall",
        guid = "Player-GDSAKG-53295G",
        reason = "Raid Scam",
        url = "some_other_url.com",
        aliases = {"Durotan"},
        previous_guids = {"Player-GJNGDS-2532FHG"},
    },
    [2] = {
        name = "Swedger",
        category = "dungeon",
        description = "Needed items for shards.",
        url = "url_to_evidence_here.com",
    }
}
local test_bl_2 = {
    name = "Orcs Anonymous Blocklist",
    provider = "ZugZug",
    description = "List of orcs who didn't zug.",
    url = "zug_url.com/nozuggers",
    realm_data = {
        [realm] = case_data_2,
    }
}

-- Register both the lists with Cutpurse, emulating extension addons.
local CP = LibStub("AceAddon-3.0"):GetAddon("Cutpurse")
if cp.add_test_list then
    CP.RegisterCallback(
        CP, "CUTPURSE_LIST_CONSTRUCTION",
        function()
            CP:Print("DEBUG: Cutpurse internal test list enabled and loaded.")
            CP:register_case_data(test_bl_1)
            -- CP:register_case_data(test_bl_2)
        end
    )
end