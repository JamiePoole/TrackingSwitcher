-- WoW Addons are passed through their Addon name (folder name) and
-- an empty global table shared across all Addon files on load
local addonName, ATS = ...

-------------------------------------------------------------------------------
-- Globals
-------------------------------------------------------------------------------

ATS.addonName = addonName
ATS.displayName = "Automatic Tracking Switcher"
ATS.slashCommand = "ats"
ATS.printColor = "#71D5FF"
ATS.ticker = nil
ATS.index = 1
ATS.defaultOptions = {
    debugMode = false,
    autoStart = true,
    mute = true,
    pauseSound = false,
    resumeSound = false,
    minimapPause = false,
    interval = 2,
    enabledAbilities = {},
}
ATS.frames = {}

-------------------------------------------------------------------------------
-- Flags
-------------------------------------------------------------------------------

local IS_LOOTING = false
local IS_AUTOREPEATING = false
local CURSOR_ON_MINIMAP = false
local HAS_PLAYED_PAUSE_SOUND = false

-------------------------------------------------------------------------------
-- Key Bindings
-------------------------------------------------------------------------------

BINDING_HEADER_ADDON_NAME = ATS.displayName
BINDING_NAME_TOGGLE = "Toggle On/Off"

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

-- Splits a string by separator, defaults to whitespace.
-- Attempts to mimic other languages `String.split`.
function ATS.Split(text, separator)
    -- Set default separator to any whitespace if none provided
    if (separator == nil) then separator = "%s" end

    local parts = {}

    for part in string.gmatch(text, "([^" .. separator .. "]+)") do
        table.insert(parts, part)
    end

    return parts
end

