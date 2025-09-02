-- GuildShoppingList.lua
local addonName = ...
local GSL = LibStub("AceAddon-3.0"):NewAddon("GuildShoppingList", "AceComm-3.0", "AceSerializer-3.0")

-- Minimap Button using LibDBIcon and LibDataBroker
local LDB = LibStub("LibDataBroker-1.1"):NewDataObject("GuildShoppingList", {
    type = "launcher",
    text = "Guild Shopping List",
    icon = "Interface\\AddOns\\GuildShoppingList\\GSLIcon.tga", -- custom icon
    OnClick = function(self, button)
        if button == "LeftButton" then
            if GuildShoppingListFrame:IsShown() then
                GuildShoppingListFrame:Hide()
            else
                GuildShoppingListFrame:Show()
            end
        elseif button == "RightButton" then
            if GSLReagentOverlayFrame:IsShown() then
                GSLReagentOverlayFrame:Hide()
            else
                UpdateGSLReagentOverlay()
                GSLReagentOverlayFrame:Show()
            end
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("Guild Shopping List")
        tooltip:AddLine("|cffffff00Left-Click|r: Toggle main window")
        tooltip:AddLine("|cffffff00Right-Click|r: Toggle reagent overlay")
    end,
})

local dbIcon = LibStub("LibDBIcon-1.0")
GuildShoppingListDB = GuildShoppingListDB or { minimap = { hide = false } }

local minimapInit = CreateFrame("Frame")
minimapInit:RegisterEvent("ADDON_LOADED")
minimapInit:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName then
        dbIcon:Register("GuildShoppingList", LDB, GuildShoppingListDB.minimap)
    end
end)

-- GSL Reagent Overlay Frame (borderless, no background, no scroll bar, mousewheel scroll)
local GSLReagentOverlayFrame = CreateFrame("Frame", "GSLReagentOverlayFrame", UIParent)
GSLReagentOverlayFrame:SetSize(420, 420)
GSLReagentOverlayFrame:SetPoint("CENTER")
GSLReagentOverlayFrame:SetMovable(true)
GSLReagentOverlayFrame:EnableMouse(true)
GSLReagentOverlayFrame:RegisterForDrag("LeftButton")
GSLReagentOverlayFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
GSLReagentOverlayFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
GSLReagentOverlayFrame:Hide()

-- ScrollFrame (no scroll bar)
local overlayScrollFrame = CreateFrame("ScrollFrame", nil, GSLReagentOverlayFrame)
overlayScrollFrame:SetPoint("TOPLEFT", GSLReagentOverlayFrame, "TOPLEFT", 10, -30)
overlayScrollFrame:SetPoint("BOTTOMRIGHT", GSLReagentOverlayFrame, "BOTTOMRIGHT", -10, 10)

local overlayContent = CreateFrame("Frame", nil, overlayScrollFrame)
overlayContent:SetSize(1, 1)
overlayScrollFrame:SetScrollChild(overlayContent)

local overlayFontStrings = {}

-- Title (make it clickable to minimize/expand)
GSLReagentOverlayFrame.title = GSLReagentOverlayFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
GSLReagentOverlayFrame.title:SetPoint("TOP", GSLReagentOverlayFrame, "TOP", 0, -10)
GSLReagentOverlayFrame.title:SetText("GSL Reagent Tracker")

-- Make the title clickable
GSLReagentOverlayFrame.titleButton = CreateFrame("Button", nil, GSLReagentOverlayFrame)
GSLReagentOverlayFrame.titleButton:SetAllPoints(GSLReagentOverlayFrame.title)
GSLReagentOverlayFrame.titleButton:SetScript("OnClick", function()
    if overlayScrollFrame:IsShown() then
        overlayScrollFrame:Hide()
    else
        overlayScrollFrame:Show()
    end
end)
GSLReagentOverlayFrame.titleButton:SetAlpha(0) -- invisible but clickable

-- Optionally, change the title color on hover for feedback
GSLReagentOverlayFrame.titleButton:SetScript("OnEnter", function()
    GSLReagentOverlayFrame.title:SetText("|cff00ff00GSL Reagent Tracker|r")
end)
GSLReagentOverlayFrame.titleButton:SetScript("OnLeave", function()
    GSLReagentOverlayFrame.title:SetText("GSL Reagent Tracker")
end)

-- Mousewheel scrolling
overlayScrollFrame:EnableMouseWheel(true)
overlayScrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local current = self:GetVerticalScroll()
    local min, max = self:GetVerticalScrollRange()
    min = min or 0
    max = max or 0
    local step = 30
    if delta > 0 then
        self:SetVerticalScroll(math.max(current - step, min))
    elseif delta < 0 then
        self:SetVerticalScroll(math.min(current + step, max))
    end
end)

-- Utility: Find the designated GSL player in the guild
function GetGSLPlayer()
    local function TruncateRealm(name)
        return name and name:match("^[^%-]+") or name
    end

    if GuildShoppingList_ForcedGSLPlayer and GuildShoppingList_ForcedGSLPlayer ~= "" then
        return TruncateRealm(GuildShoppingList_ForcedGSLPlayer)
    end
    return TruncateRealm(cachedGSLPlayer)
end

function PrintCurrentGSLPlayer()
    local gslPlayer = GetGSLPlayer and GetGSLPlayer() or "unknown"
    print("|cff00ff00[GSL]|r Current GSL player: |cffffff00" .. gslPlayer .. "|r")
end

-- Load recipes table for each profession (expand as you add more)
local RecipeData = {}
local professionList = { "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Leatherworking", "Tailoring", "Cooking" }

if GuildShoppingList_AlchemyRecipes then
    RecipeData["Alchemy"] = GuildShoppingList_AlchemyRecipes
else
    RecipeData["Alchemy"] = {}
end

if GuildShoppingList_EngineeringSchematics then
    RecipeData["Engineering"] = GuildShoppingList_EngineeringSchematics
else
    RecipeData["Engineering"] = {}
end

if GuildShoppingList_BlacksmithingPlans then
    RecipeData["Blacksmithing"] = GuildShoppingList_BlacksmithingPlans
else
    RecipeData["Blacksmithing"] = {}
end

if GuildShoppingList_LeatherworkingPatterns then
    RecipeData["Leatherworking"] = GuildShoppingList_LeatherworkingPatterns
else
    RecipeData["Leatherworking"] = {}
end

if GuildShoppingList_TailoringPatterns then
    RecipeData["Tailoring"] = GuildShoppingList_TailoringPatterns
else
    RecipeData["Tailoring"] = {}
end

if GuildShoppingList_CookingRecipes then
    RecipeData["Cooking"] = GuildShoppingList_CookingRecipes
else
    RecipeData["Cooking"] = {}
end

if GuildShoppingList_EnchantingFormulae then
    RecipeData["Enchanting"] = GuildShoppingList_EnchantingFormulae
else
    RecipeData["Enchanting"] = {}
end

