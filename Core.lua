local addonName, ns = ...
local Data = ns.Data

-- Initialize AceAddon
local TFTB = LibStub("AceAddon-3.0"):NewAddon("TFTB", "AceConsole-3.0", "AceEvent-3.0")
ns.TFTB = TFTB

local sessionCooldowns = {}
local welcomeMessageShown = false

---------------------------------------------------------------------------
-- Utilities
---------------------------------------------------------------------------
function TFTB:PrintMsg(msg)
    local prefix = string.format("|cff%s%s|r |cff%s//|r ", Data.COLORS.BRAND, Data.ADDON_TITLE, Data.COLORS.SEP)
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. msg)
end

local function IsOnCooldown(guid)
    local now = GetTime()
    local expiresAt = sessionCooldowns[guid]
    return expiresAt and expiresAt > now
end

local function SetCooldown(guid, duration)
    sessionCooldowns[guid] = GetTime() + (duration or 10)
end

function TFTB:CreateAutoMacro()
    if InCombatLockdown() then
        return
    end

    -- Safety Check
    if not self.db or not self.db.profile or not self.db.profile.slash then
        return
    end

    if not self.db.profile.slash.createMacro then
        return
    end

    local macroIndex = GetMacroIndexByName(Data.MACRO_NAME)
    if macroIndex == 0 then
        local numGlobal, _ = GetNumMacros()
        if numGlobal < 120 then
            CreateMacro(Data.MACRO_NAME, 134411, "/thankyou", nil)
            self:PrintMsg("Created macro '" .. Data.MACRO_NAME .. "'.")
        end
    end
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------
function TFTB:OnInitialize()
    if Data.DEFAULTS and Data.DEFAULTS.profile and Data.DEFAULTS.profile.groupBuffs then
        Data.DEFAULTS.profile.groupBuffs.messaging = "PRINT"
    end

    -- Initialize DB
    self.db = LibStub("AceDB-3.0"):New("TFTB_DB", Data.DEFAULTS, "Default")

    -- Force Global Sharing
    self.db:SetProfile("Default")

    -- Critical Safety Check
    if not self.db.profile.groupBuffs then
        self:PrintMsg("|cffff0000ERROR:|r Database defaults failed to load. Please reset your profile.")
        return
    end

    if ns.SetupOptions then
        ns.SetupOptions()
    end

    -- Populate Watched Buffs (if missing)
    local watched = self.db.profile.groupBuffs.watchedBuffs
    if Data.SPELL_LIST then
        for class, spellGroups in pairs(Data.SPELL_LIST) do
            for _, spellData in ipairs(spellGroups) do
                for _, id in ipairs(spellData.ids) do
                    if C_Spell.DoesSpellExist(id) and watched[id] == nil then
                        watched[id] = true
                    end
                end
            end
        end
    end
end

function TFTB:OnEnable()
    self.isReady = false

    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:CreateAutoMacro()
end

