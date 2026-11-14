local ADDON_NAME = "ForeverQuestKey"
local ADDON_VERSION = "1.2.8"

ForeverQuestKeyDB = ForeverQuestKeyDB or {}

local DEFAULTS = {
    enabled = true,
    soundEnabled = true,
    debug = false,
}

local MAX_DEBUG_LINES = 120
local debugLogLines = {}

local optionsFrame
local debugEditBox
local debugScrollFrame
local statusIndicatorText
local checkEnabled
local checkSound
local checkDebug

local function PrintMsg(msg)
DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[ForeverQuestKey]|r " .. tostring(msg))
end

local function RefreshDebugLogDisplay()
if not debugEditBox then return end

    if #debugLogLines == 0 then
        if ForeverQuestKeyDB and ForeverQuestKeyDB.debug then
            debugEditBox:SetText("Debug logging is ON. Interact with a quest NPC or press SPACE to record events...")
            else
                debugEditBox:SetText("Debug logging is OFF. Check 'Enable Debug Logging' above (or run /fqk debug) to capture events.")
                end
                else
                    debugEditBox:SetText(table.concat(debugLogLines, "\n"))
                    end

                    if debugScrollFrame and debugScrollFrame.UpdateScrollChildRect then
                        debugScrollFrame:UpdateScrollChildRect()
                        local maxScroll = debugScrollFrame:GetVerticalScrollRange() or 0
                        debugScrollFrame:SetVerticalScroll(maxScroll)
                        end
                        end

                        local function DebugLog(msg)
                        if not (ForeverQuestKeyDB and ForeverQuestKeyDB.debug) then
                            return
                            end

                            local text = tostring(msg)
                            local stamp = (date and date("%H:%M:%S")) or "00:00:00"

                            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[FQK Debug]|r " .. text)

                            table.insert(debugLogLines, string.format("[%s] %s", stamp, text))
                            while #debugLogLines > MAX_DEBUG_LINES do
                                table.remove(debugLogLines, 1)
                                end

                                RefreshDebugLogDisplay()
                                end

                                local function PlayUISound(soundName)
                                if ForeverQuestKeyDB and ForeverQuestKeyDB.soundEnabled and soundName then
                                    pcall(PlaySound, soundName)
                                    end
                                    end

                                    -- ============================================================================
                                    -- Override Keybinding Owner & Virtual Action Button
                                    -- ============================================================================
                                    local bindingOwner = CreateFrame("Frame", "FQKBindingOwnerFrame", UIParent)
                                    local spaceClickBtn = CreateFrame("Button", "FQKSpaceActionButton", UIParent)
                                    spaceClickBtn:SetSize(1, 1)
                                    spaceClickBtn:RegisterForClicks("AnyDown", "AnyUp")

                                    local pendingClearAfterCombat = false
                                    local bindingsActive = false
                                    local questDialogActive = false
                                    local statusBanner
                                    local statusBannerText

                                    local function IsTypingInChat()
                                    local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
                                    return focus ~= nil
                                    end

                                    local function IsAnyQuestFrameShown()
                                    return (GossipFrame and GossipFrame:IsShown())
                                    or (QuestFrame and QuestFrame:IsShown())
                                    or (QuestGreetingFrame and QuestGreetingFrame:IsShown())
                                    or (QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsShown())
                                    or (QuestFrameDetailPanel and QuestFrameDetailPanel:IsShown())
                                    or (QuestFrameProgressPanel and QuestFrameProgressPanel:IsShown())
                                    or (QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown())
                                    end

                                    local function UpdateBindingIndicator()
                                    if not statusIndicatorText then return end
                                        local action = GetBindingAction and GetBindingAction("SPACE", true) or "UNKNOWN"
                                        if bindingsActive and action == "CLICK FQKSpaceActionButton:LeftButton" then
                                            statusIndicatorText:SetText("SPACE Key State: |cff00ff00INTERCEPTED (Quest Advance)|r")
                                            else
                                                statusIndicatorText:SetText("SPACE Key State: |cffaaaaaaNormal (" .. tostring(action) .. ")|r")
                                                end
                                                end

                                                -- ============================================================================
                                                -- Status Banner (Yellow Background + Black Text)
                                                -- ============================================================================
                                                local function EnsureStatusBanner()
                                                if statusBanner then return end

                                                    statusBanner = CreateFrame("Frame", "FQKStatusBanner", QuestFrame)
                                                    statusBanner:SetSize(360, 26)
                                                    statusBanner:SetPoint("BOTTOM", QuestFrame, "TOP", -12, 4)
                                                    statusBanner:SetFrameStrata("HIGH")
                                                    statusBanner:Hide()

                                                    local border = statusBanner:CreateTexture(nil, "BACKGROUND")
                                                    border:SetPoint("TOPLEFT", statusBanner, "TOPLEFT", -1, 1)
                                                    border:SetPoint("BOTTOMRIGHT", statusBanner, "BOTTOMRIGHT", 1, -1)
                                                    border:SetColorTexture(0.12, 0.10, 0.04, 0.95)

                                                    local bg = statusBanner:CreateTexture(nil, "BORDER")
                                                    bg:SetAllPoints(statusBanner)
                                                    bg:SetColorTexture(0.98, 0.84, 0.24, 0.96)

                                                    statusBannerText = statusBanner:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                                                    statusBannerText:SetPoint("CENTER", statusBanner, "CENTER", 0, 0)
                                                    statusBannerText:SetTextColor(0.05, 0.05, 0.05, 1.0)
                                                    statusBannerText:SetShadowOffset(0, 0)
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
                                                            -- Gossip & Greeting Progression (Completed Quests First -> Available Quests)
                                                            -- ============================================================================
                                                            local function ProcessGreetingOrGossip()
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

                                                                            DebugLog("GossipFrame has no completed or available quests")
                                                                            return false
                                                                            end

                                                                            if GossipFrame and GossipFrame:IsShown() and GetGossipActiveQuests then
                                                                                local activeArgs = { GetGossipActiveQuests() }
                                                                                local numActive = GetNumGossipActiveQuests and GetNumGossipActiveQuests() or 0
                                                                                DebugLog(string.format("Legacy Gossip: active=%d", numActive))
                                                                                if numActive > 0 then
                                                                                    local stride = math.floor(#activeArgs / numActive)
                                                                                    if stride < 1 then stride = 6 end
                                                                                        for idx = 1, numActive do
                                                                                            local base = (idx - 1) * stride
                                                                                            if activeArgs[base + 4] then
                                                                                                DebugLog("Selecting legacy completed gossip quest #" .. idx)
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

                                                                                                    local greetingShown = (QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsShown())
                                                                                                    or (QuestGreetingFrame and QuestGreetingFrame:IsShown())

                                                                                                    if greetingShown then
                                                                                                        local numActive = GetNumActiveQuests and GetNumActiveQuests() or 0
                                                                                                        local numAvail = GetNumAvailableQuests and GetNumAvailableQuests() or 0
                                                                                                        DebugLog(string.format("GreetingPanel: active=%d, available=%d", numActive, numAvail))

                                                                                                        for i = 1, numActive do
                                                                                                            local _, isComplete = GetActiveTitle(i)
                                                                                                            if isComplete then
                                                                                                                DebugLog("Selecting completed greeting quest #" .. i)
                                                                                                                PlayUISound("igQuestListSelect")
                                                                                                                SelectActiveQuest(i)
                                                                                                                return true
                                                                                                                end
                                                                                                                end

                                                                                                                if numAvail > 0 then
                                                                                                                    DebugLog("Selecting available greeting quest #1")
                                                                                                                    PlayUISound("igQuestListSelect")
                                                                                                                    SelectAvailableQuest(1)
                                                                                                                    return true
                                                                                                                    end

                                                                                                                    return false
                                                                                                                    end

                                                                                                                    return false
                                                                                                                    end

                                                                                                                    -- ============================================================================
                                                                                                                    -- SPACE Progression Handler
                                                                                                                    -- ============================================================================
                                                                                                                    local function HandleSpaceAction(_, _, down)
                                                                                                                    -- Fire once on key-down (or legacy nil down); ignore key-up release event
                                                                                                                    if down == false then return end

                                                                                                                        if not ForeverQuestKeyDB or not ForeverQuestKeyDB.enabled then return end
                                                                                                                            if IsTypingInChat() then
                                                                                                                                DebugLog("SPACE ignored because an EditBox has keyboard focus")
                                                                                                                                return
                                                                                                                                end
                                                                                                                                if IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() then return end

                                                                                                                                    -- 1. Reward Panel: claim single/no-choice reward, or clicked multi-choice reward
                                                                                                                                    if QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown() then
                                                                                                                                        local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
                                                                                                                                        if numChoices <= 1 then
                                                                                                                                            local choiceArg = (numChoices == 1) and 1 or nil
                                                                                                                                            DebugLog("SPACE -> GetQuestReward(" .. tostring(choiceArg) .. ")")
                                                                                                                                            PlayUISound("igQuestListComplete")
                                                                                                                                            HideBanner()
                                                                                                                                            GetQuestReward(choiceArg)
                                                                                                                                            else
                                                                                                                                                local choice = (QuestInfoFrame and QuestInfoFrame.itemChoice)
                                                                                                                                                or (QuestFrameRewardPanel and QuestFrameRewardPanel.itemChoice)
                                                                                                                                                or 0
                                                                                                                                                if choice >= 1 and choice <= numChoices then
                                                                                                                                                    DebugLog("SPACE -> GetQuestReward(" .. tostring(choice) .. ")")
                                                                                                                                                    PlayUISound("igQuestListComplete")
                                                                                                                                                    HideBanner()
                                                                                                                                                    GetQuestReward(choice)
                                                                                                                                                    else
                                                                                                                                                        DebugLog("SPACE on RewardPanel with numChoices=" .. numChoices .. ", no choice clicked yet")
                                                                                                                                                        ShowBanner("Click a reward choice, then press SPACE to complete")
                                                                                                                                                        end
                                                                                                                                                        end
                                                                                                                                                        return
                                                                                                                                                        end

                                                                                                                                                        -- 2. Gossip or Greeting Frame
                                                                                                                                                        if (GossipFrame and GossipFrame:IsShown())
                                                                                                                                                            or (QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsShown())
                                                                                                                                                            or (QuestGreetingFrame and QuestGreetingFrame:IsShown()) then
                                                                                                                                                            DebugLog("SPACE -> ProcessGreetingOrGossip()")
                                                                                                                                                            ProcessGreetingOrGossip()
                                                                                                                                                            return
                                                                                                                                                            end

                                                                                                                                                            -- 3. Quest Detail Panel (Accept Quest)
                                                                                                                                                            if QuestFrameDetailPanel and QuestFrameDetailPanel:IsShown() then
                                                                                                                                                                DebugLog("SPACE -> AcceptQuest()")
                                                                                                                                                                PlayUISound("igQuestListComplete")
                                                                                                                                                                HideBanner()
                                                                                                                                                                AcceptQuest()
                                                                                                                                                                return
                                                                                                                                                                end

                                                                                                                                                                -- 4. Quest Progress Panel (Continue to Reward)
                                                                                                                                                                if QuestFrameProgressPanel and QuestFrameProgressPanel:IsShown() then
                                                                                                                                                                    if IsQuestCompletable and IsQuestCompletable() then
                                                                                                                                                                        DebugLog("SPACE -> CompleteQuest()")
                                                                                                                                                                        PlayUISound("igQuestListComplete")
                                                                                                                                                                        HideBanner()
                                                                                                                                                                        CompleteQuest()
                                                                                                                                                                        else
                                                                                                                                                                            DebugLog("SPACE -> Quest objectives incomplete")
                                                                                                                                                                            ShowBanner("Quest objectives are still incomplete.")
                                                                                                                                                                            end
                                                                                                                                                                            return
                                                                                                                                                                            end

                                                                                                                                                                            DebugLog("SPACE intercepted, but no active quest sub-panel matched")
                                                                                                                                                                            end

                                                                                                                                                                            spaceClickBtn:SetScript("OnClick", HandleSpaceAction)

                                                                                                                                                                            -- ============================================================================
                                                                                                                                                                            -- Taint-Safe SPACE Override Binding Lifecycle
                                                                                                                                                                            -- ============================================================================
                                                                                                                                                                            local function ClearAllBindings()
                                                                                                                                                                            if InCombatLockdown() then
                                                                                                                                                                                pendingClearAfterCombat = true
                                                                                                                                                                                return
                                                                                                                                                                                end
                                                                                                                                                                                if bindingsActive then
                                                                                                                                                                                    ClearOverrideBindings(bindingOwner)
                                                                                                                                                                                    bindingsActive = false
                                                                                                                                                                                    DebugLog("Cleared SPACE override binding -> restored " .. tostring(GetBindingAction and GetBindingAction("SPACE", true)))
                                                                                                                                                                                    end
                                                                                                                                                                                    UpdateBindingIndicator()
                                                                                                                                                                                    end

                                                                                                                                                                                    local function RefreshBindings()
                                                                                                                                                                                    if not ForeverQuestKeyDB or not ForeverQuestKeyDB.enabled then
                                                                                                                                                                                        ClearAllBindings()
                                                                                                                                                                                        return
                                                                                                                                                                                        end

                                                                                                                                                                                        if InCombatLockdown() then
                                                                                                                                                                                            DebugLog("Skipped binding update (InCombatLockdown)")
                                                                                                                                                                                            return
                                                                                                                                                                                            end

                                                                                                                                                                                            if IsTypingInChat() then
                                                                                                                                                                                                ClearAllBindings()
                                                                                                                                                                                                return
                                                                                                                                                                                                end

                                                                                                                                                                                                local shouldBind = questDialogActive or IsAnyQuestFrameShown()
                                                                                                                                                                                                if not shouldBind then
                                                                                                                                                                                                    ClearAllBindings()
                                                                                                                                                                                                    return
                                                                                                                                                                                                    end

                                                                                                                                                                                                    SetOverrideBindingClick(bindingOwner, true, "SPACE", "FQKSpaceActionButton", "LeftButton")
                                                                                                                                                                                                    bindingsActive = true
                                                                                                                                                                                                    local activeAction = GetBindingAction and GetBindingAction("SPACE", true) or "UNKNOWN"
                                                                                                                                                                                                    DebugLog("Bound SPACE -> active binding is now: " .. tostring(activeAction))
                                                                                                                                                                                                    UpdateBindingIndicator()
                                                                                                                                                                                                    end

                                                                                                                                                                                                    -- ============================================================================
                                                                                                                                                                                                    -- Options & Live Debug Window (/fqk)
                                                                                                                                                                                                    -- ============================================================================
                                                                                                                                                                                                    local function SyncOptionsUI()
                                                                                                                                                                                                    if not optionsFrame then return end
                                                                                                                                                                                                        if checkEnabled then
                                                                                                                                                                                                            checkEnabled:SetChecked(ForeverQuestKeyDB.enabled and true or false)
                                                                                                                                                                                                            end
                                                                                                                                                                                                            if checkSound then
                                                                                                                                                                                                                checkSound:SetChecked(ForeverQuestKeyDB.soundEnabled and true or false)
                                                                                                                                                                                                                end
                                                                                                                                                                                                                if checkDebug then
                                                                                                                                                                                                                    checkDebug:SetChecked(ForeverQuestKeyDB.debug and true or false)
                                                                                                                                                                                                                    end
                                                                                                                                                                                                                    UpdateBindingIndicator()
                                                                                                                                                                                                                    RefreshDebugLogDisplay()
                                                                                                                                                                                                                    end

                                                                                                                                                                                                                    local function CreateOptionCheckbox(parent, name, labelText, anchorTo, offsetY, onClick)
                                                                                                                                                                                                                    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
                                                                                                                                                                                                                    cb:SetSize(24, 24)
                                                                                                                                                                                                                    cb:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, offsetY)

                                                                                                                                                                                                                    local label = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                                                                                                                                                                                                                    label:SetPoint("LEFT", cb, "RIGHT", 6, 0)
                                                                                                                                                                                                                    label:SetText(labelText)
                                                                                                                                                                                                                    label:SetTextColor(0.95, 0.95, 0.95)
                                                                                                                                                                                                                    cb.label = label

                                                                                                                                                                                                                    cb:SetScript("OnClick", function(self)
                                                                                                                                                                                                                    local checked = self:GetChecked() and true or false
                                                                                                                                                                                                                    onClick(checked)
                                                                                                                                                                                                                    end)

                                                                                                                                                                                                                    return cb
                                                                                                                                                                                                                    end

                                                                                                                                                                                                                    local function EnsureOptionsWindow()
                                                                                                                                                                                                                    if optionsFrame then return optionsFrame end

                                                                                                                                                                                                                        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
                                                                                                                                                                                                                        optionsFrame = CreateFrame("Frame", "FQKOptionsFrame", UIParent, template)
                                                                                                                                                                                                                        optionsFrame:SetSize(440, 400)
                                                                                                                                                                                                                        optionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
                                                                                                                                                                                                                        optionsFrame:SetFrameStrata("DIALOG")
                                                                                                                                                                                                                        optionsFrame:SetMovable(true)
                                                                                                                                                                                                                        optionsFrame:EnableMouse(true)
                                                                                                                                                                                                                        optionsFrame:RegisterForDrag("LeftButton")
                                                                                                                                                                                                                        optionsFrame:SetClampedToScreen(true)
                                                                                                                                                                                                                        optionsFrame:Hide()

                                                                                                                                                                                                                        local backdropApplied = false
                                                                                                                                                                                                                        if optionsFrame.SetBackdrop then
                                                                                                                                                                                                                            backdropApplied = pcall(function()
                                                                                                                                                                                                                            optionsFrame:SetBackdrop({
                                                                                                                                                                                                                                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                                                                                                                                                                                                                                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                                                                                                                                                                                                                                tile = true,
                                                                                                                                                                                                                                tileSize = 32,
                                                                                                                                                                                                                                edgeSize = 24,
                                                                                                                                                                                                                                insets = { left = 6, right = 6, top = 6, bottom = 6 },
                                                                                                                                                                                                                            })
                                                                                                                                                                                                                            optionsFrame:SetBackdropColor(0.06, 0.07, 0.10, 0.96)
                                                                                                                                                                                                                            end)
                                                                                                                                                                                                                            end

                                                                                                                                                                                                                            if not backdropApplied then
                                                                                                                                                                                                                                local bg = optionsFrame:CreateTexture(nil, "BACKGROUND")
                                                                                                                                                                                                                                bg:SetAllPoints(optionsFrame)
                                                                                                                                                                                                                                bg:SetColorTexture(0.06, 0.07, 0.10, 0.95)
                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                optionsFrame:SetScript("OnDragStart", function(self)
                                                                                                                                                                                                                                self:StartMoving()
                                                                                                                                                                                                                                end)
                                                                                                                                                                                                                                optionsFrame:SetScript("OnDragStop", function(self)
                                                                                                                                                                                                                                self:StopMovingOrSizing()
                                                                                                                                                                                                                                local point, _, relPoint, x, y = self:GetPoint()
                                                                                                                                                                                                                                ForeverQuestKeyDB.windowPos = { point = point, relPoint = relPoint, x = x, y = y }
                                                                                                                                                                                                                                end)

                                                                                                                                                                                                                                if ForeverQuestKeyDB.windowPos then
                                                                                                                                                                                                                                    local p = ForeverQuestKeyDB.windowPos
                                                                                                                                                                                                                                    optionsFrame:ClearAllPoints()
                                                                                                                                                                                                                                    optionsFrame:SetPoint(p.point or "CENTER", UIParent, p.relPoint or "CENTER", p.x or 0, p.y or 20)
                                                                                                                                                                                                                                    end

                                                                                                                                                                                                                                    if UISpecialFrames then
                                                                                                                                                                                                                                        table.insert(UISpecialFrames, "FQKOptionsFrame")
                                                                                                                                                                                                                                        end

                                                                                                                                                                                                                                        local title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                                                                                                                                                                                                                                        title:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 18, -16)
                                                                                                                                                                                                                                        title:SetText("|cff33ff99ForeverQuestKey|r  |cffaaaaaa(v" .. ADDON_VERSION .. ")|r")

                                                                                                                                                                                                                                        local closeBtn = CreateFrame("Button", "FQKOptionsCloseButton", optionsFrame, "UIPanelCloseButton")
                                                                                                                                                                                                                                        closeBtn:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -6, -6)

                                                                                                                                                                                                                                        local subtitle = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                                                                                                                                                                                                                                        subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
                                                                                                                                                                                                                                        subtitle:SetTextColor(0.75, 0.78, 0.85)
                                                                                                                                                                                                                                        subtitle:SetText("Intercepts SPACE (Jump) while quest or gossip dialogs are open.")

                                                                                                                                                                                                                                        statusIndicatorText = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                                                                                                                                                                                                                                        statusIndicatorText:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -6)

                                                                                                                                                                                                                                        checkEnabled = CreateOptionCheckbox(
                                                                                                                                                                                                                                            optionsFrame,
                                                                                                                                                                                                                                            "FQKCheckEnabled",
                                                                                                                                                                                                                                            "Enable ForeverQuestKey (SPACE Quest Progression)",
                                                                                                                                                                                                                                                                statusIndicatorText,
                                                                                                                                                                                                                                                                -10,
                                                                                                                                                                                                                                                                function(checked)
                                                                                                                                                                                                                                                                ForeverQuestKeyDB.enabled = checked
                                                                                                                                                                                                                                                                if not checked then
                                                                                                                                                                                                                                                                HideBanner()
                                                                                                                                                                                                                                                                ClearAllBindings()
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                RefreshBindings()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                PrintMsg("Addon enabled: " .. (checked and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                        )

                                                                                                                                                                                                                                        checkSound = CreateOptionCheckbox(
                                                                                                                                                                                                                                            optionsFrame,
                                                                                                                                                                                                                                            "FQKCheckSound",
                                                                                                                                                                                                                                            "Play UI Sound Feedback on SPACE Actions",
                                                                                                                                                                                                                                            checkEnabled,
                                                                                                                                                                                                                                            -4,
                                                                                                                                                                                                                                            function(checked)
                                                                                                                                                                                                                                            ForeverQuestKeyDB.soundEnabled = checked
                                                                                                                                                                                                                                            PrintMsg("Sound feedback: " .. (checked and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
                                                                                                                                                                                                                                            end
                                                                                                                                                                                                                                        )

                                                                                                                                                                                                                                        checkDebug = CreateOptionCheckbox(
                                                                                                                                                                                                                                            optionsFrame,
                                                                                                                                                                                                                                            "FQKCheckDebug",
                                                                                                                                                                                                                                            "Enable Debug Logging (Chat Window + Log Panel Below)",
                                                                                                                                                                                                                                                                checkSound,
                                                                                                                                                                                                                                                                -4,
                                                                                                                                                                                                                                                                function(checked)
                                                                                                                                                                                                                                                                ForeverQuestKeyDB.debug = checked
                                                                                                                                                                                                                                                                PrintMsg("Debug logging: " .. (checked and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
                                                                                                                                                                                                                                                                if checked then
                                                                                                                                                                                                                                                                DebugLog("Debug logging enabled (v" .. ADDON_VERSION .. ")")
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                RefreshDebugLogDisplay()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                        )

                                                                                                                                                                                                                                        local logHeader = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                                                                                                                                                                                                                                        logHeader:SetPoint("TOPLEFT", checkDebug, "BOTTOMLEFT", 2, -12)
                                                                                                                                                                                                                                        logHeader:SetText("Live Debug Log (Select & Ctrl+C to copy):")
                                                                                                                                                                                                                                        logHeader:SetTextColor(1.0, 0.85, 0.25)

                                                                                                                                                                                                                                        local logBox = CreateFrame("Frame", "FQKDebugLogBox", optionsFrame, template)
                                                                                                                                                                                                                                        logBox:SetPoint("TOPLEFT", logHeader, "BOTTOMLEFT", -2, -6)
                                                                                                                                                                                                                                        logBox:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -16, 44)

                                                                                                                                                                                                                                        local boxBackdropApplied = false
                                                                                                                                                                                                                                        if logBox.SetBackdrop then
                                                                                                                                                                                                                                            boxBackdropApplied = pcall(function()
                                                                                                                                                                                                                                            logBox:SetBackdrop({
                                                                                                                                                                                                                                                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                                                                                                                                                                                                                                                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                                                                                                                                                                                                                                                tile = true,
                                                                                                                                                                                                                                                tileSize = 16,
                                                                                                                                                                                                                                                edgeSize = 12,
                                                                                                                                                                                                                                                insets = { left = 3, right = 3, top = 3, bottom = 3 },
                                                                                                                                                                                                                                            })
                                                                                                                                                                                                                                            logBox:SetBackdropColor(0.02, 0.02, 0.04, 0.92)
                                                                                                                                                                                                                                            logBox:SetBackdropBorderColor(0.35, 0.38, 0.45, 0.9)
                                                                                                                                                                                                                                            end)
                                                                                                                                                                                                                                            end
                                                                                                                                                                                                                                            if not boxBackdropApplied then
                                                                                                                                                                                                                                                local innerBg = logBox:CreateTexture(nil, "BACKGROUND")
                                                                                                                                                                                                                                                innerBg:SetAllPoints(logBox)
                                                                                                                                                                                                                                                innerBg:SetColorTexture(0.02, 0.02, 0.04, 0.92)
                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                debugScrollFrame = CreateFrame("ScrollFrame", "FQKDebugScrollFrame", logBox, "UIPanelScrollFrameTemplate")
                                                                                                                                                                                                                                                debugScrollFrame:SetPoint("TOPLEFT", logBox, "TOPLEFT", 8, -8)
                                                                                                                                                                                                                                                debugScrollFrame:SetPoint("BOTTOMRIGHT", logBox, "BOTTOMRIGHT", -28, 8)

                                                                                                                                                                                                                                                debugEditBox = CreateFrame("EditBox", "FQKDebugEditBox", debugScrollFrame)
                                                                                                                                                                                                                                                debugEditBox:SetMultiLine(true)
                                                                                                                                                                                                                                                debugEditBox:SetAutoFocus(false)
                                                                                                                                                                                                                                                debugEditBox:EnableMouse(true)
                                                                                                                                                                                                                                                debugEditBox:SetFontObject("ChatFontNormal")
                                                                                                                                                                                                                                                debugEditBox:SetWidth(365)
                                                                                                                                                                                                                                                debugEditBox:SetTextColor(0.92, 0.92, 0.92)
                                                                                                                                                                                                                                                debugEditBox:SetScript("OnEscapePressed", function(self)
                                                                                                                                                                                                                                                self:ClearFocus()
                                                                                                                                                                                                                                                optionsFrame:Hide()
                                                                                                                                                                                                                                                end)
                                                                                                                                                                                                                                                debugEditBox:SetScript("OnTextChanged", function()
                                                                                                                                                                                                                                                if debugScrollFrame and debugScrollFrame.UpdateScrollChildRect then
                                                                                                                                                                                                                                                    debugScrollFrame:UpdateScrollChildRect()
                                                                                                                                                                                                                                                    end
                                                                                                                                                                                                                                                    end)

                                                                                                                                                                                                                                                debugScrollFrame:SetScrollChild(debugEditBox)

                                                                                                                                                                                                                                                local clearBtn = CreateFrame("Button", "FQKClearLogButton", optionsFrame, "UIPanelButtonTemplate")
                                                                                                                                                                                                                                                clearBtn:SetSize(96, 22)
                                                                                                                                                                                                                                                clearBtn:SetPoint("BOTTOMLEFT", optionsFrame, "BOTTOMLEFT", 16, 14)
                                                                                                                                                                                                                                                clearBtn:SetText("Clear Log")
                                                                                                                                                                                                                                                clearBtn:SetScript("OnClick", function()
                                                                                                                                                                                                                                                wipe(debugLogLines)
                                                                                                                                                                                                                                                RefreshDebugLogDisplay()
                                                                                                                                                                                                                                                end)

                                                                                                                                                                                                                                                local selectAllBtn = CreateFrame("Button", "FQKSelectAllLogButton", optionsFrame, "UIPanelButtonTemplate")
                                                                                                                                                                                                                                                selectAllBtn:SetSize(116, 22)
                                                                                                                                                                                                                                                selectAllBtn:SetPoint("LEFT", clearBtn, "RIGHT", 8, 0)
                                                                                                                                                                                                                                                selectAllBtn:SetText("Select All")
                                                                                                                                                                                                                                                selectAllBtn:SetScript("OnClick", function()
                                                                                                                                                                                                                                                debugEditBox:SetFocus()
                                                                                                                                                                                                                                                debugEditBox:HighlightText()
                                                                                                                                                                                                                                                end)

                                                                                                                                                                                                                                                local closeBottomBtn = CreateFrame("Button", "FQKCloseBottomButton", optionsFrame, "UIPanelButtonTemplate")
                                                                                                                                                                                                                                                closeBottomBtn:SetSize(84, 22)
                                                                                                                                                                                                                                                closeBottomBtn:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -16, 14)
                                                                                                                                                                                                                                                closeBottomBtn:SetText("Close")
                                                                                                                                                                                                                                                closeBottomBtn:SetScript("OnClick", function()
                                                                                                                                                                                                                                                optionsFrame:Hide()
                                                                                                                                                                                                                                                end)

                                                                                                                                                                                                                                                SyncOptionsUI()
                                                                                                                                                                                                                                                return optionsFrame
                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                local function ToggleOptionsWindow()
                                                                                                                                                                                                                                                local frame = EnsureOptionsWindow()
                                                                                                                                                                                                                                                if frame:IsShown() then
                                                                                                                                                                                                                                                    frame:Hide()
                                                                                                                                                                                                                                                    else
                                                                                                                                                                                                                                                        SyncOptionsUI()
                                                                                                                                                                                                                                                        frame:Show()
                                                                                                                                                                                                                                                        end
                                                                                                                                                                                                                                                        end

                                                                                                                                                                                                                                                        -- ============================================================================
                                                                                                                                                                                                                                                        -- Frame Hooks & Events
                                                                                                                                                                                                                                                        -- ============================================================================
                                                                                                                                                                                                                                                        local function DeferredRefresh()
                                                                                                                                                                                                                                                        if not IsAnyQuestFrameShown() then
                                                                                                                                                                                                                                                            questDialogActive = false
                                                                                                                                                                                                                                                            end
                                                                                                                                                                                                                                                            RefreshBindings()
                                                                                                                                                                                                                                                            end

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
                                                                                                                                                                                                                                                                questDialogActive = true
                                                                                                                                                                                                                                                                RefreshBindings()
                                                                                                                                                                                                                                                                end)
                                                                                                                                                                                                                                                                frame:HookScript("OnHide", function()
                                                                                                                                                                                                                                                                if frame == QuestFrame then
                                                                                                                                                                                                                                                                HideBanner()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                if C_Timer and C_Timer.After then
                                                                                                                                                                                                                                                                C_Timer.After(0.05, DeferredRefresh)
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                DeferredRefresh()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end)
                                                                                                                                                                                                                                                                frame.fqkHooked = true
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if ChatFrame1EditBox and not ChatFrame1EditBox.fqkHooked then
                                                                                                                                                                                                                                                                ChatFrame1EditBox:HookScript("OnEditFocusGained", ClearAllBindings)
                                                                                                                                                                                                                                                                ChatFrame1EditBox:HookScript("OnEditFocusLost", function()
                                                                                                                                                                                                                                                                if C_Timer and C_Timer.After then
                                                                                                                                                                                                                                                                C_Timer.After(0.05, DeferredRefresh)
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                DeferredRefresh()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end)
                                                                                                                                                                                                                                                                ChatFrame1EditBox.fqkHooked = true
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local eventFrame = CreateFrame("Frame")
                                                                                                                                                                                                                                                                eventFrame:RegisterEvent("ADDON_LOADED")
                                                                                                                                                                                                                                                                eventFrame:RegisterEvent("GOSSIP_SHOW")
                                                                                                                                                                                                                                                                eventFrame:RegisterEvent("GOSSIP_CLOSED")
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
                                                                                                                                                                                                                                                                DeferredRefresh()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                HookQuestFrames()

                                                                                                                                                                                                                                                                if event == "QUEST_FINISHED" or event == "GOSSIP_CLOSED" then
                                                                                                                                                                                                                                                                DebugLog("Event: " .. event)
                                                                                                                                                                                                                                                                HideBanner()
                                                                                                                                                                                                                                                                questDialogActive = IsAnyQuestFrameShown()
                                                                                                                                                                                                                                                                RefreshBindings()
                                                                                                                                                                                                                                                                if C_Timer and C_Timer.After then
                                                                                                                                                                                                                                                                C_Timer.After(0.05, DeferredRefresh)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                -- Active dialog event (GOSSIP_SHOW, QUEST_GREETING, QUEST_DETAIL, QUEST_PROGRESS, QUEST_COMPLETE)
                                                                                                                                                                                                                                                                DebugLog("Event: " .. event)
                                                                                                                                                                                                                                                                questDialogActive = true
                                                                                                                                                                                                                                                                RefreshBindings()
                                                                                                                                                                                                                                                                if C_Timer and C_Timer.After then
                                                                                                                                                                                                                                                                C_Timer.After(0.05, RefreshBindings)
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if event == "QUEST_DETAIL" then
                                                                                                                                                                                                                                                                ShowBanner("Press SPACE to accept quest")
                                                                                                                                                                                                                                                                elseif event == "QUEST_PROGRESS" then
                                                                                                                                                                                                                                                                if IsQuestCompletable and IsQuestCompletable() then
                                                                                                                                                                                                                                                                ShowBanner("Press SPACE to continue")
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                ShowBanner("Quest objectives are still incomplete.")
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                elseif event == "QUEST_COMPLETE" then
                                                                                                                                                                                                                                                                local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
                                                                                                                                                                                                                                                                if numChoices <= 1 then
                                                                                                                                                                                                                                                                ShowBanner("Press SPACE to complete quest")
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                ShowBanner("Click a reward choice, then press SPACE to complete")
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                HideBanner()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end)

                                                                                                                                                                                                                                                                -- ============================================================================
                                                                                                                                                                                                                                                                -- Slash Commands (/fqk)
                                                                                                                                                                                                                                                                -- ============================================================================
                                                                                                                                                                                                                                                                SLASH_FOREVERQUESTKEY1 = "/fqk"
                                                                                                                                                                                                                                                                SLASH_FOREVERQUESTKEY2 = "/foreverquestkey"

                                                                                                                                                                                                                                                                SlashCmdList["FOREVERQUESTKEY"] = function(rawMsg)
                                                                                                                                                                                                                                                                local cmd = string.lower(string.match(rawMsg or "", "^%s*(.-)%s*$"))

                                                                                                                                                                                                                                                                if cmd == "" or cmd == "options" or cmd == "config" or cmd == "ui" then
                                                                                                                                                                                                                                                                ToggleOptionsWindow()
                                                                                                                                                                                                                                                                elseif cmd == "debug" then
                                                                                                                                                                                                                                                                ForeverQuestKeyDB.debug = not ForeverQuestKeyDB.debug
                                                                                                                                                                                                                                                                PrintMsg("Debug logging: " .. (ForeverQuestKeyDB.debug and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
                                                                                                                                                                                                                                                                if ForeverQuestKeyDB.debug then
                                                                                                                                                                                                                                                                DebugLog("Debug logging enabled via slash command")
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                SyncOptionsUI()
                                                                                                                                                                                                                                                                elseif cmd == "sound" then
                                                                                                                                                                                                                                                                ForeverQuestKeyDB.soundEnabled = not ForeverQuestKeyDB.soundEnabled
                                                                                                                                                                                                                                                                PrintMsg("Sound feedback: " .. (ForeverQuestKeyDB.soundEnabled and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
                                                                                                                                                                                                                                                                SyncOptionsUI()
                                                                                                                                                                                                                                                                elseif cmd == "toggle" then
                                                                                                                                                                                                                                                                ForeverQuestKeyDB.enabled = not ForeverQuestKeyDB.enabled
                                                                                                                                                                                                                                                                if not ForeverQuestKeyDB.enabled then
                                                                                                                                                                                                                                                                HideBanner()
                                                                                                                                                                                                                                                                ClearAllBindings()
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                RefreshBindings()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                PrintMsg("Addon enabled: " .. (ForeverQuestKeyDB.enabled and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
                                                                                                                                                                                                                                                                SyncOptionsUI()
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                PrintMsg("v" .. ADDON_VERSION .. " Commands:")
                                                                                                                                                                                                                                                                PrintMsg("  /fqk — Open or close the Options & Debug Log window")
                                                                                                                                                                                                                                                                PrintMsg("  /fqk toggle — Enable/disable addon (" .. tostring(ForeverQuestKeyDB.enabled) .. ")")
                                                                                                                                                                                                                                                                PrintMsg("  /fqk sound — Toggle UI sound effects (" .. tostring(ForeverQuestKeyDB.soundEnabled) .. ")")
                                                                                                                                                                                                                                                                PrintMsg("  /fqk debug — Toggle debug logging (" .. tostring(ForeverQuestKeyDB.debug) .. ")")
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