-- Expand the width and center the title
local frame = CreateFrame("Frame", "GuildShoppingListFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(600, 598)
frame:SetPoint("CENTER")
frame.title = frame:CreateFontString(nil, "OVERLAY")
frame.title:SetFontObject("GameFontHighlight")
frame.title:SetPoint("CENTER", frame.TitleBg, "CENTER", 0, 0)
frame.title:SetText("Guild Shopping List")

-- Make the frame draggable
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

-- Persistent shopping list table
GuildShoppingList_SavedItems = GuildShoppingList_SavedItems or {}

items = GuildShoppingList_SavedItems  -- no 'local'

-- Profession Dropdown
local selectedProfession = "Alchemy"
local professionDropdown = CreateFrame("Frame", "GSLProfessionDropdown", frame, "UIDropDownMenuTemplate")
professionDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -65)
UIDropDownMenu_SetWidth(professionDropdown, 150)
UIDropDownMenu_SetText(professionDropdown, selectedProfession)

UIDropDownMenu_Initialize(professionDropdown, function(self, level, menuList)
    local info = UIDropDownMenu_CreateInfo()
    for _, prof in ipairs(professionList) do
        info.text = prof
        info.checked = (prof == selectedProfession)
        info.func = function()
            selectedProfession = prof
            UIDropDownMenu_SetText(professionDropdown, prof)
            UpdateRecipeDropdown()
        end
        UIDropDownMenu_AddButton(info)
    end
end)

-- Recipe Searchable Auto-complete Input Field
local selectedRecipe = nil

-- Create the search box
local recipeSearchBox = CreateFrame("EditBox", "GSLRecipeSearchBox", frame, "InputBoxTemplate")
recipeSearchBox:SetSize(330, 24)
recipeSearchBox:SetPoint("TOPLEFT", professionDropdown, "BOTTOMLEFT", 20, -0)
recipeSearchBox:SetAutoFocus(false)
recipeSearchBox:SetText("")
recipeSearchBox:SetCursorPosition(0)
recipeSearchBox:SetMaxLetters(100)
recipeSearchBox:ClearFocus()
recipeSearchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
recipeSearchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
recipeSearchBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
recipeSearchBox:SetScript("OnEditFocusLost", function(self) self:HighlightText(0,0) end)
recipeSearchBox:SetScript("OnTextChanged", function(self)
    GSL_UpdateRecipeSuggestions()
end)

-- Suggestion dropdown frame
local suggestionFrame = CreateFrame("Frame", "GSLRecipeSuggestionFrame", frame, "BackdropTemplate")
suggestionFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
suggestionFrame:SetFrameStrata("TOOLTIP")
suggestionFrame:SetSize(330, 10)
suggestionFrame:SetPoint("TOPLEFT", recipeSearchBox, "BOTTOMLEFT", 0, -2)
suggestionFrame:Hide()

local suggestionButtons = {}
local MAX_SUGGESTIONS = 10

function GSL_UpdateRecipeSuggestions()
    local text = recipeSearchBox:GetText()
    local textLower = text:lower()
    local recipes = RecipeData[selectedProfession] or {}
    local recipeNames = {}
    for name in pairs(recipes) do
        if textLower == "" or name:lower():find(textLower, 1, true) then
            table.insert(recipeNames, name)
        end
    end
    table.sort(recipeNames)

    -- Only set selectedRecipe if the text matches a recipe exactly
    selectedRecipe = nil
    for _, name in ipairs(recipeNames) do
        if name:lower() == textLower and textLower ~= "" then
            selectedRecipe = name
            break
        end
    end

    -- Hide all old buttons
    for i = 1, MAX_SUGGESTIONS do
        if suggestionButtons[i] then
            suggestionButtons[i]:Hide()
        end
    end

    local shown = 0
    for i, name in ipairs(recipeNames) do
        if shown >= MAX_SUGGESTIONS then break end
        shown = shown + 1
        local btn = suggestionButtons[shown]
        if not btn then
            btn = CreateFrame("Button", nil, suggestionFrame, "UIPanelButtonTemplate")
            btn:SetSize(310, 18)
            btn:SetPoint("TOPLEFT", suggestionFrame, "TOPLEFT", 10, -5 - (shown-1)*20)
            btn:SetScript("OnClick", function(self)
                selectedRecipe = self.recipeName
                recipeSearchBox:SetText(self.recipeName)
                suggestionFrame:Hide()
            end)
            suggestionButtons[shown] = btn
        end
        btn:SetText(name)
        btn.recipeName = name
        btn:Show()
    end

    if shown > 0 and recipeSearchBox:HasFocus() then
        suggestionFrame:SetHeight(shown * 20 + 10)
        suggestionFrame:Show()
    else
        suggestionFrame:Hide()
    end
end

-- Hide suggestions when focus is lost
recipeSearchBox:SetScript("OnEditFocusLost", function(self)
    suggestionFrame:Hide()
end)

-- Hide suggestions when clicking elsewhere
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
eventFrame:SetScript("OnEvent", function(_, btn)
    if suggestionFrame:IsShown() and not MouseIsOver(suggestionFrame) and not MouseIsOver(recipeSearchBox) then
        suggestionFrame:Hide()
    end
end)

-- Update suggestions when profession changes
local oldProfFunc = UIDropDownMenu_Initialize
UIDropDownMenu_Initialize(professionDropdown, function(self, level, menuList)
    local info = UIDropDownMenu_CreateInfo()
    for _, prof in ipairs(professionList) do
        info.text = prof
        info.checked = (prof == selectedProfession)
        info.func = function()
            selectedProfession = prof
            UIDropDownMenu_SetText(professionDropdown, prof)
            GSL_UpdateRecipeSuggestions()
        end
        UIDropDownMenu_AddButton(info)
    end
end)

-- Number entry box (move to line up with profession dropdown)
local numberBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
numberBox:SetSize(60, 30)
numberBox:SetPoint("LEFT", professionDropdown, "RIGHT", 5, 2.5) -- Aligned horizontally with profession dropdown
numberBox:SetAutoFocus(false)
numberBox:SetNumeric(true)
numberBox:SetNumber(1)

-- FontString pool for list items
local listFontStrings = {}
local editButtons = {}
local removeButtons = {}

