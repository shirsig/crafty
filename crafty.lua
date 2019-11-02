local crafty = CreateFrame'Frame'
crafty:SetScript('OnUpdate', function()
	crafty.UPDATE()
end)
crafty:SetScript('OnEvent', function(self, event, ...)
	self[event](self, ...)
end)
crafty:RegisterEvent'ADDON_LOADED'

crafty_favorites = {}

local TRADE, CRAFT = 1, 2

local ALT = false

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
	local function action(self)
		local input = strlower(self.editBox:GetText())
	    if tonumber(input) then
	    	crafty.SendReagentMessage('CHANNEL', input)
		elseif input == 'guild' or input == 'g' then
			crafty.SendReagentMessage'GUILD'
		elseif input == 'o' then
			crafty.SendReagentMessage'OFFICER'
		elseif input == 'raid' or input == 'ra' then
			crafty.SendReagentMessage'RAID'
		elseif input == 'rw' then
			crafty.SendReagentMessage'RAID_WARNING'
		elseif input == 'bg' then
			crafty.SendReagentMessage'BATTLEGROUND'
		elseif input == 'party' or input == 'p' then
			crafty.SendReagentMessage'PARTY'
		elseif input == 'say' or input == 's' then
			crafty.SendReagentMessage'SAY'
		elseif input == 'yell' or input == 'y' then
			crafty.SendReagentMessage'YELL'
		elseif input == 'emote' or input == 'em' then
			crafty.SendReagentMessage'EMOTE'
		elseif input == 'reply' or input == 'r' then
			if ChatEdit_GetLastTellTarget(ChatFrameEditBox) ~= '' then
				crafty.SendReagentMessage('WHISPER', ChatEdit_GetLastTellTarget(ChatFrameEditBox))
			end
		elseif strlen(input) > 1 then
			crafty.SendReagentMessage('WHISPER', gsub(input, '^@', ''))
		end
	end

	StaticPopupDialogs['CRAFTY_LINK'] = {
	    text = 'Enter a character name or channel.',
	    button1 = 'Link',
	    button2 = 'Cancel',
	    hasEditBox = 1,
	    OnShow = function(self)
	    	local editBox = getglobal(self:GetName()..'EditBox')
			editBox:SetText('')
			editBox:SetFocus()
		end,
	    OnAccept = action,
	    EditBoxOnEnterPressed = function(self)
	    	action(self)
			self:GetParent():Hide()
		end,
		EditBoxOnEscapePressed = function(self)
			self:GetParent():Hide()
		end,
	    timeout = 0,
	    hideOnEscape = 1,
	}
end

do
	local state = {}
	function crafty.State()
		local profession
		if crafty.mode == TRADE then
			profession = GetTradeSkillLine()
		elseif crafty.mode == CRAFT then
			profession = GetCraftSkillLine(1)
		end
		profession = profession or '' -- TODO better solution

		crafty_favorites[profession] = crafty_favorites[profession] or {}
		state[profession] = state[profession] or {
			searchText = '',
			materials = false,
			favorites = crafty_favorites[profession],
		}
		return state[profession]
	end
end

-- throttling the update event
function crafty.UPDATE()
	if not not IsAltKeyDown() ~= ALT and crafty.frame and crafty.frame:IsShown() then
		ALT = not ALT
		crafty.update_required = true
	end
	if crafty.update_required then
		crafty.update_required = nil
		crafty.currentFrame.orig_update()
		crafty.UpdateListing()
	end
end

