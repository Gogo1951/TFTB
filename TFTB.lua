local playerGUID = UnitGUID("player")
local frame = CreateFrame("Frame")
local inCombat = false
local hasLoggedIn = false

-- Helper function to create a set from a list
local function Set(list)
    local set = {}
    for _, value in ipairs(list) do
        set[value] = true
    end
    return set
end

-- Register events for entering and leaving the world
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Fired when entering combat
frame:RegisterEvent("PLAYER_REGEN_ENABLED") -- Fired when leaving combat

frame:SetScript(
    "OnEvent",
    function(self, event)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            self:OnCombatEvent(event, CombatLogGetCurrentEventInfo())
        elseif event == "PLAYER_REGEN_DISABLED" then
            inCombat = true
        elseif event == "PLAYER_REGEN_ENABLED" then
            inCombat = false
        else
            if self[event] then
                self[event](self)
            end
        end
    end
)

-- Build a more comprehensive spell list (ignores ranks)
local buffList =
    Set {
    -- Druid
    GetSpellInfo(21849), -- Gift of the Wild
    GetSpellInfo(5231), -- Mark of the Wild
    GetSpellInfo(467), -- Thorns
    -- Mage
    GetSpellInfo(1008), -- Amplify Magic
    GetSpellInfo(23028), -- Arcane Brilliance
    GetSpellInfo(1459), -- Arcane Intellect
    GetSpellInfo(604), -- Dampen Magic
    -- Priest
    GetSpellInfo(14752), -- Divine Spirit
    GetSpellInfo(6346), -- Fear Ward
    GetSpellInfo(21562), -- Prayer of Fortitude
    GetSpellInfo(27683), -- Prayer of Shadow Protection
    GetSpellInfo(27681), -- Prayer of Spirit
    GetSpellInfo(1243), -- Power Word: Fortitude
    GetSpellInfo(976), -- Shadow Protection
    -- Paladin
    GetSpellInfo(20217), -- Blessing of Kings
    GetSpellInfo(1044), -- Blessing of Freedom
    GetSpellInfo(19977), -- Blessing of Light
    GetSpellInfo(19740), -- Blessing of Might
    GetSpellInfo(1022), -- Blessing of Protection
    GetSpellInfo(20911), -- Blessing of Sanctuary
    GetSpellInfo(1038), -- Blessing of Salvation
    GetSpellInfo(19742), -- Blessing of Wisdom
    GetSpellInfo(19752), -- Divine Intervention
    GetSpellInfo(25898), -- Greater Blessing of Kings
    GetSpellInfo(25890), -- Greater Blessing of Light
    GetSpellInfo(19834), -- Greater Blessing of Might
    GetSpellInfo(25899), -- Greater Blessing of Sanctuary
    GetSpellInfo(25895), -- Greater Blessing of Salvation
    GetSpellInfo(25894), -- Greater Blessing of Wisdom
    -- Warlock
    GetSpellInfo(2970), -- Detect Invisibility
    GetSpellInfo(11743), -- Detect Greater Invisibility
    GetSpellInfo(20707), -- Soulstone Resurrection
    GetSpellInfo(5697) -- Unending Breath
}

-- List of random emotes
local randomEmoteList = {
    EMOTE98_TOKEN,
    EMOTE21_TOKEN,
    EMOTE54_TOKEN,
    EMOTE123_TOKEN,
    EMOTE36_TOKEN
}

local emoteCount = #randomEmoteList

-- Cooldown for thanking players
local thankCooldown = {}

-- Handle leaving the world (e.g., instance, portals)
function frame:PLAYER_LEAVING_WORLD()
    self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

-- Handle entering the world
function frame:PLAYER_ENTERING_WORLD()
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self._enterTime = GetTime()
    hasLoggedIn = true -- Set the login flag
    C_Timer.After(
        5,
        function()
            hasLoggedIn = false
        end
    ) -- After 5 seconds, clear the login flag
end

-- Handle combat log events
function frame:OnCombatEvent(_, ...)
    local _, subEvent, _, sourceGUID, sourceName, _, _, destGUID, destName = ...
    local spellName, _, auraType = select(13, ...)
    local now = GetTime()

    -- Avoid actions shortly after entering the world and prevent emotes in combat
    if hasLoggedIn or inCombat or (self._enterTime and now - self._enterTime < 2) then
        return
    end

    -- Handle spell aura application
    if subEvent == "SPELL_AURA_APPLIED" then
        -- Clear expired thank cooldowns
        for key, value in pairs(thankCooldown) do
            if value < now then
                thankCooldown[key] = nil
            end
        end

        -- Ensure the buff was applied to us by another player not in our party/raid
        if
            destGUID == playerGUID and sourceGUID and sourceGUID ~= playerGUID and not thankCooldown[sourceGUID] and
                not (UnitInParty(sourceName) or UnitInRaid(sourceName))
         then
            if buffList[spellName] then
                local sourceType = strsplit("-", sourceGUID)

                -- Ensure the source is a player
                if sourceType == "Player" then
                    thankCooldown[sourceGUID] = now + 90

                    local emote =
                        TFTB_NEWEMOTE and TFTB_NEWEMOTE ~= "EMOTE0_TOKEN" and _G[TFTB_NEWEMOTE] or
                        randomEmoteList[math.random(1, emoteCount)]
                    DoEmote(emote, sourceName)
                end
            end
        end
    end
end

-- Cache available emotes
local emoteCache = {}
for i = 1, 306 do
    local token = string.format("EMOTE%d_TOKEN", i)
    if _G[token] then
        emoteCache[_G[token]] = token
    end
end

-- Slash command handler for TFTB
local function TFTBCommands(msg)
    msg = string.upper(msg or "")

    if msg == "" then
        if TFTB_NEWEMOTE and TFTB_NEWEMOTE ~= "EMOTE0_TOKEN" then
            print("TFTB current emote is: " .. _G[TFTB_NEWEMOTE] .. ".")
        else
            print("TFTB is currently using a random emote.")
            print("Use /tftb EMOTE to set your preferred one, e.g., /tftb thank")
        end
    elseif msg == "RANDOM" then
        TFTB_NEWEMOTE = "EMOTE0_TOKEN" -- Random emote
        print("TFTB is now using a random emote.")
    else
        local token = emoteCache[msg]
        if token then
            TFTB_NEWEMOTE = token
            print("TFTB emote has been set to: " .. msg .. ".")
        else
            print(msg .. " is not a valid emote.")
        end
    end
end

-- Register slash command
SLASH_TFTB1 = "/tftb"
SlashCmdList.TFTB = TFTBCommands
