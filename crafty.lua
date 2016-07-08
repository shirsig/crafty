local crafty = CreateFrame('Frame', nil, UIParent)
crafty:SetScript('OnEvent', function()
	this[event](this)
end)
crafty:RegisterEvent('ADDON_LOADED')

local TRADE, CRAFT = 1, 2

do
	local function action()
	    local input = strlower(getglobal(this:GetParent():GetName()..'EditBox'):GetText())
	    if tonumber(input) then
	    	crafty:SendReagentsMessage('CHANNEL', input)
		elseif input == 'guild' or input == 'g' then
			crafty:SendReagentsMessage('GUILD')
		elseif input == 'o' then
			crafty:SendReagentsMessage('OFFICER')
		elseif input == 'raid' or input == 'ra' then
			crafty:SendReagentsMessage('RAID')
		elseif input == 'rw' then
			crafty:SendReagentsMessage('RAID_WARNING')
		elseif input == 'bg' then
			crafty:SendReagentsMessage('BATTLEGROUND')
		elseif input == 'party' or input == 'p' then
			crafty:SendReagentsMessage('PARTY')
		elseif input == 'say' or input == 's' then
			crafty:SendReagentsMessage('SAY')
		elseif input == 'yell' or input == 'y' then
			crafty:SendReagentsMessage('YELL')	
		elseif input == 'emote' or input == 'em' then
			crafty:SendReagentsMessage('EMOTE')	
		elseif input == 'reply' or input == 'r' then
			if ChatEdit_GetLastTellTarget(ChatFrameEditBox) ~= '' then
				crafty:SendReagentsMessage('WHISPER', ChatEdit_GetLastTellTarget(ChatFrameEditBox))
			end
		elseif strlen(input) > 1 then
			crafty:SendReagentsMessage('WHISPER', input)
		end
	end

	StaticPopupDialogs['CRAFTY_LINK'] = {
	    text = 'Enter a character name or channel.',
	    button1 = 'Link',
	    button2 = 'Cancel',
	    hasEditBox = 1,
	    OnShow = function()
	    	local editBox = getglobal(this:GetName()..'EditBox')
			editBox:SetText('')
			editBox:SetFocus()
		end,
	    OnAccept = action,
	    EditBoxOnEnterPressed = function()
	    	action()
			this:GetParent():Hide()
		end,
		EditBoxOnEscapePressed = function()
			this:GetParent():Hide()
		end,
	    timeout = 0,
	    hideOnEscape = 1,
	}
end

function crafty:loadState()
	self.state = self.state or {}

	local profession
	if self.mode == TRADE then
		profession = GetTradeSkillLine()
	elseif self.mode == CRAFT then
		profession = GetCraftSkillLine(1)
	end
	profession = profession or '' -- TODO better solution

	self.state[profession] = self.state[profession] or {
		searchText = '',
		searchType = 1,
	}
	return self.state[profession]
end

function crafty:SetSearchText(searchText)
	crafty:loadState().searchText = searchText
end

function crafty:GetSearchText()
	return crafty:loadState().searchText
end

function crafty:SetAvailableOnly(availableOnly)
	crafty:loadState().availableOnly = availableOnly
end

function crafty:GetAvailableOnly()
	return crafty:loadState().availableOnly
end