---------------------------------------------------------------------------
-- Logic: Buffs from Strangers
---------------------------------------------------------------------------
local function HandleStrangersBuff(sourceGUID, sourceName, spellID)
    -- Safety Check
    if not TFTB.db or not TFTB.db.profile.strangers then
        return
    end

    local db = TFTB.db.profile.strangers
    if not db.enabled then
        return
    end

    local spellLink = GetSpellLink(spellID) or "Unknown Spell"

    -- 1. Emote
    if db.emotesEnabled then
        local availableEmotes = {}
        for emoteCmd, isEnabled in pairs(db.emotes) do
            if isEnabled then
                table.insert(availableEmotes, emoteCmd)
            end
        end
        if #availableEmotes > 0 then
            DoEmote(availableEmotes[math.random(#availableEmotes)], sourceName)
        end
    end

    -- 2. Messaging
    if db.messaging == "PRINT" then
        TFTB:PrintMsg(spellLink .. " from " .. sourceName .. ".")
    elseif db.messaging == "WHISPER" then
        local msg = "Thanks for " .. spellLink .. "!"
        SendChatMessage(msg, "WHISPER", nil, sourceName)
    end

    SetCooldown(sourceGUID, db.cooldown)
end

---------------------------------------------------------------------------
-- Logic: In-Party Combat Buffs
---------------------------------------------------------------------------
local function HandleGroupBuff(sourceGUID, sourceName, spellID)
    -- Safety Check
    if not TFTB.db or not TFTB.db.profile.groupBuffs then
        return
    end

    local db = TFTB.db.profile.groupBuffs
    if not db.watchedBuffs[spellID] then
        return
    end

    local spellLink = GetSpellLink(spellID) or "Unknown Spell"

    -- [DEFAULT: PRINT]
    if db.messaging == "PRINT" then
        -- [CHANGE] Added period at the end
        TFTB:PrintMsg(spellLink .. " from " .. sourceName .. ".")
    elseif db.messaging == "WHISPER" then
        local msg = "Thanks for " .. spellLink .. "!"
        SendChatMessage(msg, "WHISPER", nil, sourceName)
    end

    SetCooldown(sourceGUID, 5)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
function TFTB:COMBAT_LOG_EVENT_UNFILTERED()
    -- Login Safety Check: Don't process events until the 8s timer finishes
    if not self.isReady then
        return
    end

    -- Safety Check
    if not self.db or not self.db.profile.global.enabled then
        return
    end

    local _, subEvent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, _, _, _, spellID =
        CombatLogGetCurrentEventInfo()

    if subEvent ~= "SPELL_AURA_APPLIED" then
        return
    end
    if destGUID ~= UnitGUID("player") then
        return
    end
    if sourceGUID == UnitGUID("player") then
        return
    end
    if not sourceName then
        return
    end
    if IsOnCooldown(sourceGUID) then
        return
    end

    local inGroup = UnitInParty(sourceName) or UnitInRaid(sourceName)

    if inGroup then
        HandleGroupBuff(sourceGUID, sourceName, spellID)
    else
        if not InCombatLockdown() then
            if bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0 then
                HandleStrangersBuff(sourceGUID, sourceName, spellID)
            end
        end
    end
end

function TFTB:PLAYER_ENTERING_WORLD()
    self:CreateAutoMacro()

    C_Timer.After(
        5,
        function()
            self.isReady = true
        end
    )

    if self.db and self.db.profile and self.db.profile.global and not welcomeMessageShown then
        if self.db.profile.global.welcomeMessage then
            TFTB:PrintMsg("Enabled. You can use /tftb to disable this message or update your settings.")
            welcomeMessageShown = true
        end
    end
end

---------------------------------------------------------------------------
-- Slash Commands (/thankyou)
---------------------------------------------------------------------------
SLASH_THANKYOU1 = "/thankyou"
SlashCmdList.THANKYOU = function(msg)
    if not UnitExists("target") or not UnitIsPlayer("target") then
        TFTB:PrintMsg("Select a player to thank.")
        return
    end
    if UnitIsUnit("target", "player") then
        TFTB:PrintMsg("You can't thank yourself!")
        return
    end

    if not TFTB.db or not TFTB.db.profile.slash then
        return
    end
    local db = TFTB.db.profile.slash

    -- 1. Emote
    local availableEmotes = {}
    for emoteCmd, isEnabled in pairs(db.emotes) do
        if isEnabled then
            table.insert(availableEmotes, emoteCmd)
        end
    end
    if #availableEmotes > 0 then
        DoEmote(availableEmotes[math.random(#availableEmotes)], "target")
    end

    -- 2. Whisper
    if UnitFactionGroup("player") == UnitFactionGroup("target") then
        if db.message and db.message ~= "" then
            SendChatMessage(db.message, "WHISPER", nil, GetUnitName("target", true))
        end
    end
end