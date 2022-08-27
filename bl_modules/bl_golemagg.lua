local addon_name, cb = ...
CBL = LibStub("AceAddon-3.0"):GetAddon("ClassicBlacklist")

-- The central Golemagg discord blocklist.
CBL.bl_golemagg = {
    ["Killerzenn"] = {
        reason = "Test: is a dirty rotten no good cheat.",
        evidence = "https://discord.com/channels/610036506974748700/1007955249266425946/1007984013555810354",
    },
    ["Playerb"] = {
        reason = "Test: stole all the gold from a GDKP.",
        evidence = "https://discord.com/channels/610036506974748700/1011016570467790979/1011657792651788289",
    },
}
