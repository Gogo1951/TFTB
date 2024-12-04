local TFTB = {}
local frame = CreateFrame("Frame")

-- State, Config, and Cooldown Management
TFTB.state = {inCombat = false, hasLoggedIn = false, enterTime = nil}
TFTB.config = {
    cooldownDuration = 10,
    loginDelay = 5,
    randomEmotes = {
        "BOW",
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
        -- Define thank-you messages
        "Thanks, you're the best! (="
    }
}
TFTB.cooldowns = {}

-- Function to clear expired cooldowns
local function clearExpiredCooldowns(now)
    for key, expiry in pairs(TFTB.cooldowns) do
        if expiry < now then
            TFTB.cooldowns[key] = nil
        end
    end
end

-- Function to check if a unit is in the party, raid, or battleground
local function isInPartyRaidOrBG(sourceGUID)
    for i = 1, GetNumGroupMembers() do
        local unitID = IsInRaid() and "raid" .. i or "party" .. i
        if UnitGUID(unitID) == sourceGUID then
            return true
        end
    end
    return false
end

-- Function to check if a unit is a valid player on the same faction
local function isValidSameFactionPlayer(unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) then
        return false
    end

    local playerFaction = UnitFactionGroup("player")
    local targetFaction = UnitFactionGroup(unit)
    return playerFaction == targetFaction
end

-- Function to determine if the event should be processed
function TFTB:shouldProcessEvent()
    return self.state.hasLoggedIn == false and self.state.inCombat == false
end

-- Combat Log Event Processing
function TFTB:OnCombatEvent(...)
    local _, subEvent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, _, _, _, spellName = ...
    local now = GetTime()

    if subEvent ~= "SPELL_AURA_APPLIED" or not self:shouldProcessEvent() then
        return
    end

    clearExpiredCooldowns(now)

    -- Ignore NPC buffs or invalid data
    if not sourceName or bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_NPC) > 0 then
        return
    end

    -- Ensure the source isn't the player (self-buff check)
    if sourceGUID == UnitGUID("player") then
        return
    end

    -- Ensure the source isn't in your party, raid, or battleground group
    if isInPartyRaidOrBG(sourceGUID) then
        return
    end

    -- Check faction alignment
    local sourceUnitID = "target"
    if UnitGUID(sourceUnitID) == sourceGUID and not isValidSameFactionPlayer(sourceUnitID) then
        return
    end

    -- Avoid sending multiple thanks during the cooldown
    if destGUID == UnitGUID("player") and not TFTB.cooldowns[sourceGUID] then
        TFTB.cooldowns[sourceGUID] = now + TFTB.config.cooldownDuration
        local emote = TFTB.config.randomEmotes[math.random(#TFTB.config.randomEmotes)]
        pcall(DoEmote, emote, sourceName)
    end
end

-- Event Handlers
function TFTB:OnEvent(event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        self:OnCombatEvent(CombatLogGetCurrentEventInfo())
    elseif event == "PLAYER_REGEN_DISABLED" then
        self.state.inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        self.state.inCombat = false
    elseif event == "PLAYER_ENTERING_WORLD" then
        self.state.hasLoggedIn = true
        -- Delay processing events after login
        C_Timer.After(
            self.config.loginDelay,
            function()
                self.state.hasLoggedIn = false
            end
        )
    end
end

-- Register Events
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:SetScript(
    "OnEvent",
    function(_, event, ...)
        TFTB:OnEvent(event, ...)
    end
)

-- Periodic cleanup of stale cooldowns
C_Timer.NewTicker(
    600,
    function()
        clearExpiredCooldowns(GetTime())
    end
)

-- Function to use a random emote and send a thank you message to the target
local function cheerAndThankTarget()
    -- Get the current target's name
    local targetName = GetUnitName("target", true)

    -- Check if the target is valid and on the same faction
    if not isValidSameFactionPlayer("target") then
        print("|cff00C853TFTB|r : Invalid target. Please select a valid player on the same faction.")
        return
    end

    if targetName then
        -- Select a random emote from the list
        local emote = TFTB.config.randomEmotes[math.random(#TFTB.config.randomEmotes)]
        local message = TFTB.config.thankYouMessages[math.random(#TFTB.config.thankYouMessages)]

        -- Perform the emote targeted at the player
        DoEmote(emote, targetName)

        -- Send the thank you message as a whisper to the target
        SendChatMessage(message, "WHISPER", nil, targetName)
    else
        print("|cff00C853TFTB|r : No target selected. Please select a player to thank.")
    end
end

-- Register the /thankyou slash command
SLASH_THANKYOU1 = "/thankyou"
SlashCmdList["THANKYOU"] = cheerAndThankTarget
