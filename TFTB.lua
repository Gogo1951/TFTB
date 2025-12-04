local ADDON_NAME = "Thanks for the Buff"
local COLOR_NAME = "|cffFFEE58"
local COLOR_SEPARATOR = "|cffF9A825"
local COLOR_TEXT = "|cffFFFFFF"
local BRAND_PREFIX = COLOR_NAME .. ADDON_NAME .. "|r " .. COLOR_SEPARATOR .. "//|r " .. COLOR_TEXT

local TFTB = {}
local frame = CreateFrame("Frame")
TFTB.frame = frame

---------------------------------------------------------------------------
-- API Localization & Constants
---------------------------------------------------------------------------
local GetTime = GetTime
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local UnitGUID, UnitExists, UnitIsPlayer, UnitIsUnit = UnitGUID, UnitExists, UnitIsPlayer, UnitIsUnit
local GetUnitName, UnitFactionGroup, UnitName = GetUnitName, UnitFactionGroup, UnitName
local DoEmote, SendChatMessage = DoEmote, SendChatMessage
local C_Timer_After = C_Timer.After
local IsInInstance = IsInInstance
local bit_band, bit_bor = bit.band, bit.bor
local math_random = math.random

local OBJ_TYPE_NPC = COMBATLOG_OBJECT_TYPE_NPC
local OBJ_TYPE_PET = COMBATLOG_OBJECT_TYPE_PET
local OBJ_TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER
local OBJ_REACTION_FRIENDLY = COMBATLOG_OBJECT_REACTION_FRIENDLY
local OBJ_CONTROL_PLAYER = COMBATLOG_OBJECT_CONTROL_PLAYER
local OBJ_AFFIL_OUTSIDER = COMBATLOG_OBJECT_AFFILIATION_OUTSIDER

local FRIENDLY_PLAYER_MASK = bit_bor(OBJ_TYPE_PLAYER, OBJ_REACTION_FRIENDLY, OBJ_CONTROL_PLAYER)

local INSTANCE_RESTRICTED = {
    arena = true,
    party = true,
    pvp = true,
    raid = true,
}

---------------------------------------------------------------------------
-- Configuration
---------------------------------------------------------------------------

local DEFAULTS = {
    cooldownDuration = 10,
    loginDelay = 10,
    disableInInstances = false,
    randomEmotes = {
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
        "YES",
    },
    thankYouMessages = {
        "Thanks, you're the best! (="
        -- "Add any custom message you want here! (=",
    }
}

---------------------------------------------------------------------------
-- Runtime State & Tables
---------------------------------------------------------------------------
local PLAYER_GUID

local TFTB_State = {
    hasLoggedIn = false,
    inCombat = false,
    inRestrictedArea = false,
}

local sessionCooldowns = {}

---------------------------------------------------------------------------
-- Utility Functions
---------------------------------------------------------------------------
local function isOnCooldown(guid)
    local now = GetTime()
    local expiresAt = sessionCooldowns[guid]

    if expiresAt and expiresAt > now then
        return true
    end
    return false
end

local function setCooldown(guid)
    sessionCooldowns[guid] = GetTime() + (TFTB_DB.cooldownDuration or 5)
end

---------------------------------------------------------------------------
-- State Management
---------------------------------------------------------------------------
local function InitializeDB()
    if not TFTB_DB then
        TFTB_DB = {}
    end

    for k, v in pairs(DEFAULTS) do
        if TFTB_DB[k] == nil then
            TFTB_DB[k] = v
        end
    end
end

local function shouldListen()
    return not TFTB_State.inCombat and not TFTB_State.hasLoggedIn and not TFTB_State.inRestrictedArea
end

local isListening = false
local function updateCLEURegistration()
    local shouldListenNow = shouldListen()
    if shouldListenNow and not isListening then
        frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        isListening = true
    elseif not shouldListenNow and isListening then
        frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        isListening = false
    end
end

local function updateRestrictedAreaState()
    if not TFTB_DB.disableInInstances then
        TFTB_State.inRestrictedArea = false
    else
        local inInstance, instanceType = IsInInstance()
        TFTB_State.inRestrictedArea = inInstance and INSTANCE_RESTRICTED[instanceType] or false
    end
    updateCLEURegistration()
end

---------------------------------------------------------------------------
-- Event Handlers
---------------------------------------------------------------------------
function TFTB:OnCombatEvent()
    local _, subEvent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, _, _, _, _, _, _, auraType =
        CombatLogGetCurrentEventInfo()

    if subEvent ~= "SPELL_AURA_APPLIED" or auraType ~= "BUFF" then
        return
    end

    if destGUID ~= PLAYER_GUID or not sourceName then
        return
    end

    if bit_band(sourceFlags, FRIENDLY_PLAYER_MASK) ~= FRIENDLY_PLAYER_MASK then
        return
    end

    if bit_band(sourceFlags, OBJ_TYPE_NPC) ~= 0 or bit_band(sourceFlags, OBJ_TYPE_PET) ~= 0 then
        return
    end

    if bit_band(sourceFlags, OBJ_AFFIL_OUTSIDER) == 0 then
        return
    end

    if sourceGUID == PLAYER_GUID then
        return
    end

    if isOnCooldown(sourceGUID) then
        return
    end

    setCooldown(sourceGUID)

    local emotes = TFTB_DB.randomEmotes
    if emotes and #emotes > 0 then
        DoEmote(emotes[math_random(#emotes)], sourceName)
    end
end

function TFTB:OnEvent(event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        self:OnCombatEvent()
    elseif event == "PLAYER_ENTERING_WORLD" then
        PLAYER_GUID = UnitGUID("player")
        InitializeDB()

        TFTB_State.hasLoggedIn = true
        updateRestrictedAreaState()

        C_Timer_After(
            TFTB_DB.loginDelay,
            function()
                TFTB_State.hasLoggedIn = false
                updateCLEURegistration()
            end
        )
    elseif event == "PLAYER_REGEN_DISABLED" then
        TFTB_State.inCombat = true
        updateCLEURegistration()
    elseif event == "PLAYER_REGEN_ENABLED" then
        TFTB_State.inCombat = false
        updateCLEURegistration()
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        updateRestrictedAreaState()
    end
end

---------------------------------------------------------------------------
-- Frame Registration
---------------------------------------------------------------------------
frame:SetScript(
    "OnEvent",
    function(self, event, ...)
        TFTB:OnEvent(event, ...)
    end
)
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

---------------------------------------------------------------------------
-- Slash Commands
---------------------------------------------------------------------------
SLASH_THANKYOU1 = "/thankyou"
SlashCmdList.THANKYOU = function(msg)
    if not UnitExists("target") or not UnitIsPlayer("target") then
        print(BRAND_PREFIX .. "Select a player to thank.")
        return
    end

    if UnitIsUnit("target", "player") then
        print(BRAND_PREFIX .. "You can't thank yourself!")
        return
    end

    local targetName, targetRealm = UnitName("target")
    local fullName = targetName
    if targetRealm then
        fullName = targetName .. "-" .. targetRealm
    end

    local emotes = TFTB_DB.randomEmotes
    if emotes and #emotes > 0 then
        DoEmote(emotes[math_random(#emotes)], targetName)
    end

    local playerFaction = UnitFactionGroup("player")
    local targetFaction = UnitFactionGroup("target")

    if playerFaction == targetFaction then
        local msgs = TFTB_DB.thankYouMessages
        if msgs and #msgs > 0 then
            SendChatMessage(msgs[math_random(#msgs)], "WHISPER", nil, fullName)
        end
    end
end
