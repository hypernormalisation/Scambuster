local addon_name, cp = ...
if not cp.add_test_list then return end

-- This module contains a test list for debugging purposes.
local golemagg_list = {
    [0] = {
        last_known_name = "TestName",
        last_known_guid = "Player-GDSAKG-53295G",
        reason = "Raid Scam",
        evidence = "some_other_url",
        previous_aliases = {
            SomeOtherName = "Player-GNFDSA-2153FSA",
        },
    }
}

local my_test_bl = {
    name = "Golemagg EU Discord Blocklist",
    provider = "Golemagg EU",
    description = "Golemagg EU Discord",
    url = "some_url",
    realm_data = {
        Golemagg = golemagg_list
    }
}


local CP = LibStub("AceAddon-3.0"):GetAddon("Cutpurse")
CP.RegisterCallback(
    CP, "CUTPURSE_LIST_CONSTRUCTION",
    function() CP:register_curated_list(my_test_bl) end
)
