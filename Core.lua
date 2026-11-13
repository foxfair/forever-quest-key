local ADDON_NAME = "ForeverQuestKey"
local frame = CreateFrame("Frame", "ForeverQuestKeyFrame", UIParent)

-- Sound configuration tables
local CANCEL_SOUND_OPTIONS = {
    { text = "Parchment Fold (Quest Log Close)", id = 844 },
    { text = "Paper Rustle (Quest Log Open)",   id = 843 },
    { text = "Scroll Slide (Document Close)",    id = 1184 },
    { text = "Subtle Click (Quest Cancel)",      id = 851 },
    { text = "Micro Tick (Chat Scroll)",         id = 1115 },
    { text = "Soft Blip (Minimap Zoom)",         id = 896 },
    { text = "Standard Close (Main Menu)",       id = 857 },
    { text = "None (Muted)",                     id = 0 },
}

local ACCEPT_SOUND_OPTIONS = {
    { text = "Parchment Rustle (Quest Open)", id = 843 },
    { text = "Scroll Roll (Document Open)",   id = 1183 },
    { text = "Quest Accept Click",            id = 850 },
    { text = "Subtle Tick",                   id = 1115 },
    { text = "None (Muted)",                  id = 0 },
}

local COMPLETE_SOUND_OPTIONS = {
    { text = "Classic Fanfare (Quest Complete)", id = 619 },
    { text = "Coins Clinking (Money Select)",    id = 120 },
    { text = "Parchment Fold (Quest Close)",     id = 844 },
    { text = "Scroll Clasp (Document Close)",    id = 1184 },
    { text = "None (Muted)",                     id = 0 },
}

-- Default SavedVariables
local dbDefaults = {
    primaryKey = "SPACE",
    autoSelectHighestValue = true,
    protectUsableGear = true,
    autoOpenFirstQuest = false,
    soundOnCancel = true,
    cancelSoundID = 844,
    soundOnAccept = true,
    acceptSoundID = 843,
    soundOnComplete = true,
    completeSoundID = 619,
}

ForeverQuestKeyDB = ForeverQuestKeyDB or {}

-- Chain transition state (survives transient GOSSIP_CLOSED / QUEST_FINISHED frames)
local pendingUntil = 0
local pendingNpcGUID = nil
local lastNpcGUID = nil
local timerGen = 0
local _, playerClass = UnitClass("player")

local function SetChainPending(guid)
pendingUntil = GetTime() + 1.0
pendingNpcGUID = guid or UnitGUID("npc") or UnitGUID("target") or lastNpcGUID
end

local function ClearChainPending()
pendingUntil = 0
pendingNpcGUID = nil
end

