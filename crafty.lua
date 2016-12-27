local crafty = CreateFrame'Frame'
crafty:SetScript('OnUpdate', function()
	this:UPDATE()
end)
crafty:SetScript('OnEvent', function()
	this[event](this)
end)
crafty:RegisterEvent'ADDON_LOADED'

local TRADE, CRAFT = 1, 2

crafty.frames = {
	trade = {
		elements = {
			Main = 'TradeSkillFrame',
			Title = 'TradeSkillFrameTitleText',
			Scroll = 'TradeSkillListScrollFrame',
			ScrollBar = 'TradeSkillListScrollFrameScrollBar',
			Highlight = 'TradeSkillHighlightFrame',
			CollapseAll = 'TradeSkillCollapseAllButton',
		},
		anchor = {'TOPLEFT', 'TradeSkillCreateAllButton', 'BOTTOMLEFT', -9, -8},
	},
	craft = {
		elements = {
			Main = 'CraftFrame',
			Title = 'CraftFrameTitleText',
			Scroll = 'CraftListScrollFrame',
			ScrollBar = 'CraftListScrollFrameScrollBar',
			Highlight = 'CraftHighlightFrame',
		},
		anchor = {'TOPRIGHT', 'CraftCancelButton', 'BOTTOMRIGHT', 6, -8}
	},
}

do
	local function action()
	    local input = strlower(getglobal(this:GetParent():GetName()..'EditBox'):GetText())
	    if tonumber(input) then
	    	crafty:SendReagentMessage('CHANNEL', input)
		elseif input == 'guild' or input == 'g' then
			crafty:SendReagentMessage'GUILD'
		elseif input == 'o' then
			crafty:SendReagentMessage'OFFICER'
		elseif input == 'raid' or input == 'ra' then
			crafty:SendReagentMessage'RAID'
		elseif input == 'rw' then
			crafty:SendReagentMessage'RAID_WARNING'
		elseif input == 'bg' then
			crafty:SendReagentMessage'BATTLEGROUND'
		elseif input == 'party' or input == 'p' then
			crafty:SendReagentMessage'PARTY'
		elseif input == 'say' or input == 's' then
			crafty:SendReagentMessage'SAY'
		elseif input == 'yell' or input == 'y' then
			crafty:SendReagentMessage'YELL'	
		elseif input == 'emote' or input == 'em' then
			crafty:SendReagentMessage'EMOTE'	
		elseif input == 'reply' or input == 'r' then
			if ChatEdit_GetLastTellTarget(ChatFrameEditBox) ~= '' then
				crafty:SendReagentMessage('WHISPER', ChatEdit_GetLastTellTarget(ChatFrameEditBox))
			end
		elseif strlen(input) > 1 then
			crafty:SendReagentMessage('WHISPER', gsub(input, '^@', ''))
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

function crafty:LoadState()
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
	crafty:LoadState().searchText = searchText
end

function crafty:GetSearchText()
	return crafty:LoadState().searchText
end

function crafty:SetAvailable(available)
	crafty:LoadState().available = available
end

function crafty:GetAvailable()
	return crafty:LoadState().available
end

-- throttling the update event
function crafty:UPDATE() 
	if self.update_required then
		self.update_required = nil
		self.currentFrame.orig_update()
		self:UpdateListing()
	end
end

