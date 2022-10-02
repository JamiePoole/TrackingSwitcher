-------------------------------------------------------------------------------
-- Globals
-------------------------------------------------------------------------------
local addonSlug = "TrackingSwitcher"
local addonName = "Tracking Switcher"
local addonColor = "#FF71D5"
local defaultOptions = {
    Updated = false,
    Mute = true,
    Interval = 2,
    EnabledAbilities = {},
}

-------------------------------------------------------------------------------
-- Flags
-------------------------------------------------------------------------------
local DEBUG_MODE = true
local IS_LOOTING = false

-------------------------------------------------------------------------------
-- Key Bindings
-------------------------------------------------------------------------------
BINDING_HEADER_ADDON_NAME = addonName
BINDING_NAME_TOGGLE = "Toggle On/Off"

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
local function makeColoredTextFromHex(hex, text)
    -- Remove Hash if present
    local nohash = string.gsub(hex, "^#", "")
    local valid = string.gsub(nohash, "[^a-fA-F0-9]", "")

    -- Fail if the Hex is now anything other than 6 (a valid hex color) or 8 (already contains alpha)
    assert(#valid == 6 or #valid == 8, "Hex string is invalid")

    -- Set 'FF' alpha as default, or use the last two characters from 8-char hex
    local alpha = "FF"
    if (#valid == 8) then alpha = string.sub(valid, -2) end

    -- Combine 'hex' with 'alpha'
    local color = tostring(valid) .. tostring(alpha)

    return "|c" .. color .. tostring(text) .. "|r"
end

local function printFromAddon(message)
    print(makeColoredTextFromHex(addonColor, "[" .. addonName .. "]") .. " " .. message)
end

local function printDebug(message)
    if (DEBUG_MODE) then printFromAddon(makeColoredTextFromHex("#FFFF00", "DEBUG!") .. " " .. tostring(message)) end
end

-------------------------------------------------------------------------------
-- Methods
-------------------------------------------------------------------------------
local function UpdateAbilities()
    -- Reset existing values
    TrackingSwitcherCharacter.Abilities = {}

    -- WoW API `GetNumTrackingTypes`
    -- Gets all Tracking abilities (not just spells, but townspeople and trainers etc too)
    local numTrackingAbilities = GetNumTrackingTypes()

    for i = 1, numTrackingAbilities do
        local name, texture, active, category, nested = GetTrackingInfo(i)

        if (category == "spell") then
            local ability = {
                index = i,
                name = name,
                texture = texture
            }

            table.insert(TrackingSwitcherCharacter.Abilities, ability)
        end
    end

    -- Print number of tracking abilities info message
    printFromAddon("has found " .. tostring(#TrackingSwitcherCharacter.Abilities) .. " tracking " .. format("\1244ability:abilities", #TrackingSwitcherCharacter.Abilities) .. ".")
end

local function EnableDefaultAbilities()
    -- Exit early if the options have already been set, perhaps intentionally to no Trackers
    if (TrackingSwitcherCharacter.Options.Updated) then return end
    -- Exit early if there are no available Abilities anyway
    if (#TrackingSwitcherCharacter.Abilities == 0) then return end

    -- Reset Enabled Abilities for potential order of operations conflicts
    TrackingSwitcherCharacter.Options.EnabledAbilities = {}

    -- Loop through available Abilties, search for Mining or Herbalism
    for index, ability in ipairs(TrackingSwitcherCharacter.Abilities) do
        printDebug(index .. ": " .. ability.name)

        if (ability.name == "Find Minerals") then
            table.insert(TrackingSwitcherCharacter.Options.EnabledAbilities, ability)
        end

        if (ability.name == "Find Herbs") then
            table.insert(TrackingSwitcherCharacter.Options.EnabledAbilities, ability)
        end
    end

    for index, ability in ipairs(TrackingSwitcherCharacter.Options.EnabledAbilities) do
        printDebug("Enabled [" .. ability.index .. "] '" .. ability.name .. "'")
    end
end

local function CanSwitchTo(ability)
    -- Can only switch if the Tracking ability is not on cooldown
    local _, cooldownRemaining = GetSpellCooldown(ability.name)
    if (cooldownRemaining > 0) then printDebug("The tracking spell is on cooldown") end

    -- Can only switch if the user is not casting any item or spell
    local currentCastingSpell = UnitCastingInfo("player")
    if (currentCastingSpell ~= nil) then printDebug("Currently casting spell " .. currentCastingSpell) end

    -- Can only switch if the user is not looting
    local looting = IS_LOOTING
    if (looting) then printDebug("Loot window currently open") end

    -- Can only switch if the user currently has something on their cursor (loot, spell)
    local cursorType, cursorInfo1, cursorInfo2 = GetCursorInfo()
    if (cursorType ~= nil) then printDebug("Cursor is currently active with: " .. cursorType) end

    -- Can only switch if the user is not channeling a spell or item
    local channelling = UnitChannelInfo("player")
    if (channelling ~= nil) then printDebug("Currently channelling an ability: " .. channelling) end

    return (cooldownRemaining == 0) and (currentCastingSpell == nil) and (not looting) and (channelling == nil) and (cursorType == nil)
end

local function SwitchAbility()
    -- Exit early if there are no enabled Abilities for this character (via Interface Options)
    if (not TrackingSwitcherCharacter.Options.EnabledAbilities or #TrackingSwitcherCharacter.Options.EnabledAbilities == 0) then return end

    local ability = TrackingSwitcherCharacter.Options.EnabledAbilities[TrackingSwitcherCharacter.Index]

    -- Only switch and move index forward if allowed to cast/use tracking ability
    if (CanSwitchTo(ability)) then
        -- If the Addon option 'Mute' is true
        -- The sound file is a common sound '567407' "sound/interface/uchatscrollbutton.ogg"
        -- While highly unlikely (nigh impossible) muting this may unintentionally mute some other events made at the exact moment of switching
        if (TrackingSwitcherCharacter.Options.Mute) then MuteSoundFile(567407) end

        -- WoW API `SetTracking`
        -- Sets Tracker to Index (not spell ID, but index from `GetTrackingInfo()`)
        SetTracking(ability.index, true)

        -- Unmute the sound effect
        if (TrackingSwitcherCharacter.Options.Mute) then UnmuteSoundFile(567407) end

        -- Progress this Index, loop back to 1 at end
        if (TrackingSwitcherCharacter.Index == #TrackingSwitcherCharacter.Options.EnabledAbilities) then
            TrackingSwitcherCharacter.Index = 1
        else
            TrackingSwitcherCharacter.Index = TrackingSwitcherCharacter.Index + 1
        end
    end
end

-------------------------------------------------------------------------------
-- Callbacks
-------------------------------------------------------------------------------
-- Event ADDON_LOADED
local function OnAddonLoaded(event, ...)
    if (... == addonSlug) then
        -- Get config data and store in table
        TrackingSwitcherCharacter = TrackingSwitcherCharacter or {}
        TrackingSwitcherCharacter.Abilities = {}
        TrackingSwitcherCharacter.Ticker = nil
        TrackingSwitcherCharacter.Index = 1
        TrackingSwitcherCharacter.Options = TrackingSwitcherCharacter.Options or defaultOptions

        printFromAddon('has loaded. To start, type /ts into the chat window.')
    end
end

-- Event PLAYER_LOGIN
local function OnPlayerLogin(event, ...)
    -- Collects and stores possible tracking Abilities into table
    UpdateAbilities()

    -- Try enable Mining or Herbalism as default
    EnableDefaultAbilities()
end

-- Event LOOT_OPENED or LOOT_CLOSED
local function OnLootEvent(event, ...)
    -- Toggle flag when loot is opened or closed
    IS_LOOTING = (event == "LOOT_OPENED")
end

-- Frame ONEVENT
local function OnEvent(self, event, ...)
    if (event == "ADDON_LOADED") then OnAddonLoaded(event, ...) end
    if (event == "PLAYER_LOGIN") then OnPlayerLogin(event, ...) end
    if (event == "LOOT_OPENED" or event == "LOOT_CLOSED") then OnLootEvent(event, ...) end
end

-- C_Timer.NewTicker ONTICKER (intervsal)
local function OnTicker(event, ...)
    SwitchAbility()
end

-------------------------------------------------------------------------------
-- Ticker
-------------------------------------------------------------------------------
local function TickerExists()
    return TrackingSwitcherCharacter.Ticker and not TrackingSwitcherCharacter.Ticker:IsCancelled()
end

local function StartTicker()
    -- Create Ticker if it doesn't already exist
    if (not TickerExists()) then
        printFromAddon("is starting, type /ts again to cancel.")

        TrackingSwitcherCharacter.Ticker = C_Timer.NewTicker(TrackingSwitcherCharacter.Interval, OnTicker)
    end
end

local function StopTicker()
    -- Check if Ticker exists
    if (TickerExists()) then
        printFromAddon("has been stopped, type /ts again to restart.")

        TrackingSwitcherCharacter.Ticker:Cancel()
    end
end

local function ToggleTicker()
    -- Check if Ticker exists and is on
    if (TickerExists()) then
        StopTicker()
    else
        StartTicker()
    end
end

-------------------------------------------------------------------------------
-- Event Frame
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("LOOT_OPENED")
eventFrame:RegisterEvent("LOOT_CLOSED")
eventFrame:SetScript("OnEvent", OnEvent)

-------------------------------------------------------------------------------
-- Interface Options
-------------------------------------------------------------------------------
local optionsFrame = CreateFrame("Frame")
optionsFrame.name = addonName
InterfaceOptions_AddCategory(optionsFrame)

local optionsTitle = optionsFrame:CreateFontString("ARTWORK", nil, "GameFontNormalLarge")
optionsTitle:SetPoint("TOPLEFT", 16, -16)
optionsTitle:SetText(addonName)

local optionsSound = CreateFrame("CheckButton", nil, optionsFrame, "InterfaceOptionsCheckButtonTemplate")
optionsSound:SetPoint("TOPLEFT", optionsTitle, "BOTTOMLEFT", 0, -8)
optionsSound.Text:SetText("Mute ability activation sound")
optionsSound.SetValue = function(_, value) TrackingSwitcherCharacter.Options.Mute = (value == "1") end
-- optionsSound:SetChecked(TrackingSwitcherCharacter.Options.Mute)

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
local function OnCommand(command)
    if (command == "config") then
        InterfaceOptionsFrame_OpenToCategory(optionsFrame)
    elseif (command == "debug 0") then
        DEBUG_MODE = false
    elseif (command == "debug 1") then
        DEBUG_MODE = true
    else
        ToggleTicker()
    end
end

SLASH_TRACKINGSWITCHER_CMD1 = "/ts"
SlashCmdList["TRACKINGSWITCHER_CMD"] = OnCommand