local function IsChainPending(currentGUID)
if GetTime() > pendingUntil then
    ClearChainPending()
    return false
    end
    if pendingNpcGUID and currentGUID and pendingNpcGUID ~= currentGUID then
        return false
        end
        return true
        end

        -- Class armor affinity lookup
        local CLASS_DESIRED_ARMOR = {
            ["MAGE"]    = { ["Cloth"] = true },
            ["PRIEST"]  = { ["Cloth"] = true },
            ["WARLOCK"] = { ["Cloth"] = true },
            ["ROGUE"]   = { ["Leather"] = true },
            ["DRUID"]   = { ["Cloth"] = true, ["Leather"] = true },
            ["HUNTER"]  = { ["Leather"] = true, ["Mail"] = true },
            ["SHAMAN"]  = { ["Cloth"] = true, ["Leather"] = true, ["Mail"] = true },
            ["WARRIOR"] = { ["Mail"] = true, ["Plate"] = true },
            ["PALADIN"] = { ["Cloth"] = true, ["Leather"] = true, ["Mail"] = true, ["Plate"] = true },
        }

        -- Weapon proficiency lookup for WoW Forever
        local CLASS_USABLE_WEAPONS = {
            ["MAGE"] = { ["Daggers"] = true, ["One-Handed Swords"] = true, ["Staves"] = true, ["Wands"] = true },
            ["PRIEST"] = { ["Daggers"] = true, ["One-Handed Maces"] = true, ["Staves"] = true, ["Wands"] = true },
            ["WARLOCK"] = { ["Daggers"] = true, ["One-Handed Swords"] = true, ["Staves"] = true, ["Wands"] = true },
            ["ROGUE"] = { ["Daggers"] = true, ["One-Handed Swords"] = true, ["One-Handed Maces"] = true, ["Fist Weapons"] = true, ["Bows"] = true, ["Crossbows"] = true, ["Guns"] = true, ["Thrown"] = true },
            ["DRUID"] = { ["Daggers"] = true, ["One-Handed Maces"] = true, ["Two-Handed Maces"] = true, ["Polearms"] = true, ["Staves"] = true, ["Fist Weapons"] = true },
            ["HUNTER"] = { ["Bows"] = true, ["Crossbows"] = true, ["Guns"] = true, ["Daggers"] = true, ["One-Handed Swords"] = true, ["Two-Handed Swords"] = true, ["One-Handed Axes"] = true, ["Two-Handed Axes"] = true, ["Polearms"] = true, ["Staves"] = true, ["Fist Weapons"] = true },
            ["SHAMAN"] = { ["Daggers"] = true, ["One-Handed Maces"] = true, ["Two-Handed Maces"] = true, ["One-Handed Axes"] = true, ["Two-Handed Axes"] = true, ["Staves"] = true, ["Fist Weapons"] = true, ["Shields"] = true },
            ["WARRIOR"] = { ["Bows"] = true, ["Crossbows"] = true, ["Guns"] = true, ["Thrown"] = true, ["Daggers"] = true, ["One-Handed Swords"] = true, ["Two-Handed Swords"] = true, ["One-Handed Axes"] = true, ["Two-Handed Axes"] = true, ["One-Handed Maces"] = true, ["Two-Handed Maces"] = true, ["Polearms"] = true, ["Staves"] = true, ["Fist Weapons"] = true, ["Shields"] = true },
            ["PALADIN"] = { ["One-Handed Swords"] = true, ["Two-Handed Swords"] = true, ["One-Handed Maces"] = true, ["Two-Handed Maces"] = true, ["One-Handed Axes"] = true, ["Two-Handed Axes"] = true, ["Polearms"] = true, ["Shields"] = true },
        }

        -- Hidden action button to bind key
        local bindButton = CreateFrame("Button", "ForeverQuestKeyActionButton", UIParent)
        bindButton:RegisterForClicks("AnyUp", "AnyDown")

        -- Gold selection texture overlay for quest rewards
        local highlightOverlay = CreateFrame("Frame", "ForeverQuestKeyHighlight", QuestFrameRewardPanel)
        highlightOverlay:SetSize(42, 42)
        highlightOverlay.tex = highlightOverlay:CreateTexture(nil, "OVERLAY")
        highlightOverlay.tex:SetAllPoints()
        highlightOverlay.tex:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        highlightOverlay.tex:SetBlendMode("ADD")
        highlightOverlay:Hide()

        -- Sound triggers
        local function PlayCancelSound()
        if ForeverQuestKeyDB.soundOnCancel then
            local soundID = ForeverQuestKeyDB.cancelSoundID or 844
            if soundID > 0 then PlaySound(soundID) end
                end
                end

                local function PlayAcceptSound()
                if ForeverQuestKeyDB.soundOnAccept then
                    local soundID = ForeverQuestKeyDB.acceptSoundID or 843
                    if soundID > 0 then PlaySound(soundID) end
                        end
                        end

                        local function PlayCompleteSound()
                        if ForeverQuestKeyDB.soundOnComplete then
                            local soundID = ForeverQuestKeyDB.completeSoundID or 619
                            if soundID > 0 then PlaySound(soundID) end
                                end
                                end

                                local function ClearActionBinding()
                                ClearOverrideBindings(bindButton)
                                end

                                local function ApplyActionBinding()
                                ClearOverrideBindings(bindButton)
                                if GetCurrentKeyBoardFocus() then
                                    return
                                    end
                                    local key = ForeverQuestKeyDB.primaryKey or "SPACE"
                                    SetOverrideBindingClick(bindButton, true, key, "ForeverQuestKeyActionButton")
                                    end

                                    -- Inspect whether reward choices include usable gear or weapons
                                    local function FindUsableGearChoice(numChoices)
                                    if not ForeverQuestKeyDB.protectUsableGear then return false, nil end
                                        local validArmor = CLASS_DESIRED_ARMOR[playerClass] or {}
                                        local validWeapons = CLASS_USABLE_WEAPONS[playerClass] or {}

                                        for i = 1, numChoices do
                                            local link = GetQuestItemLink("choice", i)
                                            if link then
                                                local _, _, _, _, _, itemType, itemSubType, _, itemEquipLoc = GetItemInfo(link)
                                                if itemType == "Armor" and itemEquipLoc and itemEquipLoc ~= "" and itemEquipLoc ~= "INVTYPE_TABARD" and itemEquipLoc ~= "INVTYPE_BODY" then
                                                    if validArmor[itemSubType] then
                                                        return true, i
                                                        end
                                                        end
                                                        if itemType == "Weapon" and validWeapons[itemSubType] then
                                                            return true, i
                                                            end
                                                            end
                                                            end
                                                            return false, nil
                                                            end

                                                            -- Determine highest vendor sell price item choice index
                                                            local function GetHighestValueRewardIndex()
                                                            local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
                                                            if numChoices <= 1 then return numChoices end

                                                                local bestIndex = 1
                                                                local highestPrice = -1

                                                                for i = 1, numChoices do
                                                                    local link = GetQuestItemLink("choice", i)
                                                                    local price = 0
                                                                    if link then
                                                                        local _, _, _, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(link)
                                                                        price = itemSellPrice or 0
                                                                        end

                                                                        if price > highestPrice then
                                                                            highestPrice = price
                                                                            bestIndex = i
                                                                            end
                                                                            end

                                                                            return bestIndex
                                                                            end

                                                                            local function UpdateRewardHighlight(targetIndex)
                                                                            highlightOverlay:Hide()
                                                                            if not targetIndex or targetIndex <= 0 then return end

                                                                                local btn = _G["QuestRewardItem" .. targetIndex]
                                                                                if btn and btn:IsShown() then
                                                                                    highlightOverlay:SetParent(btn)
                                                                                    highlightOverlay:SetPoint("CENTER", btn, "CENTER", 0, 0)
                                                                                    highlightOverlay:Show()
                                                                                    end
                                                                                    end

                                                                                    -- Helper to select an active quest entry safely across C_GossipInfo and legacy APIs
                                                                                    local function SelectGossipActiveEntry(index, entry)
                                                                                    if entry and type(entry.questID) == "number" and entry.questID > 0 and C_GossipInfo and C_GossipInfo.SelectActiveQuest then
                                                                                        C_GossipInfo.SelectActiveQuest(entry.questID)
                                                                                        return true
                                                                                        elseif SelectGossipActiveQuest then
                                                                                            SelectGossipActiveQuest(index)
                                                                                            return true
                                                                                            end
                                                                                            return false
                                                                                            end

                                                                                            -- Helper to select an available quest entry safely across C_GossipInfo and legacy APIs
                                                                                            local function SelectGossipAvailableEntry(index, entry)
                                                                                            if entry and type(entry.questID) == "number" and entry.questID > 0 and C_GossipInfo and C_GossipInfo.SelectAvailableQuest then
                                                                                                C_GossipInfo.SelectAvailableQuest(entry.questID)
                                                                                                return true
                                                                                                elseif SelectGossipAvailableQuest then
                                                                                                    SelectGossipAvailableQuest(index)
                                                                                                    return true
                                                                                                    end
                                                                                                    return false
                                                                                                    end

                                                                                                    -- Deterministic Dialog Engine:
                                                                                                    -- 1. Completed Active Turn-ins
                                                                                                    -- 2. Available New Quests (in listed order)
                                                                                                    -- 3. Unfinished Active Quests (manual keypress only; skipped during auto-advance)
                                                                                                    -- 4. Single Gossip Service Option (when no quests exist)
                                                                                                    local function ProcessGreetingOrGossip(isAutoAdvance)
                                                                                                    -- Case 1: GossipFrame
                                                                                                    if GossipFrame and GossipFrame:IsShown() then
                                                                                                        if C_GossipInfo and C_GossipInfo.GetActiveQuests then
                                                                                                            local activeQuests = C_GossipInfo.GetActiveQuests() or {}
                                                                                                            local availableQuests = C_GossipInfo.GetAvailableQuests() or {}
                                                                                                            local options = C_GossipInfo.GetOptions and C_GossipInfo.GetOptions() or {}

                                                                                                            -- 1. Absolute Priority: Completed active quests ready to turn in
                                                                                                            for i, q in ipairs(activeQuests) do
                                                                                                                if not q.isIgnored and (q.isComplete == true or q.isComplete == 1) then
                                                                                                                    if SelectGossipActiveEntry(i, q) then
                                                                                                                        return true
                                                                                                                        end
                                                                                                                        end
                                                                                                                        end

                                                                                                                        -- 2. Second Priority: Available new quests in listed order
                                                                                                                        for i, q in ipairs(availableQuests) do
                                                                                                                            if not q.isIgnored then
                                                                                                                                if SelectGossipAvailableEntry(i, q) then
                                                                                                                                    return true
                                                                                                                                    end
                                                                                                                                    end
                                                                                                                                    end

                                                                                                                                    -- 3. Third Priority: Unfinished active quests (manual press only)
                                                                                                                                    if not isAutoAdvance then
                                                                                                                                        for i, q in ipairs(activeQuests) do
                                                                                                                                            if not q.isIgnored and not q.isComplete then
                                                                                                                                                if SelectGossipActiveEntry(i, q) then
                                                                                                                                                    return true
                                                                                                                                                    end
                                                                                                                                                    end
                                                                                                                                                    end
                                                                                                                                                    end

                                                                                                                                                    -- 4. Fourth Priority: Single gossip service option when no quests are present
                                                                                                                                                    if #activeQuests == 0 and #availableQuests == 0 and #options == 1 then
                                                                                                                                                        if options[1].gossipOptionID and C_GossipInfo.SelectOption then
                                                                                                                                                            C_GossipInfo.SelectOption(options[1].gossipOptionID)
                                                                                                                                                            return true
                                                                                                                                                            elseif SelectGossipOption then
                                                                                                                                                                SelectGossipOption(1)
                                                                                                                                                                return true
                                                                                                                                                                end
                                                                                                                                                                end
                                                                                                                                                                else
                                                                                                                                                                    -- Legacy API fallback
                                                                                                                                                                    local numActive = GetNumGossipActiveQuests and GetNumGossipActiveQuests() or 0
                                                                                                                                                                    local numAvailable = GetNumGossipAvailableQuests and GetNumGossipAvailableQuests() or 0
                                                                                                                                                                    local numOptions = GetNumGossipOptions and GetNumGossipOptions() or 0

                                                                                                                                                                    if numActive > 0 then
                                                                                                                                                                        local activeData = { GetGossipActiveQuests() }
                                                                                                                                                                        local stride = math.floor(#activeData / numActive)
                                                                                                                                                                        if stride < 4 then stride = 6 end

                                                                                                                                                                            for i = 1, numActive do
                                                                                                                                                                                local offset = (i - 1) * stride
                                                                                                                                                                                local isComplete = activeData[offset + 4]
                                                                                                                                                                                if isComplete == true or isComplete == 1 then
                                                                                                                                                                                    SelectGossipActiveQuest(i)
                                                                                                                                                                                    return true
                                                                                                                                                                                    end
                                                                                                                                                                                    end
                                                                                                                                                                                    end

                                                                                                                                                                                    if numAvailable > 0 then
                                                                                                                                                                                        SelectGossipAvailableQuest(1)
                                                                                                                                                                                        return true
                                                                                                                                                                                        end

                                                                                                                                                                                        if not isAutoAdvance and numActive > 0 then
                                                                                                                                                                                            SelectGossipActiveQuest(1)
                                                                                                                                                                                            return true
                                                                                                                                                                                            end

                                                                                                                                                                                            if numActive == 0 and numAvailable == 0 and numOptions == 1 then
                                                                                                                                                                                                SelectGossipOption(1)
                                                                                                                                                                                                return true
                                                                                                                                                                                                end
                                                                                                                                                                                                end

                                                                                                                                                                                                -- Case 2: QuestFrameGreetingPanel (Pure quest givers firing QUEST_GREETING)
                                                                                                                                                                                                elseif (QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsShown()) or (QuestGreetingFrame and QuestGreetingFrame:IsShown()) then
                                                                                                                                                                                                    local numActive = GetNumActiveQuests and GetNumActiveQuests() or 0
                                                                                                                                                                                                    local numAvailable = GetNumAvailableQuests and GetNumAvailableQuests() or 0

                                                                                                                                                                                                    -- 1. Completed turn-in first
                                                                                                                                                                                                    if numActive > 0 then
                                                                                                                                                                                                        for i = 1, numActive do
                                                                                                                                                                                                            local _, isComplete = GetActiveTitle(i)
                                                                                                                                                                                                            if isComplete == true or isComplete == 1 then
                                                                                                                                                                                                                SelectActiveQuest(i)
                                                                                                                                                                                                                return true
                                                                                                                                                                                                                end
                                                                                                                                                                                                                end
                                                                                                                                                                                                                end

                                                                                                                                                                                                                -- 2. Available new quests second
                                                                                                                                                                                                                if numAvailable > 0 then
                                                                                                                                                                                                                    SelectAvailableQuest(1)
                                                                                                                                                                                                                    return true
                                                                                                                                                                                                                    end

                                                                                                                                                                                                                    -- 3. Unfinished active quests last (manual press only)
                                                                                                                                                                                                                    if not isAutoAdvance and numActive > 0 then
                                                                                                                                                                                                                        SelectActiveQuest(1)
                                                                                                                                                                                                                        return true
                                                                                                                                                                                                                        end
                                                                                                                                                                                                                        end

                                                                                                                                                                                                                        return false
                                                                                                                                                                                                                        end

                                                                                                                                                                                                                        -- Primary Action on Action Key (Spacebar)
                                                                                                                                                                                                                        local function OnActionPressed()
                                                                                                                                                                                                                        local currentGUID = UnitGUID("npc") or UnitGUID("target")

                                                                                                                                                                                                                        -- 1. Quest Detail Panel (Accepting an offered quest)
                                                                                                                                                                                                                        if QuestFrameDetailPanel and QuestFrameDetailPanel:IsShown() then
                                                                                                                                                                                                                            if QuestFrameAcceptButton and QuestFrameAcceptButton:IsEnabled() then
                                                                                                                                                                                                                                SetChainPending(currentGUID)
                                                                                                                                                                                                                                QuestFrameAcceptButton:Click()
                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                -- 2. Quest Progress Panel (Completing objectives / hand-in)
                                                                                                                                                                                                                                if QuestFrameProgressPanel and QuestFrameProgressPanel:IsShown() then
                                                                                                                                                                                                                                    if IsQuestCompletable() and QuestFrameCompleteButton and QuestFrameCompleteButton:IsEnabled() then
                                                                                                                                                                                                                                        SetChainPending(currentGUID)
                                                                                                                                                                                                                                        QuestFrameCompleteButton:Click()
                                                                                                                                                                                                                                        return
                                                                                                                                                                                                                                        end
                                                                                                                                                                                                                                        end

                                                                                                                                                                                                                                        -- 3. Quest Reward Panel (Claiming rewards)
                                                                                                                                                                                                                                        if QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown() then
                                                                                                                                                                                                                                            local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0

                                                                                                                                                                                                                                            if numChoices <= 1 then
                                                                                                                                                                                                                                                SetChainPending(currentGUID)
                                                                                                                                                                                                                                                if numChoices == 1 then
                                                                                                                                                                                                                                                    GetQuestReward(1)
                                                                                                                                                                                                                                                    else
                                                                                                                                                                                                                                                        GetQuestReward()
                                                                                                                                                                                                                                                        end
                                                                                                                                                                                                                                                        return
                                                                                                                                                                                                                                                        else
                                                                                                                                                                                                                                                            local selectedChoice = GetQuestItemSelection and GetQuestItemSelection() or 0
                                                                                                                                                                                                                                                            if selectedChoice > 0 then
                                                                                                                                                                                                                                                                SetChainPending(currentGUID)
                                                                                                                                                                                                                                                                GetQuestReward(selectedChoice)
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local hasUsable, usableIdx = FindUsableGearChoice(numChoices)
                                                                                                                                                                                                                                                                if hasUsable then
                                                                                                                                                                                                                                                                UpdateRewardHighlight(usableIdx)
                                                                                                                                                                                                                                                                UIErrorsFrame:AddMessage("Usable gear/weapon detected! Click your choice.", 1.0, 0.8, 0.0)
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if ForeverQuestKeyDB.autoSelectHighestValue then
                                                                                                                                                                                                                                                                local bestIdx = GetHighestValueRewardIndex()
                                                                                                                                                                                                                                                                SetChainPending(currentGUID)
                                                                                                                                                                                                                                                                GetQuestReward(bestIdx)
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                UIErrorsFrame:AddMessage("Select a reward choice first!", 1.0, 0.2, 0.2)
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                -- 4. Greeting or Gossip list: manual press advances highest-priority task
                                                                                                                                                                                                                                                                ProcessGreetingOrGossip(false)
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                bindButton:SetScript("OnClick", function(self, button, down)
                                                                                                                                                                                                                                                                if not down then
                                                                                                                                                                                                                                                                OnActionPressed()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end)

                                                                                                                                                                                                                                                                local function UpdateBindingState()
                                                                                                                                                                                                                                                                local isOpen = (QuestFrame and QuestFrame:IsShown()) or
                                                                                                                                                                                                                                                                (GossipFrame and GossipFrame:IsShown()) or
                                                                                                                                                                                                                                                                (QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsShown()) or
                                                                                                                                                                                                                                                                (QuestGreetingFrame and QuestGreetingFrame:IsShown())

                                                                                                                                                                                                                                                                if isOpen then
                                                                                                                                                                                                                                                                ApplyActionBinding()
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                ClearActionBinding()
                                                                                                                                                                                                                                                                highlightOverlay:Hide()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                -- Release keybind while typing in chat so Spacebar works normally
                                                                                                                                                                                                                                                                if ChatFrame1EditBox then
                                                                                                                                                                                                                                                                ChatFrame1EditBox:HookScript("OnEditFocusGained", ClearActionBinding)
                                                                                                                                                                                                                                                                ChatFrame1EditBox:HookScript("OnEditFocusLost", UpdateBindingState)
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                -- Frame Visibility Handler
                                                                                                                                                                                                                                                                local function OnDialogFrameClosed()
                                                                                                                                                                                                                                                                local currentGUID = UnitGUID("npc") or UnitGUID("target")
                                                                                                                                                                                                                                                                if not IsChainPending(currentGUID) then
                                                                                                                                                                                                                                                                PlayCancelSound()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                UpdateBindingState()
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if QuestFrame then QuestFrame:HookScript("OnHide", OnDialogFrameClosed) end
                                                                                                                                                                                                                                                                if GossipFrame then GossipFrame:HookScript("OnHide", OnDialogFrameClosed) end
                                                                                                                                                                                                                                                                if QuestGreetingFrame then QuestGreetingFrame:HookScript("OnHide", OnDialogFrameClosed) end

                                                                                                                                                                                                                                                                -- Debounced scheduler so GOSSIP_SHOW / QUEST_GREETING / QUEST_FINISHED never double-fire
                                                                                                                                                                                                                                                                local function ScheduleGreetingCheck(delay, isAutoAdvance)
                                                                                                                                                                                                                                                                timerGen = timerGen + 1
                                                                                                                                                                                                                                                                local myGen = timerGen
                                                                                                                                                                                                                                                                C_Timer.After(delay, function()
                                                                                                                                                                                                                                                                if myGen ~= timerGen then
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                local processed = ProcessGreetingOrGossip(isAutoAdvance)
                                                                                                                                                                                                                                                                if not processed then
                                                                                                                                                                                                                                                                ClearChainPending()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end)
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                -- Event Handling
                                                                                                                                                                                                                                                                frame:RegisterEvent("ADDON_LOADED")
                                                                                                                                                                                                                                                                frame:RegisterEvent("GOSSIP_SHOW")
                                                                                                                                                                                                                                                                frame:RegisterEvent("GOSSIP_CLOSED")
                                                                                                                                                                                                                                                                frame:RegisterEvent("QUEST_GREETING")
                                                                                                                                                                                                                                                                frame:RegisterEvent("QUEST_DETAIL")
                                                                                                                                                                                                                                                                frame:RegisterEvent("QUEST_PROGRESS")
                                                                                                                                                                                                                                                                frame:RegisterEvent("QUEST_COMPLETE")
                                                                                                                                                                                                                                                                frame:RegisterEvent("QUEST_FINISHED")
                                                                                                                                                                                                                                                                frame:RegisterEvent("QUEST_ACCEPTED")
                                                                                                                                                                                                                                                                frame:RegisterEvent("QUEST_TURNED_IN")

                                                                                                                                                                                                                                                                frame:SetScript("OnEvent", function(self, event, arg1, ...)
                                                                                                                                                                                                                                                                if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
                                                                                                                                                                                                                                                                for k, v in pairs(dbDefaults) do
                                                                                                                                                                                                                                                                if ForeverQuestKeyDB[k] == nil then
                                                                                                                                                                                                                                                                ForeverQuestKeyDB[k] = v
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ForeverQuestKey]|r loaded successfully! Type |cffffd100/fqk|r for settings.")
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local currentGUID = UnitGUID("npc") or UnitGUID("target")

                                                                                                                                                                                                                                                                if event == "GOSSIP_SHOW" or event == "QUEST_GREETING" then
                                                                                                                                                                                                                                                                UpdateBindingState()

                                                                                                                                                                                                                                                                if IsChainPending(currentGUID) then
                                                                                                                                                                                                                                                                -- Continuing a chain after turning in or accepting a quest on the same NPC
                                                                                                                                                                                                                                                                lastNpcGUID = currentGUID
                                                                                                                                                                                                                                                                ScheduleGreetingCheck(0.08, true)
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                -- Fresh NPC interaction
                                                                                                                                                                                                                                                                lastNpcGUID = currentGUID
                                                                                                                                                                                                                                                                if ForeverQuestKeyDB.autoOpenFirstQuest then
                                                                                                                                                                                                                                                                ScheduleGreetingCheck(0.08, true)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                elseif event == "QUEST_COMPLETE" then
                                                                                                                                                                                                                                                                lastNpcGUID = currentGUID
                                                                                                                                                                                                                                                                UpdateBindingState()

                                                                                                                                                                                                                                                                C_Timer.After(0.05, function()
                                                                                                                                                                                                                                                                local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
                                                                                                                                                                                                                                                                if numChoices > 1 then
                                                                                                                                                                                                                                                                local hasUsable, usableIdx = FindUsableGearChoice(numChoices)
                                                                                                                                                                                                                                                                if hasUsable then
                                                                                                                                                                                                                                                                UpdateRewardHighlight(usableIdx)
                                                                                                                                                                                                                                                                elseif ForeverQuestKeyDB.autoSelectHighestValue then
                                                                                                                                                                                                                                                                local bestIdx = GetHighestValueRewardIndex()
                                                                                                                                                                                                                                                                UpdateRewardHighlight(bestIdx)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end)

                                                                                                                                                                                                                                                                elseif event == "QUEST_ACCEPTED" then
                                                                                                                                                                                                                                                                PlayAcceptSound()
                                                                                                                                                                                                                                                                SetChainPending(currentGUID)

                                                                                                                                                                                                                                                                elseif event == "QUEST_TURNED_IN" then
                                                                                                                                                                                                                                                                PlayCompleteSound()
                                                                                                                                                                                                                                                                SetChainPending(currentGUID)

                                                                                                                                                                                                                                                                elseif event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" then
                                                                                                                                                                                                                                                                lastNpcGUID = currentGUID
                                                                                                                                                                                                                                                                UpdateBindingState()

                                                                                                                                                                                                                                                                elseif event == "GOSSIP_CLOSED" then
                                                                                                                                                                                                                                                                if not IsChainPending(currentGUID) then
                                                                                                                                                                                                                                                                PlayCancelSound()
                                                                                                                                                                                                                                                                lastNpcGUID = nil
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                UpdateBindingState()

                                                                                                                                                                                                                                                                elseif event == "QUEST_FINISHED" then
                                                                                                                                                                                                                                                                if IsChainPending(currentGUID) then
                                                                                                                                                                                                                                                                ScheduleGreetingCheck(0.08, true)
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                PlayCancelSound()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                UpdateBindingState()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end)

                                                                                                                                                                                                                                                                ------------------------------------------------------
                                                                                                                                                                                                                                                                -- Standalone Settings Dialog (/fqk)
                                                                                                                                                                                                                                                                ------------------------------------------------------
                                                                                                                                                                                                                                                                local configDialog = CreateFrame("Frame", "FQKConfigDialog", UIParent, "BasicFrameTemplateWithInset")
                                                                                                                                                                                                                                                                configDialog:SetSize(400, 480)
                                                                                                                                                                                                                                                                configDialog:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
                                                                                                                                                                                                                                                                configDialog:SetMovable(true)
                                                                                                                                                                                                                                                                configDialog:EnableMouse(true)
                                                                                                                                                                                                                                                                configDialog:RegisterForDrag("LeftButton")
                                                                                                                                                                                                                                                                configDialog:SetScript("OnDragStart", configDialog.StartMoving)
                                                                                                                                                                                                                                                                configDialog:SetScript("OnDragStop", configDialog.StopMovingOrSizing)
                                                                                                                                                                                                                                                                configDialog:Hide()

                                                                                                                                                                                                                                                                tinsert(UISpecialFrames, "FQKConfigDialog")

                                                                                                                                                                                                                                                                configDialog.TitleText:SetText("Forever Quest Key")

                                                                                                                                                                                                                                                                local headerText = configDialog:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                                                                                                                                                                                                                                                                headerText:SetPoint("TOPLEFT", configDialog, "TOPLEFT", 20, -36)
                                                                                                                                                                                                                                                                headerText:SetText("Configuration")

                                                                                                                                                                                                                                                                local keyLabel = configDialog:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                                                                                                                                                                                                                                                                keyLabel:SetPoint("TOPLEFT", headerText, "BOTTOMLEFT", 0, -14)
                                                                                                                                                                                                                                                                keyLabel:SetText("Primary Action Key:")

                                                                                                                                                                                                                                                                local keyEditBox = CreateFrame("EditBox", "FQKKeyEditBox", configDialog, "InputBoxTemplate")
                                                                                                                                                                                                                                                                keyEditBox:SetSize(80, 22)
                                                                                                                                                                                                                                                                keyEditBox:SetPoint("LEFT", keyLabel, "RIGHT", 14, 0)
                                                                                                                                                                                                                                                                keyEditBox:SetAutoFocus(false)
                                                                                                                                                                                                                                                                keyEditBox:SetMaxLetters(10)

                                                                                                                                                                                                                                                                local highestValCheck = CreateFrame("CheckButton", "FQK_AutoHighestValBtn", configDialog, "UICheckButtonTemplate")
                                                                                                                                                                                                                                                                highestValCheck:SetPoint("TOPLEFT", keyLabel, "BOTTOMLEFT", -4, -14)
                                                                                                                                                                                                                                                                _G[highestValCheck:GetName() .. "Text"]:SetText("Auto-select highest vendor value reward")
                                                                                                                                                                                                                                                                _G[highestValCheck:GetName() .. "Text"]:SetFontObject("GameFontNormalSmall")

                                                                                                                                                                                                                                                                local protectGearCheck = CreateFrame("CheckButton", "FQK_ProtectGearBtn", configDialog, "UICheckButtonTemplate")
                                                                                                                                                                                                                                                                protectGearCheck:SetPoint("TOPLEFT", highestValCheck, "BOTTOMLEFT", 0, -6)
                                                                                                                                                                                                                                                                _G[protectGearCheck:GetName() .. "Text"]:SetText("Pause if usable class weapon/armor is offered")
                                                                                                                                                                                                                                                                _G[protectGearCheck:GetName() .. "Text"]:SetFontObject("GameFontNormalSmall")

                                                                                                                                                                                                                                                                local autoOpenCheck = CreateFrame("CheckButton", "FQK_AutoOpenBtn", configDialog, "UICheckButtonTemplate")
                                                                                                                                                                                                                                                                autoOpenCheck:SetPoint("TOPLEFT", protectGearCheck, "BOTTOMLEFT", 0, -6)
                                                                                                                                                                                                                                                                _G[autoOpenCheck:GetName() .. "Text"]:SetText("Instant auto-open on first talk")
                                                                                                                                                                                                                                                                _G[autoOpenCheck:GetName() .. "Text"]:SetFontObject("GameFontNormalSmall")

                                                                                                                                                                                                                                                                -- Sound 1: Dismiss / Walk Away
                                                                                                                                                                                                                                                                local soundCancelCheck = CreateFrame("CheckButton", "FQK_SoundCancelBtn", configDialog, "UICheckButtonTemplate")
                                                                                                                                                                                                                                                                soundCancelCheck:SetPoint("TOPLEFT", autoOpenCheck, "BOTTOMLEFT", 0, -10)
                                                                                                                                                                                                                                                                _G[soundCancelCheck:GetName() .. "Text"]:SetText("Sound on Dismiss / Walk Away")
                                                                                                                                                                                                                                                                _G[soundCancelCheck:GetName() .. "Text"]:SetFontObject("GameFontNormalSmall")

                                                                                                                                                                                                                                                                local cancelDropdown = CreateFrame("Frame", "FQK_CancelDropdown", configDialog, "UIDropDownMenuTemplate")
                                                                                                                                                                                                                                                                cancelDropdown:SetPoint("TOPLEFT", soundCancelCheck, "BOTTOMLEFT", -14, -2)
                                                                                                                                                                                                                                                                UIDropDownMenu_SetWidth(cancelDropdown, 195)

                                                                                                                                                                                                                                                                local cancelPreviewBtn = CreateFrame("Button", nil, configDialog, "UIPanelButtonTemplate")
                                                                                                                                                                                                                                                                cancelPreviewBtn:SetSize(65, 22)
                                                                                                                                                                                                                                                                cancelPreviewBtn:SetPoint("LEFT", cancelDropdown, "RIGHT", -6, 2)
                                                                                                                                                                                                                                                                cancelPreviewBtn:SetText("Preview")

                                                                                                                                                                                                                                                                local selectedCancelSoundID = 844
                                                                                                                                                                                                                                                                cancelPreviewBtn:SetScript("OnClick", function()
                                                                                                                                                                                                                                                                if selectedCancelSoundID > 0 then PlaySound(selectedCancelSoundID) end
                                                                                                                                                                                                                                                                end)

                                                                                                                                                                                                                                                                UIDropDownMenu_Initialize(cancelDropdown, function(self, level)
                                                                                                                                                                                                                                                                local info = UIDropDownMenu_CreateInfo()
                                                                                                                                                                                                                                                                for _, item in ipairs(CANCEL_SOUND_OPTIONS) do
                                                                                                                                                                                                                                                                info.text = item.text
                                                                                                                                                                                                                                                                info.value = item.id
                                                                                                                                                                                                                                                                info.func = function()
                                                                                                                                                                                                                                                                selectedCancelSoundID = item.id
                                                                                                                                                                                                                                                                UIDropDownMenu_SetSelectedValue(cancelDropdown, item.id)
                                                                                                                                                                                                                                                                UIDropDownMenu_SetText(cancelDropdown, item.text)
                                                                                                                                                                                                                                                                if item.id > 0 then PlaySound(item.id) end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                info.checked = (selectedCancelSoundID == item.id)
                                                                                                                                                                                                                                                                UIDropDownMenu_AddButton(info)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end)

                                                                                                                                                                                                                                                                -- Sound 2: Quest Accept
                                                                                                                                                                                                                                                                local soundAcceptCheck = CreateFrame("CheckButton", "FQK_SoundAcceptBtn", configDialog, "UICheckButtonTemplate")
                                                                                                                                                                                                                                                                soundAcceptCheck:SetPoint("TOPLEFT", cancelDropdown, "BOTTOMLEFT", 14, -6)
                                                                                                                                                                                                                                                                _G[soundAcceptCheck:GetName() .. "Text"]:SetText("Sound on Quest Accept")
                                                                                                                                                                                                                                                                _G[soundAcceptCheck:GetName() .. "Text"]:SetFontObject("GameFontNormalSmall")

                                                                                                                                                                                                                                                                local acceptDropdown = CreateFrame("Frame", "FQK_AcceptDropdown", configDialog, "UIDropDownMenuTemplate")
                                                                                                                                                                                                                                                                acceptDropdown:SetPoint("TOPLEFT", soundAcceptCheck, "BOTTOMLEFT", -14, -2)
                                                                                                                                                                                                                                                                UIDropDownMenu_SetWidth(acceptDropdown, 195)

                                                                                                                                                                                                                                                                local acceptPreviewBtn = CreateFrame("Button", nil, configDialog, "UIPanelButtonTemplate")
                                                                                                                                                                                                                                                                acceptPreviewBtn:SetSize(65, 22)
                                                                                                                                                                                                                                                                acceptPreviewBtn:SetPoint("LEFT", acceptDropdown, "RIGHT", -6, 2)
                                                                                                                                                                                                                                                                acceptPreviewBtn:SetText("Preview")

                                                                                                                                                                                                                                                                local selectedAcceptSoundID = 843
                                                                                                                                                                                                                                                                acceptPreviewBtn:SetScript("OnClick", function()
                                                                                                                                                                                                                                                                if selectedAcceptSoundID > 0 then PlaySound(selectedAcceptSoundID) end
                                                                                                                                                                                                                                                                end)

                                                                                                                                                                                                                                                                UIDropDownMenu_Initialize(acceptDropdown, function(self, level)
                                                                                                                                                                                                                                                                local info = UIDropDownMenu_CreateInfo()
                                                                                                                                                                                                                                                                for _, item in ipairs(ACCEPT_SOUND_OPTIONS) do
                                                                                                                                                                                                                                                                info.text = item.text
                                                                                                                                                                                                                                                                info.value = item.id
                                                                                                                                                                                                                                                                info.func = function()
                                                                                                                                                                                                                                                                selectedAcceptSoundID = item.id
                                                                                                                                                                                                                                                                UIDropDownMenu_SetSelectedValue(acceptDropdown, item.id)
                                                                                                                                                                                                                                                                UIDropDownMenu_SetText(acceptDropdown, item.text)
                                                                                                                                                                                                                                                                if item.id > 0 then PlaySound(item.id) end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                info.checked = (selectedAcceptSoundID == item.id)
                                                                                                                                                                                                                                                                UIDropDownMenu_AddButton(info)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end)

                                                                                                                                                                                                                                                                -- Sound 3: Quest Complete / Turn-In
                                                                                                                                                                                                                                                                local soundCompleteCheck = CreateFrame("CheckButton", "FQK_SoundCompleteBtn", configDialog, "UICheckButtonTemplate")
                                                                                                                                                                                                                                                                soundCompleteCheck:SetPoint("TOPLEFT", acceptDropdown, "BOTTOMLEFT", 14, -6)
                                                                                                                                                                                                                                                                _G[soundCompleteCheck:GetName() .. "Text"]:SetText("Sound on Quest Complete / Turn-In")
                                                                                                                                                                                                                                                                _G[soundCompleteCheck:GetName() .. "Text"]:SetFontObject("GameFontNormalSmall")

                                                                                                                                                                                                                                                                local completeDropdown = CreateFrame("Frame", "FQK_CompleteDropdown", configDialog, "UIDropDownMenuTemplate")
                                                                                                                                                                                                                                                                completeDropdown:SetPoint("TOPLEFT", soundCompleteCheck, "BOTTOMLEFT", -14, -2)
                                                                                                                                                                                                                                                                UIDropDownMenu_SetWidth(completeDropdown, 195)

                                                                                                                                                                                                                                                                local completePreviewBtn = CreateFrame("Button", nil, configDialog, "UIPanelButtonTemplate")
                                                                                                                                                                                                                                                                completePreviewBtn:SetSize(65, 22)
                                                                                                                                                                                                                                                                completePreviewBtn:SetPoint("LEFT", completeDropdown, "RIGHT", -6, 2)
                                                                                                                                                                                                                                                                completePreviewBtn:SetText("Preview")

                                                                                                                                                                                                                                                                local selectedCompleteSoundID = 619
                                                                                                                                                                                                                                                                completePreviewBtn:SetScript("OnClick", function()
                                                                                                                                                                                                                                                                if selectedCompleteSoundID > 0 then PlaySound(selectedCompleteSoundID) end
                                                                                                                                                                                                                                                                end)

                                                                                                                                                                                                                                                                UIDropDownMenu_Initialize(completeDropdown, function(self, level)
                                                                                                                                                                                                                                                                local info = UIDropDownMenu_CreateInfo()
                                                                                                                                                                                                                                                                for _, item in ipairs(COMPLETE_SOUND_OPTIONS) do
                                                                                                                                                                                                                                                                info.text = item.text
                                                                                                                                                                                                                                                                info.value = item.id
                                                                                                                                                                                                                                                                info.func = function()
                                                                                                                                                                                                                                                                selectedCompleteSoundID = item.id
                                                                                                                                                                                                                                                                UIDropDownMenu_SetSelectedValue(completeDropdown, item.id)
                                                                                                                                                                                                                                                                UIDropDownMenu_SetText(completeDropdown, item.text)
                                                                                                                                                                                                                                                                if item.id > 0 then PlaySound(item.id) end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                info.checked = (selectedCompleteSoundID == item.id)
                                                                                                                                                                                                                                                                UIDropDownMenu_AddButton(info)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end)

                                                                                                                                                                                                                                                                local function UpdateSoundControlStates()
                                                                                                                                                                                                                                                                if soundCancelCheck:GetChecked() then
                                                                                                                                                                                                                                                                UIDropDownMenu_EnableDropDown(cancelDropdown)
                                                                                                                                                                                                                                                                cancelPreviewBtn:Enable()
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                UIDropDownMenu_DisableDropDown(cancelDropdown)
                                                                                                                                                                                                                                                                cancelPreviewBtn:Disable()
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if soundAcceptCheck:GetChecked() then
                                                                                                                                                                                                                                                                UIDropDownMenu_EnableDropDown(acceptDropdown)
                                                                                                                                                                                                                                                                acceptPreviewBtn:Enable()
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                UIDropDownMenu_DisableDropDown(acceptDropdown)
                                                                                                                                                                                                                                                                acceptPreviewBtn:Disable()
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if soundCompleteCheck:GetChecked() then
                                                                                                                                                                                                                                                                UIDropDownMenu_EnableDropDown(completeDropdown)
                                                                                                                                                                                                                                                                completePreviewBtn:Enable()
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                UIDropDownMenu_DisableDropDown(completeDropdown)
                                                                                                                                                                                                                                                                completePreviewBtn:Disable()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                soundCancelCheck:SetScript("OnClick", UpdateSoundControlStates)
                                                                                                                                                                                                                                                                soundAcceptCheck:SetScript("OnClick", UpdateSoundControlStates)
                                                                                                                                                                                                                                                                soundCompleteCheck:SetScript("OnClick", UpdateSoundControlStates)

                                                                                                                                                                                                                                                                local function RefreshConfigValues()
                                                                                                                                                                                                                                                                keyEditBox:SetText(ForeverQuestKeyDB.primaryKey or "SPACE")
                                                                                                                                                                                                                                                                highestValCheck:SetChecked(ForeverQuestKeyDB.autoSelectHighestValue)
                                                                                                                                                                                                                                                                protectGearCheck:SetChecked(ForeverQuestKeyDB.protectUsableGear)
                                                                                                                                                                                                                                                                autoOpenCheck:SetChecked(ForeverQuestKeyDB.autoOpenFirstQuest)

                                                                                                                                                                                                                                                                soundCancelCheck:SetChecked(ForeverQuestKeyDB.soundOnCancel)
                                                                                                                                                                                                                                                                selectedCancelSoundID = ForeverQuestKeyDB.cancelSoundID or 844
                                                                                                                                                                                                                                                                UIDropDownMenu_SetSelectedValue(cancelDropdown, selectedCancelSoundID)
                                                                                                                                                                                                                                                                for _, it in ipairs(CANCEL_SOUND_OPTIONS) do
                                                                                                                                                                                                                                                                if it.id == selectedCancelSoundID then UIDropDownMenu_SetText(cancelDropdown, it.text) break end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                soundAcceptCheck:SetChecked(ForeverQuestKeyDB.soundOnAccept)
                                                                                                                                                                                                                                                                selectedAcceptSoundID = ForeverQuestKeyDB.acceptSoundID or 843
                                                                                                                                                                                                                                                                UIDropDownMenu_SetSelectedValue(acceptDropdown, selectedAcceptSoundID)
                                                                                                                                                                                                                                                                for _, it in ipairs(ACCEPT_SOUND_OPTIONS) do
                                                                                                                                                                                                                                                                if it.id == selectedAcceptSoundID then UIDropDownMenu_SetText(acceptDropdown, it.text) break end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                soundCompleteCheck:SetChecked(ForeverQuestKeyDB.soundOnComplete)
                                                                                                                                                                                                                                                                selectedCompleteSoundID = ForeverQuestKeyDB.completeSoundID or 619
                                                                                                                                                                                                                                                                UIDropDownMenu_SetSelectedValue(completeDropdown, selectedCompleteSoundID)
                                                                                                                                                                                                                                                                for _, it in ipairs(COMPLETE_SOUND_OPTIONS) do
                                                                                                                                                                                                                                                                if it.id == selectedCompleteSoundID then UIDropDownMenu_SetText(completeDropdown, it.text) break end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                UpdateSoundControlStates()
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local saveButton = CreateFrame("Button", nil, configDialog, "UIPanelButtonTemplate")
                                                                                                                                                                                                                                                                saveButton:SetSize(90, 22)
                                                                                                                                                                                                                                                                saveButton:SetPoint("BOTTOMRIGHT", configDialog, "BOTTOMRIGHT", -16, 14)
                                                                                                                                                                                                                                                                saveButton:SetText("Save")
                                                                                                                                                                                                                                                                saveButton:SetScript("OnClick", function()
                                                                                                                                                                                                                                                                local text = keyEditBox:GetText():upper():gsub("%s+", "")
                                                                                                                                                                                                                                                                if text ~= "" then
                                                                                                                                                                                                                                                                ForeverQuestKeyDB.primaryKey = text
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                ForeverQuestKeyDB.autoSelectHighestValue = highestValCheck:GetChecked() and true or false
                                                                                                                                                                                                                                                                ForeverQuestKeyDB.protectUsableGear = protectGearCheck:GetChecked() and true or false
                                                                                                                                                                                                                                                                ForeverQuestKeyDB.autoOpenFirstQuest = autoOpenCheck:GetChecked() and true or false

                                                                                                                                                                                                                                                                ForeverQuestKeyDB.soundOnCancel = soundCancelCheck:GetChecked() and true or false
                                                                                                                                                                                                                                                                ForeverQuestKeyDB.cancelSoundID = selectedCancelSoundID

                                                                                                                                                                                                                                                                ForeverQuestKeyDB.soundOnAccept = soundAcceptCheck:GetChecked() and true or false
                                                                                                                                                                                                                                                                ForeverQuestKeyDB.acceptSoundID = selectedAcceptSoundID

                                                                                                                                                                                                                                                                ForeverQuestKeyDB.soundOnComplete = soundCompleteCheck:GetChecked() and true or false
                                                                                                                                                                                                                                                                ForeverQuestKeyDB.completeSoundID = selectedCompleteSoundID

                                                                                                                                                                                                                                                                configDialog:Hide()
                                                                                                                                                                                                                                                                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ForeverQuestKey]|r Settings saved. Key bound to: |cffffd100" .. ForeverQuestKeyDB.primaryKey .. "|r")
                                                                                                                                                                                                                                                                end)

                                                                                                                                                                                                                                                                local cancelButton = CreateFrame("Button", nil, configDialog, "UIPanelButtonTemplate")
                                                                                                                                                                                                                                                                cancelButton:SetSize(90, 22)
                                                                                                                                                                                                                                                                cancelButton:SetPoint("RIGHT", saveButton, "LEFT", -8, 0)
                                                                                                                                                                                                                                                                cancelButton:SetText("Cancel")
                                                                                                                                                                                                                                                                cancelButton:SetScript("OnClick", function()
                                                                                                                                                                                                                                                                configDialog:Hide()
                                                                                                                                                                                                                                                                end)

                                                                                                                                                                                                                                                                ------------------------------------------------------
                                                                                                                                                                                                                                                                -- Debug Inspector (/fqk debug) & Slash Commands
                                                                                                                                                                                                                                                                ------------------------------------------------------
                                                                                                                                                                                                                                                                local function DumpTableFields(tbl)
                                                                                                                                                                                                                                                                if type(tbl) ~= "table" then
                                                                                                                                                                                                                                                                return tostring(tbl)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                local parts = {}
                                                                                                                                                                                                                                                                for k, v in pairs(tbl) do
                                                                                                                                                                                                                                                                local valStr = (type(v) == "table") and "{table}" or tostring(v)
                                                                                                                                                                                                                                                                table.insert(parts, tostring(k) .. "=" .. valStr)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                table.sort(parts)
                                                                                                                                                                                                                                                                return "{ " .. table.concat(parts, ", ") .. " }"
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local function PrintGossipDebug()
                                                                                                                                                                                                                                                                local currentGUID = UnitGUID("npc") or UnitGUID("target")
                                                                                                                                                                                                                                                                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ForeverQuestKey Debug]|r --- NPC Dialog State ---")
                                                                                                                                                                                                                                                                DEFAULT_CHAT_FRAME:AddMessage(string.format(
                                                                                                                                                                                                                                                                "Frames: Gossip=%s | GreetingPanel=%s | Quest=%s | chainPending=%s",
                                                                                                                                                                                                                                                                tostring(GossipFrame and GossipFrame:IsShown() or false),
                                                                                                                                                                                                                                                                tostring(QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsShown() or false),
                                                                                                                                                                                                                                                                tostring(QuestFrame and QuestFrame:IsShown() or false),
                                                                                                                                                                                                                                                                tostring(IsChainPending(currentGUID))
                                                                                                                                                                                                                                                                ))

                                                                                                                                                                                                                                                                if C_GossipInfo then
                                                                                                                                                                                                                                                                if C_GossipInfo.GetActiveQuests then
                                                                                                                                                                                                                                                                local activeQuests = C_GossipInfo.GetActiveQuests() or {}
                                                                                                                                                                                                                                                                DEFAULT_CHAT_FRAME:AddMessage("|cffffd100C_GossipInfo.GetActiveQuests()|r count: " .. #activeQuests)
                                                                                                                                                                                                                                                                for i, q in ipairs(activeQuests) do
                                                                                                                                                                                                                                                                DEFAULT_CHAT_FRAME:AddMessage("  [" .. i .. "] " .. DumpTableFields(q))
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if C_GossipInfo.GetAvailableQuests then
                                                                                                                                                                                                                                                                local availableQuests = C_GossipInfo.GetAvailableQuests() or {}
                                                                                                                                                                                                                                                                DEFAULT_CHAT_FRAME:AddMessage("|cffffd100C_GossipInfo.GetAvailableQuests()|r count: " .. #availableQuests)
                                                                                                                                                                                                                                                                for i, q in ipairs(availableQuests) do
                                                                                                                                                                                                                                                                DEFAULT_CHAT_FRAME:AddMessage("  [" .. i .. "] " .. DumpTableFields(q))
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local greetActive = GetNumActiveQuests and GetNumActiveQuests() or 0
                                                                                                                                                                                                                                                                local greetAvail = GetNumAvailableQuests and GetNumAvailableQuests() or 0
                                                                                                                                                                                                                                                                DEFAULT_CHAT_FRAME:AddMessage(string.format(
                                                                                                                                                                                                                                                                "|cffffd100QuestGreeting|r (Active/Available): %d / %d",
                                                                                                                                                                                                                                                                greetActive, greetAvail
                                                                                                                                                                                                                                                                ))
                                                                                                                                                                                                                                                                for i = 1, greetActive do
                                                                                                                                                                                                                                                                local title, isComplete = GetActiveTitle(i)
                                                                                                                                                                                                                                                                DEFAULT_CHAT_FRAME:AddMessage(string.format("  Active[%d]: %s (isComplete=%s)", i, tostring(title), tostring(isComplete)))
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                for i = 1, greetAvail do
                                                                                                                                                                                                                                                                local title = GetAvailableTitle(i)
                                                                                                                                                                                                                                                                DEFAULT_CHAT_FRAME:AddMessage(string.format("  Available[%d]: %s", i, tostring(title)))
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                SLASH_FOREVERQUESTKEY1 = "/fqk"
                                                                                                                                                                                                                                                                SLASH_FOREVERQUESTKEY2 = "/foreverquest"
                                                                                                                                                                                                                                                                SlashCmdList["FOREVERQUESTKEY"] = function(msg)
                                                                                                                                                                                                                                                                local cmd = (msg or ""):match("^%s*(.-)%s*$"):lower()

                                                                                                                                                                                                                                                                if cmd == "debug" then
                                                                                                                                                                                                                                                                PrintGossipDebug()
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                elseif cmd ~= "" then
                                                                                                                                                                                                                                                                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ForeverQuestKey]|r Usage: |cffffd100/fqk|r (Settings) | |cffffd100/fqk debug|r (Inspect quest tables)")
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if configDialog:IsShown() then
                                                                                                                                                                                                                                                                configDialog:Hide()
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                RefreshConfigValues()
                                                                                                                                                                                                                                                                configDialog:Show()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