function crafty:ADDON_LOADED()
	if arg1 ~= 'crafty' then
		return
	end

	self.frames = {
		trade = {
			elements = {
				Main = 'TradeSkillFrame',
				Title = 'TradeSkillFrameTitleText',
				Scroll = 'TradeSkillListScrollFrame',
				ScrollBar = 'TradeSkillListScrollFrameScrollBar',
				Highlight = 'TradeSkillHighlightFrame',
				CollapseAll = 'TradeSkillCollapseAllButton',
			},
			anchor = 'TradeSkillCreateAllButton',
			anchor_offset_x = -9,
			anchor_offset_y = -8,
		},
		craft = {
			elements = {
				Main = 'CraftFrame',
				Title = 'CraftFrameTitleText',
				Scroll = 'CraftListScrollFrame',
				ScrollBar = 'CraftListScrollFrameScrollBar',
				Highlight = 'CraftHighlightFrame',
			},
			anchor = 'CraftCancelButton',
			anchor_offset_x = 6,
			anchor_offset_y = -8,
		},
	}

	self.found = {}

	self:RegisterEvent('TRADE_SKILL_SHOW')
	self:RegisterEvent('CRAFT_SHOW')
	
	local origSetItemRef = SetItemRef
	SetItemRef = function(...)
		local popup = StaticPopup_FindVisible('CRAFTY_LINK')
	    local _, _, playerName = strfind(unpack(arg), 'player:(.+)')
	    if popup and IsShiftKeyDown() and playerName then
	    	getglobal(popup:GetName()..'EditBox'):SetText(playerName)
	    	return
	    end
	    return origSetItemRef(unpack(arg))
	end

	if not self.frame then
		-- Create main frame 
		self.frame = CreateFrame('Frame', 'craftyFrame', UIParent)
		self.frame:Hide()
		-- Set main frame properties
		self.frame:SetPoint('CENTER', 'UIParent', 'CENTER', 0, 0)
		self.frame:SetWidth(342)  
		self.frame:SetHeight(45)
		self.frame:SetFrameStrata('MEDIUM')
		self.frame:SetMovable(false)
		self.frame:EnableMouse(true)
		-- Set the main frame backdrop
		self.frame:SetBackdrop({
				bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background', tile = true, tileSize = 32,
				edgeFile = 'Interface\\DialogFrame\\UI-DialogBox-Border', edgeSize = 20,
				insets = {left = 5, right = 6, top = 6, bottom = 5},
		})
		self.frame:SetBackdropColor(1, 1, 1, 1)
		self.frame:SetBackdropBorderColor(0, .8, 0, 1)
		
		-- Create sub-frames
		-- Editbox for search text
		self.frame.SearchBox = CreateFrame('EditBox', nil, self.frame, 'InputBoxTemplate')
		self.frame.SearchBox:SetAutoFocus(false)
		self.frame.SearchBox:SetWidth(206)
		self.frame.SearchBox:SetHeight(20)
		self.frame.SearchBox:SetPoint('LEFT', self.frame, 'LEFT', 17, 0)
		self.frame.SearchBox:SetBackdropColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
		self.frame.SearchBox:SetBackdropBorderColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)
		self.frame.SearchBox:SetScript('OnTextChanged', function() self:Search() end)
		self.frame.SearchBox:SetScript('OnEnterPressed', function()
			this:ClearFocus()
		end)

		-- Reset Button
		self.frame.ResetButton = CreateFrame('Button', nil, self.frame.SearchBox, 'UIPanelCloseButton')
		self.frame.ResetButton:SetWidth(20)
		self.frame.ResetButton:SetHeight(20)
		self.frame.ResetButton:SetPoint('RIGHT', self.frame.SearchBox, 'RIGHT')
		self.frame.ResetButton:SetText('Clear')
		self.frame.ResetButton:SetScript('OnClick', function() self:Reset() end)

		-- Available Only Button
		self.frame.AvailableOnlyButton = CreateFrame('Button', nil, self.frame, 'GameMenuButtonTemplate')
		self.frame.AvailableOnlyButton:SetWidth(52)
		self.frame.AvailableOnlyButton:SetHeight(25)
		self.frame.AvailableOnlyButton:SetPoint('LEFT', self.frame.SearchBox, 'RIGHT', 2, 0)
		self.frame.AvailableOnlyButton:SetText('Avail')
		self.frame.AvailableOnlyButton:SetScript('OnClick', function()
			self:SetAvailableOnly(not self:GetAvailableOnly())
			if self:GetAvailableOnly() then
				this:LockHighlight()
			else
				this:UnlockHighlight()
			end
            self:Search()
        end)

		-- Link Reagents button
		self.frame.LinkReagentButton = CreateFrame('Button', nil, self.frame, 'GameMenuButtonTemplate')
		self.frame.LinkReagentButton:SetWidth(52)
		self.frame.LinkReagentButton:SetHeight(25)
		self.frame.LinkReagentButton:SetPoint('LEFT', self.frame.AvailableOnlyButton, 'RIGHT', 2, 0)
		self.frame.LinkReagentButton:SetText('Link')
		self.frame.LinkReagentButton:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
		self.frame.LinkReagentButton:SetScript('OnClick', function() 
			if StaticPopup_Visible('CRAFTY_LINK') then 
				StaticPopup_Hide('CRAFTY_LINK')
			elseif arg1 == 'RightButton' then
				StaticPopup_Show('CRAFTY_LINK') 
			end

			if arg1 == 'LeftButton' then
				local channel = GetNumPartyMembers() == 0 and 'WHISPER' or 'PARTY'
				if channel == 'PARTY' or ChatEdit_GetLastTellTarget(ChatFrameEditBox) ~= '' then
					crafty:SendReagentsMessage(channel, ChatEdit_GetLastTellTarget(ChatFrameEditBox))
				end
			end
		end)
	end
