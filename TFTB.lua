local addonName, ns = ...

---------------------------------------------------------------------------
-- Configuration
---------------------------------------------------------------------------
local CONFIG = {
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
        -- "Custom Message Here!",
    }
}

---------------------------------------------------------------------------
-- Constants & Setup
---------------------------------------------------------------------------
local ADDON_TITLE = "Thanks for the Buff"
local HEX_PRIMARY = "FFEE58"
local HEX_ACCENT = "F9A825"
local HEX_TEXT = "FFFFFF"

local function Wrap(text, colorHex)
    return "|cff" .. colorHex .. text .. "|r"
end

local BRAND_PREFIX = Wrap(ADDON_TITLE, HEX_PRIMARY) .. " " .. Wrap("//", HEX_ACCENT) .. " "

local bit_band = bit.band or bit32.band
local bit_bor = bit.bor or bit32.bor

local frame = CreateFrame("Frame")

---------------------------------------------------------------------------
-- API Localization
---------------------------------------------------------------------------
local GetTime = GetTime
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local UnitGUID, UnitExists, UnitIsPlayer, UnitIsUnit = UnitGUID, UnitExists, UnitIsPlayer, UnitIsUnit
local GetUnitName, UnitFactionGroup = GetUnitName, UnitFactionGroup
local DoEmote, SendChatMessage = DoEmote, SendChatMessage
local C_Timer_After = C_Timer.After
local IsInInstance = IsInInstance
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
    raid = true
}

---------------------------------------------------------------------------
-- Runtime State
---------------------------------------------------------------------------
local PLAYER_GUID = nil
local isListening = false
local sessionCooldowns = {}

local TFTB_State = {
    hasLoggedIn = false,
    inCombat = false,
    inRestrictedArea = false
}

---------------------------------------------------------------------------
-- Helper Functions
---------------------------------------------------------------------------
local function isOnCooldown(guid)
    local now = GetTime()
    local expiresAt = sessionCooldowns[guid]
    return expiresAt and expiresAt > now
end

local function setCooldown(guid)
    sessionCooldowns[guid] = GetTime() + (CONFIG.cooldownDuration or 5)
end

local function shouldListen()
    return not TFTB_State.inCombat and not TFTB_State.hasLoggedIn and not TFTB_State.inRestrictedArea
end

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
    if not CONFIG.disableInInstances then
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
local function OnCombatEvent()
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

    local emotes = CONFIG.randomEmotes
    if emotes and #emotes > 0 then
        DoEmote(emotes[math_random(#emotes)], sourceName)
    end
end

local function OnEvent(self, event, arg1, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatEvent()
    elseif event == "PLAYER_ENTERING_WORLD" then
        PLAYER_GUID = UnitGUID("player")
        TFTB_State.hasLoggedIn = true
        updateRestrictedAreaState()

        C_Timer_After(
            CONFIG.loginDelay,
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
frame:SetScript("OnEvent", OnEvent)
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
        print(BRAND_PREFIX .. Wrap("Select a player to thank.", HEX_TEXT))
        return
    end

    if UnitIsUnit("target", "player") then
        print(BRAND_PREFIX .. Wrap("You can't thank yourself!", HEX_TEXT))
        return
    end

    local fullName = GetUnitName("target", true)
    local targetName = GetUnitName("target", false)

    local emotes = CONFIG.randomEmotes
    if emotes and #emotes > 0 then
        DoEmote(emotes[math_random(#emotes)], targetName)
    end

    local playerFaction = UnitFactionGroup("player")
    local targetFaction = UnitFactionGroup("target")

    if playerFaction == targetFaction then
        local msgs = CONFIG.thankYouMessages
        if msgs and #msgs > 0 then
            SendChatMessage(msgs[math_random(#msgs)], "WHISPER", nil, fullName)
        end
    end
end
