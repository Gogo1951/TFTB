local addonName, ns = ...
local Data = ns.Data

local TFTB = LibStub("AceAddon-3.0"):NewAddon("TFTB", "AceConsole-3.0", "AceEvent-3.0")
ns.TFTB = TFTB

local sessionCooldowns = {}
local welcomeMessageShown = false
local spellLookup = {}

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

---------------------------------------------------------------------------
-- Spell Lookup (built once, avoids nested loops every combat log event)
---------------------------------------------------------------------------
function TFTB:BuildSpellLookup()
    wipe(spellLookup)
    if not Data.SPELL_LIST then
        return
    end
    for class, spellGroups in pairs(Data.SPELL_LIST) do
        for _, spellData in ipairs(spellGroups) do
            for _, id in ipairs(spellData.ids) do
                spellLookup[id] = {
                    name = spellData.name,
                    category = spellData.category or "CLASS",
                    noAura = spellData.noAura or false
                }
            end
        end
    end
end

---------------------------------------------------------------------------
-- Auto Macro
---------------------------------------------------------------------------
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
    local currentVersion = C_AddOns.GetAddOnMetadata(addonName, "Version") or "2026.02.21.E"

    if Data.DEFAULTS and Data.DEFAULTS.profile and Data.DEFAULTS.profile.groupBuffs then
        Data.DEFAULTS.profile.groupBuffs.messaging = "PRINT"
    end

    self.db = LibStub("AceDB-3.0"):New("TFTB_DB", Data.DEFAULTS, "Default")

    local lastVersion = self.db.profile.lastRunVersion
    if not lastVersion or lastVersion < currentVersion then
        self.db:ResetProfile()
        self:PrintMsg("Version " .. currentVersion .. " detected. Settings updated.")
    end

    self.db.profile.lastRunVersion = currentVersion

    if not self.db.profile.groupBuffs then
        self:PrintMsg("Error: Database defaults failed to load. Please reset your profile via /tftb.")
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

    self:BuildSpellLookup()
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
local function SendAppreciation(sourceGUID, sourceName, spellLink, spellName, category, messagingType, noAura)
    if messagingType == "PRINT" then
        local coloredName = sourceName

        -- Attempt to fetch the English Class name via GUID and match it to Data.COLORS
        if sourceGUID then
            local _, englishClass = GetPlayerInfoByGUID(sourceGUID)
            if englishClass and Data.COLORS[englishClass] then
                coloredName = string.format("|cff%s%s|r", Data.COLORS[englishClass], sourceName)
            end
        end

        if category == "PARTY_ITEM" then
            TFTB:PrintMsg(coloredName .. " used " .. spellLink .. " for your party!")
        elseif noAura then
            TFTB:PrintMsg(coloredName .. " hit you with " .. spellLink .. "!")
        else
            TFTB:PrintMsg(coloredName .. " buffed you with " .. spellLink .. "!")
        end
    elseif messagingType == "WHISPER" then
        SendChatMessage("Thanks for the " .. spellLink .. "!", "WHISPER", nil, sourceName)
    end
end

local function HandleStrangersBuff(sourceGUID, sourceName, spellID)
    local db = TFTB.db.profile.strangers
    if not db or not db.enabled then
        return
    end

    local spellLink = GetSpellLink(spellID) or "Unknown Spell"

    -- Pass sourceGUID into SendAppreciation so it can look up the class color
    SendAppreciation(sourceGUID, sourceName, spellLink, spellLink, "STRANGER", db.messaging)

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

local function HandleGroupBuff(sourceGUID, sourceName, spellID, isAuraEvent)
    local db = TFTB.db.profile.groupBuffs
    if not db or not db.watchedBuffs[spellID] then
        return
    end

    local info = spellLookup[spellID]
    if not info then
        return
    end

    -- Avoid double-firing: aura spells only fire on SPELL_AURA_APPLIED,
    -- non-aura spells (resurrects, grips, etc.) only fire on SPELL_CAST_SUCCESS
    if info.noAura and isAuraEvent then
        return
    end
    if not info.noAura and not isAuraEvent then
        return
    end

    local spellLink = GetSpellLink(spellID) or "Unknown Spell"

    -- Pass sourceGUID into SendAppreciation so it can look up the class color
    SendAppreciation(sourceGUID, sourceName, spellLink, info.name, info.category, db.messaging, info.noAura)
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

    local isAuraEvent = (subEvent == "SPELL_AURA_APPLIED")
    local isCastEvent = (subEvent == "SPELL_CAST_SUCCESS")

    if not isAuraEvent and not isCastEvent then
        return
    end

    if destGUID ~= UnitGUID("player") or sourceGUID == UnitGUID("player") or not sourceName then
        return
    end

    if UnitInParty(sourceName) or UnitInRaid(sourceName) then
        HandleGroupBuff(sourceGUID, sourceName, spellID, isAuraEvent)
    elseif isAuraEvent and not InCombatLockdown() and bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0 then
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
        TFTB:PrintMsg("Enabled. Use /tftb to adjust your settings; including turning off this message. (=")
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