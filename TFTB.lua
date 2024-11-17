local BuffCheerAddon = {}
local frame = CreateFrame("Frame")

BuffCheerAddon.state = {
    inCombat = false,
    hasLoggedIn = false,
    enterTime = nil
}

BuffCheerAddon.config = {
    cooldownDuration = 5,
    loginDelay = 5,
    randomEmotes = {
        -- https://warcraft.wiki.gg/wiki/List_of_emotes
        "APPLAUD",
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
        "WAVE",
        "WHOA",
        "WINK",
        "YES"
    }
}

BuffCheerAddon.thankCooldown = {}

local function clearExpiredCooldowns(now)
    for key, value in pairs(BuffCheerAddon.thankCooldown) do
        if value < now then
            BuffCheerAddon.thankCooldown[key] = nil
        end
    end
end

-- Check if a player is in your party or raid
local function isInPartyOrRaid(sourceGUID)
    for i = 1, GetNumGroupMembers() do
        local unitID = IsInRaid() and "raid" .. i or "party" .. i
        if UnitGUID(unitID) == sourceGUID then
            return true
        end
    end
    return false
end

function BuffCheerAddon:shouldProcessEvent()
    return not self.state.hasLoggedIn and not self.state.inCombat
end

function BuffCheerAddon:OnCombatEvent(...)
    local _, subEvent, _, sourceGUID, sourceName, _, _, destGUID, _, _, _, spellName = ...
    local now = GetTime()

    if subEvent ~= "SPELL_AURA_APPLIED" or not self:shouldProcessEvent() then
        return
    end

    if not sourceName or not spellName then
        return -- Ignore invalid data
    end

    clearExpiredCooldowns(now)

    if destGUID == UnitGUID("player") and sourceGUID ~= UnitGUID("player") then
        -- Check if the source is in the same party or raid
        if isInPartyOrRaid(sourceGUID) then
            return -- Skip thanking party/raid members
        end

        if not self.thankCooldown[sourceGUID] then
            self.thankCooldown[sourceGUID] = now + self.config.cooldownDuration
            local emote = self.config.randomEmotes[math.random(1, #self.config.randomEmotes)]
            DoEmote(emote, sourceName)
        end
    end
end

function BuffCheerAddon:OnEvent(event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        self:OnCombatEvent(CombatLogGetCurrentEventInfo())
    elseif event == "PLAYER_REGEN_DISABLED" then
        self.state.inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        self.state.inCombat = false
    elseif event == "PLAYER_ENTERING_WORLD" then
        self.state.hasLoggedIn = true
        self.state.enterTime = GetTime()
        C_Timer.After(
            self.config.loginDelay,
            function()
                self.state.hasLoggedIn = false
            end
        )
    end
end

-- Register Events
local events = {
    "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "COMBAT_LOG_EVENT_UNFILTERED"
}

for _, event in ipairs(events) do
    frame:RegisterEvent(event)
end

frame:SetScript(
    "OnEvent",
    function(self, event, ...)
        BuffCheerAddon:OnEvent(event, ...)
    end
)

-- Periodic cleanup of stale cooldowns
C_Timer.NewTicker(
    600,
    function()
        clearExpiredCooldowns(GetTime())
    end
)

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
    "Nice! Thanks for doing what you do!"
}

-- Function to use a random emote and send a thank you message to the target
local function cheerAndThankTarget()
    -- Get the current target's name
    local targetName = GetUnitName("target", true)

    if targetName then
        -- Select a random emote from the list
        local emote = BuffCheerAddon.config.randomEmotes[math.random(#BuffCheerAddon.config.randomEmotes)]
        local message = thankYouMessages[math.random(#thankYouMessages)]

        -- Perform the emote targeted at the player
        DoEmote(emote, targetName)

        -- Send the thank you message as a whisper to the target
        SendChatMessage(message, "WHISPER", nil, targetName)
    else
        print("|cff4FC3F7TFTB|r : No target selected. Please select a player to thank.")
    end
end

-- Register the /thankyou slash command
SLASH_THANKYOU1 = "/thankyou"
SlashCmdList["THANKYOU"] = cheerAndThankTarget