-- List display border frame
local listBorder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
listBorder:SetSize(550, 353)
listBorder:SetPoint("TOPLEFT", recipeSearchBox, "BOTTOMLEFT", -5, -7.5)
listBorder:SetBackdrop({
    bgFile = nil,
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
listBorder:SetBackdropBorderColor(1, 1, 1, 1)

-- ScrollFrame for the shopping list
local listScrollFrame = CreateFrame("ScrollFrame", nil, listBorder, "UIPanelScrollFrameTemplate")
listScrollFrame:SetPoint("TOPLEFT", listBorder, "TOPLEFT", 4, -4)
listScrollFrame:SetPoint("BOTTOMRIGHT", listBorder, "BOTTOMRIGHT", -24, 4)

-- List content frame 
local listContent = CreateFrame("Frame", nil, listScrollFrame)
listContent:SetSize(1, 1)
listScrollFrame:SetScrollChild(listContent)


-- Allows editing the quantity of a shopping list item
local function EditItemQuantity(index)
    local item = items[index]
    if not item then return end
    local recipeName, count = item:match("^(.-) x(%d+)$")
    count = tonumber(count) or 1

    StaticPopupDialogs["GSL_EDIT_QUANTITY"] = {
        text = "Edit quantity for:\n" .. recipeName,
        button1 = "OK",
        button2 = "Cancel",
        hasEditBox = true,
        maxLetters = 4,
        OnShow = function(self)
            self.editBox:SetText(tostring(count))
            self.editBox:SetFocus()
        end,
        OnAccept = function(self)
            local newCount = tonumber(self.editBox:GetText())
            if newCount and newCount > 0 then
                items[index] = recipeName .. " x" .. newCount
                UpdateList()
            end
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            local newCount = tonumber(self:GetText())
            if newCount and newCount > 0 then
                items[index] = recipeName .. " x" .. newCount
                UpdateList()
                parent:Hide()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 4,
    }
    StaticPopup_Show("GSL_EDIT_QUANTITY")
end

function UpdateList()
    for _, fs in ipairs(listFontStrings) do
        fs:Hide()
    end
    for _, btn in ipairs(editButtons) do
        btn:Hide()
    end
    for _, btn in ipairs(removeButtons) do
        btn:Hide()
    end

    local yOffset = 0
    local lineHeight = 18
    for i, item in ipairs(items) do
        local fs = listFontStrings[i]
        if not fs then
            fs = listContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetJustifyH("LEFT")
            listFontStrings[i] = fs
        end
        
        fs:SetPoint("TOPLEFT", listContent, "TOPLEFT", 10, -yOffset - 5)
        fs:SetText(i .. ". " .. item)
        fs:Show()

        -- Edit button
        local btn = editButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, listContent, "UIPanelButtonTemplate")
            btn:SetSize(30, 16)
            btn:SetText("Edit")
            editButtons[i] = btn
        end
        btn:SetPoint("LEFT", fs, "RIGHT", 10, 0)
        btn:SetScript("OnClick", function() EditItemQuantity(i) end)
        btn:Show()

        -- Remove ("X") button
        local rbtn = removeButtons[i]
        if not rbtn then
            rbtn = CreateFrame("Button", nil, listContent, "UIPanelButtonTemplate")
            rbtn:SetSize(20, 20)
            rbtn.icon = rbtn:CreateTexture(nil, "ARTWORK")
            rbtn.icon:SetAllPoints()
            removeButtons[i] = rbtn
        end
        rbtn.icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        rbtn.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        rbtn:SetText("")
        rbtn:SetPoint("LEFT", btn, "RIGHT", 5, 0)
        rbtn:SetScript("OnClick", function()
            table.remove(items, i)
            UpdateList()
        end)
        rbtn:Show()

        yOffset = yOffset + lineHeight
    end
    listContent:SetHeight(yOffset)
end

-- Add Button
local addButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
addButton:SetPoint("LEFT", numberBox, "RIGHT", 10, 0)
addButton:SetSize(80, 30)
addButton:SetText("Add")
addButton:SetScript("OnClick", function()
    local recipe = recipeSearchBox:GetText()
    local count = tonumber(numberBox:GetText()) or 1
    if recipe and recipe ~= "" and count > 0 then
        table.insert(items, recipe .. " x" .. count)
        UpdateList()
        recipeSearchBox:SetText("")
        numberBox:SetNumber(1)
    end
end)

-- Clear GSL Data Button 
local clearButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
clearButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
clearButton:SetSize(120, 30)
clearButton:SetText("Clear GSL Data")
clearButton:SetScript("OnClick", function()
    -- Show a confirmation dialog before clearing data
    StaticPopupDialogs["GSL_CLEAR_CONFIRM"] = {
        text = "Are you sure you want to clear all Guild Shopping List data?\nThis cannot be undone.",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            SlashCmdList["GSLCLEAR"]()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("GSL_CLEAR_CONFIRM")
end)

-- Broadcast Button
local broadcastButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
broadcastButton:SetPoint("LEFT", clearButton, "RIGHT", 10, 0)
broadcastButton:SetSize(120, 30)
broadcastButton:SetText("Sync GSL Data")
broadcastButton:SetScript("OnClick", function()
    -- Call the same sync as /gslshare
    GSL:ShareShoppingList()
end)

-- Remove Button
local removeButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
removeButton:SetPoint("LEFT", broadcastButton, "RIGHT", 10, 0)
removeButton:SetSize(120, 30)
removeButton:SetText("Remove Last")
removeButton:SetScript("OnClick", function()
    if #items > 0 then
        table.remove(items)
        UpdateList()
    end
end)

-- Guild Sync Button (for non-GSL players only)
local guildSyncButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
guildSyncButton:SetPoint("LEFT", clearButton, "RIGHT", 10, 0)
guildSyncButton:SetSize(120, 30)
guildSyncButton:SetText("Guild Sync")
guildSyncButton:SetScript("OnClick", function()
    GSL:RequestGSLData()
end)

-- Only show the Guild Sync button if you are NOT the GSL player
local function UpdateGuildSyncButtonVisibility()
    if GetGSLPlayer() ~= UnitName("player") then
        guildSyncButton:Show()
    else
        guildSyncButton:Hide()
    end
end

-- Hide the Remove Last button if not the GSL player
local function UpdateRemoveButtonVisibility()
    local playerName = UnitName("player")
    if GetGSLPlayer() ~= playerName then
        removeButton:Hide()
    else
        removeButton:Show()
    end
end

-- Only show the Sync GSL Data button if you are the GSL player
local function UpdateSyncButtonVisibility()
    if GetGSLPlayer() == UnitName("player") then
        broadcastButton:Show()
    else
        broadcastButton:Hide()
    end
end

-- Hide/Show GSL-only controls based on player
local function UpdateGSLControlsVisibility()
    local isGSL = GetGSLPlayer() == UnitName("player")
    if isGSL then
        professionDropdown:Show()
        addButton:Show()
        numberBox:Show()
        recipeSearchBox:Show()
        -- Show edit and remove buttons for each row
        for _, btn in ipairs(editButtons) do
            btn:Show()
        end
        for _, btn in ipairs(removeButtons) do
            btn:Show()
        end
        -- Always show the clear button
        clearButton:Show()
    else
        professionDropdown:Hide()
        addButton:Hide()
        numberBox:Hide()
        recipeSearchBox:Hide()
        suggestionFrame:Hide()
        -- Hide edit and remove buttons for each row
        for _, btn in ipairs(editButtons) do
            btn:Hide()
        end
        for _, btn in ipairs(removeButtons) do
            btn:Hide()
        end
        -- Always show the clear button
        clearButton:Show()
    end
end

-- Call these on load and whenever GSL player might change
UpdateRemoveButtonVisibility()
UpdateSyncButtonVisibility()
UpdateGSLControlsVisibility()
UpdateGuildSyncButtonVisibility()

-- Utility: Get total count of an item in bags and bank
local function GetTotalItemCount(itemName)
    local total = 0
    local playerName = UnitName("player")
    -- Bags (0-4)
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemLink = C_Container.GetContainerItemLink(bag, slot)
            if itemLink then
                local name = GetItemInfo(itemLink)
                if name == itemName then
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    local itemCount = info and info.stackCount or 0
                    total = total + itemCount
                end
            end
        end
    end
    -- Bank: live scan if open, otherwise use cache
    if BankFrame and BankFrame:IsShown() then
        -- Main bank slots (bank bag -1)
        for slot = 1, C_Container.GetContainerNumSlots(-1) do
            local itemLink = C_Container.GetContainerItemLink(-1, slot)
            if itemLink then
                local name = GetItemInfo(itemLink)
                if name == itemName then
                    local info = C_Container.GetContainerItemInfo(-1, slot)
                    local itemCount = info and info.stackCount or 0
                    total = total + itemCount
                end
            end
        end
        -- Bank bags (5-11)
        for bag = 5, 11 do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                if itemLink then
                    local name = GetItemInfo(itemLink)
                    if name == itemName then
                        local info = C_Container.GetContainerItemInfo(bag, slot)
                        local itemCount = info and info.stackCount or 0
                        total = total + itemCount
                    end
                end
            end
        end
    elseif GuildShoppingList_BankCache and GuildShoppingList_BankCache[playerName] and GuildShoppingList_BankCache[playerName][itemName] then
        total = total + GuildShoppingList_BankCache[playerName][itemName]
    end
    return total
end

-- Utility: Scan your own reagents and save to SavedVariables
local function ScanAndSaveReagents()
    local reagentCounts = {}
    -- Aggregate all reagents from the current shopping list
    local reagentTotals = {}
    for _, item in ipairs(items) do
        local recipeName, count = item:match("^(.-) x(%d+)$")
        count = tonumber(count) or 1
        for prof, recipes in pairs(RecipeData) do
            if recipes[recipeName] then
                for _, reagent in ipairs(recipes[recipeName].reagents or {}) do
                    if reagent.name then
                        reagentTotals[reagent.name] = true
                    end
                end
            end
        end
    end
    -- Scan bags/bank for each reagent
    for reagentName in pairs(reagentTotals) do
        reagentCounts[reagentName] = GetTotalItemCount(reagentName)
    end
    -- Save to SavedVariables under player name
    local playerName = UnitName("player")
    GuildShoppingList_ReagentData[playerName] = reagentCounts
end

-- Broadcast your reagent data to the guild
local function BroadcastReagentData()
    local gslPlayer = GetGSLPlayer()
    local playerName = UnitName("player")
    if gslPlayer ~= playerName then
        print("|cffff0000[GSL]|r Only the GSL player can broadcast reagent data.")
        return
    end

    -- Prepare data for sync
    local lastReagentData = GuildShoppingList_GSLLastReagentData and GuildShoppingList_GSLLastReagentData[gslPlayer] or {}
    local savedItems = GuildShoppingList_SavedItems or {}
    local timestamp = time()

    -- Debug print: Show what is being broadcast
    print("Broadcasting items:", table.concat(savedItems, ", "))

    -- Serialize tables
    local function serializeTable(tbl)
        local parts = {}
        for k, v in pairs(tbl) do
            table.insert(parts, tostring(k) .. "=" .. tostring(v))
        end
        return table.concat(parts, ";")
    end

    local reagentDataStr = serializeTable(lastReagentData)
    local savedItemsStr = table.concat(savedItems, "||")
    local msg = "GSL_SYNC:" ..
        "reagents=" .. reagentDataStr ..
        "||items=" .. savedItemsStr ..
        "||timestamp=" .. tostring(timestamp) ..
        "||gslplayer=" .. gslPlayer

    -- Always use the classic API
    SendAddonMessage(GSL_COMM_PREFIX, msg, "GUILD", "")

    GuildShoppingList_GSLLastReagentTimestamp = GuildShoppingList_GSLLastReagentTimestamp or {}
    GuildShoppingList_GSLLastReagentTimestamp[gslPlayer] = timestamp
    print("|cff00ff00[GSL]|r GSL data (reagents and shopping list) shared to guild.")
end

-- Communication prefix for sharing
local GSL_COMM_PREFIX = "GSL_SHARE"

if RegisterAddonMessagePrefix then
    RegisterAddonMessagePrefix(GSL_COMM_PREFIX)
end

-- Serialize a table to a string (simple key-value pairs)
local function serializeTable(tbl)
    local parts = {}
    for k, v in pairs(tbl) do
        table.insert(parts, tostring(k) .. "=" .. tostring(v))
    end
    return table.concat(parts, ";")
end

-- Deserialize a simple key=value;key2=value2 string to a table
local function deserializeTable(str)
    local tbl = {}
    for pair in string.gmatch(str or "", "([^;]+)") do
        local k, v = string.match(pair, "^(.-)=(.+)$")
        if k and v then
            tbl[k] = tonumber(v) or v
        end
    end
    return tbl
end

-- Initialize the new SavedVariable
GuildShoppingList_GSLPlayerCache = GuildShoppingList_GSLPlayerCache or {}

-- Function to cache the current inventory for the GSL player
local function CacheGSLPlayerInventory()
    local playerName = UnitName("player")
    if GetGSLPlayer and GetGSLPlayer() == playerName then
        local inventory = {}
        for bag = 0, 4 do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                if itemLink then
                    local name = GetItemInfo(itemLink)
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    local itemCount = info and info.stackCount or 0
                    if name then
                        inventory[name] = (inventory[name] or 0) + itemCount
                    end
                end
            end
        end
        GuildShoppingList_GSLPlayerCache = inventory
        print("|cff00ff00[GSL]|r GSLPlayerCache updated for GSL player: " .. playerName)
    end
end

-- Call CacheGSLPlayerInventory on login/reload for the GSL player
local initFrameGSLPlayerCache = CreateFrame("Frame")
initFrameGSLPlayerCache:RegisterEvent("ADDON_LOADED")
initFrameGSLPlayerCache:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName then
        if GetGSLPlayer and GetGSLPlayer() == UnitName("player") then
            CacheGSLPlayerInventory()
        end
    end
end)

-- List of SavedVariables to sync (exclude GuildShoppingList_BankCache)
local GSL_SYNC_VARS = {
    "GuildShoppingList_SavedItems",
    "GuildShoppingList_GSLBankCache",
    "GuildShoppingList_GSLPlayerCache",
    -- add more here if you add more SavedVariables and want them synced
}

GuildShoppingList_GSLDataSyncTimestamp = GuildShoppingList_GSLDataSyncTimestamp or nil

function GSL:ShareShoppingList()
    local syncData = {
        player = UnitName("player"),
        GuildShoppingList_SavedItems = GuildShoppingList_SavedItems,
        GuildShoppingList_GSLBankCache = GuildShoppingList_GSLBankCache,
        GuildShoppingList_GSLPlayerCache = GuildShoppingList_GSLPlayerCache,
        GuildShoppingList_GSLDataSyncTimestamp = time(), -- Add timestamp to sync
        -- add more variables here if you want to sync them
    }
    GuildShoppingList_GSLDataSyncTimestamp = syncData.GuildShoppingList_GSLDataSyncTimestamp -- Save locally for GSL player
    local serialized = self:Serialize(syncData)
    self:SendCommMessage("GSLShare", serialized, "GUILD")
    print("|cff00ff00[GSL]|r Shared GuildShoppingList data (explicit variables) to guild.")
end

-- Slash command for /gslshare (AceComm-based sync)
SLASH_GSLSHARE1 = "/gslshare"
SlashCmdList["GSLSHARE"] = function()
    GSL:ShareShoppingList()
end

SLASH_GSLCLEAR1 = "/gslclear"
SlashCmdList["GSLCLEAR"] = function()
    GuildShoppingList_SavedItems = {}
    GuildShoppingList_BankCache = {}
    GuildShoppingList_GSLBankCache = {}
    GuildShoppingList_GSLPlayerCache = {}
    GuildShoppingList_GSLDataSyncTimestamp = nil
    print("|cffff0000[GSL]|r All GuildShoppingList data has been cleared. |cffff0000Please /reload your UI to fully reset.|r")
    if UpdateList then UpdateList() end
    if UpdateReagentList then UpdateReagentList() end
end

SLASH_GSLHELP1 = "/gslhelp"
SlashCmdList["GSLHELP"] = function()
    print("|cff00ff00GuildShoppingList Commands:|r")
    print("|cffffff00/gsl|r - Toggle the main Guild Shopping List window.")
    print("|cffffff00/gsl share|r - Save your current reagent data for offline viewing (does not broadcast).")
    print("|cffffff00/gsl who|r - Print the current GSL player for your guild.")
    print("|cffffff00/gslreagents|r - Toggle the GSL Reagent Tracker overlay window.")
    print("|cffffff00/gslshare|r - Broadcast your Guild Shopping List data to the guild (GSL player only).")
    print("|cffffff00/gslrequest|r - Request the latest Guild Shopping List data from the guild (non-GSL players).")
    print("|cffffff00/gslclear|r - Clear all Guild Shopping List data (irreversible, use with caution).")
    print("|cffffff00/gslhelp|r - Show this help message.")
end

-- Hide the Remove Last button if not the GSL player
local function UpdateRemoveButtonVisibility()
    local playerName = UnitName("player")
    if GetGSLPlayer() ~= playerName then
        removeButton:Hide()
    else
        removeButton:Show()
    end
end

-- Call this on load and whenever GSL player might change
UpdateRemoveButtonVisibility()

-- Optionally, hook it to tab switching or other events if needed

-- Reagent List Border and ScrollFrame (hidden by default)
local reagentBorder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
reagentBorder:SetSize(550, 353)
reagentBorder:SetPoint("TOPLEFT", recipeSearchBox, "BOTTOMLEFT", -5, -7.5)
reagentBorder:SetBackdrop({
    bgFile = nil,
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
reagentBorder:SetBackdropBorderColor(1, 1, 1, 1)
reagentBorder:Hide()

local reagentScrollFrame = CreateFrame("ScrollFrame", nil, reagentBorder, "UIPanelScrollFrameTemplate")
reagentScrollFrame:SetPoint("TOPLEFT", reagentBorder, "TOPLEFT", 4, -4)
reagentScrollFrame:SetPoint("BOTTOMRIGHT", reagentBorder, "BOTTOMRIGHT", -24, 4)

local reagentContent = CreateFrame("Frame", nil, reagentScrollFrame)
reagentContent:SetSize(1, 1)
reagentScrollFrame:SetScrollChild(reagentContent)

local reagentFontStrings = {}

-- Hide the Remove Last button if not the GSL player
local function UpdateRemoveButtonVisibility()
    local playerName = UnitName("player")
    if GetGSLPlayer() ~= playerName then
        removeButton:Hide()
    else
        removeButton:Show()
    end
end

UpdateRemoveButtonVisibility()

-- Utility: Scan the GSL player's current inventory and save to SavedVariables
local function CacheGSLInventory()
    local playerName = UnitName("player")
    if GetGSLPlayer() == playerName then
        local inventory = {}
        for bag = 0, 4 do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                if itemLink then
                    local name = GetItemInfo(itemLink)
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    local itemCount = info and info.stackCount or 0
                    if name then
                        inventory[name] = (inventory[name] or 0) + itemCount
                    end
                end
            end
        end
        GuildShoppingList_GSLInventory = inventory
        print("|cff00ff00[GSL]|r Inventory cached for GSL player: " .. playerName)
    end
end

-- Scan the guild roster and update the cache
local function ScanGuildForGSLPlayer()
    cachedGSLPlayer = nil
    if not IsInGuild() then return end
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local name, _, _, _, _, _, note = GetGuildRosterInfo(i)
        if note and note:find("%[GSL%]") then
            cachedGSLPlayer = Ambiguate(name, "none")
            break
        end
    end
    UpdateRemoveButtonVisibility()
    UpdateSyncButtonVisibility()
    UpdateGSLControlsVisibility()
    UpdateGuildSyncButtonVisibility() 
    if GetGSLPlayer() == UnitName("player") then
        CacheGSLPlayerInventory()
        CacheGSLInventory()
    end
end

local gslGuildFrame = CreateFrame("Frame")
gslGuildFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
gslGuildFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
gslGuildFrame:SetScript("OnEvent", function(self, event)
    if event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
        ScanGuildForGSLPlayer()
    end
end)

-- Request a guild roster update on login/reload
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName then
        GuildShoppingList_SavedItems = GuildShoppingList_SavedItems or {}
        items = GuildShoppingList_SavedItems
        GuildShoppingList_ReagentData = GuildShoppingList_ReagentData or {}
        GuildRoster() 
        UpdateList()
        ScanAndSaveReagents()
        if GetGSLPlayer() == UnitName("player") then
            CacheGSLInventory()
        end
        
    end
end)

-- Tabs
local tabFrame = CreateFrame("Frame", "GuildShoppingListTabFrame", frame)
tabFrame:SetSize(200, 32)
tabFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -25)

local tabs = {}
local tabNames = { "Shopping List", "Reagent List" }
local activeTab = 1

for i, name in ipairs(tabNames) do
    local tab = CreateFrame("Button", "GuildShoppingListTabFrameTab"..i, tabFrame, "OptionsFrameTabButtonTemplate")
    tab:SetID(i)
    tab:SetText(name)
    tab:SetSize(120, 24)
    if i == 1 then
        tab:SetPoint("LEFT", tabFrame, "LEFT", 0, 0)
    else
        tab:SetPoint("LEFT", tabs[i-1], "RIGHT", 10, 0)
    end
    tab:SetScript("OnClick", function(self)
        activeTab = self:GetID()
        PanelTemplates_SetTab(tabFrame, activeTab)
        if activeTab == 1 then
            listBorder:Show()
            listScrollFrame:Show()
            reagentBorder:Hide()
            reagentScrollFrame:Hide()
        else
            listBorder:Hide()
            listScrollFrame:Hide()
            reagentBorder:Show()
            reagentScrollFrame:Show()
            UpdateReagentList()
        end
    end)
    tabs[i] = tab
end
PanelTemplates_SetNumTabs(tabFrame, #tabs)
PanelTemplates_SetTab(tabFrame, 1)

-- Show only the shopping list by default
listBorder:Show()
listScrollFrame:Show()
reagentBorder:Hide()
reagentScrollFrame:Hide()

-- Slash command to show/hide
SLASH_GUILDSHOPPINGLIST1 = "/gsl"
SlashCmdList["GUILDSHOPPINGLIST"] = function(msg)
    msg = msg and msg:lower() or ""
    if msg == "share" then
        -- Only update local data, do not broadcast
        ScanAndSaveReagents()
        print("|cff00ff00[GSL]|r Data saved for offline viewing.")
    elseif msg == "who" then
        PrintCurrentGSLPlayer()
    else
        if frame:IsShown() then
            frame:Hide()
        else
            frame:Show()
        end
    end
end

frame:Hide()

function UpdateReagentList()
        for _, fsRow in ipairs(reagentFontStrings) do
        for _, fs in ipairs(fsRow) do
            fs:Hide()
        end
    end

    -- Aggregate reagents needed
    local reagentTotals = {}
    for _, item in ipairs(items) do
        local recipeName, count = item:match("^(.-) x(%d+)$")
        count = tonumber(count) or 1
        for prof, recipes in pairs(RecipeData) do
            if recipes[recipeName] then
                for _, reagent in ipairs(recipes[recipeName].reagents or {}) do
                    if reagent.name then
                        reagentTotals[reagent.name] = (reagentTotals[reagent.name] or 0) + (reagent.count or 1) * count
                    end
                end
            end
        end
    end

    local playerName = UnitName("player")
    local yOffset = 0
    local lineHeight = 18

    -- Header row
    if not reagentFontStrings.header then
        reagentFontStrings.header = {}
        reagentFontStrings.header[1] = reagentContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        reagentFontStrings.header[2] = reagentContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        reagentFontStrings.header[3] = reagentContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        reagentFontStrings.header[4] = reagentContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        reagentFontStrings.header[1]:SetJustifyH("LEFT")
        for i=2,4 do reagentFontStrings.header[i]:SetJustifyH("RIGHT") end
    end
    local col1, col2, col3, col4 = 10, 270, 350, 430
    reagentFontStrings.header[1]:SetPoint("TOPLEFT", reagentContent, "TOPLEFT", col1, -yOffset - 5)
    reagentFontStrings.header[2]:SetPoint("TOPLEFT", reagentContent, "TOPLEFT", col2, -yOffset - 5)
    reagentFontStrings.header[3]:SetPoint("TOPLEFT", reagentContent, "TOPLEFT", col3, -yOffset - 5)
    reagentFontStrings.header[4]:SetPoint("TOPLEFT", reagentContent, "TOPLEFT", col4, -yOffset - 5)
    reagentFontStrings.header[1]:SetText("Reagent")
    reagentFontStrings.header[2]:SetText("You")
    reagentFontStrings.header[3]:SetText("GSL")
    reagentFontStrings.header[4]:SetText("Needed")
    for i=1,4 do reagentFontStrings.header[i]:Show() end
    yOffset = yOffset + lineHeight

    -- Data rows
    local i = 1
    for reagent, total in pairs(reagentTotals) do
        reagentFontStrings[i] = reagentFontStrings[i] or {}
        -- Reagent name
        if not reagentFontStrings[i][1] then
            reagentFontStrings[i][1] = reagentContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            reagentFontStrings[i][1]:SetJustifyH("LEFT")
        end
        -- You
        if not reagentFontStrings[i][2] then
            reagentFontStrings[i][2] = reagentContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            reagentFontStrings[i][2]:SetJustifyH("RIGHT")
        end
        -- GSL
        if not reagentFontStrings[i][3] then
            reagentFontStrings[i][3] = reagentContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            reagentFontStrings[i][3]:SetJustifyH("RIGHT")
        end
        -- Needed
        if not reagentFontStrings[i][4] then
            reagentFontStrings[i][4] = reagentContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            reagentFontStrings[i][4]:SetJustifyH("RIGHT")
        end

        local youHave = GuildShoppingList_ReagentData[playerName] and GuildShoppingList_ReagentData[playerName][reagent] or 0
        local gslHave = 0

        -- Only use GuildShoppingList_GSLBankCache and GuildShoppingList_GSLPlayerCache for the GSL column
        if GuildShoppingList_GSLBankCache and GuildShoppingList_GSLBankCache[reagent] then
            gslHave = gslHave + GuildShoppingList_GSLBankCache[reagent]
        end
        if GuildShoppingList_GSLPlayerCache and GuildShoppingList_GSLPlayerCache[reagent] then
            gslHave = gslHave + GuildShoppingList_GSLPlayerCache[reagent]
        end

        reagentFontStrings[i][1]:SetPoint("TOPLEFT", reagentContent, "TOPLEFT", col1, -yOffset - 5)
        reagentFontStrings[i][2]:SetPoint("TOPLEFT", reagentContent, "TOPLEFT", col2, -yOffset - 5)
        reagentFontStrings[i][3]:SetPoint("TOPLEFT", reagentContent, "TOPLEFT", col3, -yOffset - 5)
        reagentFontStrings[i][4]:SetPoint("TOPLEFT", reagentContent, "TOPLEFT", col4, -yOffset - 5)

        reagentFontStrings[i][1]:SetText(reagent)
        reagentFontStrings[i][2]:SetText(youHave)

        if gslHave >= total and total > 0 then
            reagentFontStrings[i][3]:SetText("|cff00ff00" .. gslHave .. "|r")
            reagentFontStrings[i][4]:SetText("|cff00ff00" .. total .. "|r")
        elseif gslHave < total and total > 0 then
            reagentFontStrings[i][3]:SetText("|cffff0000" .. gslHave .. "|r")
            reagentFontStrings[i][4]:SetText("|cffff0000" .. total .. "|r")
        else
            reagentFontStrings[i][3]:SetText(gslHave)
            reagentFontStrings[i][4]:SetText(total)
        end

        for j=1,4 do reagentFontStrings[i][j]:Show() end
        yOffset = yOffset + lineHeight
        i = i + 1
    end
    reagentContent:SetHeight(yOffset)
end

-- Addon: Automatically open the frame on guild invite
local f = CreateFrame("Frame")
f:RegisterEvent("GUILD_INVITE_REQUEST")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "GUILD_INVITE_REQUEST" then
        -- Check if the player is already in the guild
        if IsInGuild() then
            return
        end
        -- Show the frame
        frame:Show()
        -- Optionally, you can also bring the frame to the front
        frame:SetFrameStrata("HIGH")
        frame:SetFrameLevel(1000)
    end
end)

-- Function to update the overlay with reagent data (with color coding)
function UpdateGSLReagentOverlay()
    -- Clear old fontstrings
    for _, fsRow in ipairs(overlayFontStrings) do
        for _, fs in ipairs(fsRow) do
            fs:Hide()
        end
    end

    -- Aggregate reagents needed (reuse your logic)
    local reagentTotals = {}
    for _, item in ipairs(items) do
        local recipeName, count = item:match("^(.-) x(%d+)$")
        count = tonumber(count) or 1
        for prof, recipes in pairs(RecipeData) do
            if recipes[recipeName] then
                for _, reagent in ipairs(recipes[recipeName].reagents or {}) do
                    if reagent.name then
                        reagentTotals[reagent.name] = (reagentTotals[reagent.name] or 0) + (reagent.count or 1) * count
                    end
                end
            end
        end
    end

    local playerName = UnitName("player")
    local yOffset = 0
    local lineHeight = 18

    -- Header row
    if not overlayFontStrings.header then
        overlayFontStrings.header = {}
        overlayFontStrings.header[1] = overlayContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        overlayFontStrings.header[2] = overlayContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        overlayFontStrings.header[3] = overlayContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        overlayFontStrings.header[4] = overlayContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        overlayFontStrings.header[1]:SetJustifyH("LEFT")
        for i=2,4 do overlayFontStrings.header[i]:SetJustifyH("RIGHT") end
    end
    local col1, col2, col3, col4 = 10, 260, 300, 340
    overlayFontStrings.header[1]:SetPoint("TOPLEFT", overlayContent, "TOPLEFT", col1, -yOffset - 5)
    overlayFontStrings.header[2]:SetPoint("TOPLEFT", overlayContent, "TOPLEFT", col2, -yOffset - 5)
    overlayFontStrings.header[3]:SetPoint("TOPLEFT", overlayContent, "TOPLEFT", col3, -yOffset - 5)
    overlayFontStrings.header[4]:SetPoint("TOPLEFT", overlayContent, "TOPLEFT", col4, -yOffset - 5)
    overlayFontStrings.header[1]:SetText("Reagent")
    overlayFontStrings.header[2]:SetText("You")
    overlayFontStrings.header[3]:SetText("GSL")
    overlayFontStrings.header[4]:SetText("Needed")
    for i=1,4 do overlayFontStrings.header[i]:Show() end
    yOffset = yOffset + lineHeight

    -- Data rows
    local i = 1
    for reagent, total in pairs(reagentTotals) do
        overlayFontStrings[i] = overlayFontStrings[i] or {}
        -- Reagent name
        if not overlayFontStrings[i][1] then
            overlayFontStrings[i][1] = overlayContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            overlayFontStrings[i][1]:SetJustifyH("LEFT")
        end
        -- You
        if not overlayFontStrings[i][2] then
            overlayFontStrings[i][2] = overlayContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            overlayFontStrings[i][2]:SetJustifyH("RIGHT")
        end
        -- GSL
        if not overlayFontStrings[i][3] then
            overlayFontStrings[i][3] = overlayContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            overlayFontStrings[i][3]:SetJustifyH("RIGHT")
        end
        -- Needed
        if not overlayFontStrings[i][4] then
            overlayFontStrings[i][4] = overlayContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            overlayFontStrings[i][4]:SetJustifyH("RIGHT")
        end

        local youHave = GuildShoppingList_ReagentData[playerName] and GuildShoppingList_ReagentData[playerName][reagent] or 0
        local gslHave = 0

        if GuildShoppingList_GSLBankCache and GuildShoppingList_GSLBankCache[reagent] then
            gslHave = gslHave + GuildShoppingList_GSLBankCache[reagent]
        end
        if GuildShoppingList_GSLPlayerCache and GuildShoppingList_GSLPlayerCache[reagent] then
            gslHave = gslHave + GuildShoppingList_GSLPlayerCache[reagent]
        end

        overlayFontStrings[i][1]:SetPoint("TOPLEFT", overlayContent, "TOPLEFT", col1, -yOffset - 5)
        overlayFontStrings[i][2]:SetPoint("TOPLEFT", overlayContent, "TOPLEFT", col2, -yOffset - 5)
        overlayFontStrings[i][3]:SetPoint("TOPLEFT", overlayContent, "TOPLEFT", col3, -yOffset - 5)
        overlayFontStrings[i][4]:SetPoint("TOPLEFT", overlayContent, "TOPLEFT", col4, -yOffset - 5)

        overlayFontStrings[i][1]:SetText(reagent)
        overlayFontStrings[i][2]:SetText(youHave)

        -- Color coding for GSL and Needed columns (same as your table)
        if gslHave >= total and total > 0 then
            overlayFontStrings[i][3]:SetText("|cff00ff00" .. gslHave .. "|r")
            overlayFontStrings[i][4]:SetText("|cff00ff00" .. total .. "|r")
        elseif gslHave < total and total > 0 then
            overlayFontStrings[i][3]:SetText("|cffff0000" .. gslHave .. "|r")
            overlayFontStrings[i][4]:SetText("|cffff0000" .. total .. "|r")
        else
            overlayFontStrings[i][3]:SetText(gslHave)
            overlayFontStrings[i][4]:SetText(total)
        end

        for j=1,4 do overlayFontStrings[i][j]:Show() end
        yOffset = yOffset + lineHeight
        i = i + 1
    end
    overlayContent:SetHeight(yOffset)
end

-- Slash command to show/hide the overlay
SLASH_GSLREAGENTS1 = "/gslreagents"
SlashCmdList["GSLREAGENTS"] = function()
    if GSLReagentOverlayFrame:IsShown() then
        GSLReagentOverlayFrame:Hide()
    else
        UpdateGSLReagentOverlay()
        GSLReagentOverlayFrame:Show()
    end
end

-- Button to open/close the overlay
local overlayToggleButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
overlayToggleButton:SetSize(160, 30)
overlayToggleButton:SetPoint("LEFT", removeButton, "RIGHT", 10, 0)
overlayToggleButton:SetText("Toggle Tracker")
overlayToggleButton:SetScript("OnClick", function()
    if GSLReagentOverlayFrame:IsShown() then
        GSLReagentOverlayFrame:Hide()
    else
        UpdateGSLReagentOverlay()
        GSLReagentOverlayFrame:Show()
    end
end)

-- List your buttons in the order you want them to appear
local bottomButtons = {
    clearButton,
    broadcastButton,
    removeButton,
    overlayToggleButton,
    guildSyncButton,
}

-- Create a container frame for the buttons
local buttonBar = CreateFrame("Frame", nil, frame)
buttonBar:SetSize(600, 40) -- Reduced width from 700 to 600
buttonBar:SetPoint("BOTTOM", frame, "BOTTOM", 0, 15)

-- Set all buttons to a slightly smaller width for better fit
for _, btn in ipairs(bottomButtons) do
    btn:SetParent(buttonBar)
    btn:ClearAllPoints()
    btn:SetSize(110, 30) 
end

-- Position buttons in a row, centered
local numButtons = #bottomButtons
local totalWidth = numButtons * 110 + (numButtons - 1) * 10
local startX = (buttonBar:GetWidth() - totalWidth) / 2

for i, btn in ipairs(bottomButtons) do
    if i == 1 then
        btn:SetPoint("LEFT", buttonBar, "LEFT", startX, 0)
    else
        btn:SetPoint("LEFT", bottomButtons[i-1], "RIGHT", 10, 0)
    end
end

-- Optional: re-center when button visibility changes
local function CenterBottomButtons()
    local shownButtons = {}
    for _, btn in ipairs(bottomButtons) do
        if btn:IsShown() then
            table.insert(shownButtons, btn)
        end
    end
    local n = #shownButtons
    if n == 0 then return end
    local totalW = n * 110 + (n - 1) * 10
    local start = (buttonBar:GetWidth() - totalW) / 2
    for i, btn in ipairs(shownButtons) do
        btn:ClearAllPoints()
        if i == 1 then
            btn:SetPoint("LEFT", buttonBar, "LEFT", start, 0)
        else
            btn:SetPoint("LEFT", shownButtons[i-1], "RIGHT", 10, 0)
        end
    end
end

-- Hook show/hide for dynamic centering
for _, btn in ipairs(bottomButtons) do
    btn:HookScript("OnShow", CenterBottomButtons)
    btn:HookScript("OnHide", CenterBottomButtons)
end

-- Call once on load
CenterBottomButtons()

-- Show the GSL Reagent Tracker overlay when the addon is loaded
local gslOverlayInitFrame = CreateFrame("Frame")
gslOverlayInitFrame:RegisterEvent("ADDON_LOADED")
gslOverlayInitFrame:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName then
        UpdateGSLReagentOverlay()
        GSLReagentOverlayFrame:Show()
    end
end)