end

function crafty:relevel(frame)
	for _, child in { frame:GetChildren() } do
		child:SetFrameLevel(frame:GetFrameLevel() + 1)
		self:relevel(child)
	end
end

function crafty:CRAFT_SHOW()
	if GetCraftSkillLine(1) ~= 'Enchanting' then
		return
	end

	self.mode = CRAFT

	-- first time window has been opened
	if not self.frames.craft.orig_update then
		self:RegisterEvent('CRAFT_CLOSE')
		self.frames.craft.orig_update = CraftFrame_Update
		CraftFrame_Update = function() self:BuildList(self:GetSearchText()) self:UpdateListing() end
	end
	self.frames.craft.orig_update()
	
	self.currentFrame = self.frames.craft
	
	if getglobal(self.frames.trade.elements.Main) and getglobal(self.frames.trade.elements.Main):IsShown() then
		getglobal(self.frames.trade.elements.Main):Hide()
	end
	
	self.frame:SetParent(self.frames.craft.elements.Main)
	self:relevel(self.frame)
	self.frame:ClearAllPoints()
	self.frame:SetPoint('TOPRIGHT', self.frames.craft.anchor, 'BOTTOMRIGHT', self.frames.craft.anchor_offset_x, self.frames.craft.anchor_offset_y)

	crafty:Show()
end

function crafty:TRADE_SKILL_SHOW()
	self.mode = TRADE

	-- first time window has been opened
	if not self.frames.trade.orig_update then
		self:RegisterEvent('TRADE_SKILL_CLOSE')
		self.frames.trade.orig_update = TradeSkillFrame_Update
		TradeSkillFrame_Update = function() self:BuildList(self:GetSearchText()) self:UpdateListing() end
	end
	self.frames.trade.orig_update()
		
	self.currentFrame = self.frames.trade
	
	if getglobal(self.frames.craft.elements.Main) and getglobal(self.frames.craft.elements.Main):IsShown() then
		getglobal(self.frames.craft.elements.Main):Hide()
	end
	
	self.frame:SetParent(self.frames.trade.elements.Main)
	self:relevel(self.frame)
	self.frame:ClearAllPoints()
	self.frame:SetPoint('TOPLEFT', self.frames.trade.anchor, 'BOTTOMLEFT', self.frames.trade.anchor_offset_x, self.frames.trade.anchor_offset_y)

	crafty:Show()
end

function crafty:Show()
	self.frame:Show()
	if self:GetAvailableOnly() then
		self.frame.AvailableOnlyButton:LockHighlight()
	else
		self.frame.AvailableOnlyButton:UnlockHighlight()
	end
	self.frame.SearchBox:SetText(self:GetSearchText())
	self:Search()
