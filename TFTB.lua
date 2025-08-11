local TFTB, frame = {}, CreateFrame("Frame")

local GetTime, CombatLogGetCurrentEventInfo = GetTime, CombatLogGetCurrentEventInfo
local UnitGUID, UnitExists, UnitIsPlayer, UnitFactionGroup, GetUnitName =
    UnitGUID,
    UnitExists,
    UnitIsPlayer,
    UnitFactionGroup,
    GetUnitName
local DoEmote, SendChatMessage, C_Timer_After, NewTicker = DoEmote, SendChatMessage, C_Timer.After, C_Timer.NewTicker
local IsInInstance = IsInInstance
local bit_band, math_random = bit.band, math.random

local OBJ_TYPE_NPC, OBJ_TYPE_PET = COMBATLOG_OBJECT_TYPE_NPC, COMBATLOG_OBJECT_TYPE_PET
local OBJ_TYPE_PLAYER, OBJ_REACTION_FRIENDLY, OBJ_CONTROL_PLAYER =
    COMBATLOG_OBJECT_TYPE_PLAYER,
    COMBATLOG_OBJECT_REACTION_FRIENDLY,
    COMBATLOG_OBJECT_CONTROL_PLAYER
local OBJ_AFFIL_OUTSIDER = COMBATLOG_OBJECT_AFFILIATION_OUTSIDER
local FRIENDLY_MASK = OBJ_TYPE_PLAYER + OBJ_REACTION_FRIENDLY + OBJ_CONTROL_PLAYER

local PLAYER_GUID
TFTB.state = {inCombat = false, hasLoggedIn = false, inRestrictedArea = false}
TFTB.config = {
    cooldownDuration = 5,
    loginDelay = 5,
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
        "YES"
    },
    thankYouMessages = {
        "Thanks, you're the best! (="
        -- "Your Custom Message Here!",
    }
}
TFTB.cooldowns = {}

local function clearExpiredCooldowns(now)
    for k, v in pairs(TFTB.cooldowns) do
        if v < now then
            TFTB.cooldowns[k] = nil
        end
    end
end

local function shouldListen()
    return not TFTB.state.inCombat and not TFTB.state.hasLoggedIn and not TFTB.state.inRestrictedArea
end

local listening
local function updateCLEURegistration()
    local want = shouldListen()
    if want and not listening then
        frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        listening = true
    elseif not want and listening then
        frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        listening = false
    end
end

local function updateRestrictedAreaState()
    if not TFTB.config.disableInInstances then
        TFTB.state.inRestrictedArea = false
    else
        local inInstance, t = IsInInstance()
        TFTB.state.inRestrictedArea = inInstance and (t == "party" or t == "raid" or t == "pvp")
    end
    updateCLEURegistration()
end

function TFTB:OnCombatEvent()
    local _, subEvent, _, sourceGUID, sourceName, sourceFlags, _, destGUID = CombatLogGetCurrentEventInfo()
    if subEvent ~= "SPELL_AURA_APPLIED" then
        return
    end
    if self.state.hasLoggedIn or self.state.inCombat or self.state.inRestrictedArea then
        return
    end
    if destGUID ~= PLAYER_GUID or not sourceName then
        return
    end

    if bit_band(sourceFlags, OBJ_TYPE_NPC) > 0 or bit_band(sourceFlags, OBJ_TYPE_PET) > 0 then
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
    local cd = TFTB.cooldowns[sourceGUID]
    if cd and cd > now then
        return
    end
    TFTB.cooldowns[sourceGUID] = now + TFTB.config.cooldownDuration

    local emote = TFTB.config.randomEmotes[math_random(#TFTB.config.randomEmotes)]
    DoEmote(emote, sourceName)
end

function TFTB:OnEvent(event)
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
                self.state.hasLoggedIn = false
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
    600,
    function()
        clearExpiredCooldowns(GetTime())
    end
)

-- /thankyou
local function isValidSameFactionPlayer(unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) then
        return false
    end
    return UnitFactionGroup("player") == UnitFactionGroup(unit)
end

local function cheerAndThankTarget()
    local targetName = GetUnitName("target", true)
    if not isValidSameFactionPlayer("target") then
        print("|cff00C853TFTB|r : Invalid target. Please select a valid player on the same faction.")
        return
    end
    if targetName then
        local emote = TFTB.config.randomEmotes[math_random(#TFTB.config.randomEmotes)]
        local message = TFTB.config.thankYouMessages[math_random(#TFTB.config.thankYouMessages)]
        DoEmote(emote, targetName)
        SendChatMessage(message, "WHISPER", nil, targetName)
    else
        print("|cff00C853TFTB|r : No target selected. Please select a player to thank.")
    end
end

SLASH_THANKYOU1 = "/thankyou"
SlashCmdList.THANKYOU = cheerAndThankTarget
