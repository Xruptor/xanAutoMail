--This mod expands the functionality of the auto-name generation of blizzards in game mail system.
--Typically it will only auto-fill for names of players in your guild.
--This mod will expand it to include all your toons you've logged in as, B.Net Friends, and last 10 recently mailed individuals

local DB_PLAYER
local DB_RECENT
local currentPlayer
local currentRealm
local origHook = {}
local inboxAllButton
local inboxInfoText

local xanAutoMail = CreateFrame("frame","xanAutoMailFrame",UIParent)
xanAutoMail:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)

local debugf = tekDebug and tekDebug:GetFrame("xanAutoMail")
local function Debug(...)
    if debugf then debugf:AddMessage(string.join(", ", tostringall(...))) end
end

--[[------------------------
	CORE
--------------------------]]

function xanAutoMail:PLAYER_LOGIN()
	
	currentPlayer = UnitName('player')
	currentRealm = GetRealmName()
	
	--do the db initialization
	self:StartupDB()
	
	--increase the mailbox history lines to 15
	SendMailNameEditBox:SetHistoryLines(15)
	
	--HOOKS FOR CHARACTER NAME HISTORY
	---------------------------------
	---------------------------------
	origHook["SendMailFrame_Reset"] = SendMailFrame_Reset
	SendMailFrame_Reset = self.SendMailFrame_Reset
	
	origHook["MailFrameTab_OnClick"] = MailFrameTab_OnClick
	MailFrameTab_OnClick = self.MailFrameTab_OnClick
	
	origHook["AutoComplete_Update"] = AutoComplete_Update
	AutoComplete_Update = self.AutoComplete_Update
	
	origHook[SendMailNameEditBox] = origHook[SendMailNameEditBox] or {}
	origHook[SendMailNameEditBox]["OnEditFocusGained"] = SendMailNameEditBox:GetScript("OnEditFocusGained")
	origHook[SendMailNameEditBox]["OnChar"] = SendMailNameEditBox:GetScript("OnChar")
	SendMailNameEditBox:SetScript("OnEditFocusGained", self.OnEditFocusGained)
	SendMailNameEditBox:SetScript("OnChar", self.OnChar)
	---------------------------------
	---------------------------------
	
	--make the open all button
	inboxAllButton = CreateFrame("Button", "xanAutoMail_OpenAllBTN", InboxFrame, "UIPanelButtonTemplate")
	inboxAllButton:SetWidth(100)
	inboxAllButton:SetHeight(20)
	inboxAllButton:SetPoint("CENTER", InboxFrame, "TOP", -80, -55)
	inboxAllButton:SetText("Open All")
	inboxAllButton:SetScript("OnClick", function() xanAutoMail.StartMailGrab() end)

	inboxInfoText = InboxFrame:CreateFontString("xanAutoMail_InfoText", "ARTWORK", "GameFontNormalSmall")
	inboxInfoText:SetJustifyH("LEFT")
	inboxInfoText:SetFontObject("GameFontNormal")
	inboxInfoText:SetPoint("TOPLEFT", inboxAllButton, "TOPRIGHT", 5, -5)

	self:UnregisterEvent("PLAYER_LOGIN")
	self.PLAYER_LOGIN = nil

end

function xanAutoMail:StartupDB()
	xanAutoMailDB = xanAutoMailDB or {}
	xanAutoMailDB[currentRealm] = xanAutoMailDB[currentRealm] or {}

	--player list
	xanAutoMailDB[currentRealm]["player"] = xanAutoMailDB[currentRealm]["player"] or {}
	DB_PLAYER = xanAutoMailDB[currentRealm]["player"]
	
	--recent list
	xanAutoMailDB[currentRealm]["recent"] = xanAutoMailDB[currentRealm]["recent"] or {}
	DB_RECENT = xanAutoMailDB[currentRealm]["recent"]
	
	--check for current user
	if DB_PLAYER[currentPlayer] == nil then DB_PLAYER[currentPlayer] = true end
end


---------------------------------------------------
---------------CHARACTER NAME DB ------------------
---------------------------------------------------