-- Register comms on enable
function GSL:OnEnable()
    self:RegisterComm("GSLShare")
    self:RegisterComm("GSLRequest")
end

-- RequestGSLData: Ask the guild for the latest GSL data
function GSL:RequestGSLData()
    print("|cff00ff00[GSL]|r [DEBUG] Sending Guild Sync request to guild. My timestamp:", GuildShoppingList_GSLDataSyncTimestamp)
    self:SendCommMessage("GSLRequest", tostring(GuildShoppingList_GSLDataSyncTimestamp or 0), "GUILD")
    print("|cff00ff00[GSL]|r Requested latest GuildShoppingList data from guild.")
end

-- OnCommReceived: Handle incoming data and requests
function GSL:OnCommReceived(prefix, message, distribution, sender)
    if prefix == "GSLShare" then
        local success, syncData = self:Deserialize(message)
        if success and type(syncData) == "table" then
            local incomingTimestamp = tonumber(syncData.GuildShoppingList_GSLDataSyncTimestamp or 0)
            local localTimestamp = tonumber(GuildShoppingList_GSLDataSyncTimestamp or 0)
            if incomingTimestamp > localTimestamp then
                GuildShoppingList_SavedItems = syncData.GuildShoppingList_SavedItems or {}
                GuildShoppingList_GSLBankCache = syncData.GuildShoppingList_GSLBankCache or {}
                GuildShoppingList_GSLPlayerCache = syncData.GuildShoppingList_GSLPlayerCache or {}
                GuildShoppingList_GSLDataSyncTimestamp = incomingTimestamp
                print("|cff00ff00[GSL]|r GuildShoppingList data updated from " .. (syncData.player or sender) .. ". |cffff0000Please /reload your UI to see the updated data.|r")
                if UpdateList then UpdateList() end
                if UpdateReagentList then UpdateReagentList() end
            else
                print("|cffffff00[GSL]|r Received older or same data from " .. (syncData.player or sender) .. "; ignoring.")
            end
        end
    elseif prefix == "GSLRequest" then
        local requesterTimestamp = tonumber(message or 0)
        local localTimestamp = tonumber(GuildShoppingList_GSLDataSyncTimestamp or 0)
        if localTimestamp > requesterTimestamp then
            -- Send data to the requester only
            local syncData = {
                player = UnitName("player"),
                GuildShoppingList_SavedItems = GuildShoppingList_SavedItems,
                GuildShoppingList_GSLBankCache = GuildShoppingList_GSLBankCache,
                GuildShoppingList_GSLPlayerCache = GuildShoppingList_GSLPlayerCache,
                GuildShoppingList_GSLDataSyncTimestamp = localTimestamp,
            }
            local serialized = self:Serialize(syncData)
            self:SendCommMessage("GSLShare", serialized, "WHISPER", sender)
            print("|cff00ff00[GSL]|r Sent GuildShoppingList data to " .. sender .. ".")
        end
    end