function crafty:ADDON_LOADED()
	if arg1 ~= 'crafty' then
		return
	end

	self.found = {}

	self:RegisterEvent'TRADE_SKILL_SHOW'
	self:RegisterEvent'CRAFT_SHOW'
	
	local origSetItemRef = SetItemRef
	SetItemRef = function(...)
		local popup = StaticPopup_FindVisible'CRAFTY_LINK'
	    local _, _, playerName = strfind(unpack(arg), 'player:(.+)')
	    if popup and IsShiftKeyDown() and playerName then
	    	getglobal(popup:GetName()..'EditBox'):SetText(playerName)
	    	return
	    end
	    return origSetItemRef(unpack(arg))
	end

	-- Create main frame 
	self.frame = CreateFrame'Frame'
	self.frame:Hide()
	self.frame:SetPoint('CENTER', 'UIParent', 'CENTER', 0, 0)
	self.frame:SetWidth(342)  
	self.frame:SetHeight(45)
	self.frame:SetFrameStrata'MEDIUM'
	self.frame:SetMovable(false)
	self.frame:EnableMouse(true)
	self.frame:SetBackdrop({
			bgFile = [[Interface\DialogFrame\UI-DialogBox-Background]], tile = true, tileSize = 32,
			edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]], edgeSize = 20,
			insets = {left=5, right=6, top=6, bottom=5},
	})
	
	local searchBox = CreateFrame('EditBox', nil, self.frame, 'InputBoxTemplate')
	self.frame.SearchBox = searchBox
	searchBox:SetTextInsets(16, 20, 0, 0)
	-- self.Instructions:SetText(SEARCH);
	-- self.Instructions:ClearAllPoints();
	-- self.Instructions:SetPoint("TOPLEFT", self, "TOPLEFT", 16, 0);
	-- self.Instructions:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -20, 0);
	searchBox:SetAutoFocus(false)
	searchBox:SetWidth(204)
	searchBox:SetHeight(20)
	searchBox:SetPoint('LEFT', self.frame, 'LEFT', 17, 0)
	searchBox:SetBackdropColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
	searchBox:SetBackdropBorderColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)
	searchBox:SetScript('OnEnterPressed', function()
		this:ClearFocus()
	end)
	do
		local instructions = searchBox:CreateFontString(nil, 'ARTWORK')
		instructions:SetPoint('TOPLEFT', searchBox, 'TOPLEFT', 16, 0)
		instructions:SetPoint('BOTTOMRIGHT', searchBox, 'BOTTOMRIGHT', -20, 0)
		instructions:SetJustifyH'LEFT'
		instructions:SetFontObject(GameFontDisableSmall)
		instructions:SetTextColor(.35, .35, .35)
		instructions:SetText'Search'
		local searchIcon = searchBox:CreateTexture(nil, 'OVERLAY')
		searchIcon:SetTexture[[Interface\AddOns\crafty\UI-Searchbox-Icon]]
		searchIcon:SetPoint('LEFT', 0, -2)
		searchIcon:SetWidth(14)
		searchIcon:SetHeight(14)
		searchIcon:SetVertexColor(.6, .6, .6)
		local clearButton = CreateFrame('Button', nil, searchBox)
		clearButton:SetPoint('RIGHT', -3, 0)
		clearButton:SetWidth(17)
		clearButton:SetHeight(17)
		do
			local tex = clearButton:CreateTexture(nil, 'ARTWORK')
			tex:SetTexture[[Interface\AddOns\crafty\ClearBroadcastIcon]]
			tex:SetPoint('TOPLEFT', 0, 0)
			tex:SetWidth(17)
			tex:SetHeight(17)
			tex:SetAlpha(.5)
			clearButton.tex = tex
		end
		clearButton:SetScript('OnEnter', function()
			this.tex:SetAlpha(1)
		end)
		clearButton:SetScript('OnLeave', function()
			this.tex:SetAlpha(.5)
		end)
		clearButton:SetScript('OnMouseUp', function()
			this.tex:SetPoint('TOPLEFT', 0, 0)
		end)
		clearButton:SetScript('OnMouseDown', function()
			this.tex:SetPoint('TOPLEFT', 1, -1)
		end)
		clearButton:SetScript('OnClick', function()
			PlaySound'igMainMenuOptionCheckBoxOn'
			searchBox:SetText''
			searchBox:ClearFocus()
		end)
		searchBox:SetScript('OnEditFocusGained', function()
			this.focused = true
			searchIcon:SetVertexColor(1, 1, 1)
			clearButton:Show()
		end)
		searchBox:SetScript('OnEditFocusLost', function()
			this.focused = false
			if this:GetText() == '' then
				searchIcon:SetVertexColor(.6, .6, .6)
				clearButton:Hide()
			end
		end)
		searchBox:SetScript('OnTextChanged', function()
			if this:GetText() == '' then
				instructions:Show()
			else
				instructions:Hide()
			end
			if this:GetText() == '' and not this.focused then
				searchIcon:SetVertexColor(.6, .6, .6)
				clearButton:Hide()
			else
				searchIcon:SetVertexColor(1, 1, 1)
				clearButton:Show()	
			end
			self:Search()
		end)
	end

	-- Available Button
	self.frame.MaterialsButton = CreateFrame('Button', nil, self.frame, 'UIPanelButtonTemplate')
	self.frame.MaterialsButton:SetWidth(52)
	self.frame.MaterialsButton:SetHeight(25)
	self.frame.MaterialsButton:SetPoint('LEFT', searchBox, 'RIGHT', 4, 0)
	self.frame.MaterialsButton:SetText'Mats'
	self.frame.MaterialsButton:SetScript('OnClick', function()
		self:SetAvailable(not self:GetAvailable())
		if self:GetAvailable() then
			this:LockHighlight()
		else
			this:UnlockHighlight()
		end
        self:Search()
    end)

	-- Link button
	self.frame.LinkButton = CreateFrame('Button', nil, self.frame, 'UIPanelButtonTemplate')
	self.frame.LinkButton:SetWidth(52)
	self.frame.LinkButton:SetHeight(25)
	self.frame.LinkButton:SetPoint('LEFT', self.frame.MaterialsButton, 'RIGHT', 2, 0)
	self.frame.LinkButton:SetText'Link'
	self.frame.LinkButton:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
	self.frame.LinkButton:SetScript('OnClick', function() 
		if StaticPopup_Visible'CRAFTY_LINK' then 
			StaticPopup_Hide'CRAFTY_LINK'
		elseif arg1 == 'RightButton' then
			StaticPopup_Show'CRAFTY_LINK'
		end

		if arg1 == 'LeftButton' then
			local channel = GetNumPartyMembers() == 0 and 'WHISPER' or 'PARTY'
			if channel == 'PARTY' or ChatEdit_GetLastTellTarget(ChatFrameEditBox) ~= '' then
				crafty:SendReagentMessage(channel, ChatEdit_GetLastTellTarget(ChatFrameEditBox))
			end
		end
	end)