--This is called when mailed is sent
function xanAutoMail:SendMailFrame_Reset()

	--first lets get the playername
	local playerName = strtrim(SendMailNameEditBox:GetText())
	
	--if we don't have something to work with then call original function
	if string.len(playerName) < 1 then
		return origHook["SendMailFrame_Reset"]()
	end
	
	--add the name to the history
	SendMailNameEditBox:AddHistoryLine(playerName)

	--add the name to our recent DB, first check to see if it's already there
	--if so then remove it, otherwise add it to the top of the list and remove the 11 entry from the table.
	--afterwards call the original function
	for k = 1, #DB_RECENT do
		if playerName == DB_RECENT[k] then
			tremove(DB_RECENT, k)
			break
		end
	end
	tinsert(DB_RECENT, 1, playerName)
	for k = #DB_RECENT, 11, -1 do
		tremove(DB_RECENT, k)
	end
	origHook["SendMailFrame_Reset"]()
	
	-- set the name to the auto fill
	SendMailNameEditBox:SetText(playerName)
	SendMailNameEditBox:HighlightText()
end

--this is called when one of the mailtabs is clicked
--we have to autofill the name when the tabs are clicked
function xanAutoMail:MailFrameTab_OnClick(tab)
	origHook["MailFrameTab_OnClick"](self, tab)
	if tab == 2 then
		local playerName = DB_RECENT[1]
		if playerName and SendMailNameEditBox:GetText() == "" then
			SendMailNameEditBox:SetText(playerName)
			SendMailNameEditBox:HighlightText()
		end
	end
end

--this function is called each time a character is pressed in the playername field of the mail window
function xanAutoMail:OnChar(...)
	if self:GetUTF8CursorPosition() ~= strlenutf8(self:GetText()) then return end
	local text = strupper(self:GetText())
	local textlen = strlen(text)
	local foundName

	--check player toons
	for k, v in pairs(DB_PLAYER) do
		if strfind(strupper(k), text, 1, 1) == 1 then
			foundName = k
			break
		end
	end

	--check our recent list
	if not foundName then
		for k = 1, #DB_RECENT do
			local playerName = DB_RECENT[k]
			if strfind(strupper(playerName), text, 1, 1) == 1 then
				foundName = playerName
				break
			end
		end
	end

	--Check our RealID friends
	if not foundName then
		local numBNetTotal, numBNetOnline = BNGetNumFriends()
		for i = 1, numBNetOnline do
			local presenceID, givenName, surname, toonName, toonID, client = BNGetFriendInfo(i)
			if (toonName and client == BNET_CLIENT_WOW and CanCooperateWithToon(toonID)) then
				if strfind(strupper(toonName), text, 1, 1) == 1 then
					foundName = toonName
					break
				end
			end
		end
	end

	--call the original onChar to display the dropdown
	origHook[SendMailNameEditBox]["OnChar"](self, ...)
	
	--if we found a name then override the one in the editbox
	if foundName then
		self:SetText(foundName)
		self:HighlightText(textlen, -1)
		self:SetCursorPosition(textlen)
	end

end

function xanAutoMail:OnEditFocusGained(...)
	SendMailNameEditBox:HighlightText()
end

function xanAutoMail:AutoComplete_Update(editBoxText, utf8Position, ...)
	if self ~= SendMailNameEditBox then
		origHook["AutoComplete_Update"](self, editBoxText, utf8Position, ...)
	end
end

---------------------------------------------------
---------------------------------------------------
---------------------------------------------------

--[[------------------------
	OPEN ALL MAIL
--------------------------]]

local delayCount = {}
local moneyCount = 0
local skipCount = 0
local errorCheckCount = 0
local currentStatus = "STOP"

xanAutoMail:RegisterEvent("MAIL_CLOSED")
xanAutoMail:RegisterEvent("MAIL_SHOW")
xanAutoMail:RegisterEvent("MAIL_INBOX_UPDATE")
xanAutoMail:RegisterEvent("UI_ERROR_MESSAGE")

local function colorMoneyText(value)
	if not value then return "" end
	local gold = abs(value / 10000)
	local silver = abs(mod(value / 100, 100))
	local copper = abs(mod(value, 100))
	
	local GOLD_ABRV = "g"
	local SILVER_ABRV = "s"
	local COPPER_ABRV = "c"
	
	local WHITE = "ffffff"
	local COLOR_COPPER = "eda55f"
	local COLOR_SILVER = "c7c7cf"
	local COLOR_GOLD = "ffd700"

	if value >= 10000 or value <= -10000 then
		return format("|cff%s%d|r|cff%s%s|r |cff%s%d|r|cff%s%s|r |cff%s%d|r|cff%s%s|r", WHITE, gold, COLOR_GOLD, GOLD_ABRV, WHITE, silver, COLOR_SILVER, SILVER_ABRV, WHITE, copper, COLOR_COPPER, COPPER_ABRV)
	elseif value >= 100 or value <= -100 then
		return format("|cff%s%d|r|cff%s%s|r |cff%s%d|r|cff%s%s|r", WHITE, silver, COLOR_SILVER, SILVER_ABRV, WHITE, copper, COLOR_COPPER, COPPER_ABRV)
	else
		return format("|cff%s%d|r|cff%s%s|r", WHITE, copper, COLOR_COPPER, COPPER_ABRV)
	end
