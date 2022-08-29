local addon_name, cb = ...
CBL = LibStub("AceAddon-3.0"):GetAddon(addon_name)

local golemagg_bl = {
    ["Playera"] = {
        reason = "Test: stole all the gold from a GDKP.",
        evidence = "https://discord.com/channels/610036506974748700/1011016570467790979/1011657792651788289",
    },
}

-- The Golemagg EU discord blocklist.
CBL.bl_golemagg_disc = {
    provider = "Golemagg EU Discord",
    desc = "List of scammers curated by the mod team at the Golemagg EU discord.",
    provider_url = "https://discord.gg/SM2u5FUr2C",
    provider_bl_channel = "https://discord.com/channels/610036506974748700/1011016570467790979",
    realms = {
        Golemagg = golemagg_bl
    },
}
