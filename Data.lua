local addonName, ns = ...
ns.Data = {}

---------------------------------------------------------------------------
-- Colors & Branding
---------------------------------------------------------------------------
ns.Data.COLORS = {
    TITLE = "ffd700", -- Gold
    BRAND = "00BBFF", -- Blue
    SEP = "AAAAAA", -- Gray
    TEXT = "FFFFFF", -- White

    -- Class Colors
    DRUID = "FF7D0A",
    HUNTER = "ABD473",
    MAGE = "40C7EB",
    PALADIN = "F58CBA",
    PRIEST = "FFFFFF",
    ROGUE = "FFF569",
    SHAMAN = "0070DE",
    WARLOCK = "9482C9",
    WARRIOR = "C79C6E",
    MONK = "00FF96",
    DEATHKNIGHT = "C41F3B",
    DEMONHUNTER = "A330C9",
    EVOKER = "33937F"
}

ns.Data.SAFETY_PAUSE = 3
ns.Data.MACRO_NAME = "- Thank"
ns.Data.ADDON_TITLE = "Thanks for the Buff"

---------------------------------------------------------------------------
-- Spell List
---------------------------------------------------------------------------
ns.Data.SPELL_LIST = {
    ["DEATHKNIGHT"] = {
        {name = "Hysteria", ids = {49016}}
    },
    ["DRUID"] = {
        {name = "Innervate", ids = {29166}},
        {name = "Rebirth", ids = {20484, 20739, 20742, 20747, 20748, 26994, 48477}}
    },
    ["HUNTER"] = {
        {name = "Master's Call", ids = {53271}},
        {name = "Misdirection", ids = {34477}},
        {name = "Roar of Sacrifice", ids = {53480}}
    },
    ["MAGE"] = {
        {name = "Focus Magic", ids = {54646}}
    },
    ["PALADIN"] = {
        {name = "Divine Intervention", ids = {19752}},
        {name = "Hand of Freedom", ids = {1044}},
        {name = "Hand of Protection", ids = {1022, 5599, 10278}},
        {name = "Hand of Sacrifice", ids = {6940, 20729, 27147, 27148}},
        {name = "Hand of Salvation", ids = {1038}},
        {name = "Lay on Hands", ids = {633, 2800, 10310, 27154, 48788}}
    },
    ["PRIEST"] = {
        {name = "Fear Ward", ids = {6346}},
        {name = "Guardian Spirit", ids = {47788}},
        {name = "Pain Suppression", ids = {33206}},
        {name = "Power Infusion", ids = {10060}}
    },
    ["ROGUE"] = {
        {name = "Tricks of the Trade", ids = {57934}}
    },
    ["SHAMAN"] = {
        {name = "Water Walking", ids = {546}},
        {name = "Water Breathing", ids = {131}},
        {name = "Bloodlust", ids = {2825}},
        {name = "Heroism", ids = {32182}}
    },
    ["WARLOCK"] = {
        {name = "Soulstone", ids = {20707, 20710, 20712, 20714, 20716, 20718, 47883}},
        {name = "Unending Breath", ids = {5697}}
    },
    ["WARRIOR"] = {
        {name = "Intervene", ids = {3411}},
        {name = "Vigilance", ids = {50720}}
    }
}

-- Original 12 Emotes
ns.Data.EMOTES_LIST = {
    "CHEER",
    "DRINK",
    "FLEX",
    "GRIN",
    "HIGHFIVE",
    "PRAISE",
    "SALUTE",
    "SMILE",
    "THANK",
    "WHOA",
    "WINK",
    "YES"
}

ns.Data.EMOTE_DESCRIPTIONS = {
    ["CHEER"] = "You cheer at <Target>.",
    ["DRINK"] = "You raise a drink to <Target>.",
    ["FLEX"] = "You flex at <Target>.",
    ["GRIN"] = "You grin wickedly at <Target>.",
    ["HIGHFIVE"] = "You high-five <Target>.",
    ["PRAISE"] = "You praise <Target>.",
    ["SALUTE"] = "You salute <Target> with respect.",
    ["SMILE"] = "You smile at <Target>.",
    ["THANK"] = "You thank <Target>.",
    ["WHOA"] = "You look at <Target> and exclaim 'Whoa!'",
    ["WINK"] = "You wink at <Target>.",
    ["YES"] = "You nod at <Target>."
}

local function GetDefaultEmotes()
    local e = {}
    for _, v in ipairs(ns.Data.EMOTES_LIST) do
        e[v] = true
    end
    return e
end

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------
ns.Data.DEFAULTS = {
    profile = {
        global = {
            enabled = true,
            welcomeMessage = true
        },
        strangers = {
            enabled = true,
            messaging = "NONE",
            cooldown = 3,
            emotesEnabled = true,
            emotes = GetDefaultEmotes()
        },
        slash = {
            createMacro = true,
            message = "Thanks, you're the best! (=",
            emotes = GetDefaultEmotes()
        },
        groupBuffs = {
            messaging = "PRINT",
            watchedBuffs = {}
        }
    }
}