end

function crafty:CRAFT_CLOSE()
	crafty:OnClose()
end

function crafty:TRADE_SKILL_CLOSE()
	crafty:OnClose()
end

function crafty:OnClose()
	self.frame:Hide()
	StaticPopup_Hide('CRAFTY_LINK')
end

function crafty:UpdateListing()

	-- may be disabled from the no results message
	getglobal((self.mode == CRAFT and 'Craft' or 'TradeSkillSkill')..1):Enable()
	
	if (self:GetSearchText() ~= '' or self:GetAvailableOnly()) and getglobal(self.currentFrame.elements.Main):IsShown() then

		local skillOffset = FauxScrollFrame_GetOffset(getglobal(self.currentFrame.elements.Scroll))	
		local skillButton
		
		self:BuildList(self:GetSearchText())
						
		if self.mode == TRADE then
			getglobal(self.frames.trade.elements.CollapseAll):Disable();
			for i=1, TRADE_SKILLS_DISPLAYED, 1 do
				getglobal('TradeSkillSkill'..i..'Text'):SetPoint('TOPLEFT', 'TradeSkillSkill'..i, 'TOPLEFT', 3, 0)
			end
		end
		
		FauxScrollFrame_Update(getglobal(self.currentFrame.elements.Scroll), getn(self.found), (self.mode == CRAFT and CRAFTS_DISPLAYED or TRADE_SKILLS_DISPLAYED), (self.mode == CRAFT and CRAFT_SKILL_HEIGHT or TRADE_SKILL_HEIGHT), nil, nil, nil, getglobal(self.currentFrame.elements.Highlight), 293, 316 )
		getglobal(self.currentFrame.elements.Highlight):Hide()
		
		if getn(self.found) > 0 then
					
			for i=1,self.mode == CRAFT and CRAFTS_DISPLAYED or TRADE_SKILLS_DISPLAYED do
				local skillIndex = i + skillOffset
				skillButton = getglobal((self.mode == CRAFT and 'Craft' or 'TradeSkillSkill')..i)
				
				if self.found[skillIndex] then
					if getglobal(self.currentFrame.elements.Scroll):IsVisible() then
						skillButton:SetWidth(293)
					else
						skillButton:SetWidth(323)
					end
					
					local color = (self.mode == CRAFT and CraftTypeColor[self.found[skillIndex].type] or TradeSkillTypeColor[self.found[skillIndex].type])
					if color then
						skillButton:SetTextColor(color.r, color.g, color.b)
					end
					skillButton:SetID(self.found[skillIndex].index)
					skillButton:Show()
					
					if self.found[skillIndex].name == '' then
						return
					end
					
					skillButton:SetNormalTexture('')
					getglobal((self.mode == CRAFT and 'Craft' or 'TradeSkillSkill')..i..'Highlight'):SetTexture('')
					if self.found[skillIndex].available == 0 then
						skillButton:SetText(' '..self.found[skillIndex].name)
					else
						skillButton:SetText(' '.. self.found[skillIndex].name ..' ['.. self.found[skillIndex].available ..']')
					end
					
					if (self.mode == CRAFT and GetCraftSelectionIndex() or GetTradeSkillSelectionIndex()) == self.found[skillIndex].index then
						getglobal(self.currentFrame.elements.Highlight):SetPoint('TOPLEFT', skillButton, 'TOPLEFT', 0, 0)
						getglobal(self.currentFrame.elements.Highlight):Show()
						skillButton:LockHighlight()
						-- Setting the num avail so the create all button works for tradeskills
						if self.mode == TRADE and getglobal(self.frames.trade.elements.Main) then
							getglobal(self.currentFrame.elements.Main).numAvailable = self.found[skillIndex].available
						end
					else
						if not self:SelectionInList(skillOffset) then
							getglobal(self.currentFrame.elements.Highlight):Hide()
						end
						skillButton:UnlockHighlight()
					end
				else
					skillButton:Hide()					
				end
			end
		else
			getglobal(self.currentFrame.elements.Scroll):Hide()
			for i=1,self.mode == CRAFT and CRAFTS_DISPLAYED or TRADE_SKILLS_DISPLAYED do
				skillButton = getglobal((self.mode == CRAFT and 'Craft' or 'TradeSkillSkill')..i)
				if i == 1 then
					skillButton:Disable()
					skillButton:SetWidth(323)
					skillButton:SetDisabledTextColor(1, 1, 1)
					skillButton:SetDisabledTexture('')
					skillButton:SetText('No results matched your search.')
					skillButton:UnlockHighlight()
					skillButton:Show()
				else
					skillButton:Hide()
				end
			end
		end
	else
		if self.mode == CRAFT then
			self.frames.craft.orig_update()
		elseif self.mode == TRADE then
			for i=1, TRADE_SKILLS_DISPLAYED, 1 do
				getglobal('TradeSkillSkill'..i..'Text'):SetPoint('TOPLEFT', 'TradeSkillSkill'..i, 'TOPLEFT', 21, 0)
			end
			self.frames.trade.orig_update()
		end
	end
