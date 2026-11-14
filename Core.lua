local ADDON_NAME = "ForeverQuestKey"
local ADDON_VERSION = "1.2.7"

ForeverQuestKeyDB = ForeverQuestKeyDB or {}

local DEFAULTS = {
    enabled = true,
    protectUsableGear = true,
    autoSelectHighestValue = true,
    soundEnabled = true,
    debug = false,
}

local function PrintMsg(msg)
DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[ForeverQuestKey]|r " .. tostring(msg))
end

local function DebugLog(msg)
if ForeverQuestKeyDB and ForeverQuestKeyDB.debug then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[FQK Debug]|r " .. tostring(msg))
    end
    end

    local function PlayUISound(soundName)
    if ForeverQuestKeyDB and ForeverQuestKeyDB.soundEnabled and soundName then
        pcall(PlaySound, soundName)
        end
        end

        -- ============================================================================
        -- State & Frame References
        -- ============================================================================
        local bindingOwner = CreateFrame("Frame", "FQKBindingOwnerFrame", UIParent)
        local spaceClickBtn = CreateFrame("Button", "FQKSpaceActionButton", UIParent)
        local rewardClickBtns = {}

        for i = 1, 4 do
            local btn = CreateFrame("Button", "FQKRewardChoiceButton" .. i, UIParent)
            btn:SetID(i)
            rewardClickBtns[i] = btn
            end

            local pendingClearAfterCombat = false
            local chainPendingUntil = 0
            local bindingsActive = false
            local activeRewardChoices = 0

            local rewardBadges = {}
            local rewardGlowFrame
            local rewardFlashAnim
            local flashCycles = 0
            local statusBanner
            local statusBannerText

            local function SetChainPending()
            chainPendingUntil = GetTime() + 1.5
            end

            local function IsChainPending()
            return GetTime() <= chainPendingUntil
            end

            local function IsTypingInChat()
            local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
            if focus then
                return true
                end
                if ChatFrame1EditBox and ChatFrame1EditBox:IsShown() then
                    return true
                    end
                    return false
                    end

                    -- ============================================================================
                    -- On-Screen Status Banner
                    -- ============================================================================
                    local function EnsureStatusBanner()
                    if statusBanner then return end

                        statusBanner = CreateFrame("Frame", "FQKStatusBanner", QuestFrame)
                        statusBanner:SetSize(330, 26)
                        statusBanner:SetPoint("BOTTOM", QuestFrame, "TOP", -12, 4)
                        statusBanner:SetFrameStrata("HIGH")
                        statusBanner:Hide()

                        local bg = statusBanner:CreateTexture(nil, "BACKGROUND")
                        bg:SetAllPoints(statusBanner)
                        bg:SetColorTexture(0.06, 0.08, 0.14, 0.90)

                        local border = statusBanner:CreateTexture(nil, "BORDER")
                        border:SetPoint("TOPLEFT", statusBanner, "TOPLEFT", -1, 1)
                        border:SetPoint("BOTTOMRIGHT", statusBanner, "BOTTOMRIGHT", 1, -1)
                        border:SetColorTexture(0.85, 0.68, 0.15, 0.85)

                        statusBannerText = statusBanner:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        statusBannerText:SetPoint("CENTER", statusBanner, "CENTER", 0, 0)
                        statusBannerText:SetTextColor(1.0, 0.9, 0.4)
                        end

                        local function ShowBanner(text)
                        if not QuestFrame or not QuestFrame:IsShown() then return end
                            EnsureStatusBanner()
                            statusBannerText:SetText(text)
                            statusBanner:Show()
                            end

                            local function HideBanner()
                            if statusBanner then
                                statusBanner:Hide()
                                end
                                end

                                -- ============================================================================
                                -- Reward Highlighting: [1]-[4] Badges, 3-Flash Golden Border, Dimming, Tooltip
                                -- ============================================================================
                                local function EnsureRewardVisuals()
                                if not rewardGlowFrame and QuestFrameRewardPanel then
                                    rewardGlowFrame = CreateFrame("Frame", "FQKRewardGlowFrame", QuestFrameRewardPanel)
                                    rewardGlowFrame:SetFrameStrata("HIGH")
                                    rewardGlowFrame:Hide()

                                    local tex = rewardGlowFrame:CreateTexture(nil, "OVERLAY")
                                    tex:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
                                    tex:SetBlendMode("ADD")
                                    tex:SetVertexColor(1.0, 0.85, 0.1, 1.0)
                                    tex:SetWidth(68)
                                    tex:SetHeight(68)
                                    tex:SetPoint("CENTER", rewardGlowFrame, "CENTER", 0, 0)

                                    rewardFlashAnim = rewardGlowFrame:CreateAnimationGroup()
                                    rewardFlashAnim:SetLooping("BOUNCE")

                                    local alphaAnim = rewardFlashAnim:CreateAnimation("Alpha")
                                    alphaAnim:SetFromAlpha(1.0)
                                    alphaAnim:SetToAlpha(0.25)
                                    alphaAnim:SetDuration(0.14)
                                    alphaAnim:SetSmoothing("IN_OUT")

                                    local scaleAnim = rewardFlashAnim:CreateAnimation("Scale")
                                    scaleAnim:SetScale(1.18, 1.18)
                                    scaleAnim:SetDuration(0.14)
                                    scaleAnim:SetSmoothing("IN_OUT")

                                    rewardFlashAnim:SetScript("OnLoop", function(self, loopState)
                                    if loopState == "FORWARD" then
                                        flashCycles = flashCycles + 1
                                        if flashCycles >= 3 then
                                            self:Stop()
                                            end
                                            end
                                            end)
                                    end

                                    for i = 1, 4 do
                                        local btn = _G["QuestRewardItem" .. i]
                                        if btn and not rewardBadges[i] then
                                            local badge = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
                                            badge:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
                                            badge:SetTextColor(1.0, 0.82, 0.0)
                                            badge:SetText("[" .. i .. "]")
                                            badge:Hide()
                                            rewardBadges[i] = badge
                                            end
                                            end
                                            end

                                            local function ShowRewardKeyBadges(numChoices)
                                            EnsureRewardVisuals()
                                            for i = 1, 4 do
                                                if rewardBadges[i] then
                                                    if i <= numChoices then
                                                        rewardBadges[i]:Show()
                                                        else
                                                            rewardBadges[i]:Hide()
                                                            end
                                                            end
                                                            end
                                                            end

                                                            local function HighlightRewardChoice(index, silent)
                                                            local btn = _G["QuestRewardItem" .. index]
                                                            if not btn or not btn:IsShown() then return end

                                                                EnsureRewardVisuals()

                                                                -- Select the reward in Blizzard's UI (updates QuestFrameRewardPanel.itemChoice)
                                                                btn:Click()
                                                                if QuestFrameRewardPanel then
                                                                    QuestFrameRewardPanel.itemChoice = index
                                                                    end

                                                                    -- Dim unselected choices so the active selection stands out immediately
                                                                    for i = 1, 4 do
                                                                        local otherBtn = _G["QuestRewardItem" .. i]
                                                                        if otherBtn and otherBtn:IsShown() then
                                                                            otherBtn:SetAlpha(i == index and 1.0 or 0.45)
                                                                            end
                                                                            end

                                                                            -- Anchor golden glow to the reward icon and trigger the 3-flash pulse
                                                                            local icon = _G["QuestRewardItem" .. index .. "IconTexture"] or btn
                                                                            if rewardGlowFrame then
                                                                                rewardGlowFrame:ClearAllPoints()
                                                                                rewardGlowFrame:SetAllPoints(icon)
                                                                                rewardGlowFrame:SetAlpha(1.0)
                                                                                rewardGlowFrame:Show()

                                                                                rewardFlashAnim:Stop()
                                                                                flashCycles = 0
                                                                                rewardFlashAnim:Play()
                                                                                end

                                                                                -- Pop item tooltip for quick stat inspection before SPACE confirm
                                                                                GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                                                                                GameTooltip:SetQuestItem("choice", index)
                                                                                GameTooltip:Show()

                                                                                local itemName = GetQuestItemInfo("choice", index) or ("Choice " .. index)
                                                                                ShowBanner("Selected [" .. index .. "]: " .. itemName .. " — Press SPACE to claim")

                                                                                if not silent then
                                                                                    PlayUISound("igMainMenuOptionCheckBoxOn")
                                                                                    end
                                                                                    DebugLog("Highlighted reward choice #" .. index .. " (" .. tostring(itemName) .. ")")
                                                                                    end

                                                                                    local function ClearRewardVisuals()
                                                                                    if rewardFlashAnim then
                                                                                        rewardFlashAnim:Stop()
                                                                                        end
                                                                                        if rewardGlowFrame then
                                                                                            rewardGlowFrame:Hide()
                                                                                            end
                                                                                            for i = 1, 4 do
                                                                                                local btn = _G["QuestRewardItem" .. i]
                                                                                                if btn then
                                                                                                    btn:SetAlpha(1.0)
                                                                                                    end
                                                                                                    if rewardBadges[i] then
                                                                                                        rewardBadges[i]:Hide()
                                                                                                        end
                                                                                                        end
                                                                                                        if GameTooltip and GameTooltip:IsOwned(QuestFrameRewardPanel) then
                                                                                                            GameTooltip:Hide()
                                                                                                            end
                                                                                                            HideBanner()
                                                                                                            activeRewardChoices = 0
                                                                                                            end

                                                                                                            -- ============================================================================
                                                                                                            -- Class Gear Usability & Reward Evaluation
                                                                                                            -- ============================================================================
                                                                                                            local CLASS_ARMOR_MAX = {
                                                                                                                WARRIOR = "Plate",
                                                                                                                PALADIN = "Plate",
                                                                                                                HUNTER  = "Mail",
                                                                                                                SHAMAN  = "Mail",
                                                                                                                ROGUE   = "Leather",
                                                                                                                DRUID   = "Leather",
                                                                                                                MAGE    = "Cloth",
                                                                                                                PRIEST  = "Cloth",
                                                                                                                WARLOCK = "Cloth",
                                                                                                            }

                                                                                                            local CLASS_USABLE_WEAPONS = {
                                                                                                                WARRIOR = { ["One-Handed Axes"]=true, ["Two-Handed Axes"]=true, ["One-Handed Swords"]=true, ["Two-Handed Swords"]=true, ["One-Handed Maces"]=true, ["Two-Handed Maces"]=true, ["Polearms"]=true, ["Staves"]=true, ["Daggers"]=true, ["Fist Weapons"]=true, ["Bows"]=true, ["Crossbows"]=true, ["Guns"]=true, ["Thrown"]=true, ["Shields"]=true },
                                                                                                                PALADIN = { ["One-Handed Axes"]=true, ["Two-Handed Axes"]=true, ["One-Handed Swords"]=true, ["Two-Handed Swords"]=true, ["One-Handed Maces"]=true, ["Two-Handed Maces"]=true, ["Polearms"]=true, ["Shields"]=true },
                                                                                                                HUNTER  = { ["One-Handed Axes"]=true, ["Two-Handed Axes"]=true, ["One-Handed Swords"]=true, ["Two-Handed Swords"]=true, ["Polearms"]=true, ["Staves"]=true, ["Daggers"]=true, ["Fist Weapons"]=true, ["Bows"]=true, ["Crossbows"]=true, ["Guns"]=true, ["Thrown"]=true },
                                                                                                                ROGUE   = { ["One-Handed Swords"]=true, ["One-Handed Maces"]=true, ["Daggers"]=true, ["Fist Weapons"]=true, ["Bows"]=true, ["Crossbows"]=true, ["Guns"]=true, ["Thrown"]=true },
                                                                                                                PRIEST  = { ["One-Handed Maces"]=true, ["Staves"]=true, ["Daggers"]=true, ["Wands"]=true },
                                                                                                                SHAMAN  = { ["One-Handed Axes"]=true, ["Two-Handed Axes"]=true, ["One-Handed Maces"]=true, ["Two-Handed Maces"]=true, ["Staves"]=true, ["Daggers"]=true, ["Fist Weapons"]=true, ["Shields"]=true },
                                                                                                                MAGE    = { ["One-Handed Swords"]=true, ["Staves"]=true, ["Daggers"]=true, ["Wands"]=true },
                                                                                                                WARLOCK = { ["One-Handed Swords"]=true, ["Staves"]=true, ["Daggers"]=true, ["Wands"]=true },
                                                                                                                DRUID   = { ["One-Handed Maces"]=true, ["Two-Handed Maces"]=true, ["Polearms"]=true, ["Staves"]=true, ["Daggers"]=true, ["Fist Weapons"]=true },
                                                                                                            }

                                                                                                            local function IsUsableClassEquipment(itemLink)
                                                                                                            if not itemLink then return false end
                                                                                                                local _, _, _, _, _, itemType, itemSubType, _, equipLoc = GetItemInfo(itemLink)
                                                                                                                if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_BAG" then
                                                                                                                    return false
                                                                                                                    end

                                                                                                                    -- Accessories (neck, finger, trinket, cloak) are usable by all classes
                                                                                                                    if equipLoc == "INVTYPE_NECK" or equipLoc == "INVTYPE_FINGER" or equipLoc == "INVTYPE_TRINKET" or equipLoc == "INVTYPE_CLOAK" then
                                                                                                                        return true
                                                                                                                        end

                                                                                                                        local _, playerClass = UnitClass("player")
                                                                                                                        if not playerClass then return true end

                                                                                                                            if itemType == "Weapon" or itemSubType == "Shields" then
                                                                                                                                local allowed = CLASS_USABLE_WEAPONS[playerClass]
                                                                                                                                return allowed and allowed[itemSubType] or false
                                                                                                                                end

                                                                                                                                if itemType == "Armor" then
                                                                                                                                    if itemSubType == "Miscellaneous" or itemSubType == "Cloth" then
                                                                                                                                        return true
                                                                                                                                        end
                                                                                                                                        local maxArmor = CLASS_ARMOR_MAX[playerClass]
                                                                                                                                        if maxArmor == "Plate" then
                                                                                                                                            return itemSubType == "Plate" or itemSubType == "Mail" or itemSubType == "Leather"
                                                                                                                                            elseif maxArmor == "Mail" then
                                                                                                                                                return itemSubType == "Mail" or itemSubType == "Leather"
                                                                                                                                                elseif maxArmor == "Leather" then
                                                                                                                                                    return itemSubType == "Leather"
                                                                                                                                                    end
                                                                                                                                                    return false
                                                                                                                                                    end

                                                                                                                                                    return false
                                                                                                                                                    end

                                                                                                                                                    local function EvaluateQuestRewards(numChoices)
                                                                                                                                                    local bestValueIndex = 1
                                                                                                                                                    local bestValue = -1
                                                                                                                                                    local firstUsableGearIndex = nil

                                                                                                                                                    for i = 1, numChoices do
                                                                                                                                                        local _, _, numItems, _, isUsable = GetQuestItemInfo("choice", i)
                                                                                                                                                        local link = GetQuestItemLink("choice", i)
                                                                                                                                                        local count = numItems or 1
                                                                                                                                                        local sellPrice = 0

                                                                                                                                                        if link then
                                                                                                                                                            local _, _, _, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(link)
                                                                                                                                                            sellPrice = (itemSellPrice or 0) * count

                                                                                                                                                            if isUsable ~= false and IsUsableClassEquipment(link) and not firstUsableGearIndex then
                                                                                                                                                                firstUsableGearIndex = i
                                                                                                                                                                end
                                                                                                                                                                end

                                                                                                                                                                DebugLog(string.format("Choice #%d: link=%s, value=%d, usableGear=%s",
                                                                                                                                                                                       i, tostring(link), sellPrice, tostring(firstUsableGearIndex == i)))

                                                                                                                                                                if sellPrice > bestValue then
                                                                                                                                                                    bestValue = sellPrice
                                                                                                                                                                    bestValueIndex = i
                                                                                                                                                                    end
                                                                                                                                                                    end

                                                                                                                                                                    return firstUsableGearIndex, bestValueIndex
                                                                                                                                                                    end

                                                                                                                                                                    -- ============================================================================
                                                                                                                                                                    -- Gossip & Greeting Priority Engine
                                                                                                                                                                    -- Priority: 1. Completed Quests (turn-in) -> 2. Available Quests -> Skip Incomplete
                                                                                                                                                                    -- ============================================================================
                                                                                                                                                                    local function ProcessGreetingOrGossip()
                                                                                                                                                                    -- 1. Modern C_GossipInfo API (Classic Era / WoW Forever)
                                                                                                                                                                    if GossipFrame and GossipFrame:IsShown() and C_GossipInfo then
                                                                                                                                                                        local activeQuests = C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests() or {}
                                                                                                                                                                        local availableQuests = C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetAvailableQuests() or {}

                                                                                                                                                                        DebugLog(string.format("C_GossipInfo: active=%d, available=%d", #activeQuests, #availableQuests))

                                                                                                                                                                        for _, q in ipairs(activeQuests) do
                                                                                                                                                                            if q.isComplete then
                                                                                                                                                                                DebugLog("Selecting completed C_GossipInfo quest: " .. tostring(q.title))
                                                                                                                                                                                PlayUISound("igQuestListSelect")
                                                                                                                                                                                C_GossipInfo.SelectActiveQuest(q.questID)
                                                                                                                                                                                return true
                                                                                                                                                                                end
                                                                                                                                                                                end

                                                                                                                                                                                if #availableQuests > 0 then
                                                                                                                                                                                    local q = availableQuests[1]
                                                                                                                                                                                    DebugLog("Selecting available C_GossipInfo quest: " .. tostring(q.title))
                                                                                                                                                                                    PlayUISound("igQuestListSelect")
                                                                                                                                                                                    C_GossipInfo.SelectAvailableQuest(q.questID)
                                                                                                                                                                                    return true
                                                                                                                                                                                    end

                                                                                                                                                                                    DebugLog("GossipFrame has only incomplete active quests or non-quest options; skipping.")
                                                                                                                                                                                    return false
                                                                                                                                                                                    end

                                                                                                                                                                                    -- 2. Legacy Gossip API fallback
                                                                                                                                                                                    if GossipFrame and GossipFrame:IsShown() and GetGossipActiveQuests then
                                                                                                                                                                                        local activeArgs = { GetGossipActiveQuests() }
                                                                                                                                                                                        local numActive = GetNumGossipActiveQuests and GetNumGossipActiveQuests() or 0
                                                                                                                                                                                        if numActive > 0 then
                                                                                                                                                                                            local stride = math.floor(#activeArgs / numActive)
                                                                                                                                                                                            if stride < 1 then stride = 6 end
                                                                                                                                                                                                for idx = 1, numActive do
                                                                                                                                                                                                    local base = (idx - 1) * stride
                                                                                                                                                                                                    local title = activeArgs[base + 1]
                                                                                                                                                                                                    local isComplete = activeArgs[base + 4]
                                                                                                                                                                                                    if isComplete then
                                                                                                                                                                                                        DebugLog("Selecting legacy completed gossip quest: " .. tostring(title))
                                                                                                                                                                                                        PlayUISound("igQuestListSelect")
                                                                                                                                                                                                        SelectGossipActiveQuest(idx)
                                                                                                                                                                                                        return true
                                                                                                                                                                                                        end
                                                                                                                                                                                                        end
                                                                                                                                                                                                        end

                                                                                                                                                                                                        local numAvail = GetNumGossipAvailableQuests and GetNumGossipAvailableQuests() or 0
                                                                                                                                                                                                        if numAvail > 0 then
                                                                                                                                                                                                            DebugLog("Selecting legacy available gossip quest #1")
                                                                                                                                                                                                            PlayUISound("igQuestListSelect")
                                                                                                                                                                                                            SelectGossipAvailableQuest(1)
                                                                                                                                                                                                            return true
                                                                                                                                                                                                            end

                                                                                                                                                                                                            return false
                                                                                                                                                                                                            end

                                                                                                                                                                                                            -- 3. Classic QuestFrameGreetingPanel / QuestGreetingFrame
                                                                                                                                                                                                            local greetingShown = (QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsShown())
                                                                                                                                                                                                            or (QuestGreetingFrame and QuestGreetingFrame:IsShown())

                                                                                                                                                                                                            if greetingShown then
                                                                                                                                                                                                                local numActive = GetNumActiveQuests and GetNumActiveQuests() or 0
                                                                                                                                                                                                                local numAvail = GetNumAvailableQuests and GetNumAvailableQuests() or 0
                                                                                                                                                                                                                DebugLog(string.format("QuestGreetingPanel: active=%d, available=%d", numActive, numAvail))

                                                                                                                                                                                                                for i = 1, numActive do
                                                                                                                                                                                                                    local title, isComplete = GetActiveTitle(i)
                                                                                                                                                                                                                    if isComplete then
                                                                                                                                                                                                                        DebugLog("Selecting completed greeting quest #" .. i .. ": " .. tostring(title))
                                                                                                                                                                                                                        PlayUISound("igQuestListSelect")
                                                                                                                                                                                                                        SelectActiveQuest(i)
                                                                                                                                                                                                                        return true
                                                                                                                                                                                                                        end
                                                                                                                                                                                                                        end

                                                                                                                                                                                                                        if numAvail > 0 then
                                                                                                                                                                                                                            local title = GetAvailableTitle(1)
                                                                                                                                                                                                                            DebugLog("Selecting available greeting quest #1: " .. tostring(title))
                                                                                                                                                                                                                            PlayUISound("igQuestListSelect")
                                                                                                                                                                                                                            SelectAvailableQuest(1)
                                                                                                                                                                                                                            return true
                                                                                                                                                                                                                            end

                                                                                                                                                                                                                            DebugLog("QuestGreetingPanel has only incomplete quests; skipping.")
                                                                                                                                                                                                                            return false
                                                                                                                                                                                                                            end

                                                                                                                                                                                                                            return false
                                                                                                                                                                                                                            end

                                                                                                                                                                                                                            -- ============================================================================
                                                                                                                                                                                                                            -- SPACE & 1-4 Reward Action Handlers
                                                                                                                                                                                                                            -- ============================================================================
                                                                                                                                                                                                                            local function HandleRewardKey(index)
                                                                                                                                                                                                                            if not ForeverQuestKeyDB.enabled then return end
                                                                                                                                                                                                                                if IsTypingInChat() then return end
                                                                                                                                                                                                                                    if not QuestFrameRewardPanel or not QuestFrameRewardPanel:IsShown() then return end

                                                                                                                                                                                                                                        local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
                                                                                                                                                                                                                                        if index >= 1 and index <= numChoices and index <= 4 then
                                                                                                                                                                                                                                            HighlightRewardChoice(index, false)
                                                                                                                                                                                                                                            end
                                                                                                                                                                                                                                            end

                                                                                                                                                                                                                                            local function HandleSpaceAction()
                                                                                                                                                                                                                                            if not ForeverQuestKeyDB.enabled then return end
                                                                                                                                                                                                                                                if IsTypingInChat() then return end
                                                                                                                                                                                                                                                    if IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() then return end

                                                                                                                                                                                                                                                        -- 1. Greeting or Gossip frame
                                                                                                                                                                                                                                                        if (GossipFrame and GossipFrame:IsShown())
                                                                                                                                                                                                                                                            or (QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsShown())
                                                                                                                                                                                                                                                            or (QuestGreetingFrame and QuestGreetingFrame:IsShown()) then
                                                                                                                                                                                                                                                            ProcessGreetingOrGossip()
                                                                                                                                                                                                                                                            return
                                                                                                                                                                                                                                                            end

                                                                                                                                                                                                                                                            -- 2. Quest Detail (Accept Quest)
                                                                                                                                                                                                                                                            if QuestFrameDetailPanel and QuestFrameDetailPanel:IsShown() then
                                                                                                                                                                                                                                                                DebugLog("Accepting quest via SPACE")
                                                                                                                                                                                                                                                                PlayUISound("igQuestListComplete")
                                                                                                                                                                                                                                                                SetChainPending()
                                                                                                                                                                                                                                                                AcceptQuest()
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                -- 3. Quest Progress (Continue to Reward if completable)
                                                                                                                                                                                                                                                                if QuestFrameProgressPanel and QuestFrameProgressPanel:IsShown() then
                                                                                                                                                                                                                                                                if IsQuestCompletable and IsQuestCompletable() then
                                                                                                                                                                                                                                                                DebugLog("Completing quest objectives via SPACE")
                                                                                                                                                                                                                                                                PlayUISound("igQuestListComplete")
                                                                                                                                                                                                                                                                CompleteQuest()
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                ShowBanner("Quest objectives are still incomplete.")
                                                                                                                                                                                                                                                                DebugLog("Quest objectives incomplete; ignoring SPACE")
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                -- 4. Quest Reward (Turn-In & Claim Reward)
                                                                                                                                                                                                                                                                if QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown() then
                                                                                                                                                                                                                                                                local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0

                                                                                                                                                                                                                                                                if numChoices <= 1 then
                                                                                                                                                                                                                                                                local choiceArg = (numChoices == 1) and 1 or nil
                                                                                                                                                                                                                                                                DebugLog("Claiming single/no-choice quest reward (arg=" .. tostring(choiceArg) .. ")")
                                                                                                                                                                                                                                                                PlayUISound("igQuestListComplete")
                                                                                                                                                                                                                                                                ClearRewardVisuals()
                                                                                                                                                                                                                                                                SetChainPending()
                                                                                                                                                                                                                                                                GetQuestReward(choiceArg)
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                -- Multiple choices: confirm currently highlighted choice
                                                                                                                                                                                                                                                                local selected = QuestFrameRewardPanel.itemChoice
                                                                                                                                                                                                                                                                if selected and selected >= 1 and selected <= numChoices then
                                                                                                                                                                                                                                                                DebugLog("Confirming selected reward #" .. selected .. " via SPACE")
                                                                                                                                                                                                                                                                PlayUISound("igQuestListComplete")
                                                                                                                                                                                                                                                                ClearRewardVisuals()
                                                                                                                                                                                                                                                                SetChainPending()
                                                                                                                                                                                                                                                                GetQuestReward(selected)
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                ShowBanner("Press 1-" .. math.min(numChoices, 4) .. " to pick a reward first, then SPACE.")
                                                                                                                                                                                                                                                                PlayUISound("igMainMenuOptionCheckBoxOff")
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                spaceClickBtn:SetScript("OnClick", HandleSpaceAction)
                                                                                                                                                                                                                                                                for i = 1, 4 do
                                                                                                                                                                                                                                                                rewardClickBtns[i]:SetScript("OnClick", function()
                                                                                                                                                                                                                                                                HandleRewardKey(i)
                                                                                                                                                                                                                                                                end)
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                -- ============================================================================
                                                                                                                                                                                                                                                                -- Taint-Safe Override Keybinding Lifecycle
                                                                                                                                                                                                                                                                -- ============================================================================
                                                                                                                                                                                                                                                                local function ClearAllBindings()
                                                                                                                                                                                                                                                                if InCombatLockdown() then
                                                                                                                                                                                                                                                                pendingClearAfterCombat = true
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                if bindingsActive then
                                                                                                                                                                                                                                                                ClearOverrideBindings(bindingOwner)
                                                                                                                                                                                                                                                                bindingsActive = false
                                                                                                                                                                                                                                                                DebugLog("Cleared override keybindings")
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local function RefreshBindings()
                                                                                                                                                                                                                                                                if not ForeverQuestKeyDB or not ForeverQuestKeyDB.enabled then
                                                                                                                                                                                                                                                                ClearAllBindings()
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if InCombatLockdown() then
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if IsTypingInChat() then
                                                                                                                                                                                                                                                                ClearAllBindings()
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local anyQuestUI = (GossipFrame and GossipFrame:IsShown())
                                                                                                                                                                                                                                                                or (QuestFrame and QuestFrame:IsShown())
                                                                                                                                                                                                                                                                or (QuestGreetingFrame and QuestGreetingFrame:IsShown())

                                                                                                                                                                                                                                                                if not anyQuestUI then
                                                                                                                                                                                                                                                                ClearAllBindings()
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                ClearOverrideBindings(bindingOwner)
                                                                                                                                                                                                                                                                SetOverrideBindingClick(bindingOwner, true, "SPACE", "FQKSpaceActionButton")
                                                                                                                                                                                                                                                                bindingsActive = true

                                                                                                                                                                                                                                                                if QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown() then
                                                                                                                                                                                                                                                                local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
                                                                                                                                                                                                                                                                if numChoices > 1 then
                                                                                                                                                                                                                                                                local maxKeys = math.min(numChoices, 4)
                                                                                                                                                                                                                                                                for i = 1, maxKeys do
                                                                                                                                                                                                                                                                SetOverrideBindingClick(bindingOwner, true, tostring(i), "FQKRewardChoiceButton" .. i)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                DebugLog("Bound SPACE and keys 1-" .. maxKeys .. " for reward selection")
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                DebugLog("Bound SPACE for quest progression")
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                -- ============================================================================
                                                                                                                                                                                                                                                                -- Reward Panel Initialization on QUEST_COMPLETE
                                                                                                                                                                                                                                                                -- ============================================================================
                                                                                                                                                                                                                                                                local function OnQuestCompleteShown()
                                                                                                                                                                                                                                                                if not ForeverQuestKeyDB or not ForeverQuestKeyDB.enabled then return end
                                                                                                                                                                                                                                                                if not QuestFrameRewardPanel or not QuestFrameRewardPanel:IsShown() then return end

                                                                                                                                                                                                                                                                local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
                                                                                                                                                                                                                                                                activeRewardChoices = numChoices

                                                                                                                                                                                                                                                                if numChoices <= 1 then
                                                                                                                                                                                                                                                                ClearRewardVisuals()
                                                                                                                                                                                                                                                                ShowBanner("Press SPACE to complete quest")
                                                                                                                                                                                                                                                                RefreshBindings()
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                ShowRewardKeyBadges(numChoices)
                                                                                                                                                                                                                                                                local usableIndex, bestValueIndex = EvaluateQuestRewards(numChoices)

                                                                                                                                                                                                                                                                -- Clear any stale Blizzard pre-selection before applying smart suggestion
                                                                                                                                                                                                                                                                QuestFrameRewardPanel.itemChoice = nil

                                                                                                                                                                                                                                                                if ForeverQuestKeyDB.protectUsableGear and usableIndex then
                                                                                                                                                                                                                                                                HighlightRewardChoice(usableIndex, true)
                                                                                                                                                                                                                                                                ShowBanner("Usable gear [" .. usableIndex .. "] detected! Press 1-" .. math.min(numChoices, 4) .. " or SPACE to claim")
                                                                                                                                                                                                                                                                elseif ForeverQuestKeyDB.autoSelectHighestValue and bestValueIndex then
                                                                                                                                                                                                                                                                HighlightRewardChoice(bestValueIndex, true)
                                                                                                                                                                                                                                                                ShowBanner("Best value [" .. bestValueIndex .. "] selected — SPACE to claim or 1-" .. math.min(numChoices, 4) .. " to switch")
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                ShowBanner("Press 1-" .. math.min(numChoices, 4) .. " to select a reward, then SPACE to claim")
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                RefreshBindings()
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                -- ============================================================================
                                                                                                                                                                                                                                                                -- Frame Hooks & Event Handling
                                                                                                                                                                                                                                                                -- ============================================================================
                                                                                                                                                                                                                                                                local function HookQuestFrames()
                                                                                                                                                                                                                                                                local framesToHook = {
                                                                                                                                                                                                                                                                QuestFrame,
                                                                                                                                                                                                                                                                GossipFrame,
                                                                                                                                                                                                                                                                QuestFrameGreetingPanel,
                                                                                                                                                                                                                                                                QuestFrameDetailPanel,
                                                                                                                                                                                                                                                                QuestFrameProgressPanel,
                                                                                                                                                                                                                                                                QuestFrameRewardPanel,
                                                                                                                                                                                                                                                                QuestGreetingFrame,
                                                                                                                                                                                                                                                                }

                                                                                                                                                                                                                                                                for _, frame in ipairs(framesToHook) do
                                                                                                                                                                                                                                                                if frame and not frame.fqkHooked then
                                                                                                                                                                                                                                                                frame:HookScript("OnShow", function()
                                                                                                                                                                                                                                                                RefreshBindings()
                                                                                                                                                                                                                                                                end)
                                                                                                                                                                                                                                                                frame:HookScript("OnHide", function()
                                                                                                                                                                                                                                                                if frame == QuestFrameRewardPanel or frame == QuestFrame then
                                                                                                                                                                                                                                                                ClearRewardVisuals()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                C_Timer.After(0.05, RefreshBindings)
                                                                                                                                                                                                                                                                end)
                                                                                                                                                                                                                                                                frame.fqkHooked = true
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if ChatFrame1EditBox and not ChatFrame1EditBox.fqkHooked then
                                                                                                                                                                                                                                                                ChatFrame1EditBox:HookScript("OnEditFocusGained", ClearAllBindings)
                                                                                                                                                                                                                                                                ChatFrame1EditBox:HookScript("OnEditFocusLost", function()
                                                                                                                                                                                                                                                                C_Timer.After(0.05, RefreshBindings)
                                                                                                                                                                                                                                                                end)
                                                                                                                                                                                                                                                                ChatFrame1EditBox.fqkHooked = true
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local eventFrame = CreateFrame("Frame")
                                                                                                                                                                                                                                                                eventFrame:RegisterEvent("ADDON_LOADED")
                                                                                                                                                                                                                                                                eventFrame:RegisterEvent("GOSSIP_SHOW")
                                                                                                                                                                                                                                                                eventFrame:RegisterEvent("QUEST_GREETING")
                                                                                                                                                                                                                                                                eventFrame:RegisterEvent("QUEST_DETAIL")
                                                                                                                                                                                                                                                                eventFrame:RegisterEvent("QUEST_PROGRESS")
                                                                                                                                                                                                                                                                eventFrame:RegisterEvent("QUEST_COMPLETE")
                                                                                                                                                                                                                                                                eventFrame:RegisterEvent("QUEST_FINISHED")
                                                                                                                                                                                                                                                                eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

                                                                                                                                                                                                                                                                eventFrame:SetScript("OnEvent", function(_, event, arg1)
                                                                                                                                                                                                                                                                if event == "ADDON_LOADED" then
                                                                                                                                                                                                                                                                if arg1 == ADDON_NAME then
                                                                                                                                                                                                                                                                for k, v in pairs(DEFAULTS) do
                                                                                                                                                                                                                                                                if ForeverQuestKeyDB[k] == nil then
                                                                                                                                                                                                                                                                ForeverQuestKeyDB[k] = v
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                HookQuestFrames()
                                                                                                                                                                                                                                                                DebugLog("Loaded v" .. ADDON_VERSION)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if event == "PLAYER_REGEN_ENABLED" then
                                                                                                                                                                                                                                                                if pendingClearAfterCombat then
                                                                                                                                                                                                                                                                pendingClearAfterCombat = false
                                                                                                                                                                                                                                                                RefreshBindings()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                HookQuestFrames()

                                                                                                                                                                                                                                                                if event == "QUEST_COMPLETE" then
                                                                                                                                                                                                                                                                C_Timer.After(0.05, OnQuestCompleteShown)
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if event == "QUEST_FINISHED" then
                                                                                                                                                                                                                                                                ClearRewardVisuals()
                                                                                                                                                                                                                                                                C_Timer.After(0.05, RefreshBindings)
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if event == "GOSSIP_SHOW" or event == "QUEST_GREETING" or event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" then
                                                                                                                                                                                                                                                                HideBanner()
                                                                                                                                                                                                                                                                if event == "QUEST_DETAIL" then
                                                                                                                                                                                                                                                                ShowBanner("Press SPACE to accept quest")
                                                                                                                                                                                                                                                                elseif event == "QUEST_PROGRESS" and IsQuestCompletable and IsQuestCompletable() then
                                                                                                                                                                                                                                                                ShowBanner("Press SPACE to turn in quest")
                                                                                                                                                                                                                                                                elseif IsChainPending() then
                                                                                                                                                                                                                                                                DebugLog("Chain quest follow-up detected on " .. event)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                C_Timer.After(0.05, RefreshBindings)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end)

                                                                                                                                                                                                                                                                -- ============================================================================
                                                                                                                                                                                                                                                                -- Slash Commands (/fqk)
                                                                                                                                                                                                                                                                -- ============================================================================
                                                                                                                                                                                                                                                                SLASH_FOREVERQUESTKEY1 = "/fqk"
                                                                                                                                                                                                                                                                SLASH_FOREVERQUESTKEY2 = "/foreverquestkey"

                                                                                                                                                                                                                                                                SlashCmdList["FOREVERQUESTKEY"] = function(rawMsg)
                                                                                                                                                                                                                                                                local cmd = string.lower(strtrim(rawMsg or ""))

                                                                                                                                                                                                                                                                if cmd == "debug" then
                                                                                                                                                                                                                                                                ForeverQuestKeyDB.debug = not ForeverQuestKeyDB.debug
                                                                                                                                                                                                                                                                PrintMsg("Debug logging: " .. (ForeverQuestKeyDB.debug and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
                                                                                                                                                                                                                                                                elseif cmd == "gear" or cmd == "protect" then
                                                                                                                                                                                                                                                                ForeverQuestKeyDB.protectUsableGear = not ForeverQuestKeyDB.protectUsableGear
                                                                                                                                                                                                                                                                PrintMsg("Usable class gear protection: " .. (ForeverQuestKeyDB.protectUsableGear and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
                                                                                                                                                                                                                                                                elseif cmd == "value" or cmd == "autovalue" then
                                                                                                                                                                                                                                                                ForeverQuestKeyDB.autoSelectHighestValue = not ForeverQuestKeyDB.autoSelectHighestValue
                                                                                                                                                                                                                                                                PrintMsg("Auto-highlight highest vendor value: " .. (ForeverQuestKeyDB.autoSelectHighestValue and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
                                                                                                                                                                                                                                                                elseif cmd == "sound" then
                                                                                                                                                                                                                                                                ForeverQuestKeyDB.soundEnabled = not ForeverQuestKeyDB.soundEnabled
                                                                                                                                                                                                                                                                PrintMsg("Sound feedback: " .. (ForeverQuestKeyDB.soundEnabled and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
                                                                                                                                                                                                                                                                elseif cmd == "toggle" then
                                                                                                                                                                                                                                                                ForeverQuestKeyDB.enabled = not ForeverQuestKeyDB.enabled
                                                                                                                                                                                                                                                                if not ForeverQuestKeyDB.enabled then
                                                                                                                                                                                                                                                                ClearRewardVisuals()
                                                                                                                                                                                                                                                                ClearAllBindings()
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                RefreshBindings()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                PrintMsg("Addon enabled: " .. (ForeverQuestKeyDB.enabled and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                PrintMsg("v" .. ADDON_VERSION .. " Commands:")
                                                                                                                                                                                                                                                                PrintMsg("  /fqk toggle — Enable/disable addon (" .. tostring(ForeverQuestKeyDB.enabled) .. ")")
                                                                                                                                                                                                                                                                PrintMsg("  /fqk gear — Toggle usable class gear highlight (" .. tostring(ForeverQuestKeyDB.protectUsableGear) .. ")")
                                                                                                                                                                                                                                                                PrintMsg("  /fqk value — Toggle highest vendor value highlight (" .. tostring(ForeverQuestKeyDB.autoSelectHighestValue) .. ")")
                                                                                                                                                                                                                                                                PrintMsg("  /fqk sound — Toggle UI sound effects (" .. tostring(ForeverQuestKeyDB.soundEnabled) .. ")")
                                                                                                                                                                                                                                                                PrintMsg("  /fqk debug — Toggle debug logging (" .. tostring(ForeverQuestKeyDB.debug) .. ")")
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
