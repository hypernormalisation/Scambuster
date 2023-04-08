--=========================================================================================
-- This module contains test lists for debugging and development purposes.
--=========================================================================================
local addon_name, sb = ...
if not sb.add_test_list then return end
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
        -- guid = "Player-GDDFDG-535321",
        category = "dungeon",
        description = "Ninja needed an item they could not use.",
        url = "some_other_url_again.com",
    },
    [2] = {
        name = "Swedger",
        guid = "Player-4904-0079C620",
        --guid = "SOME-WRONG-GUID",
        category = "raid",
        description = "Failed to uphold the holy light and turned to shadow.",
        url = "https://wowpedia.fandom.com/wiki/Holy",
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
            },
            [1] = {
                name = "Kasuka",
                class = "DRUID",
            }
        },
        category = "trade",
        url = "https://wowpedia.fandom.com/wiki/Void",
    },
    [5] = {
        guid = "Player-4904-007D2BDC",
        category = "gdkp",
        description = "Some test description for incident with the player.",
        url = "https://wowpedia.fandom.com/wiki/Outland",
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
        category = "trade",
        url = "some_other_url_yet_again.com",
    },
    [1] = {
        name = "Thrall",
        guid = "Player-GDSAKG-53295G",
        category = "raid",
        url = "some_other_url.com",
        aliases = {"Durotan"},
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
local SB = LibStub("AceAddon-3.0"):GetAddon(addon_name)
if sb.add_test_list then
    SB.RegisterCallback(
        SB, "SCAMBUSTER_LIST_CONSTRUCTION",
        function()
            if sb.debug then
                SB:Print("DEBUG: internal test list enabled and loaded.")
            end
            SB:register_case_data(test_bl_1)
            -- SB:register_case_data(test_bl_2)
        end
    )
end