end

-- Register comms when the addon is loaded
local gslCommInitFrame = CreateFrame("Frame")
gslCommInitFrame:RegisterEvent("ADDON_LOADED")
gslCommInitFrame:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName then
        if GSL.OnEnable then GSL:OnEnable() end
    end
end)

-- Automatically sync local data when bags change (item added/removed)
local bagSyncFrame = CreateFrame("Frame")
bagSyncFrame:RegisterEvent("BAG_UPDATE")
bagSyncFrame:SetScript("OnEvent", function(self, event, arg1)
    ScanAndSaveReagents()
    if UpdateList then UpdateList() end
    if UpdateReagentList then UpdateReagentList() end
    if UpdateGSLReagentOverlay then UpdateGSLReagentOverlay() end
    -- Optional: print a debug message
    -- print("|cff00ff00[GSL]|r Data auto-synced due to bag change.")
end)

-- Update UI and overlay when the bank is opened or closed
local bankSyncFrame = CreateFrame("Frame")
bankSyncFrame:RegisterEvent("BANKFRAME_OPENED")
bankSyncFrame:RegisterEvent("BANKFRAME_CLOSED")
bankSyncFrame:SetScript("OnEvent", function(self, event)
    ScanAndSaveReagents()
    if UpdateList then UpdateList() end
    if UpdateReagentList then UpdateReagentList() end
    if UpdateGSLReagentOverlay then UpdateGSLReagentOverlay() end
end)