end

function crafty:Search()
	self:SetSearchText(self.frame.SearchBox:GetText())

	FauxScrollFrame_SetOffset(getglobal(self.currentFrame.elements.Main), 0)
	getglobal(self.currentFrame.elements.ScrollBar):SetValue(0)

	self:BuildList(self:GetSearchText())
	if getn(self.found) > 0 then
		if self.mode == CRAFT and GetCraftSelectionIndex() > 0 then
			CraftFrame_SetSelection(self.found[1].index)
		elseif self.mode == TRADE then
			TradeSkillFrame_SetSelection(self.found[1].index)
		end
	end
	self:UpdateListing()
end

function crafty:Reset()
	self.frame.SearchBox:SetText('')
end

function crafty:SelectionInList(skillOffset)
	for i=skillOffset + 1, skillOffset + (self.mode == CRAFT and CRAFTS_DISPLAYED or TRADE_SKILLS_DISPLAYED) do
		if self.found[i] and self.found[i].index == (self.mode == CRAFT and GetCraftSelectionIndex() or GetTradeSkillSelectionIndex()) then
			return true
		end
	end
	return false
end

function crafty:BuildList(searchText)
	self.found = {}
	local reagents = {}
	local skills = {}

	local matcher = self:FuzzyMatcher(searchText)
	
	for i=1,self.mode == CRAFT and GetNumCrafts() or GetNumTradeSkills() do
		local skillName, skillType, numAvailable, isExpanded, requires
		if self.mode == CRAFT then
			skillName, _, skillType, numAvailable, isExpanded = GetCraftInfo(i)
			requires = GetCraftSpellFocus(i)
		elseif self.mode == TRADE then
			skillName, skillType, numAvailable, isExpanded = GetTradeSkillInfo(i)
			requires = GetTradeSkillTools(i)
		end

		local nameRating = matcher(skillName)

		local reagents = {}
		local reagentsRating
		for j=1,self.mode == CRAFT and GetCraftNumReagents(i) or GetTradeSkillNumReagents(i), 1 do
			local reagentName
			if self.mode == CRAFT then
				reagentName, _, _, _ = GetCraftReagentInfo(i, j)
			elseif self.mode == TRADE then
				reagentName, _, _, _ = GetTradeSkillReagentInfo(i, j)
			end
			
			tinsert(reagents, reagentName)

			local reagentRating = reagentName and matcher(reagentName)
			if reagentRating then
				reagentsRating = reagentsRating and max(reagentsRating, reagentRating) or reagentRating
			end
		end

		local requiresRating = requires and matcher(BuildListString(requires))

		local rating = nameRating and nameRating * 2
		if reagentsRating then
			rating = rating and max(rating, reagentsRating) or reagentsRating
		end
		if requiresRating then
			rating = rating and max(rating, requiresRating) or requiresRating
		end

		if skillType ~= 'header' then
			skills[skillName] = {
				name			= skillName,
				type 			= skillType,
				available		= numAvailable,
				index 			= i,
				rating 			= rating,
				reagents        = reagents,
				reagentRank     = 0,
			}
		elseif skillType == 'header' and not isExpanded then
			-- We need to expand any unexpanded header types, otherwise we can't parse their sub data.
			ExpandTradeSkillSubClass(i)
		end
	end

	local found = {}
	for _, skill in skills do
		if skill.rating and (not self:GetAvailableOnly() or skill.available > 0) then
			found[skill.name] = true
		end
	end

	while true do
		local changed
		for _, skill in skills do
			if found[skill.name] then
				for _, reagentName in skill.reagents do
					local reagent = skills[reagentName]
					if reagent then
						if not found[reagentName] then
							found[reagentName] = true
							changed = true
						end
						if not reagent.rating or skill.rating > reagent.rating then
							reagent.rating = skill.rating
							reagent.reagentRank = skill.reagentRank + 1
						end
					end
				end
			end
		end
		if not changed then
			break
		end
	end

	for skillName, _ in found do
		tinsert(self.found, skills[skillName])
	end
	sort(self.found, function(a, b)
		if b.rating < a.rating then
			return true
		elseif a.rating == b.rating then
			if a.reagentRank < b.reagentRank then
				return true
			elseif a.reagentRank == b.reagentRank then
				if a.reagentRank == 0 and strlen(a.name) < strlen(b.name) then
					return true
				elseif a.reagentRank > 0 or strlen(a.name) == strlen(b.name) then
					return a.index < b.index
				end
			end
		end
	end)
