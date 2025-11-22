local ADDON_NAME      = "Thanks for the Buff"
local COLOR_NAME      = "|cffFFEE58"
local COLOR_SEPARATOR = "|cffF9A825"
local COLOR_TEXT      = "|cffFFFFFF"

local BRAND_PREFIX = COLOR_NAME .. ADDON_NAME .. "|r " .. COLOR_SEPARATOR .. "//|r " .. COLOR_TEXT

local TFTB = {}
local frame = CreateFrame("Frame")
TFTB.frame = frame

local GetTime, CombatLogGetCurrentEventInfo = GetTime, CombatLogGetCurrentEventInfo
local UnitGUID, UnitExists, UnitIsPlayer, UnitFactionGroup, GetUnitName, UnitIsUnit =
    UnitGUID,
    UnitExists,
    UnitIsPlayer,
    UnitFactionGroup,
    GetUnitName,
    UnitIsUnit
local DoEmote, SendChatMessage, C_Timer_After, NewTicker = DoEmote, SendChatMessage, C_Timer.After, C_Timer.NewTicker
local IsInInstance = IsInInstance
local bit_band, bit_bor, math_random = bit.band, bit.bor, math.random

local OBJ_TYPE_NPC, OBJ_TYPE_PET = COMBATLOG_OBJECT_TYPE_NPC, COMBATLOG_OBJECT_TYPE_PET
local OBJ_TYPE_PLAYER, OBJ_REACTION_FRIENDLY, OBJ_CONTROL_PLAYER =
    COMBATLOG_OBJECT_TYPE_PLAYER,
    COMBATLOG_OBJECT_REACTION_FRIENDLY,
    COMBATLOG_OBJECT_CONTROL_PLAYER
local OBJ_AFFIL_OUTSIDER = COMBATLOG_OBJECT_AFFILIATION_OUTSIDER

local FRIENDLY_MASK = bit_bor(OBJ_TYPE_PLAYER, OBJ_REACTION_FRIENDLY, OBJ_CONTROL_PLAYER)

local INSTANCE_RESTRICTED = {
    arena = true,
    party = true,
    pvp = true,
    raid = true,
}

local PLAYER_GUID

TFTB.state = {
    inCombat = false,
    hasLoggedIn = false,
    inRestrictedArea = false,
}

TFTB.config = {
    cooldownDuration = 5,
    loginDelay = 5,
    disableInInstances = false,
    cooldownCleanupInterval = 600,
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
        -- "Your Custom Message Here!",
    }
}

TFTB.cooldowns = {}

local function clearExpiredCooldowns(now)
    for guid, expiresAt in pairs(TFTB.cooldowns) do
        if expiresAt < now then
            TFTB.cooldowns[guid] = nil
        end
    end
end

local function isOnCooldown(guid, now)
    local expiresAt = TFTB.cooldowns[guid]
    return expiresAt ~= nil and expiresAt > now
end

local function setCooldown(guid, now)
    TFTB.cooldowns[guid] = now + TFTB.config.cooldownDuration
end

local function shouldListen()
    return not TFTB.state.inCombat and not TFTB.state.hasLoggedIn and not TFTB.state.inRestrictedArea
end

local listening = false
local function updateCLEURegistration()
    local shouldListenNow = shouldListen()
    if shouldListenNow and not listening then
        frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        listening = true
    elseif not shouldListenNow and listening then
        frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        listening = false
    end
end

local function updateRestrictedAreaState()
    if not TFTB.config.disableInInstances then
        TFTB.state.inRestrictedArea = false
    else
        local inInstance, instanceType = IsInInstance()
        TFTB.state.inRestrictedArea = inInstance and INSTANCE_RESTRICTED[instanceType] or false
    end
    updateCLEURegistration()
end

local function isSuppressedByState()
    return TFTB.state.hasLoggedIn or TFTB.state.inCombat or TFTB.state.inRestrictedArea
end

function TFTB:OnCombatEvent()
    local _, subEvent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, _, _, _, _, _, _, auraType =
        CombatLogGetCurrentEventInfo()

    if subEvent ~= "SPELL_AURA_APPLIED" or auraType ~= "BUFF" then
        return
    end

    if isSuppressedByState() then
        return
    end

    if destGUID ~= PLAYER_GUID or not sourceName then
        return
    end

    if bit_band(sourceFlags, OBJ_TYPE_NPC) ~= 0 or bit_band(sourceFlags, OBJ_TYPE_PET) ~= 0 then
        return
    end

    if bit_band(sourceFlags, FRIENDLY_MASK) ~= FRIENDLY_MASK then
        return
    end

    if bit_band(sourceFlags, OBJ_AFFIL_OUTSIDER) == 0 then
        return
    end

    if sourceGUID == PLAYER_GUID then
        return
    end

    local now = GetTime()
    if isOnCooldown(sourceGUID, now) then
        return
    end

    setCooldown(sourceGUID, now)

    local emote = TFTB.config.randomEmotes[math_random(#TFTB.config.randomEmotes)]
    DoEmote(emote, sourceName)
end

function TFTB:OnEvent(event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        self:OnCombatEvent()
    elseif event == "PLAYER_REGEN_DISABLED" then
        self.state.inCombat = true
        updateCLEURegistration()
    elseif event == "PLAYER_REGEN_ENABLED" then
        self.state.inCombat = false
        updateCLEURegistration()
    elseif event == "PLAYER_ENTERING_WORLD" then
        PLAYER_GUID = UnitGUID("player")
        self.state.hasLoggedIn = true
        updateRestrictedAreaState()

        C_Timer_After(
            self.config.loginDelay,
            function()
                TFTB.state.hasLoggedIn = false
                updateCLEURegistration()
            end
        )
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        updateRestrictedAreaState()
    end
end

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

frame:SetScript(
    "OnEvent",
    function(_, event, ...)
        TFTB:OnEvent(event, ...)
    end
)

NewTicker(
    TFTB.config.cooldownCleanupInterval,
    function()
        clearExpiredCooldowns(GetTime())
    end
)

------------------------------------------------------------
-- /thankyou slash command
------------------------------------------------------------

local function isValidPlayer(unit)
    return UnitExists(unit) and UnitIsPlayer(unit)
end

local function cheerAndThankTarget()
    if not UnitExists("target") then
        print(BRAND_PREFIX .. "No target selected. Please select a player to thank.")
        return
    end

    if not isValidPlayer("target") then
        print(BRAND_PREFIX .. "Invalid target. Please select a player to thank.")
        return
    end

    if UnitIsUnit("target", "player") then
        print(BRAND_PREFIX .. "Invalid target. It's weird you want to thank yourself...")
        return
    end

    local targetName = GetUnitName("target", true)
    if not targetName then
        print(BRAND_PREFIX .. "Could not determine target name.")
        return
    end

    local emote = TFTB.config.randomEmotes[math_random(#TFTB.config.randomEmotes)]
    local message = TFTB.config.thankYouMessages[math_random(#TFTB.config.thankYouMessages)]

    DoEmote(emote, targetName)

    local playerFaction = UnitFactionGroup("player")
    local targetFaction = UnitFactionGroup("target")
    if playerFaction and targetFaction and playerFaction == targetFaction then
        SendChatMessage(message, "WHISPER", nil, targetName)
    end
end

SLASH_THANKYOU1 = "/thankyou"
SlashCmdList.THANKYOU = cheerAndThankTarget