end

local function freeSpace()
	local totalFree = 0
	for i=0, NUM_BAG_SLOTS do
		local numberOfFreeSlots = GetContainerNumFreeSlots(i)
		totalFree = totalFree + numberOfFreeSlots
	end
	return totalFree
end

local function inboxFullCheck()
	--sometimes the mailbox is full, if this happens we have to make changes to the button position
	local nItem, nTotal = GetInboxNumItems()
	if nItem and nTotal then
		if ( nTotal > nItem) or InboxTooMuchMail:IsVisible() and not inboxAllButton.movedBottom then
			inboxAllButton:ClearAllPoints()
			inboxAllButton:SetPoint("CENTER", InboxFrame, "BOTTOM", -60, 100)
			inboxAllButton.movedBottom = true
			inboxInfoText:ClearAllPoints()
			inboxInfoText:SetPoint("TOPLEFT", inboxAllButton, "TOPRIGHT", 5, -5)
		elseif (( nTotal < nItem) or not InboxTooMuchMail:IsVisible()) and inboxAllButton.movedBottom then
			inboxAllButton.movedBottom = nil
			inboxAllButton:ClearAllPoints()
			inboxAllButton:SetPoint("CENTER", InboxFrame, "TOP", -80, -55)
			inboxInfoText:ClearAllPoints()
			inboxInfoText:SetPoint("TOPLEFT", inboxAllButton, "TOPRIGHT", 5, -5)
		end 
	end
end

xanAutoMail:SetScript("OnUpdate",
	function( self, elapsed )
		if #delayCount > 0 then
			for i = #delayCount, 1, -1 do
				if delayCount[i].endTime and delayCount[i].endTime <= GetTime() then
					local func = delayCount[i].callbackFunction
					tremove(delayCount, i)
					func()
				end
			end
		end
	end
)

function xanAutoMail:Delay(name, duration, callbackFunction, force)
	if not force and currentStatus == "STOP" then return end
	for k, q in ipairs(delayCount) do
		if q.name == name then
			--don't run the same delay more than once, we can however refresh it
			q.duration = duration
			q.endTime = (GetTime()+duration)
			q.callbackFunction = callbackFunction
			return
		end
	end
	tinsert(delayCount, {name=name, duration=duration, endTime=(GetTime()+duration), callbackFunction=callbackFunction})
end

function xanAutoMail:UpdateInfoText()
	local nItem, nTotal = GetInboxNumItems()
	if nTotal == nItem then
		inboxInfoText:SetText(format("Showing all %d mail.", nItem))
	else
		inboxInfoText:SetText(format("Showing %d of %d mail.", nItem, nTotal))
	end
	--hide the stupid icon if necessary
	if nTotal <= 0 and MiniMapMailFrame:IsVisible() then
		MiniMapMailFrame:Hide()
	end
end

function xanAutoMail:MAIL_SHOW()
	inboxFullCheck()
	CheckInbox()
	inboxInfoText:SetText("Waiting...")
	xanAutoMail:Delay("mailInfoText", 0.5, xanAutoMail.UpdateInfoText, true)
end

function xanAutoMail:MAIL_CLOSED()
	xanAutoMail:StopMailGrab(true, 1)
end

function xanAutoMail:MAIL_INBOX_UPDATE()
	xanAutoMail:Delay("mailInfoText", 0.5, xanAutoMail.UpdateInfoText, true)
	if currentStatus == "STOP" then return end
	--keep increasing the delay before the next mail grab until all items are taken from current opened mail
	xanAutoMail:Delay("mailGrabNextItem", 0.5, xanAutoMail.GrabNextMailItem)
end

function xanAutoMail:UI_ERROR_MESSAGE(event, num, msg)

	if currentStatus == "STOP" then return end
	local stopMailGrab = false
	
	if msg == ERR_MAIL_DATABASE_ERROR then
		DEFAULT_CHAT_FRAME:AddMessage("xanAutoMail: (ERROR) There was a mailbox database error from the server.")
		stopMailGrab = true
	elseif msg == ERR_INV_FULL then
		DEFAULT_CHAT_FRAME:AddMessage("xanAutoMail: (ERROR) Your inventory is full.")
		stopMailGrab = true
	elseif msg == ERR_ITEM_MAX_COUNT then
		DEFAULT_CHAT_FRAME:AddMessage("xanAutoMail: (ERROR) Cannot loot anymore unique items from Mailbox.")
		DEFAULT_CHAT_FRAME:AddMessage("xanAutoMail: Please the delete item(s) from the Mailbox before trying again.")
		stopMailGrab = true
	end

	if stopMailGrab then
		xanAutoMail:StopMailGrab(false, 2)
		return
	end