function crafty.ADDON_LOADED(_, arg1)
	if arg1 ~= 'crafty' then
		return
	end

	crafty.found = {}

	crafty:RegisterEvent'TRADE_SKILL_SHOW'
	crafty:RegisterEvent'CRAFT_SHOW'

	local origSetItemRef = SetItemRef
	SetItemRef = function(...)
		local popup = StaticPopup_FindVisible'CRAFTY_LINK'
	    local _, _, playerName = strfind(..., 'player:(.+)')
	    if popup and IsShiftKeyDown() and playerName then
	    	getglobal(popup:GetName()..'EditBox'):SetText(playerName)
	    	return
	    end
	    return origSetItemRef(...)
	end

	-- Create main frame
	crafty.frame = CreateFrame'Frame'
	crafty.frame:Hide()
	crafty.frame:SetPoint('CENTER', 'UIParent', 'CENTER', 0, 0)
	crafty.frame:SetWidth(342)
	crafty.frame:SetHeight(45)
	crafty.frame:SetFrameStrata'MEDIUM'
	crafty.frame:SetMovable(false)
	crafty.frame:EnableMouse(true)
	crafty.frame:SetBackdrop({
			bgFile = [[Interface\DialogFrame\UI-DialogBox-Background]], tile = true, tileSize = 32,
			edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]], edgeSize = 20,
			insets = {left=5, right=6, top=6, bottom=5},
	})

	local searchBox = CreateFrame('EditBox', nil, crafty.frame, 'InputBoxTemplate')
	crafty.frame.SearchBox = searchBox
	searchBox:SetTextInsets(16, 20, 0, 0)
	searchBox:SetAutoFocus(false)
	searchBox:SetWidth(204)
	searchBox:SetHeight(20)
	searchBox:SetPoint('LEFT', crafty.frame, 'LEFT', 17, 0)
	searchBox:SetBackdropColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
	searchBox:SetBackdropBorderColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)
	searchBox:SetScript('OnEnterPressed', function(self)
		self:ClearFocus()
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
		clearButton:SetScript('OnEnter', function(self)
			self.tex:SetAlpha(1)
		end)
		clearButton:SetScript('OnLeave', function(self)
			self.tex:SetAlpha(.5)
		end)
		clearButton:SetScript('OnMouseUp', function(self)
			self.tex:SetPoint('TOPLEFT', 0, 0)
		end)
		clearButton:SetScript('OnMouseDown', function(self)
			self.tex:SetPoint('TOPLEFT', 1, -1)
		end)
		clearButton:SetScript('OnClick', function()
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			searchBox:SetText''
			searchBox:ClearFocus()
		end)
		searchBox:SetScript('OnEditFocusGained', function(self)
			self.focused = true
			searchIcon:SetVertexColor(1, 1, 1)
			clearButton:Show()
		end)
		searchBox:SetScript('OnEditFocusLost', function(self)
			self.focused = false
			if self:GetText() == '' then
				searchIcon:SetVertexColor(.6, .6, .6)
				clearButton:Hide()
			end
		end)
		searchBox:SetScript('OnTextChanged', function(self)
			if self:GetText() == '' then
				instructions:Show()
			else
				instructions:Hide()
			end
			if self:GetText() == '' and not self.focused then
				searchIcon:SetVertexColor(.6, .6, .6)
				clearButton:Hide()
			else
				searchIcon:SetVertexColor(1, 1, 1)
				clearButton:Show()
			end
			crafty.Search()
		end)
	end

	-- Materials Button
	crafty.frame.MaterialsButton = CreateFrame('Button', nil, crafty.frame, 'UIPanelButtonTemplate')
	crafty.frame.MaterialsButton:SetWidth(52)
	crafty.frame.MaterialsButton:SetHeight(25)
	crafty.frame.MaterialsButton:SetPoint('LEFT', searchBox, 'RIGHT', 4, 0)
	crafty.frame.MaterialsButton:SetText'Mats'
	crafty.frame.MaterialsButton:SetScript('OnClick', function(self)
		crafty.State().materials = not crafty.State().materials
		if crafty.State().materials then
			self:LockHighlight()
		else
			self:UnlockHighlight()
		end
        crafty.Search()
    end)

	-- Link button
	crafty.frame.LinkButton = CreateFrame('Button', nil, crafty.frame, 'UIPanelButtonTemplate')
	crafty.frame.LinkButton:SetWidth(52)
	crafty.frame.LinkButton:SetHeight(25)
	crafty.frame.LinkButton:SetPoint('LEFT', crafty.frame.MaterialsButton, 'RIGHT', 2, 0)
	crafty.frame.LinkButton:SetText'Link'
	crafty.frame.LinkButton:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
	crafty.frame.LinkButton:SetScript('OnClick', function(_, arg1)
		if StaticPopup_Visible'CRAFTY_LINK' then
			StaticPopup_Hide'CRAFTY_LINK'
		elseif arg1 == 'RightButton' then
			StaticPopup_Show'CRAFTY_LINK'
		end

		if arg1 == 'LeftButton' then
			local channel = GetNumGroupMembers() == 0 and 'WHISPER' or 'PARTY'
			if channel == 'PARTY' or ChatEdit_GetLastTellTarget(ChatFrameEditBox) ~= '' then
				crafty.SendReagentMessage(channel, ChatEdit_GetLastTellTarget(ChatFrameEditBox))
			end
		end
	end)
end

function crafty.Relevel(frame)
	for _, child in pairs{frame:GetChildren()} do
		child:SetFrameLevel(frame:GetFrameLevel() + 1)
		crafty.Relevel(child)
	end
end

function crafty.CRAFT_SHOW()
	if not GetCraftDisplaySkillLine() then
		return
	end

	crafty.mode = CRAFT
	crafty.currentFrame = crafty.frames.craft

	-- first time window has been opened
	if not crafty.currentFrame.orig_update then
		crafty:RegisterEvent'CRAFT_CLOSE'
		crafty.currentFrame.orig_update = CraftFrame_Update
		CraftFrame_Update = function() crafty.update_required = true end
		for i = 1, 8 do
			getglobal('Craft' .. i):SetScript('OnDoubleClick', function(self)
				crafty.frame.SearchBox:SetText(GetCraftInfo(self:GetID()))
			end)
			getglobal('Craft' .. i):SetScript('OnMouseDown', function(self, arg1)
				if arg1 == 'RightButton' then
					local favorites, name = crafty.State().favorites, GetCraftInfo(self:GetID())
					favorites[name] = not favorites[name] or nil
					crafty.Search()
				end
			end)
		end
	end

	if getglobal(crafty.frames.trade.elements.Main) and getglobal(crafty.frames.trade.elements.Main):IsShown() then
		getglobal(crafty.frames.trade.elements.Main):Hide()
	end

	crafty.Show()
end

function crafty.TRADE_SKILL_SHOW()
	crafty.mode = TRADE
	crafty.currentFrame = crafty.frames.trade

	-- first time window has been opened
	if not crafty.currentFrame.orig_update then
		crafty:RegisterEvent'TRADE_SKILL_CLOSE'
		crafty.currentFrame.orig_update = TradeSkillFrame_Update
		TradeSkillFrame_Update = function() crafty.update_required = true end
		for i = 1, 8 do
			getglobal('TradeSkillSkill'..i):SetScript('OnDoubleClick', function(self)
				crafty.frame.SearchBox:SetText(GetTradeSkillInfo(self:GetID()))
			end)
			getglobal('TradeSkillSkill'..i):SetScript('OnMouseDown', function(self, arg1)
				if arg1 == 'RightButton' then
					local favorites, name = crafty.State().favorites, GetTradeSkillInfo(self:GetID())
					favorites[name] = not favorites[name] or nil
					crafty.Search()
				end
			end)
		end
	end

	if getglobal(crafty.frames.craft.elements.Main) and getglobal(crafty.frames.craft.elements.Main):IsShown() then
		getglobal(crafty.frames.craft.elements.Main):Hide()
	end

	crafty.Show()
end

function crafty.Show()
	crafty.currentFrame.orig_update()

	crafty.frame:SetParent(crafty.currentFrame.elements.Main)
	crafty.Relevel(crafty.frame)
	crafty.frame:ClearAllPoints()
	crafty.frame:SetPoint(unpack(crafty.currentFrame.anchor))

	crafty.frame:Show()
	if crafty.State().materials then
		crafty.frame.MaterialsButton:LockHighlight()
	else
		crafty.frame.MaterialsButton:UnlockHighlight()
	end
	crafty.frame.SearchBox:SetText(crafty.State().searchText)
	crafty.Search()
end

function crafty.CRAFT_CLOSE()
	crafty.Close()
end

function crafty.TRADE_SKILL_CLOSE()
	crafty.Close()
end

function crafty.Close()
	crafty.frame:Hide()
	StaticPopup_Hide'CRAFTY_LINK'
end

function crafty.UpdateListing()

	-- may be disabled from the no results message
	getglobal((crafty.mode == CRAFT and 'Craft' or 'TradeSkillSkill')..1):Enable()

	if (crafty.State().searchText ~= '' or crafty.State().materials or next(crafty.State().favorites) and not ALT) and getglobal(crafty.currentFrame.elements.Main):IsShown() then

		local skillOffset = FauxScrollFrame_GetOffset(getglobal(crafty.currentFrame.elements.Scroll))
		local skillButton

		crafty.BuildList()

		if crafty.mode == TRADE then
			getglobal(crafty.frames.trade.elements.CollapseAll):Disable();
			for i = 1, TRADE_SKILLS_DISPLAYED do
				getglobal('TradeSkillSkill'..i..'Text'):SetPoint('TOPLEFT', 'TradeSkillSkill'..i, 'TOPLEFT', 3, 0)
			end
		end

		FauxScrollFrame_Update(getglobal(crafty.currentFrame.elements.Scroll), #crafty.found, (crafty.mode == CRAFT and CRAFTS_DISPLAYED or TRADE_SKILLS_DISPLAYED), (crafty.mode == CRAFT and CRAFT_SKILL_HEIGHT or TRADE_SKILL_HEIGHT), nil, nil, nil, getglobal(crafty.currentFrame.elements.Highlight), 293, 316 )
		getglobal(crafty.currentFrame.elements.Highlight):Hide()

		if #crafty.found > 0 then

			for i = 1, crafty.mode == CRAFT and CRAFTS_DISPLAYED or TRADE_SKILLS_DISPLAYED do
				local skillIndex = i + skillOffset
				skillButton = getglobal((crafty.mode == CRAFT and 'Craft' or 'TradeSkillSkill')..i)
				skillButtonText = getglobal((crafty.mode == CRAFT and 'Craft' or 'TradeSkillSkill')..i.."SubText")

				if crafty.found[skillIndex] then
					if getglobal(crafty.currentFrame.elements.Scroll):IsShown() then
						skillButton:SetWidth(293)
					else
						skillButton:SetWidth(323)
					end

					local color = (crafty.mode == CRAFT and CraftTypeColor[crafty.found[skillIndex].type] or TradeSkillTypeColor[crafty.found[skillIndex].type])
					if color then
						skillButton:SetNormalFontObject(color.font);
						skillButtonText:SetTextColor(color.r, color.g, color.b)
						skillButton.r = color.r;
						skillButton.g = color.g;
						skillButton.b = color.b;
						skillButton.font = color.font;
					end
					skillButton:SetID(crafty.found[skillIndex].index)
					skillButton:Show()

					if crafty.found[skillIndex].name == '' then
						return
					end

					skillButton:SetNormalTexture('')
					getglobal((crafty.mode == CRAFT and 'Craft' or 'TradeSkillSkill')..i..'Highlight'):SetTexture''
					if crafty.found[skillIndex].available <= 0 then
						skillButton:SetText(' '..crafty.found[skillIndex].name)
						skillButtonText:SetWidth(275)
					else
						skillButton:SetText(' '..crafty.found[skillIndex].name..' ['..crafty.found[skillIndex].available..']')
					end

					if (crafty.mode == CRAFT and GetCraftSelectionIndex() or GetTradeSkillSelectionIndex()) == crafty.found[skillIndex].index then
						getglobal(crafty.currentFrame.elements.Highlight):SetPoint('TOPLEFT', skillButton, 'TOPLEFT', 0, 0)
						getglobal(crafty.currentFrame.elements.Highlight):Show()

						skillButtonText:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);

						skillButton:LockHighlight()
						skillButton.isHighlighted = true;
						-- Setting the num avail so the create all button works for tradeskills
						if crafty.mode == TRADE and getglobal(crafty.frames.trade.elements.Main) then
							getglobal(crafty.currentFrame.elements.Main).numAvailable = crafty.found[skillIndex].available
						end
					else
						if not crafty.SelectionInList(skillOffset) then
							getglobal(crafty.currentFrame.elements.Highlight):Hide()
						end
						skillButton:UnlockHighlight()
						skillButton.isHighlighted = false;
					end
					-- end
				else
					skillButton:Hide()
				end
			end

		else
			getglobal(crafty.currentFrame.elements.Scroll):Hide()
			for i = 1, crafty.mode == CRAFT and CRAFTS_DISPLAYED or TRADE_SKILLS_DISPLAYED do
				skillButton = getglobal((crafty.mode == CRAFT and 'Craft' or 'TradeSkillSkill')..i)
				skillButtonText = getglobal((crafty.mode == CRAFT and 'Craft' or 'TradeSkillSkill')..i.."SubText")
				if i == 1 then
					skillButton:Disable()
					skillButton:SetWidth(323)
					skillButtonText:SetTextColor(1, 1, 1)
					skillButton:SetDisabledTexture''
					skillButton:SetText'No results matched your search.'
					skillButton:UnlockHighlight()
					skillButton.isHighlighted = false;
					skillButton:Show()
				else
					skillButton:Hide()
				end
			end
		end
	else
		if crafty.mode == CRAFT then
		elseif crafty.mode == TRADE then
			for i = 1, TRADE_SKILLS_DISPLAYED do
				getglobal('TradeSkillSkill'..i..'Text'):SetPoint('TOPLEFT', 'TradeSkillSkill'..i, 'TOPLEFT', 21, 0)
			end
		end
		crafty.currentFrame.orig_update()
	end
end

function crafty.Search()
	crafty.State().searchText = crafty.frame.SearchBox:GetText() or ''

	FauxScrollFrame_SetOffset(getglobal(crafty.currentFrame.elements.Main), 0)
	getglobal(crafty.currentFrame.elements.ScrollBar):SetValue(0)

	crafty.BuildList()
	if #crafty.found > 0 and crafty.State().searchText ~= '' then
		crafty.SelectFirst()
	end
	crafty.UpdateListing()
end

function crafty.SelectFirst()
	if crafty.mode == CRAFT and GetCraftSelectionIndex() > 0 then
		CraftFrame_SetSelection(crafty.found[1].index)
	elseif crafty.mode == TRADE then
		TradeSkillFrame_SetSelection(crafty.found[1].index)
	end
end

function crafty.SelectionInList(skillOffset)
	for i = skillOffset + 1, skillOffset + (crafty.mode == CRAFT and CRAFTS_DISPLAYED or TRADE_SKILLS_DISPLAYED) do
		if crafty.found[i] and crafty.found[i].index == (crafty.mode == CRAFT and GetCraftSelectionIndex() or GetTradeSkillSelectionIndex()) then
			return true
		end
	end
	return false
end

function crafty.BuildList()
	crafty.found = {}
	local reagents = {}
	local skills = {}

	local matcher = crafty.FuzzyMatcher(crafty.State().searchText)

	for i = 1, crafty.mode == CRAFT and GetNumCrafts() or GetNumTradeSkills() do

		local skillName, skillType, numAvailable, isExpanded, requires
		if crafty.mode == CRAFT then
			skillName, _, skillType, numAvailable, isExpanded = GetCraftInfo(i)
			requires = GetCraftSpellFocus(i)
		elseif crafty.mode == TRADE then
			skillName, skillType, numAvailable, isExpanded = GetTradeSkillInfo(i)
			requires = GetTradeSkillTools(i)
		end

		local nameRating = skillName and matcher(skillName)

		local reagents = {}
		local reagentsRating
		for j = 1, crafty.mode == CRAFT and GetCraftNumReagents(i) or GetTradeSkillNumReagents(i) do
			local reagentName
			if crafty.mode == CRAFT then
				reagentName = GetCraftReagentInfo(i, j)
			elseif crafty.mode == TRADE then
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

	local found

	if crafty.State().searchText == '' and not crafty.State().materials then
		found = crafty.State().favorites
	else
		found = {}

		for _, skill in pairs(skills) do
			if skill.rating then
				found[skill.name] = true
			end
		end

		while true do
			local changed
			for _, skill in pairs(skills) do
				if found[skill.name] then
					for _, reagentName in pairs(skill.reagents) do
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

		if crafty.State().materials then
			for _, skill in pairs(skills) do
				if skill.available == 0 then
					found[skill.name] = nil
				end
			end
		end
	end

	for skill, data in pairs(skills) do
		if found[skill] then
			tinsert(crafty.found, data)
		end
	end

	sort(crafty.found, function(a, b)
		if crafty.State().searchText == '' then
			return a.index < b.index
		else
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
		end
	end)
end

function crafty.SendReagentMessage(channel, who)

	local index = crafty.mode == CRAFT and GetCraftSelectionIndex() or GetTradeSkillSelectionIndex()

	if index == 0 then
		return
	end

	local message = {}

	local messagePart = (crafty.mode == CRAFT and GetCraftItemLink(index) or GetTradeSkillItemLink(index))..' ='
	for i = 1, crafty.mode == CRAFT and GetCraftNumReagents(index) or GetTradeSkillNumReagents(index) do
		local reagentLink = crafty.mode == CRAFT and GetCraftReagentItemLink(index, i) or GetTradeSkillReagentItemLink(index, i)
		local reagentCount = (crafty.mode == CRAFT and {GetCraftReagentInfo(index, i)} or {GetTradeSkillReagentInfo(index, i)})[3]

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

function crafty.FuzzyMatcher(input)
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
			for i = 4, #match - 1 do
				if strlen(match[i]) == 0 then
					rating = rating + 1
				end
 			end
			return rating
 		end
	end
end