end

function crafty:SendReagentsMessage(channel, who)

	local index = self.mode == CRAFT and GetCraftSelectionIndex() or GetTradeSkillSelectionIndex()

	if index == 0 then
		return
	end

	local message = {}

	local messagePart = (self.mode == CRAFT and GetCraftItemLink(index) or GetTradeSkillItemLink(index))..' ='
	for i=1,self.mode == CRAFT and GetCraftNumReagents(index) or GetTradeSkillNumReagents(index) do
		local reagentLink = self.mode == CRAFT and GetCraftReagentItemLink(index, i) or GetTradeSkillReagentItemLink(index, i)
		local reagentCount = (self.mode == CRAFT and { GetCraftReagentInfo(index, i) } or { GetTradeSkillReagentInfo(index, i) })[3]

		if not reagentLink then
			return
		end

		local reagentInfo = format(
			'%s x%i',
			reagentLink,
			reagentCount
		)
		if strlen(messagePart..reagentInfo) > 255 then
			tinsert(message, messagePart)
			messagePart = '(cont.)'
		end
		messagePart = messagePart..' '..reagentInfo
	end
	tinsert(message, messagePart)

	for _, part in ipairs(message) do
		SendChatMessage(part, channel, GetDefaultLanguage('player'), who)
	end
end

function crafty:FuzzyMatcher(input)
	local uppercaseInput = strupper(input)
	local pattern = '(.*)'
	for i=1,strlen(uppercaseInput) do
		if strfind(strsub(uppercaseInput, i, i), '%w') or strfind(strsub(uppercaseInput, i, i), '%s') then
			pattern = pattern .. strsub(uppercaseInput, i, i) .. '(.-)'
 		end
	end
	return function(candidate)
		local match = { strfind(strupper(candidate), pattern) }
		if match[1] then
			local rating = 0
			for i=4,getn(match)-1 do
				if strlen(match[i]) == 0 then
					rating = rating + 1
				end
 			end
			return rating
 		end
	end
end