end

function xanAutoMail:IsMailItemEmpty(index)
	local packageIcon, stationeryIcon, sender, subject, money, COD, daysLeft, numItems, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity = GetInboxHeaderInfo(index)
	if isGM then return false end
	if canReply then return false end
	if numItems then return false end
	if COD > 0 then return false end
	if money > 0 then return false end
	if wasReturned then return false end
	return true
end

function xanAutoMail:GrabNextMailItem()
	if currentStatus == "STOP" then return end
	--do inbox check
	if currentStatus == "CHECK" then
		CheckInbox()
		currentStatus = "SKIPCHECK"
		xanAutoMail:Delay("mailGrabNextItem", 0.5, xanAutoMail.GrabNextMailItem)
		return
	end
	
	local nItem, nTotal = GetInboxNumItems()
	
	xanAutoMail:UpdateInfoText()
	
	--check to see if the last messages were read or if we have nothing to work with, or we have done more than 50 error checks, which is roughly about 10 to 11 seconds
	if nTotal <= 0 or skipCount >= nTotal or errorCheckCount > 50 then
		if errorCheckCount > 50 then
			DEFAULT_CHAT_FRAME:AddMessage("xanAutoMail: (ERROR) Mailbox latency error. (Try Again)")
		end
		xanAutoMail:StopMailGrab(false, 4)
		return
	elseif freeSpace() < 1 then
		xanAutoMail:StopMailGrab(false, 5)
		DEFAULT_CHAT_FRAME:AddMessage("xanAutoMail: (ERROR) Your inventory is full.")
		return
	elseif (nItem <= 0 or skipCount >= nItem) and nTotal > 0 then
		--if we still have something to work with then fire in another 45 seconds
		currentStatus = "CHECK"
		errorCheckCount = 0
		xanAutoMail:Delay("mailInboxCheck", 45, xanAutoMail.GrabNextMailItem)
		inboxInfoText:SetText("Waiting 45 seconds")
		DEFAULT_CHAT_FRAME:AddMessage("xanAutoMail: Waiting 45 seconds for next mail batch.")
		return
	end
	
	skipCount = 0 --reset
	
	for mIndex = nItem, 1, -1 do
		local _, _, _, _, money, COD, _, numItems, wasRead, _, _, _, isGM = GetInboxHeaderInfo(mIndex)
		
		if money > 0 or (numItems and numItems > 0) and COD <= 0 and not isGM then
			if money > 0 then moneyCount = moneyCount + money end
			TakeInboxMoney(mIndex)
			AutoLootMailItem(mIndex)
			--we looted something so lets wait for next update
			xanAutoMail:Delay("mailGrabNextItem", 0.5, xanAutoMail.GrabNextMailItem) --just in case
			return
		end
		if xanAutoMail:IsMailItemEmpty(mIndex) then
			DeleteInboxItem(mIndex)
			xanAutoMail:Delay("mailGrabNextItem", 0.5, xanAutoMail.GrabNextMailItem) --just in case
			return
		end
		
		skipCount = skipCount + 1
	end

	xanAutoMail:Delay("mailGrabNextItem", 0.2, xanAutoMail.GrabNextMailItem)
	errorCheckCount = errorCheckCount + 1

end

function xanAutoMail:StartMailGrab()
	if GetInboxNumItems() == 0 then return end
	currentStatus = "START"
	inboxAllButton:Disable()
	moneyCount = 0
	skipCount = 0
	errorCheckCount = 0
	xanAutoMail:Delay("mailGrabNextItem", 0.2, xanAutoMail.GrabNextMailItem)
end

function xanAutoMail:StopMailGrab(force, flag)
	currentStatus = "STOP"
	delayCount = {}
	inboxAllButton:Enable()
	if not force then
		if moneyCount > 0 then
			DEFAULT_CHAT_FRAME:AddMessage("xanAutoMail: Total money from mailbox ["..colorMoneyText(moneyCount).."]")
		end
		CheckInbox()
		xanAutoMail:Delay("mailInfoText", 0.5, xanAutoMail.UpdateInfoText, true)
	end
end


if IsLoggedIn() then xanAutoMail:PLAYER_LOGIN() else xanAutoMail:RegisterEvent("PLAYER_LOGIN") end



























