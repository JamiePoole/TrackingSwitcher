-------------------------------------------------------------------------------
-- Globals
-------------------------------------------------------------------------------
local addonSlug = "TrackingSwitcher"
local addonName = "Tracking Switcher"

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

    -- Fail if the Hex is now shorter than 6 (too many illegal values) or greater than 8 (just wrong)
    assert(#valid == 6 or #valid == 8, "Hex string is invalid")

    -- Set 'FF' alpha as default, or use the last two characters from 8-char hex
    local alpha = "FF"
    if (#valid == 8) then alpha = string.sub(valid, -2) end

    -- Combine 'hex' with 'alpha'
    local color = tostring(valid) .. tostring(alpha)

    return "|c" .. color .. tostring(text) .. "|r"
end

local function printMessage(message)
    print(makeColoredTextFromHex("#FF71D5", "[Tracking Switcher]") .. " " .. message)
end

-------------------------------------------------------------------------------
-- Methods
-------------------------------------------------------------------------------
local function UpdateAbilities()
    -- Reset existing values
    TrackingSwitcherCharacter.Abilities = {}

    -- WoW API `GetNumTrackingTypes`
    -- 
    local numTrackingAbilities = GetNumTrackingTypes()

    for i = 1, numTrackingAbilities do
        local name, texture, active, category, nested = GetTrackingInfo(i)

        if (category == "spell") then
            local ability = {
                name = name,
                texture = texture
            }

            table.insert(TrackingSwitcherCharacter.Abilities, ability)
        end
    end

    -- Print number of tracking abilities info message
    printMessage("has found " .. tostring(#TrackingSwitcherCharacter.Abilities) .. " tracking " .. format("\1244ability:abilities", #TrackingSwitcherCharacter.Abilities) .. ".")
end

local function IsSwitching()
    return TrackingSwitcherCharacter.Tracking
end

local function StartTimer()
    if (not IsSwitching()) then
        -- TODO
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
        TrackingSwitcherCharacter.Tracking = false

        printMessage('has loaded. To start, type /ts into the chat window.')
    end
end

-- Event PLAYER_LOGIN
local function OnPlayerLogin(event, ...)
    UpdateAbilities()
end

-- Frame ONEVENT
local function OnEvent(self, event, ...)
    if (event == "ADDON_LOADED") then OnAddonLoaded(event, ...) end
    if (event == "PLAYER_LOGIN") then OnPlayerLogin(event, ...) end
end

-- Slash Command
local function OnCommand(message)
    printMessage("slash command has been invoked.")
end

-------------------------------------------------------------------------------
-- Main
-------------------------------------------------------------------------------
-- Instantiate Event Frame
local eventFrame = CreateFrame("Frame");
eventFrame:RegisterEvent("ADDON_LOADED");
eventFrame:RegisterEvent("PLAYER_LOGIN");
eventFrame:SetScript("OnEvent", OnEvent);

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
SLASH_TRACKINGSWITCHER_CMD1 = "/ts"
SlashCmdList["TRACKINGSWITCHER_CMD"] = OnCommand