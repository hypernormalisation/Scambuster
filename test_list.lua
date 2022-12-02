local addon_name, cp = ...
if not cp.add_test_list then return end

-- This module contains a test list for debugging purposes.
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
local test_bl_1 = {
    name = "Golemagg EU Discord Blocklist",
    provider = "Golemagg EU",
    description = "Golemagg EU Discord",
    url = "some_url",
    realm_data = {
        Golemagg = golemagg_list
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
    }
}
local test_bl_2 = {
    name = "Orcs Anonymous Blocklist",
    provider = "ZugZug",
    description = "List of orcs who didn't zug.",
    url = "zug_url",
    realm_data = {
        Golemagg = golemagg_list2
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
