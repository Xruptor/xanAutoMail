--This mod expands the functionality of the auto-name generation of blizzards in game mail system.
--Typically it will only auto-fill for names of players in your guild.
--This mod will expand it to include all your toons you've logged in as, B.Net Friends, and last 10 recently mailed individuals

local DB_PLAYER
local DB_RECENT
local currentPlayer
local currentRealm

local xanAutoMail = CreateFrame("frame","xanAutoMailFrame",UIParent)
xanAutoMail:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)

--lets embed AceHooks into our addon
xanAutoMail = LibStub("AceHook-3.0"):Embed(xanAutoMail)

function xanAutoMail:PLAYER_LOGIN()
	
	currentPlayer = UnitName('player')
	currentRealm = GetRealmName()
	
	--do the db initialization
	self:StartupDB()
	
	--increase the mailbox history lines to 15
	SendMailNameEditBox:SetHistoryLines(15)
	
	--do the hooks
	self:RawHook("SendMailFrame_Reset", true)
	self:RawHook("MailFrameTab_OnClick", true)
	self:RawHookScript(SendMailNameEditBox, "OnChar")
	self:HookScript(SendMailNameEditBox, "OnEditFocusGained")
	self:RawHook("AutoComplete_Update", true)
	
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

--This is called when mailed is sent
function xanAutoMail:SendMailFrame_Reset()

	--first lets get the playername
	local playerName = strtrim(SendMailNameEditBox:GetText())
	
	--if we don't have something to work with then call original function
	if string.len(playerName) < 1 then
		return self.hooks["SendMailFrame_Reset"]()
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
	self.hooks["SendMailFrame_Reset"]()
	
	-- set the name to the auto fill
	SendMailNameEditBox:SetText(playerName)
	SendMailNameEditBox:HighlightText()
end

--this is called when one of the mailtabs is clicked
--we have to autofill the name when the tabs are clicked
function xanAutoMail:MailFrameTab_OnClick(button, tab)
	self.hooks["MailFrameTab_OnClick"](button, tab)
	if tab == 2 then
		local playerName = DB_RECENT[1]
		if playerName and SendMailNameEditBox:GetText() == "" then
			SendMailNameEditBox:SetText(playerName)
			SendMailNameEditBox:HighlightText()
		end
	end
end

--this function is called each time a character is pressed in the playername field of the mail window
function xanAutoMail:OnChar(editbox, ...)
	if editbox:GetUTF8CursorPosition() ~= strlenutf8(editbox:GetText()) then return end

	local text = strupper(editbox:GetText())
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
	self.hooks[SendMailNameEditBox].OnChar(editbox, ...)

	--if we found a name then override the one in the editbox
	if foundName then
		editbox:SetText(foundName)
		editbox:HighlightText(textlen, -1)
		editbox:SetCursorPosition(textlen)
	end

end

function xanAutoMail:OnEditFocusGained(editbox, ...)
	SendMailNameEditBox:HighlightText()
end

function xanAutoMail:AutoComplete_Update(editBox, editBoxText, utf8Position, ...)
	if editBox ~= SendMailNameEditBox then
		self.hooks["AutoComplete_Update"](editBox, editBoxText, utf8Position, ...)
	end
end

if IsLoggedIn() then xanAutoMail:PLAYER_LOGIN() else xanAutoMail:RegisterEvent("PLAYER_LOGIN") end

