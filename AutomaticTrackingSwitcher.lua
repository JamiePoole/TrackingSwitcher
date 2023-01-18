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
    pauseInCombat = false,
    pauseInDungeons = false,
    pauseInRaids = true,
    pauseInPvP = true,
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
local LISTEN_FOR_SPELLS_CHANGED = false

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
    local numTrackingAbilities = C_Minimap.GetNumTrackingTypes()

    -- Rebuild ability table with Tracker information
    for i = 1, numTrackingAbilities do
        local name, texture, active, category, nested = C_Minimap.GetTrackingInfo(i)

        -- If a 'spell' (as opposed to a Townsperson or Trainer etc)
        if (category == "spell") then
            -- Check if the Spell uses the GCD (gcd will be an integer greater than 0)
            local cd, gcd = GetSpellBaseCooldown(name)

            local ability = {
                id = i,
                name = name,
                texture = texture,
                gcd = (gcd > 0)
            }

            table.insert(ATS_Character.abilities, ability)
        end
    end

    -- Sync the enabled abilities to ensure any unlearned abilities still exist
    ATS.RemovedUnlearnedEnabledAbilities()

    -- Rebuild the 'Abilities' section of the Interface Options panel
    ATS.BuildInterfaceOptionsAbilities()

    -- Print number of tracking abilities info message
    ATS.Print("Found " .. tostring(#ATS_Character.abilities) .. " tracking " .. format("\1244ability:abilities", #ATS_Character.abilities) .. ".")
end

function ATS.IsTrackingSpell(identifier)
    -- WoW API `C_Minimap.GetNumTrackingTypes`
    -- Gets all Tracking abilities (not just spells, but townspeople and trainers etc too)
    local numTrackingAbilities = C_Minimap.GetNumTrackingTypes()
    local isTracker = false

    -- Attempt to find ability in Tracking list based on identifer
    for i = 1, numTrackingAbilities do
        local trackerName, _ = C_Minimap.GetTrackingInfo(i)
        local spellName, _ = GetSpellInfo(identifier)

        if (spellName == trackerName) then isTracker = true end
    end

    -- ATS.Debug("Was Spell '" .. identifier .. "' a Tracker? " .. (isTracker and ATS.ColoredTextFromHex("#00EE00", "YES") or ATS.ColoredTextFromHex("#CC0000", "NO")))

    return isTracker
end

function ATS.RemovedUnlearnedEnabledAbilities()
    -- If there are any abilities at all
    if (#ATS_Character.abilities > 0 and #ATS_Character.options.enabledAbilities > 0) then
        -- Loop through enabled abilities
        for i, enabledAbility in ipairs(ATS_Character.options.enabledAbilities) do
            -- Check if enabled ability still exists/is learned
            local exists = false

            -- By looping through actual learned abilities and seeing if this enabled one exists
            -- This requires `ATS.UpdateAbilities()` has ran first and updated the learned abilities list
            for j, learnedAbility in ipairs(ATS_Character.abilities) do
                if (learnedAbility.name == enabledAbility.name) then exists = true end
            end

            -- If the `exists` flag is still false, then this enabled ability was not found in the list of learned abilities
            -- So delete it from the enabled abilities list
            if (not exists) then
                ATS.Print("Removing enabled ability '" .. ATS.ColoredTextFromHex("#CC0000", "[" .. enabledAbility.name .. "]") .. "' as it is no longer available.")

                -- table.remove() is apparently not recommended for LUA for performance reasons
                -- But as we are only removing 1 entry from a max of 10 or so possible loops, it will be fine
                table.remove(ATS_Character.options.enabledAbilities, i)
            end
        end
    end
end

function ATS.GetDefaultAbilities(force)
    -- Exit early if there are no available Abilities
    if (#ATS_Character.abilities == 0) then return ATS.defaultOptions.enabledAbilities end
    -- Exit early if there are already abilities enabled (not default)
    -- The force flag can skip this check
    if (not force and #ATS_Character.options.enabledAbilities > 0) then return ATS_Character.options.enabledAbilities end

    -- Create a local returned Enabled Abilities table
    local enabledAbilities = {}

    -- Loop through available Abilties, search for Mining or Herbalism
    -- Mining and Herbalism are enabled by default if available
    for index, ability in ipairs(ATS_Character.abilities) do
        if (ability.name == "Find Minerals") then
            table.insert(enabledAbilities, ability)
        end

        if (ability.name == "Find Herbs") then
            table.insert(enabledAbilities, ability)
        end
    end

    -- Debug output of the enabled abilities
    for index, ability in ipairs(enabledAbilities) do
        ATS.Debug("Default Found [" .. ability.id .. "] '" .. ability.name .. "'")
    end

    return enabledAbilities
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

    -- Can only switch if the cursor is not on the minimap (if option enabled)
    local hovering = ATS_Character.options.minimapPause and CURSOR_ON_MINIMAP
    if (hovering) then ATS.Debug("Cursor is over minimap") end

    -- Can only switch if the user is not in combat (if option enabled)
    local inCombat = ATS_Character.options.pauseInCombat and InCombatLockdown()
    if (inCombat) then ATS.Debug("User in combat") end

    -- Can only switch if the user is not in a party dungeon (if option enabled)
    local inInstance, instanceType = IsInInstance()
    local inDungeon = ATS_Character.options.pauseInDungeons and (inInstance and instanceType == "party")
    if (inDungeon) then ATS.Debug("User in dungeon instance") end

    -- Can only switch if the user is not in a raid dungeon (if option enabled)
    local inRaid = ATS_Character.options.pauseInRaids and (inInstance and instanceType == "raid")
    if (inRaid) then ATS.Debug("User in raid instance") end

    -- Can only switch if the user is not in Arena or Battleground (if option enabled)
    local inPvP = ATS_Character.options.pauseInPvP and (inInstance and (instanceType == "pvp" or instanceType == "arena"))
    if (inPvP) then ATS.Debug("User is in a Battleground or Arena") end

    return
        (cooldownRemaining == 0)
        and (currentCastingSpell == nil)
        and (channelling == nil)
        and (cursorType == nil)
        and (not looting)
        and (not autorepeating)
        and (not targeting)
        and (not hovering)
        and (not inCombat)
        and (not inDungeon)
        and (not inRaid)
        and (not inPvP)
end

function ATS.GetValidatedTrackingId(ability)
    -- For some reason C_Minimap.GetTrackingInfo()'s ID changes from the original GetNumTrackingTypes() order
    -- So we need to check that this ability we are about to activate matches the index it will use
    local name = C_Minimap.GetTrackingInfo(ability.id)

    -- If the Tracker this ID corresponds to matches the name of the ability we are expecting, exit early
    if (ability.name == name) then return ability.id end

    -- Otherwise, the name of the ability we think we're casting does NOT match this ID
    -- We need to search for it again and update this abilities ID property
    for i = 1, C_Minimap.GetNumTrackingTypes() do
        local trackerName = C_Minimap.GetTrackingInfo(i)

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
        -- If there is only one selected, first switch to that tracker before exiting early
        if (ATS_Character.options.enabledAbilities and ATS_Character.options.enabledAbilities[1] ~= nil) then

        local ability = ATS_Character.options.enabledAbilities[1]

            ability.id = ATS.GetValidatedTrackingId(ability)

            C_Minimap.SetTracking(ability.id, true)
        end

        -- Stop Ticker / Cleanup
        ATS.StopTicker(true)

        ATS.Print("Less than 2 trackers are enabled so switching has been turned off. To start again, enable another Tracker in the Interface Options and type " .. ATS.ColoredTextFromHex("#FFCC00", "/" .. ATS.slashCommand .. " start"))

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
        -- Sets Tracker to Index (not spell ID, but index from `C_Minimap.GetTrackingInfo()`)
        C_Minimap.SetTracking(ability.id, true)

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
    -- Create Interface Options Widget UI
    ATS.CreateInterfaceOptions()

    -- Collects and stores possible tracking Abilities into table
    ATS.UpdateAbilities()

    -- Actions for first run
    if (not ATS_Character.runOnce) then
        ATS.Debug("Initial Setup")

        -- Try enable Mining or Herbalism as default
        ATS_Character.options.enabledAbilities = ATS.GetDefaultAbilities()

        ATS_Character.runOnce = true
    end

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

-- Event CHAT_MSG_SYSTEM
function ATS.OnSystemChatEvent(event, ...)
    local message = ...

    -- Exit early if no message (unlikely to be a case)
    if (message == "" or message == nil) then return end

    -- Check that this message is for an `You have unlearned` 'error' event
    -- This will be in the form of a global WoW Error code: `ERR_SPELL_UNLEARNED_S`
    -- Capture whatever ability/spell it references
    local unlearnedRegex = ERR_SPELL_UNLEARNED_S:gsub("%%s", "(.*)")
    local unlearnedAbility = message:match(unlearnedRegex)

    -- If the match correctly found an ability name
    -- And it is a tracking ability
    if (unlearnedAbility ~= nil and ATS.IsTrackingSpell(unlearnedAbility)) then
        -- Unfortunately there is no event to listen for when an ability is unlearned.
        -- The CHAT_MSG_SYSTEM event is fired BEFORE the ability is technically removed from the users spellbook.
        -- So simply running `ATS.UpdateAbilities()` now would still return the previous list of abilities
        -- including the one we think we just unlearned. So instead we now set this flag to true,
        -- and the next `SPELLS_CHANGED` event that fires we can run `ATS.UpdateAbilities()`
        LISTEN_FOR_SPELLS_CHANGED = true
    end
end

-- Event LEARNED_SPELL_IN_TAB
function ATS.OnLearnedSpellEvent(event, ...)
    local spellId, _ = ...

    -- Check that the learned spell was a Tracker
    if (ATS.IsTrackingSpell(spellId)) then
        ATS.UpdateAbilities()
    end
end

-- Event SPELLS_CHANGED
function ATS.OnSpellsChanged(event, ...)
    -- Exit early if the flag `LISTEN_FOR_SPELLS_CHANGED` is not set to `true`
    -- This is set to `true` in response to an ability being unlearned,
    -- triggered by parsing the system chat messages
    if (not LISTEN_FOR_SPELLS_CHANGED) then return end

    -- Update the Tracking Abilities list and sync with enabled abilities
    ATS.UpdateAbilities()

    -- Turn off the flag so that this event is only fired once after the player unlearns an ability
    LISTEN_FOR_SPELLS_CHANGED = false
end

-- Frame ONEVENT
function ATS.OnEvent(self, event, ...)
    if (event == "ADDON_LOADED") then ATS.OnAddonLoaded(event, ...) end
    if (event == "PLAYER_LOGIN") then ATS.OnPlayerLogin(event, ...) end
    if (event == "LOOT_OPENED" or event == "LOOT_CLOSED") then ATS.OnLootEvent(event, ...) end
    if (event == "START_AUTOREPEAT_SPELL" or event == "STOP_AUTOREPEAT_SPELL") then ATS.OnAutoRepeatEvent(event, ...) end
    if (event == "CHAT_MSG_SYSTEM") then ATS.OnSystemChatEvent(event, ...) end
    if (event == "LEARNED_SPELL_IN_TAB") then ATS.OnLearnedSpellEvent(event, ...) end
    if (event == "SPELLS_CHANGED") then ATS.OnSpellsChanged(event, ...) end
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
        if (not silent) then ATS.Print("Starting, type " .. ATS.ColoredTextFromHex("#FFCC00", "/" .. ATS.slashCommand .. " stop") .. " to cancel.") end

        ATS.ticker = C_Timer.NewTicker(ATS_Character.options.interval, ATS.OnTicker)
    end
end

function ATS.StopTicker(silent)
    -- Check if Ticker exists
    if (ATS.TickerExists()) then
        if (not silent) then ATS.Print("Stopped, type " .. ATS.ColoredTextFromHex("#FFCC00", "/" .. ATS.slashCommand .. " stop") .. " to restart.") end

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
ATS.frames.events:RegisterEvent("CHAT_MSG_SYSTEM")
ATS.frames.events:RegisterEvent("LEARNED_SPELL_IN_TAB")
ATS.frames.events:RegisterEvent("SPELLS_CHANGED")
ATS.frames.events:SetScript("OnEvent", ATS.OnEvent)