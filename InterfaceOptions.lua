-- WoW Addons are passed through their Addon name (folder name) and
-- an empty global table shared across all Addon files on load
local addonName, ATS = ...

-------------------------------------------------------------------------------
-- Interface Options
-------------------------------------------------------------------------------

function ATS.CreateInterfaceOptions()
    -- Create a container for all the Interface Options elements
    ATS.frames.options = {}

    -- Create a temporary options table, to hold reference to the option states
    -- until 'permanent' changes are made when the 'Okay' button is clicked.
    -- This is so the user can click 'Defaults' and have the option states revert to pre-defined default values.
    ATS.frames.options.temporaryValues = CopyTable(ATS_Character.options)

    -- The main Interface Options panel
    ATS.frames.options.panel = CreateFrame("Frame")
    ATS.frames.options.panel.name = ATS.displayName

    -- WoW API call to add the panel to official 'Interface Options' window
    InterfaceOptions_AddCategory(ATS.frames.options.panel)

    -- Custom properties to store the default padding and margin for options
    ATS.frames.options.padding = 16
    ATS.frames.options.margin = 32

    -- Create a Scrolling frame container
    ATS.frames.options.scrollFrame = CreateFrame("ScrollFrame", nil, ATS.frames.options.panel, "UIPanelScrollFrameTemplate")
    ATS.frames.options.scrollFrame:SetPoint("TOPLEFT", 3, -4)
    ATS.frames.options.scrollFrame:SetPoint("BOTTOMRIGHT", -27, 4)

    -- Create a content child frame for the scroll container
    ATS.frames.options.content = CreateFrame("Frame")
    ATS.frames.options.content:SetWidth(InterfaceOptionsFramePanelContainer:GetWidth() - 18)
    ATS.frames.options.content:SetHeight(1)
    ATS.frames.options.scrollFrame:SetScrollChild(ATS.frames.options.content)

    -- The title `FontString` on the panel
    ATS.frames.options.title = ATS.frames.options.content:CreateFontString("ARTWORK", nil, "GameFontNormalLarge")
    ATS.frames.options.title:SetPoint("TOPLEFT", ATS.frames.options.padding, -ATS.frames.options.padding)
    ATS.frames.options.title:SetText(ATS.displayName)

    -- Create the Interval value slider.
    -- Align the label/text to the left.
    -- On change, update the text box (editboxInterval)
    ATS.frames.options.sliderInterval = CreateFrame("Slider", "ATS_Options_Interval", ATS.frames.options.content, "OptionsSliderTemplate")
    ATS.frames.options.sliderInterval.Text = _G[ATS.frames.options.sliderInterval:GetName() .. "Text"]
    ATS.frames.options.sliderInterval.Low = _G[ATS.frames.options.sliderInterval:GetName() .. "Low"]
    ATS.frames.options.sliderInterval.High = _G[ATS.frames.options.sliderInterval:GetName() .. "High"]
    ATS.frames.options.sliderInterval.Min = 2
    ATS.frames.options.sliderInterval.Max = 15
    ATS.frames.options.sliderInterval.Step = 0.5
    ATS.frames.options.sliderInterval:SetPoint("TOPLEFT", ATS.frames.options.title, 6, (-ATS.frames.options.margin*1.5))
    ATS.frames.options.sliderInterval:SetWidth(ATS.frames.options.content:GetWidth() - ATS.frames.options.padding - 84)
    ATS.frames.options.sliderInterval:SetMinMaxValues(ATS.frames.options.sliderInterval.Min, ATS.frames.options.sliderInterval.Max)
    ATS.frames.options.sliderInterval:SetValue(tonumber(string.format("%.2f", ATS.frames.options.temporaryValues.interval)))
    ATS.frames.options.sliderInterval:SetValueStep(ATS.frames.options.sliderInterval.Step)
    ATS.frames.options.sliderInterval:SetObeyStepOnDrag(true)
    ATS.frames.options.sliderInterval.Text:SetPoint("LEFT", ATS.frames.options.sliderInterval, 0, 0)
    ATS.frames.options.sliderInterval.Text:SetJustifyH("LEFT")
    ATS.frames.options.sliderInterval.Text:SetText("Switch Interval (in seconds)")
    ATS.frames.options.sliderInterval.Low:SetText(ATS.frames.options.sliderInterval.Min)
    ATS.frames.options.sliderInterval.High:SetText(ATS.frames.options.sliderInterval.Max)
    ATS.frames.options.sliderInterval:SetScript("OnValueChanged", function(self, value) ATS.frames.options.editboxInterval:SetText(tonumber(string.format("%.2f", value))) end)

    -- Create the Interval value text box.
    -- Reflects the value of the slider.
    -- Must set `AutoFocus` to `false` or it takes over control from chat window.
    -- TODO: Cannot type in decimals to truly enter in a manual value.
    -- TODO: Cannot type in a number that starts in 1 (10, 11, 12 etc)
    ATS.frames.options.editboxInterval = CreateFrame("EditBox", "ATS_Options_Interval_Edit", ATS.frames.options.sliderInterval, "InputBoxTemplate")
    ATS.frames.options.editboxInterval:SetPoint("TOPRIGHT", ATS.frames.options.sliderInterval, 60, 0)
    ATS.frames.options.editboxInterval:SetWidth(42)
    ATS.frames.options.editboxInterval:SetHeight(20)
    ATS.frames.options.editboxInterval:SetAutoFocus(false)
    ATS.frames.options.editboxInterval:SetMaxLetters(4)
    ATS.frames.options.editboxInterval:SetJustifyH("CENTER")
    ATS.frames.options.editboxInterval:SetText(ATS.frames.options.temporaryValues.interval)
    ATS.frames.options.editboxInterval:SetCursorPosition(0)
    ATS.frames.options.editboxInterval:SetScript("OnTextChanged", function(self)
        -- Make sure the current text/value is a number (will return `fail` otherwise)
        local number = tonumber(self:GetText())

        -- If it isn't a number, reset the value to the defined slider value
        if (not number) then self:SetText(ATS.frames.options.sliderInterval:GetValue()) end
    end)
    ATS.frames.options.editboxInterval:SetScript("OnEnterPressed", function(self)
        -- Make sure the current text/value is a number (will return `fail` otherwise)
        local number = tonumber(self:GetText())

        -- If it wasn't a number, don't make the change, revert text to the Interval value
        if (not number) then number = ATS.frames.options.sliderInterval:GetValue() end

        -- Check that even if it is a number, it fits within the min/max values
        if (number < ATS.frames.options.sliderInterval.Min) then number = ATS.frames.options.sliderInterval.Min end
        if (number > ATS.frames.options.sliderInterval.Max) then number = ATS.frames.options.sliderInterval.Max end

        -- Format the number now to be a float to 1 place
        local value = tonumber(string.format("%.2f", number))

        -- Set the new text to the formatted number, and the value of the interval slider
        self:SetText(value)
        ATS.frames.options.sliderInterval:SetValue(value)

        -- Clear the Focus from this element
        self:ClearFocus()
    end)
    ATS.frames.options.editboxInterval:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Create the CheckButton for the `Autostart` option
    ATS.frames.options.checkboxAutostart = CreateFrame("CheckButton", "ATS_Options_Autostart", ATS.frames.options.content, "InterfaceOptionsCheckButtonTemplate")
    ATS.frames.options.checkboxAutostart.Text:SetText("Start switching on login")
    ATS.frames.options.checkboxAutostart:SetPoint("TOPLEFT", ATS.frames.options.sliderInterval, -12, -(ATS.frames.options.margin * 1.5))
    ATS.frames.options.checkboxAutostart:SetChecked(ATS.frames.options.temporaryValues.autoStart)

    -- Create the CheckButton for the `Mute Sound Effect` option
    ATS.frames.options.checkboxMute = CreateFrame("CheckButton", "ATS_Options_Mute", ATS.frames.options.content, "InterfaceOptionsCheckButtonTemplate")
    ATS.frames.options.checkboxMute.Text:SetText("Mute default switching sound")
    ATS.frames.options.checkboxMute:SetPoint("TOPLEFT", ATS.frames.options.checkboxAutostart, 0, -ATS.frames.options.margin)
    ATS.frames.options.checkboxMute:SetChecked(ATS.frames.options.temporaryValues.mute)

    -- Create the CheckButton for the `Play Sound on Pause` option
    ATS.frames.options.checkboxPauseSound = CreateFrame("CheckButton", "ATS_Options_PauseSound", ATS.frames.options.content, "InterfaceOptionsCheckButtonTemplate")
    ATS.frames.options.checkboxPauseSound.Text:SetText("Play sound when switching is paused")
    ATS.frames.options.checkboxPauseSound:SetPoint("TOPLEFT", ATS.frames.options.checkboxMute, 0, -ATS.frames.options.margin)
    ATS.frames.options.checkboxPauseSound:SetChecked(ATS.frames.options.temporaryValues.pauseSound)
    ATS.frames.options.checkboxPauseSound:HookScript("OnClick", function(self) ATS.frames.options.checkboxResumeSound:SetEnabled(self:GetChecked()) end)

    -- Create the CheckButton for the `Play Sound on Resuming` option
    ATS.frames.options.checkboxResumeSound = CreateFrame("CheckButton", "ATS_Options_ResumeSound", ATS.frames.options.content, "InterfaceOptionsCheckButtonTemplate")
    ATS.frames.options.checkboxResumeSound.Text:SetText("Play sound once switching resumes")
    ATS.frames.options.checkboxResumeSound:HookScript("OnDisable", function(self) self:SetAlpha(0.25) end)
    ATS.frames.options.checkboxResumeSound:HookScript("OnEnable", function(self) self:SetAlpha(1.0) end)
    ATS.frames.options.checkboxResumeSound:SetPoint("TOPLEFT", ATS.frames.options.checkboxPauseSound, ATS.frames.options.margin, -ATS.frames.options.margin)
    ATS.frames.options.checkboxResumeSound:SetChecked(ATS.frames.options.temporaryValues.resumeSound)
    ATS.frames.options.checkboxResumeSound:SetEnabled(ATS.frames.options.checkboxPauseSound:GetChecked())

    -- Create the CheckButton for the `Pause while cursor on minimap` option
    ATS.frames.options.checkboxMinimapPause = CreateFrame("CheckButton", "ATS_Options_MinimapPause", ATS.frames.options.content, "InterfaceOptionsCheckButtonTemplate")
    ATS.frames.options.checkboxMinimapPause.Text:SetText("Pause switching when cursor is over the minimap")
    ATS.frames.options.checkboxMinimapPause:SetPoint("TOPLEFT", ATS.frames.options.checkboxResumeSound, -ATS.frames.options.margin, -ATS.frames.options.margin)
    ATS.frames.options.checkboxMinimapPause:SetChecked(ATS.frames.options.temporaryValues.minimapPause)

    -- Section title `FontString` for the available abilities frame
    ATS.frames.options.abilitySectionTitle = ATS.frames.options.content:CreateFontString("ARTWORK", nil, "GameFontNormal")
    ATS.frames.options.abilitySectionTitle:SetPoint("TOPLEFT", ATS.frames.options.checkboxMinimapPause, (ATS.frames.options.padding / 2), (-ATS.frames.options.margin * 1.5))
    ATS.frames.options.abilitySectionTitle:SetText("Enabled Tracking Abilities")

    -- Create the sub-section frame to hold the list of enabled abilities
    ATS.frames.options.enabledAbilities = CreateFrame("Frame", "ATS_Options_EnabledAbilities", ATS.frames.options.content, BackdropTemplateMixin and "BackdropTemplate")
    ATS.frames.options.enabledAbilities:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", 
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
        tile = true, tileSize = 16, edgeSize = 16, 
        insets = { left = 4, right = 4, top = 4, bottom = 4 }})
    ATS.frames.options.enabledAbilities:SetBackdropBorderColor(1, 1, 1, 1.0);
    ATS.frames.options.enabledAbilities:SetBackdropColor(0, 0, 0, 0.0);
    ATS.frames.options.enabledAbilities:SetWidth(ATS.frames.options.content:GetWidth() - (ATS.frames.options.padding * 2))
    ATS.frames.options.enabledAbilities:SetHeight(100)
    ATS.frames.options.enabledAbilities:ClearAllPoints()
    ATS.frames.options.enabledAbilities:SetPoint("TOPLEFT", ATS.frames.options.abilitySectionTitle, "BOTTOMLEFT", 0, -5)

    -- Only create the CheckButtons for enabled abilities if there are abilities to enable
    if (#ATS_Character.abilities > 1) then
        -- Create a container to hold ability CheckButton frames
        ATS.frames.options.checkboxAbilities = {}
        
        -- Loop through the available Tracking abilities and generate CheckButton elements for them
        for i, ability in ipairs(ATS_Character.abilities) do
            -- Create the CheckButton for the `Pause while cursor on minimap` option
            ATS.frames.options.checkboxAbilities[i] = CreateFrame("CheckButton", "ATS_Options_Ability_" .. i, ATS.frames.options.enabledAbilities, "InterfaceOptionsCheckButtonTemplate")
            ATS.frames.options.checkboxAbilities[i].Ability = ability
            ATS.frames.options.checkboxAbilities[i].Text:SetText(ability.name)
            ATS.frames.options.checkboxAbilities[i]:SetPoint("TOPLEFT", ATS.frames.options.padding, -(ATS.frames.options.margin * (i - 0.5)))
            ATS.frames.options.checkboxAbilities[i]:SetChecked(ATS.IsAbilityOptionChecked(ability))
        end

        -- Resize the Enabled Abilities frame to adjust for number of abilities
        ATS.frames.options.enabledAbilities:SetHeight((ATS.frames.options.checkboxAbilities[1]:GetHeight() + (ATS.frames.options.margin / 2)) * (#ATS.frames.options.checkboxAbilities + 0.25))
    -- Else display a message telling the user they have no abilities to enable
    else
        ATS.frames.options.noAbilityMessage = ATS.frames.options.enabledAbilities:CreateFontString("ARTWORK", nil, "GameFontHighlight")
        ATS.frames.options.noAbilityMessage:SetPoint("LEFT", ATS.frames.options.padding, 0)
        ATS.frames.options.noAbilityMessage:SetText("There are no tracking abilities to enable.")
    end

    -- This is the built-in `refresh` callback included when assigning a panel to the Interface Options window
    -- Refresh occurs when user switches between Interface Options pages or re-opens window
    ATS.frames.options.panel.refresh = function()
        ATS.frames.options.sliderInterval:SetValue(ATS.frames.options.temporaryValues.interval)
        ATS.frames.options.editboxInterval:SetText(ATS.frames.options.temporaryValues.interval)
        ATS.frames.options.checkboxAutostart:SetChecked(ATS.frames.options.temporaryValues.autoStart)
        ATS.frames.options.checkboxMute:SetChecked(ATS.frames.options.temporaryValues.mute)
        ATS.frames.options.checkboxPauseSound:SetChecked(ATS.frames.options.temporaryValues.pauseSound)
        ATS.frames.options.checkboxResumeSound:SetChecked(ATS.frames.options.temporaryValues.resumeSound)
        ATS.frames.options.checkboxResumeSound:SetEnabled(ATS.frames.options.checkboxPauseSound:GetChecked())
        ATS.frames.options.checkboxMinimapPause:SetChecked(ATS.frames.options.temporaryValues.minimapPause)

        -- Loop through the CheckButton elements
        for i, checkboxAbility in ipairs(ATS.frames.options.checkboxAbilities) do
            local ability = checkboxAbility.Ability

            -- Make sure there is an ability added to this CheckButton element
            if (ability) then
                -- Loop through the actual enabled abilities 
                checkboxAbility:SetChecked(false)

                for j, enabledAbility in ipairs(ATS.frames.options.temporaryValues.enabledAbilities) do
                    -- If the enabled ability matches that attached to this CheckButton element, mark it checked
                    if (enabledAbility.name == ability.name) then
                        checkboxAbility:SetChecked(true)
                    end
                end
            end
        end
    end

    -- This built-in callback runs when the user clicks the `Okay` button on the Interface Options window
    -- This action is intended to save any changes to the Options
    ATS.frames.options.panel.okay = function()
        -- If the Interval has changed, we need to update the value and restart the Ticker to implement the change
        if (ATS_Character.options.interval ~= ATS.frames.options.sliderInterval:GetValue()) then
            ATS_Character.options.interval = ATS.frames.options.sliderInterval:GetValue()

            -- Silently restart Ticker
            ATS.StopTicker(true)
            ATS.StartTicker(true)
        end

        ATS_Character.options.autoStart = ATS.frames.options.checkboxAutostart:GetChecked()
        ATS_Character.options.mute = ATS.frames.options.checkboxMute:GetChecked()
        ATS_Character.options.pauseSound = ATS.frames.options.checkboxPauseSound:GetChecked()
        ATS_Character.options.resumeSound = ATS.frames.options.checkboxResumeSound:GetChecked()
        ATS_Character.options.minimapPause = ATS.frames.options.checkboxMinimapPause:GetChecked()

        -- If there is more than 1 ability to enable
        if (#ATS_Character.abilities > 1) then
            -- Reset the enabled abilities and add new selections
            ATS_Character.options.enabledAbilities = {}

            -- Loop through ability CheckButtons to see which are now enabled
            for i, checkboxAbility in ipairs(ATS.frames.options.checkboxAbilities) do
                -- If the tracker is checked, add it to the table
                if (checkboxAbility:GetChecked()) then table.insert(ATS_Character.options.enabledAbilities, checkboxAbility.Ability) end
            end
        end

        -- Set the temporary table to the new permanent options
        ATS.frames.options.temporaryValues = CopyTable(ATS_Character.options)
    end

    -- This built-in callback runs when the user attempts to reset the default settings (for this page or all addons)
    -- After this callback has completed, the `refresh` callback is ran
    ATS.frames.options.panel.default = function()
        -- Copy the original defaults table to the temporary values table
        ATS.frames.options.temporaryValues = CopyTable(ATS.defaultOptions)

        -- Enable default Tracking abilities
        ATS.frames.options.temporaryValues.enabledAbilities = ATS.GetDefaultAbilities(true)
    end

    -- This built-in callback runs when the the Interface Options window is cancelled, either through the Cancel button or Escape key
    -- On cancel, we reset the temporary options back to the saved options
    ATS.frames.options.panel.cancel = function()
        ATS.frames.options.temporaryValues = CopyTable(ATS_Character.options)
    end
end

function ATS.IsAbilityOptionChecked(optionAbility)
    if (not optionAbility or not optionAbility.name) then return false end

    for i, enabledAbility in ipairs(ATS.frames.options.temporaryValues.enabledAbilities) do
        -- Check names, if this passed option ability is in the enabled abilities table, return true
        if (enabledAbility.name == optionAbility.name) then return true end
    end
end