end

function crafty:Relevel(frame)
	for _, child in {frame:GetChildren()} do
		child:SetFrameLevel(frame:GetFrameLevel() + 1)
		self:Relevel(child)
	end
end

function crafty:CRAFT_SHOW()
	if not GetCraftDisplaySkillLine() then
		return
	end

	self.mode = CRAFT
	self.currentFrame = self.frames.craft

	-- first time window has been opened
	if not self.currentFrame.orig_update then
		self:RegisterEvent'CRAFT_CLOSE'
		self.currentFrame.orig_update = CraftFrame_Update
		CraftFrame_Update = function() self.update_required = true end
		for i = 1, 8 do
			getglobal('Craft'..i):SetScript('OnDoubleClick', function()
				self.frame.SearchBox:SetText(this.skill.name)
			end)
		end
	end

	if getglobal(self.frames.trade.elements.Main) and getglobal(self.frames.trade.elements.Main):IsShown() then
		getglobal(self.frames.trade.elements.Main):Hide()
	end

	crafty:Show()
end

function crafty:TRADE_SKILL_SHOW()
	self.mode = TRADE
	self.currentFrame = self.frames.trade

	-- first time window has been opened
	if not self.currentFrame.orig_update then
		self:RegisterEvent'TRADE_SKILL_CLOSE'
		self.currentFrame.orig_update = TradeSkillFrame_Update
		TradeSkillFrame_Update = function() self.update_required = true end
		for i = 1, 8 do
			getglobal('TradeSkillSkill'..i):SetScript('OnDoubleClick', function()
				self.frame.SearchBox:SetText(this.skill.name)
			end)
		end
	end

	if getglobal(self.frames.craft.elements.Main) and getglobal(self.frames.craft.elements.Main):IsShown() then
		getglobal(self.frames.craft.elements.Main):Hide()
	end

	crafty:Show()
end

function crafty:Show()
	self.currentFrame.orig_update()

	self.frame:SetParent(self.currentFrame.elements.Main)
	self:Relevel(self.frame)
	self.frame:ClearAllPoints()
	self.frame:SetPoint(unpack(self.currentFrame.anchor))

	self.frame:Show()
	if self:GetAvailable() then
		self.frame.MaterialsButton:LockHighlight()
	else
		self.frame.MaterialsButton:UnlockHighlight()
	end
	self.frame.SearchBox:SetText(self:GetSearchText())
	self:Search()
end

function crafty:CRAFT_CLOSE()
	crafty:Close()
end

function crafty:TRADE_SKILL_CLOSE()
	crafty:Close()
end

function crafty:Close()
	self.frame:Hide()
	StaticPopup_Hide'CRAFTY_LINK'
end

