local addonName, ns = ...
local Data = ns.Data

function ns.SetupOptions()
    local TFTB = ns.TFTB
    local AC = LibStub("AceConfig-3.0")
    local ACD = LibStub("AceConfigDialog-3.0")

    -----------------------------------------------------------------------
    -- Helper Functions
    -----------------------------------------------------------------------
    local function Colorize(text, colorHex)
        return "|cff" .. colorHex .. text .. "|r"
    end

    local function GetHeader(name)
        return Colorize(name, Data.COLORS.TITLE)
    end

    local function GetSpacer(order)
        return {
            type = "description",
            name = " ",
            fontSize = "small",
            order = order
        }
    end

    local function DefineSpellGroupToggle(spellData, order)
        local name = spellData.name
        local ids = spellData.ids
        local desc = "Toggle tracking for " .. name
        if ids and ids[1] then
            local spellDesc = C_Spell.GetSpellDescription(ids[1])
            if spellDesc and spellDesc ~= "" then
                desc = spellDesc
            end
        end

        return {
            type = "toggle",
            name = name,
            desc = desc,
            order = order,
            width = "full",
            get = function()
                if ids and ids[1] then
                    return TFTB.db.profile.groupBuffs.watchedBuffs[ids[1]]
                end
                return false
            end,
            set = function(_, val)
                if ids then
                    for _, id in ipairs(ids) do
                        TFTB.db.profile.groupBuffs.watchedBuffs[id] = val
                    end
                end
            end
        }
    end

    -----------------------------------------------------------------------
    -- Options Table
    -----------------------------------------------------------------------
    local options = {
        name = "Thanks for the Buff!",
        handler = TFTB,
        type = "group",
        args = {
            headerMain = {order = 1, type = "header", name = GetHeader("Thanks for the Buff")},
            descMain = {
                order = 2,
                type = "description",
                fontSize = "medium",
                name = "Automatically expresses happiness when you receive buffs from strangers, and thank your party members for using their critical combat cooldowns for your benefit."
            },
            space1 = GetSpacer(3),
            headerGen = {order = 10, type = "header", name = GetHeader("General Settings")},
            enableAddon = {
                order = 11,
                type = "toggle",
                name = "Enable Addon",
                desc = "Master switch for the addon.",
                width = "full",
                get = function()
                    return TFTB.db.profile.global.enabled
                end,
                set = function(_, val)
                    TFTB.db.profile.global.enabled = val
                end
            },
            spaceGen1 = GetSpacer(12),
            enableWelcome = {
                order = 13,
                type = "toggle",
                name = "Enable Welcome Message",
                desc = "Print a message to chat when you log in.",
                width = "full",
                get = function()
                    return TFTB.db.profile.global.welcomeMessage
                end,
                set = function(_, val)
                    TFTB.db.profile.global.welcomeMessage = val
                end
            },
            spaceGen2 = GetSpacer(14),
            headerStrangers = {order = 20, type = "header", name = GetHeader("Buffs from Strangers")},
            descStrangers = {
                order = 21,
                type = "description",
                name = "Used when receiving buffs from non-group members while out of combat."
            },
            spaceSt1 = GetSpacer(22),
            enableStrangers = {
                order = 23,
                type = "toggle",
                name = "Enable Buffs from Strangers",
                width = "full",
                get = function()
                    return TFTB.db.profile.strangers.enabled
                end,
                set = function(_, val)
                    TFTB.db.profile.strangers.enabled = val
                end
            },
            spaceSt2 = GetSpacer(24),
            cooldownStrangers = {
                order = 25,
                type = "range",
                name = "Cooldown (Seconds)",
                desc = "At most, how often to thank the same player.",
                min = 1,
                max = 60,
                step = 1,
                get = function()
                    return TFTB.db.profile.strangers.cooldown
                end,
                set = function(_, val)
                    TFTB.db.profile.strangers.cooldown = val
                end
            },
            spaceSt3 = GetSpacer(26),
            messagingStrangers = {
                order = 27,
                type = "select",
                name = "Messaging",
                style = "dropdown",
                width = "double",
                values = {
                    ["NONE"] = "No Message (Default)",
                    ["PRINT"] = "Print-out Message (Self Only)",
                    ["WHISPER"] = "Whisper Message"
                },
                get = function()
                    return TFTB.db.profile.strangers.messaging
                end,
                set = function(_, val)
                    TFTB.db.profile.strangers.messaging = val
                end
            },
            spaceSt4 = GetSpacer(28),
            enableEmotesStrangers = {
                order = 29,
                type = "toggle",
                name = "Enable Emotes",
                desc = "Emote your appreciation for Buffs from Strangers.",
                width = "full",
                get = function()
                    return TFTB.db.profile.strangers.emotesEnabled
                end,
                set = function(_, val)
                    TFTB.db.profile.strangers.emotesEnabled = val
                end
            },
            spaceSt5 = GetSpacer(30),
            strangersEmoteGroup = {order = 31, type = "group", inline = true, name = "Select Emotes", args = {}},
            spaceSt6 = GetSpacer(32),
            headerCombat = {order = 40, type = "header", name = GetHeader("In-Party Combat Buffs")},
            descCombat = {
                order = 41,
                type = "description",
                name = "Thank or track when party members use a major cooldown on you."
            },
            spaceCb1 = GetSpacer(42),
            messagingCombat = {
                order = 43,
                type = "select",
                name = "Messaging",
                style = "dropdown",
                width = "double",
                values = {
                    ["NONE"] = "No Message",
                    ["PRINT"] = "Print-out Message (Self Only)",
                    ["WHISPER"] = "Whisper Message"
                },
                get = function()
                    return TFTB.db.profile.groupBuffs.messaging
                end,
                set = function(_, val)
                    TFTB.db.profile.groupBuffs.messaging = val
                end
            },
            spaceCb2 = GetSpacer(44),
            headerTracked = {
                order = 45,
                type = "description",
                name = "\n" .. Colorize("Tracked Abilities:", Data.COLORS.TEXT)
            },
            spaceCb3 = GetSpacer(46),
            spaceSlHeader = GetSpacer(168),
            headerSlash = {order = 170, type = "header", name = GetHeader("Thank You Button")},
            descSlash = {
                order = 171,
                type = "description",
                name = "Thanks for the Buff comes with a slash command " .. Colorize("/thankyou", Data.COLORS.TEXT)
            },
            spaceSl1 = GetSpacer(172),
            createMacro = {
                order = 173,
                type = "toggle",
                name = "Create Macro",
                desc = "A macro named " ..
                    Colorize(Data.MACRO_NAME, Data.COLORS.TITLE) .. " will be automatically created for you on sign-in.",
                width = "full",
                get = function()
                    return TFTB.db.profile.slash.createMacro
                end,
                set = function(_, val)
                    TFTB.db.profile.slash.createMacro = val
                end
            },
            spaceSl2 = GetSpacer(174),
            whisperMsg = {
                order = 175,
                type = "input",
                name = "Whisper Message",
                width = "full",
                get = function()
                    return TFTB.db.profile.slash.message
                end,
                set = function(_, val)
                    TFTB.db.profile.slash.message = val
                end
            },
            resetMsg = {
                order = 175.5,
                type = "execute",
                name = "Reset",
                desc = "Reset the whisper message to the default text.",
                width = "half",
                func = function()
                    TFTB.db.profile.slash.message = "Thanks, you're the best! (="
                end
            },
            spaceSl3 = GetSpacer(176),
            headerSlashEmotes = {
                order = 177,
                type = "description",
                name = "\n" .. Colorize("Thank You Button Emotes:", Data.COLORS.TEXT)
            },
            slashEmoteGroup = {order = 178, type = "group", inline = true, name = "Select Emotes", args = {}},
            spaceSl4 = GetSpacer(179)
        }
    }

    -- Populate Emotes from Consolidated List
    for i, emoteData in ipairs(Data.EMOTES) do
        local emote = emoteData.cmd
        local desc = emoteData.desc

        -- Strangers Group
        options.args.strangersEmoteGroup.args[emote] = {
            type = "toggle",
            name = emote,
            desc = desc,
            order = i,
            width = "half",
            get = function()
                return TFTB.db.profile.strangers.emotes[emote]
            end,
            set = function(_, val)
                TFTB.db.profile.strangers.emotes[emote] = val
            end
        }
        -- Slash Group
        options.args.slashEmoteGroup.args[emote] = {
            type = "toggle",
            name = emote,
            desc = desc,
            order = i,
            width = "half",
            get = function()
                return TFTB.db.profile.slash.emotes[emote]
            end,
            set = function(_, val)
                TFTB.db.profile.slash.emotes[emote] = val
            end
        }
    end

    -- Populate Class/Item Spells
    if Data.SPELL_LIST then
        local classOrder = 60
        local classList = {}
        local hasItems = false

        -- Separate "ITEMS" from the standard class list so it can be appended at the end
        for class, _ in pairs(Data.SPELL_LIST) do
            if class == "ITEMS" then
                hasItems = true
            else
                table.insert(classList, class)
            end
        end

        -- Alphabetize classes
        table.sort(classList)

        -- Append "ITEMS" to the bottom of the list
        if hasItems then
            table.insert(classList, "ITEMS")
        end

        for _, class in ipairs(classList) do
            local spellGroups = Data.SPELL_LIST[class]
            local hasBuffs = false
            for _, spellData in ipairs(spellGroups) do
                for _, id in ipairs(spellData.ids) do
                    if C_Spell.DoesSpellExist(id) then
                        hasBuffs = true
                        break
                    end
                end
                if hasBuffs then
                    break
                end
            end

            if hasBuffs then
                local color = Data.COLORS[class] or "FFFFFF"
                local groupName = Colorize(class:sub(1, 1) .. class:sub(2):lower(), color)
                options.args["class_" .. class] = {
                    type = "group",
                    name = groupName,
                    order = classOrder,
                    inline = true,
                    args = {}
                }

                local spellOrder = 1
                for _, spellData in ipairs(spellGroups) do
                    local groupExists = false
                    for _, id in ipairs(spellData.ids) do
                        if C_Spell.DoesSpellExist(id) then
                            groupExists = true
                            break
                        end
                    end
                    if groupExists then
                        local key = "spell_" .. spellData.name:gsub(" ", "_")
                        options.args["class_" .. class].args[key] = DefineSpellGroupToggle(spellData, spellOrder)
                        spellOrder = spellOrder + 1
                    end
                end
                classOrder = classOrder + 1
            end
        end
    end

    AC:RegisterOptionsTable("TFTB", options)
    local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(TFTB.db)
    AC:RegisterOptionsTable("TFTB_Profiles", profiles)
    local mainPanel = ACD:AddToBlizOptions("TFTB", "Thanks for the Buff", nil)
    ACD:AddToBlizOptions("TFTB_Profiles", "Profiles", "Thanks for the Buff")

    SLASH_TFTB_CONFIG1 = "/tftb"
    SlashCmdList.TFTB_CONFIG = function()
        if _G.Settings and _G.Settings.GetCategory then
            local category = _G.Settings.GetCategory("Thanks for the Buff")
            if category then
                _G.Settings.OpenToCategory(category.ID)
                return
            end
        end
        if InterfaceOptionsFrame_OpenToCategory then
            InterfaceOptionsFrame_OpenToCategory(mainPanel)
            InterfaceOptionsFrame_OpenToCategory(mainPanel)
            return
        end
        ACD:Open("TFTB")
    end
end