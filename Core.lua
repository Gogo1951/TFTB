local addonName, ns = ...
local Data = ns.Data

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

function TFTB:StartSafetyTimer(duration)
    self.isReady = false
    C_Timer.After(
        duration or Data.SAFETY_PAUSE,
        function()
            self.isReady = true
        end
    )
end

function TFTB:CreateAutoMacro()
    if InCombatLockdown() then
        return
    end

    if not self.db or not self.db.profile or not self.db.profile.slash or not self.db.profile.slash.createMacro then
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

    self.db = LibStub("AceDB-3.0"):New("TFTB_DB", Data.DEFAULTS, "Default")
    self.db:SetProfile("Default")

    if not self.db.profile.groupBuffs then
        self:PrintMsg("|cffff0000ERROR:|r Database defaults failed to load. Please reset your profile.")
        return
    end

    if ns.SetupOptions then
        ns.SetupOptions()
    end

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
    self:StartSafetyTimer(Data.SAFETY_PAUSE)

    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("LOADING_SCREEN_DISABLED")

    self:CreateAutoMacro()
end

---------------------------------------------------------------------------
-- Logic: Notifications
---------------------------------------------------------------------------
local function SendAppreciation(sourceName, spellLink, messagingType)
    if messagingType == "PRINT" then
        TFTB:PrintMsg(spellLink .. " from " .. sourceName .. ".")
    elseif messagingType == "WHISPER" then
        SendChatMessage("Thanks for " .. spellLink .. "!", "WHISPER", nil, sourceName)
    end
end

local function HandleStrangersBuff(sourceGUID, sourceName, spellID)
    local db = TFTB.db.profile.strangers
    if not db or not db.enabled then
        return
    end

    local spellLink = GetSpellLink(spellID) or "Unknown Spell"

    SendAppreciation(sourceName, spellLink, db.messaging)

    if not IsOnCooldown(sourceGUID) then
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
        
        SetCooldown(sourceGUID, db.cooldown)
    end
end

local function HandleGroupBuff(sourceGUID, sourceName, spellID)
    local db = TFTB.db.profile.groupBuffs
    if not db or not db.watchedBuffs[spellID] then
        return
    end

    local spellLink = GetSpellLink(spellID) or "Unknown Spell"
    SendAppreciation(sourceName, spellLink, db.messaging)
    
    SetCooldown(sourceGUID, 3)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
function TFTB:COMBAT_LOG_EVENT_UNFILTERED()
    if not self.isReady or not self.db or not self.db.profile.global.enabled then
        return
    end

    local _, subEvent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, _, _, _, spellID =
        CombatLogGetCurrentEventInfo()

    if
        subEvent ~= "SPELL_AURA_APPLIED" or destGUID ~= UnitGUID("player") or sourceGUID == UnitGUID("player") or
            not sourceName
     then
        return
    end

    if UnitInParty(sourceName) or UnitInRaid(sourceName) then
        HandleGroupBuff(sourceGUID, sourceName, spellID)
    elseif not InCombatLockdown() and bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0 then
        HandleStrangersBuff(sourceGUID, sourceName, spellID)
    end
end

function TFTB:LOADING_SCREEN_DISABLED()
    self:StartSafetyTimer(Data.SAFETY_PAUSE)
end

function TFTB:PLAYER_ENTERING_WORLD()
    self:CreateAutoMacro()

    if
        self.db and self.db.profile and self.db.profile.global and self.db.profile.global.welcomeMessage and
            not welcomeMessageShown
     then
        TFTB:PrintMsg("Enabled. You can use /tftb to disable this message or update your settings.")
        welcomeMessageShown = true
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

    local db = TFTB.db.profile.slash
    if not db then
        return
    end

    local availableEmotes = {}
    for emoteCmd, isEnabled in pairs(db.emotes) do
        if isEnabled then
            table.insert(availableEmotes, emoteCmd)
        end
    end
    if #availableEmotes > 0 then
        DoEmote(availableEmotes[math.random(#availableEmotes)], "target")
    end

    if UnitFactionGroup("player") == UnitFactionGroup("target") and db.message and db.message ~= "" then
        SendChatMessage(db.message, "WHISPER", nil, GetUnitName("target", true))
    end
end
