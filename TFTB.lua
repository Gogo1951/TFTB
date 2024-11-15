local playerGUID = UnitGUID("player")
local frame = CreateFrame("Frame")

local state = {
    inCombat = false,
    hasLoggedIn = false,
    enterTime = nil
}

local config = {
    cooldownDuration = 10,
    loginDelay = 5,
    randomEmotes = {
        "CHEER",
        "THANK",
        "APPLAUD",
        "SALUTE",
        "BOW"
    }
}

local thankCooldown = {}

-- Utility function to clear expired cooldowns
local function clearExpiredCooldowns(now)
    for key, value in pairs(thankCooldown) do
        if value < now then
            thankCooldown[key] = nil
        end
    end
end

-- Debugging helper
local function debugPrint(...)
    print("[Debug]:", ...)
end

local function shouldProcessEvent()
    return not state.hasLoggedIn and not state.inCombat
end

-- Register relevant events
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- Event handler
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        self:OnCombatEvent(CombatLogGetCurrentEventInfo())
    elseif event == "PLAYER_REGEN_DISABLED" then
        state.inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        state.inCombat = false
    elseif event == "PLAYER_ENTERING_WORLD" then
        state.hasLoggedIn = true
        state.enterTime = GetTime()
        C_Timer.After(config.loginDelay, function()
            state.hasLoggedIn = false
        end)
    end
end)

-- Combat log processing
function frame:OnCombatEvent(...)
    local _, subEvent, _, sourceGUID, sourceName, _, _, destGUID, _, _, _, spellName = ...
    local now = GetTime()

    if not shouldProcessEvent() or subEvent ~= "SPELL_AURA_APPLIED" then
        return
    end

    clearExpiredCooldowns(now)

    -- Debug logging for key values
    debugPrint("SubEvent:", subEvent, "Spell:", spellName, "Source:", sourceName, "Target GUID:", destGUID)

    -- Check if the player was the target
    if destGUID == playerGUID and sourceGUID ~= playerGUID then
        if not thankCooldown[sourceGUID] then
            thankCooldown[sourceGUID] = now + config.cooldownDuration
            local emote = config.randomEmotes[math.random(1, #config.randomEmotes)]
            if sourceName then
                debugPrint("Sending emote:", emote, "to", sourceName)
                DoEmote(emote, sourceName)
            else
                debugPrint("Source name missing for GUID:", sourceGUID)
            end
        else
            debugPrint("Cooldown active for GUID:", sourceGUID)
        end
    else
        debugPrint("Event ignored: Player not target.")
    end
end


-- Define the list of thank you messages
local thankYouMessages = {
    "Thanks, you're the best! (=",
    "Great job! Thank you for that.",
    "Amazing, you're a legend!",
    "Thanks! That was just what I needed.",
    "You're really good at that -- you must practice a lot!",
    "That was so solid! Thanks for being so reliable.",
    "I don't care what everyone else says, you're amazing in my book!",
    "Wish everyone was like you, thanks!",
    "Great skills, I respect that! Thanks!",
    "You're absolutely fantastic -- thank you so much!",
    "Nicely done! You're really good at helping out.",
    "You deserve all the credit. Thank you!",
    "Thanks! My hero!",
    "Keep that up and you just might get added to my friends list. Thanks!",
    "I appreciate you, thanks!",
    "Nice! Thanks for doing what you do!",
}

-- Function to cheer and send a random thank you message to the target
local function cheerAndThankTarget()
    -- Select a random message from the list
    local message = thankYouMessages[math.random(#thankYouMessages)]
    
    -- Send a cheer emote
    DoEmote("cheer")

    -- Send the thank you message as a whisper to the target
    local targetName = GetUnitName("target", true)
    if targetName then
        SendChatMessage(message, "WHISPER", nil, targetName)
    else
        print("No target selected.")
    end
end

-- Register the /thankyou slash command
SLASH_THANKYOU1 = "/thankyou"
SlashCmdList["THANKYOU"] = cheerAndThankTarget