-- Unnecessary complication of official WoW API call: `WrapTextInColorCode()`.
-- Left it in as it provides some idiot-proof-ness for me later on if I forget.
-- https://github.com/Gethe/wow-ui-source/blob/classic/Interface/SharedXML/Color.lua#L59
function ATS.ColoredTextFromHex(hex, text)
    -- Remove Hash if present
    local nohash = string.gsub(hex, "^#", "")
    local valid = string.gsub(nohash, "[^a-fA-F0-9]", "")

    -- Fail if the Hex is now anything other than 6 (a valid hex color) or 8 (already contains alpha)
    assert(#valid == 6 or #valid == 8, "Hex string is invalid")

    -- Set 'FF' alpha as default, or use the first two characters from 8-char hex
    local alpha = "FF"
    if (#valid == 8) then alpha = string.sub(valid, 2) end

    -- Combine 'hex' with 'alpha'
    local color = tostring(alpha) .. tostring(valid)

    return WrapTextInColorCode(tostring(text), color)
end

-- Addon `print()` wrapper.
-- Concatenates the Addon 'display name' in color before the message.
function ATS.Print(message)
    print(ATS.ColoredTextFromHex(ATS.printColor, "[" .. ATS.displayName .. "]") .. " " .. message)
end

-- Addon debugging `print()` wrapper.
-- Concatenates the Addon 'display name' and 'debug' tag in color before the message.
function ATS.Debug(message)
    if (ATS_Character.options.debugMode) then
        ATS.Print(ATS.ColoredTextFromHex("#CCCC00", "[debug]") .. " " .. tostring(message))
    end
end

-------------------------------------------------------------------------------
-- Methods
-------------------------------------------------------------------------------

function ATS.UpdateAbilities()
    -- Reset existing values
    ATS_Character.abilities = {}

    -- WoW API `GetNumTrackingTypes`
    -- Gets all Tracking abilities (not just spells, but townspeople and trainers etc too)
    local numTrackingAbilities = GetNumTrackingTypes()

    for i = 1, numTrackingAbilities do
        local name, texture, active, category, nested = GetTrackingInfo(i)

        if (category == "spell") then
            local ability = {
                id = i,
                name = name,
                texture = texture
            }

            table.insert(ATS_Character.abilities, ability)
        end
    end

    -- Print number of tracking abilities info message
    ATS.Print("Found " .. tostring(#ATS_Character.abilities) .. " tracking " .. format("\1244ability:abilities", #ATS_Character.abilities) .. ".")
end

function ATS.EnableDefaultAbilities()
    -- Exit early if there are no available Abilities
    if (#ATS_Character.abilities == 0) then return end
    -- Exit early if there are already abilities enabled (not default)
    if (#ATS_Character.options.enabledAbilities > 0) then return end

    -- Reset Enabled Abilities for potential order of operations conflicts
    ATS_Character.options.enabledAbilities = {}

    -- Loop through available Abilties, search for Mining or Herbalism
    -- Mining and Herbalism are enabled by default if available
    for index, ability in ipairs(ATS_Character.abilities) do
        ATS.Debug(index .. ": " .. ability.name)

        if (ability.name == "Find Minerals") then
            table.insert(ATS_Character.options.enabledAbilities, ability)
        end

        if (ability.name == "Find Herbs") then
            table.insert(ATS_Character.options.enabledAbilities, ability)
        end
    end

    -- Debug output of the enabled abilities
    for index, ability in ipairs(ATS_Character.options.enabledAbilities) do
        ATS.Debug("Enabled [" .. ability.id .. "] '" .. ability.name .. "'")
    end
end

function ATS.CanSwitchTo(ability)
    -- Can only switch if the Tracking ability is not on cooldown
    local _, cooldownRemaining = GetSpellCooldown(ability.name)
    if (cooldownRemaining > 0) then ATS.Debug("The tracking spell is on cooldown") end

    -- Can only switch if the user is not casting an item or spell
    local currentCastingSpell = UnitCastingInfo("player")
    if (currentCastingSpell ~= nil) then ATS.Debug("Currently casting spell: " .. currentCastingSpell) end

    -- Can only switch if the user is not channeling a spell or item
    local channelling = UnitChannelInfo("player")
    if (channelling ~= nil) then ATS.Debug("Currently channelling an ability: " .. channelling) end
    
    -- Can only switch if the user doesn't have something on their cursor (left-click drag of loot or spell etc)
    local cursorType, cursorInfo1, cursorInfo2 = GetCursorInfo()
    if (cursorType ~= nil) then ATS.Debug("Cursor is currently active with: " .. cursorType) end

    -- Can only switch if the user is not looting
    local looting = IS_LOOTING
    if (looting) then ATS.Debug("Loot window currently open") end

    -- Can only switch if the user is not in an auto-repeat cast (Wand Shoot etc)
    local autorepeating = IS_AUTOREPEATING
    if (autorepeating) then ATS.Debug("Currently auto-repeating a cast") end

    -- Can only switch if the user isn't in targeting mode (free-aim like Blizzard or some throwable items usually bombs)
    local targeting = SpellIsTargeting()
    if (targeting) then ATS.Debug("User currently targeting") end

    -- Check if the user has set the Addon option to not switch while cursor is on the minimap
    local hovering = ATS_Character.options.minimapPause and CURSOR_ON_MINIMAP
    if (hovering) then ATS.Debug("Cursor is over minimap") end

    return (cooldownRemaining == 0) and (currentCastingSpell == nil) and (channelling == nil) and (cursorType == nil) and (not looting) and (not autorepeating) and (not targeting) and (not hovering)
end

function ATS.GetValidatedTrackingId(ability)
    -- For some reason GetTrackingInfo()'s ID changes from the original GetNumTrackingTypes() order
    -- So we need to check that this ability we are about to activate matches the index it will use
    local name = GetTrackingInfo(ability.id)

    -- If the Tracker this ID corresponds to matches the name of the ability we are expecting, exit early
    if (ability.name == name) then return ability.id end

    -- Otherwise, the name of the ability we think we're casting does NOT match this ID
    -- We need to search for it again and update this abilities ID property
    for i = 1, GetNumTrackingTypes() do
        local trackerName = GetTrackingInfo(i)

        -- Find the current ability again
        if (trackerName == ability.name) then
            -- Update this abilities Id to the appropriate index
            ability.id = i
        end
    end

    return ability.id
end

function ATS.SwitchAbility()
    -- Exit early and cancel Ticker if there are no enabled Abilities for this character (via Interface Options)
    if (not ATS_Character.options.enabledAbilities or #ATS_Character.options.enabledAbilities < 2) then
        -- If there is one selected, first switch to that tracker before exiting early
        if (ATS_Character.options.enabledAbilities and ATS_Character.options.enabledAbilities[1] ~= nil) then
            local ability = ATS_Character.options.enabledAbilities[1]

            ability.id = ATS.GetValidatedTrackingId(ability)

            SetTracking(ability.id, true)
        end

        -- Stop Ticker / Cleanup
        ATS.StopTicker(true)

        ATS.Print("Less than 2 trackers are enabled so Automatic Tracking Switcher has been turned off. To start again, enable another Tracker in the Interface Options and type /" .. ATS.slashCommand .. " start")
        return
    end

    local ability = ATS_Character.options.enabledAbilities[ATS.index]

    -- Only switch and move index forward if allowed to cast/use tracking ability
    if (ability ~= nil and ATS.CanSwitchTo(ability)) then
        -- If the Addon option 'Mute default sound' is true
        -- Sound file ID `567407: sound/interface/uchatscrollbutton.ogg`
        -- While highly unlikely, muting this may unintentionally mute some other events made at the exact moment of switching
        if (ATS_Character.options.mute) then MuteSoundFile(567407) end

        -- We need to validate the Tracking ID is still the same
        -- As there was a witnessed bug where the SetTracking ID had changed during runtime
        ability.id = ATS.GetValidatedTrackingId(ability)

        -- WoW API `SetTracking(trackingId, enable)`
        -- Sets Tracker to Index (not spell ID, but index from `GetTrackingInfo()`)
        SetTracking(ability.id, true)

        -- Unmute the sound effect if the option was enabled
        if (ATS_Character.options.mute) then UnmuteSoundFile(567407) end

        -- If the user has set the 'Play on Pause' option AND the 'Play sound on Resume', play sound now if Pause sound already made
        -- Sound file ID `567432: sound/interface/placeholder.ogg`
        if (HAS_PLAYED_PAUSE_SOUND and ATS_Character.options.resumeSound) then PlaySoundFile(567432, "SFX") end

        -- Reset the 'Play on Pause' single-use flag
        HAS_PLAYED_PAUSE_SOUND = false

        -- Progress this Index, loop back to 1 at end
        if (ATS.index == #ATS_Character.options.enabledAbilities) then
            ATS.index = 1
        else
            ATS.index = ATS.index + 1
        end
    -- If we can't switch, we are 'paused'
    else
        -- Check for Play Sound on Pause option
        -- Check the flag so we only play this sound once per pause
        if (ATS_Character.options.pauseSound and not HAS_PLAYED_PAUSE_SOUND) then
            -- Sound file ID `567415: sound/interface/error.ogg`
            PlaySoundFile(567415, "SFX")

            HAS_PLAYED_PAUSE_SOUND = true
        end
    end
end

-------------------------------------------------------------------------------
-- Callbacks
-------------------------------------------------------------------------------

-- Event ADDON_LOADED
function ATS.OnAddonLoaded(event, ...)
    if (... == ATS.addonName) then
        -- Get config data and store in table
        ATS_Character = ATS_Character or {}
        ATS_Character.abilities = {}
        ATS_Character.options = ATS_Character.options or CopyTable(ATS.defaultOptions)

        -- Add Minimap Hook for 'Pause on minimap hover' option monitoring
        Minimap:HookScript("OnEnter", ATS.MinimapEnter)
        Minimap:HookScript("OnLeave", ATS.MinimapLeave)

        ATS.Print("has loaded. To start, type /" .. ATS.slashCommand .. " into the chat window.")
    end
end

-- Event PLAYER_LOGIN
function ATS.OnPlayerLogin(event, ...)
    -- Collects and stores possible tracking Abilities into table
    ATS.UpdateAbilities()

    -- Try enable Mining or Herbalism as default
    ATS.EnableDefaultAbilities()

    -- Create Interface Options Widget UI
    ATS.CreateInterfaceOptions()

    -- If the `autostart` option is set, start the ticker
    if (ATS_Character.options.autoStart) then ATS.StartTicker() end
end

-- Event LOOT_OPENED or LOOT_CLOSED
function ATS.OnLootEvent(event, ...)
    -- Toggle flag when loot is opened or closed
    IS_LOOTING = (event == "LOOT_OPENED")
end

-- Event START_AUTOREPEAT_SPELL or STOP_AUTOREPEAT_SPELL
function ATS.OnAutoRepeatEvent(event, ...)
    -- Toggle flag while firing auto-repeat spell
    IS_AUTOREPEATING = (event == "START_AUTOREPEAT_SPELL")
end

-- Frame ONEVENT
function ATS.OnEvent(self, event, ...)
    if (event == "ADDON_LOADED") then ATS.OnAddonLoaded(event, ...) end
    if (event == "PLAYER_LOGIN") then ATS.OnPlayerLogin(event, ...) end
    if (event == "LOOT_OPENED" or event == "LOOT_CLOSED") then ATS.OnLootEvent(event, ...) end
    if (event == "START_AUTOREPEAT_SPELL" or event == "STOP_AUTOREPEAT_SPELL") then ATS.OnAutoRepeatEvent(event, ...) end
end

-- C_Timer.NewTicker ONTICKER (intervsal)
function ATS.OnTicker(event, ...)
    ATS.SwitchAbility()
end

-- Minimap ONENTER
function ATS.MinimapEnter(event, ...)
    CURSOR_ON_MINIMAP = true
end

-- Minimap ONLEAVE
function ATS.MinimapLeave(event, ...)
    CURSOR_ON_MINIMAP = false
end

-------------------------------------------------------------------------------
-- Ticker
-------------------------------------------------------------------------------

function ATS.TickerExists()
    return ATS.ticker and not ATS.ticker:IsCancelled()
end

function ATS.StartTicker(silent)
    -- Create Ticker if it doesn't already exist
    if (not ATS.TickerExists()) then
        if (not silent) then ATS.Print("is starting, type /" .. ATS.slashCommand .. " again to cancel.") end

        ATS.ticker = C_Timer.NewTicker(ATS_Character.options.interval, ATS.OnTicker)
    end
end

function ATS.StopTicker(silent)
    -- Check if Ticker exists
    if (ATS.TickerExists()) then
        if (not silent) then ATS.Print("has been stopped, type /" .. ATS.slashCommand .. " again to restart.") end

        ATS.ticker:Cancel()
    end
end

function ATS.ToggleTicker()
    -- Check if Ticker exists and is on
    if (ATS.TickerExists()) then
        ATS.StopTicker()
    else
        ATS.StartTicker()
    end
end

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
ATS.commandList = {
    options = {
        description = "Show the Interface Options panel",
        callback = function(parameter) InterfaceOptionsFrame_OpenToCategory(ATS.frames.options.panel) end
    },
    debug = {
        description = "Set to 0 (off) or 1 (on) to display debug messages in the chat window",
        callback = function(parameter) 
            ATS_Character.options.debugMode = (parameter == "1" or parameter == 1)
            ATS.Print("Debug mode " .. (ATS_Character.options.debugMode and "on" or "off") .. ".")
        end
    },
    start = {
        description = "Start switching trackers if 2 or more are available",
        callback = function(parameter) ATS.StartTicker() end
    },
    stop = {
        description = "Stop switching trackers",
        callback = function(parameter) ATS.StopTicker() end
    }
}

function ATS.OnCommand(text)
    local arguments = ATS.Split(text, "%s")
    local command = arguments[1]
    local parameter = arguments[2]

    if (ATS.commandList[command] ~= nil) then
        ATS.commandList[command].callback(parameter)
    else
        ATS.Print("Slash Commands:")

        for key, value in pairs(ATS.commandList) do
            ATS.Print(ATS.ColoredTextFromHex("#FFCC00", key) .. ": " .. value.description)
        end
    end
end

SLASH_AUTOMATICTRACKINGSWITCHER_CMD1 = "/" .. ATS.slashCommand
SlashCmdList["AUTOMATICTRACKINGSWITCHER_CMD"] = ATS.OnCommand

-------------------------------------------------------------------------------
-- Event Frame
-------------------------------------------------------------------------------

ATS.frames.events = CreateFrame("Frame")
ATS.frames.events:RegisterEvent("ADDON_LOADED")
ATS.frames.events:RegisterEvent("PLAYER_LOGIN")
ATS.frames.events:RegisterEvent("LOOT_OPENED")
ATS.frames.events:RegisterEvent("LOOT_CLOSED")
ATS.frames.events:RegisterEvent("START_AUTOREPEAT_SPELL")
ATS.frames.events:RegisterEvent("STOP_AUTOREPEAT_SPELL")
ATS.frames.events:SetScript("OnEvent", ATS.OnEvent)