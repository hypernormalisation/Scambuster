-- This module contains a test list for debugging purposes.

local golemagg_list = {
    [0] = {
        last_known_name = "TestName",
        last_known_guid = "Player-GDSAKG-53295G",
        reason = "Raid Scame",
        evidence = "some_other_url",
        previous_aliases = {
            SomeOtherName = "Player-GNFDSA-2153FSA",
        },
    }
}

local my_test_bl = {
    provider = "Golemagg EU",
    description = "Golemagg EU Discord",
    url = "some_url",
    data = {
        Golemagg = golemagg_list
    }
}


local CP = LibStub("AceAddon-3.0"):GetAddon("CutPurse")
CP.RegisterCallback(
    CP, "CUTPURSE_LIST_CONSTRUCTION",
    function() CP:register_curated_list(my_test_bl) end
)

-- local f = CreateFrame("Frame", nil)
-- f:RegisterEvent("ADDON_LOADED")
-- local load_list = function(self, event, addon_name)
--     if addon_name ~= "CutPurse" then return end
--     CP = LibStub("AceAddon-3.0"):GetAddon("CutPurse")
--     CP:register_curated_list(my_test_bl)
--     f:UnregisterAllEvents()
--     f:SetScript("OnEvent", nil)
-- end

-- f:SetScript("OnEvent", load_list)