function crafty:UpdateListing()

	-- may be disabled from the no results message
	getglobal((self.mode == CRAFT and 'Craft' or 'TradeSkillSkill')..1):Enable()
	
	if (self:GetSearchText() ~= '' or self:GetAvailable()) and getglobal(self.currentFrame.elements.Main):IsShown() then

		local skillOffset = FauxScrollFrame_GetOffset(getglobal(self.currentFrame.elements.Scroll))	
		local skillButton
		
		self:BuildList(self:GetSearchText())
						
		if self.mode == TRADE then
			getglobal(self.frames.trade.elements.CollapseAll):Disable();
			for i = 1, TRADE_SKILLS_DISPLAYED do
				getglobal('TradeSkillSkill'..i..'Text'):SetPoint('TOPLEFT', 'TradeSkillSkill'..i, 'TOPLEFT', 3, 0)
			end
		end
		
		FauxScrollFrame_Update(getglobal(self.currentFrame.elements.Scroll), getn(self.found), (self.mode == CRAFT and CRAFTS_DISPLAYED or TRADE_SKILLS_DISPLAYED), (self.mode == CRAFT and CRAFT_SKILL_HEIGHT or TRADE_SKILL_HEIGHT), nil, nil, nil, getglobal(self.currentFrame.elements.Highlight), 293, 316 )
		getglobal(self.currentFrame.elements.Highlight):Hide()
		
		if getn(self.found) > 0 then
					
			for i = 1, self.mode == CRAFT and CRAFTS_DISPLAYED or TRADE_SKILLS_DISPLAYED do
				local skillIndex = i + skillOffset
				skillButton = getglobal((self.mode == CRAFT and 'Craft' or 'TradeSkillSkill')..i)
				
				if self.found[skillIndex] then
					skillButton.skill = self.found[skillIndex]
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
					getglobal((self.mode == CRAFT and 'Craft' or 'TradeSkillSkill')..i..'Highlight'):SetTexture''
					if self.found[skillIndex].available == 0 then
						skillButton:SetText(' '..self.found[skillIndex].name)
					else
						skillButton:SetText(' '..self.found[skillIndex].name..' ['..self.found[skillIndex].available..']')
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
					skillButton:SetText'No results matched your search.'
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
			for i = 1, TRADE_SKILLS_DISPLAYED do
				getglobal('TradeSkillSkill'..i..'Text'):SetPoint('TOPLEFT', 'TradeSkillSkill'..i, 'TOPLEFT', 21, 0)
			end
			self.frames.trade.orig_update()
		end
	end
end

function crafty:Search()
	self:SetSearchText(self.frame.SearchBox:GetText() or '')

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

function crafty:SelectionInList(skillOffset)
	for i = skillOffset + 1, skillOffset + (self.mode == CRAFT and CRAFTS_DISPLAYED or TRADE_SKILLS_DISPLAYED) do
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
	
	for i = 1, self.mode == CRAFT and GetNumCrafts() or GetNumTradeSkills() do
		local skillName, skillType, numAvailable, isExpanded, requires
		if self.mode == CRAFT then
			skillName, _, skillType, numAvailable, isExpanded = GetCraftInfo(i)
			requires = GetCraftSpellFocus(i)
		elseif self.mode == TRADE then
			skillName, skillType, numAvailable, isExpanded = GetTradeSkillInfo(i)
			requires = GetTradeSkillTools(i)
		end

		local nameRating = skillName and matcher(skillName)

		local reagents = {}
		local reagentsRating
		for j = 1, self.mode == CRAFT and GetCraftNumReagents(i) or GetTradeSkillNumReagents(i) do
			local reagentName
			if self.mode == CRAFT then
				reagentName = GetCraftReagentInfo(i, j)
			elseif self.mode == TRADE then
				reagentName = GetTradeSkillReagentInfo(i, j)
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

		if skillName and skillType ~= 'header' then
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
		if skill.rating and (not self:GetAvailable() or skill.available > 0) then
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

function crafty:SendReagentMessage(channel, who)

	local index = self.mode == CRAFT and GetCraftSelectionIndex() or GetTradeSkillSelectionIndex()

	if index == 0 then
		return
	end

	local message = {}

	local messagePart = (self.mode == CRAFT and GetCraftItemLink(index) or GetTradeSkillItemLink(index))..' ='
	for i = 1, self.mode == CRAFT and GetCraftNumReagents(index) or GetTradeSkillNumReagents(index) do
		local reagentLink = self.mode == CRAFT and GetCraftReagentItemLink(index, i) or GetTradeSkillReagentItemLink(index, i)
		local reagentCount = (self.mode == CRAFT and {GetCraftReagentInfo(index, i)} or {GetTradeSkillReagentInfo(index, i)})[3]

		if not reagentLink then
			return
		end

		local reagentInfo = format(
			'%sx%i',
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
		SendChatMessage(part, channel, GetDefaultLanguage'player', who)
	end
end

function crafty:FuzzyMatcher(input)
	local uppercaseInput = strupper(input)
	local pattern = '(.*)'
	local captures = 0
	for i = 1, strlen(uppercaseInput) do
		if strfind(strsub(uppercaseInput, i, i), '%w') or strfind(strsub(uppercaseInput, i, i), '%s') then
			pattern = pattern..strsub(uppercaseInput, i, i)..(captures > 30 and '.-' or '(.-)')
			captures = captures + 1
 		end
	end
	return function(candidate)
		local match = {strfind(strupper(candidate), pattern)}
		if match[1] then
			local rating = 0
			for i = 4, getn(match) - 1 do
				if strlen(match[i]) == 0 then
					rating = rating + 1
				end
 			end
			return rating
 		end
	end
end