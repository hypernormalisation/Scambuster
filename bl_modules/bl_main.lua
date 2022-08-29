local addon_name, cb = ...
CBL = LibStub("AceAddon-3.0"):GetAddon(addon_name)
CBL.providers = {
    [CBL.bl_golemagg_disc.provider] = CBL.bl_golemagg_disc
}
