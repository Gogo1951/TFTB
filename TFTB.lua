
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
        EMOTE98_TOKEN,
        EMOTE21_TOKEN,
        EMOTE54_TOKEN,
        EMOTE123_TOKEN,
        EMOTE36_TOKEN
    }
}

local buffList = {
    -- Druid
    [GetSpellInfo(21849)] = true,    -- Gift of the Wild
    [GetSpellInfo(5231)] = true,     -- Mark of the Wild
    [GetSpellInfo(467)] = true,      -- Thorns
    
    -- Mage
    [GetSpellInfo(1008)] = true,     -- Amplify Magic
    [GetSpellInfo(23028)] = true,    -- Arcane Brilliance
    [GetSpellInfo(1459)] = true,     -- Arcane Intellect
    [GetSpellInfo(604)] = true,      -- Dampen Magic
    
    -- Priest
    [GetSpellInfo(14752)] = true,    -- Divine Spirit
    [GetSpellInfo(6346)] = true,     -- Fear Ward
    [GetSpellInfo(21562)] = true,    -- Prayer of Fortitude
    [GetSpellInfo(27683)] = true,    -- Prayer of Shadow Protection
    [GetSpellInfo(27681)] = true,    -- Prayer of Spirit
    [GetSpellInfo(1243)] = true,     -- Power Word: Fortitude
    [GetSpellInfo(976)] = true,      -- Shadow Protection
    
    -- Paladin
    [GetSpellInfo(20217)] = true,    -- Blessing of Kings
    [GetSpellInfo(1044)] = true,     -- Blessing of Freedom
    [GetSpellInfo(19977)] = true,    -- Blessing of Light
    [GetSpellInfo(19740)] = true,    -- Blessing of Might
    [GetSpellInfo(1022)] = true,     -- Blessing of Protection
    [GetSpellInfo(20911)] = true,    -- Blessing of Sanctuary
    [GetSpellInfo(1038)] = true,     -- Blessing of Salvation
    [GetSpellInfo(19742)] = true,    -- Blessing of Wisdom
    [GetSpellInfo(19752)] = true,    -- Divine Intervention
    [GetSpellInfo(25898)] = true,    -- Greater Blessing of Kings
    [GetSpellInfo(25890)] = true,    -- Greater Blessing of Light
    [GetSpellInfo(19834)] = true,    -- Greater Blessing of Might
    [GetSpellInfo(25899)] = true,    -- Greater Blessing of Sanctuary
    [GetSpellInfo(25895)] = true,    -- Greater Blessing of Salvation
    [GetSpellInfo(25894)] = true,    -- Greater Blessing of Wisdom
    
    -- Warlock
    [GetSpellInfo(2970)] = true,     -- Detect Invisibility
    [GetSpellInfo(11743)] = true,    -- Detect Greater Invisibility
    [GetSpellInfo(20707)] = true,    -- Soulstone Resurrection
    [GetSpellInfo(5697)] = true,     -- Unending Breath
}

local thankCooldown = {}

local function clearExpiredCooldowns(now)
    for key, value in pairs(thankCooldown) do
        if value < now then
            thankCooldown[key] = nil
        end
    end
end

local function debugPrint(...)
    if DEBUG_MODE then
        print("[DEBUG]:", ...)
    end
end

local function shouldProcessEvent()
    return not state.hasLoggedIn and not state.inCombat and not IsInRaid()
end

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

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
        C_Timer.After(config.loginDelay, function() state.hasLoggedIn = false end)
    elseif event == "PLAYER_LEAVING_WORLD" then
        self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
end)

function frame:OnCombatEvent(...)
    local _, subEvent, _, sourceGUID, sourceName, _, _, destGUID, _, _, _, spellName = ...
    local now = GetTime()

    if not shouldProcessEvent() or subEvent ~= "SPELL_AURA_APPLIED" then return end

    clearExpiredCooldowns(now)

    if destGUID == playerGUID and sourceGUID ~= playerGUID and buffList[spellName] and UnitIsPlayer(sourceName) then
        if not thankCooldown[sourceGUID] and not UnitInParty(sourceName) and not UnitInRaid(sourceName) then
            thankCooldown[sourceGUID] = now + config.cooldownDuration
            local emote = config.randomEmotes[math.random(1, #config.randomEmotes)]
            DoEmote(emote, sourceName)
        end
    end
end

-- Define the list of thank you messages
local thankYouMessages = {
    "Wow, great job! Thank you for that."
    "Thanks a lot, that really made a difference!"
    "You did an awesome thing there—really great work!"
    "I appreciate what you did. Thank you!"
    "You're the best helper around—amazing job!"
    "Thanks! That was a big help right when I needed it."
    "You're really good at this—you must practice a lot!"
    "That was so solid! Thanks for being so reliable."
    "Everyone should know—you're amazing in my book!"
    "Great skills, I respect that! Thanks!"
    "You're absolutely fantastic—thank you so much!"
    "Nicely done! You’re really good at helping out."
    "You deserve some serious credit for that. Thank you!"
    "Thanks! You really came through like a hero."
    "Wow, you’re too good at this! Keep it up!"
    "I truly appreciate that—seriously, thank you."
    "Way to go! Great job helping out!"
    "Nice moves! Thanks for stepping in and helping me!"
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
