crafty = AceLibrary("AceAddon-2.0"):new("AceDB-2.0", "AceConsole-2.0", "AceDebug-2.0", "AceEvent-2.0", "AceHook-2.0")

-- Dewdrop: handles our dropdown
local dewdrop =  AceLibrary("Dewdrop-2.0")

-- Our container for all frames.
local frames = {}

-- The search type should default to "by name"
crafty:RegisterDB("craftyDB")
crafty:RegisterDefaults('profile', {
    searchType = {},
	searchHistory = {},
})

function crafty:OnInitialize()
	self:SetDebugging(false)
	self:RegisterChatCommand({ "/crafty" }, nil)
	
	-- Tradeskill frame references
	frames.trade = {}
	frames.trade.elements = {
		["Main"] 		= "TradeSkillFrame",
		["Title"] 		= "TradeSkillFrameTitleText",
		["Scroll"]		= "TradeSkillListScrollFrame",
		["ScrollBar"] 	= "TradeSkillListScrollFrameScrollBar",
		["Highlight"]	= "TradeSkillHighlightFrame",
		["CollapseAll"] = "TradeSkillCollapseAllButton",
	}
	frames.trade.anchor = "TradeSkillCreateAllButton"
	frames.trade.anchor_offset_x = -9
	frames.trade.anchor_offset_y = -8
	frames.trade.update	 = "TradeSkillFrame_Update"

	-- Crafting frame references
	frames.craft = {}
	frames.craft.elements = {
		["Main"] 		= "CraftFrame",
		["Title"]		= "CraftFrameTitleText",
		["Scroll"] 		= "CraftListScrollFrame",
		["ScrollBar"] 	= "CraftListScrollFrameScrollBar",
		["Highlight"] 	= "CraftHighlightFrame",
	}
	frames.craft.anchor = "CraftCancelButton"
	frames.craft.anchor_offset_x = 6
	frames.craft.anchor_offset_y = -8
	frames.craft.update = "CraftFrame_Update"
	
	-- Setup some closures for use later.
	-- History search text setting variable get/save
	self.getHistory = function(var)	return self.db.profile.searchHistory[var] end
	self.setHistory = function(val) self.db.profile.searchHistory[self.lastSearchTrade or getglobal(self.currentFrame.elements.Title):GetText()] = val end
	self.clearHistory = function() self.db.profile.searchHistory = {} end
	-- History search type setting variable get/save
	self.getSearchType = function(val) return self.db.profile.searchType[getglobal(self.currentFrame.elements.Title):GetText()] or self.LOCALS.FRAME_SEARCH_TYPES[val] end
	self.setSearchType = function(val) self.db.profile.searchType[getglobal(self.currentFrame.elements.Title):GetText()] = val end
	
	-- Search Text
	self.searchText = nil
	-- Clear our the search history
	self.clearHistory()
	-- Handler for the currently opened frame.
	self.currentFrame = nil
end

function crafty:OnEnable()
	self:Debug("OnEnable called.")
	
	-- Tradeskill window --
	self:RegisterEvent("TRADE_SKILL_SHOW")
	-- Enchanting window --
	self:RegisterEvent("CRAFT_SHOW")

	self:RegisterEvent("TRADE_SKILL_UPDATE")
	self:RegisterEvent("CRAFT_UPDATE")
	
	if not self.frame then
		self:Debug("Creating craftyFrame.")
		-- Create main frame 
		self.frame = CreateFrame("Frame", "craftyFrame", UIParent)
		self.frame:Hide()
		-- Set main frame properties
		self.frame:SetPoint("CENTER", "UIParent", "CENTER", 0, 0)
		self.frame:SetWidth(342)  
		self.frame:SetHeight(45)
		self.frame:SetFrameStrata("MEDIUM")
		self.frame:SetMovable(false)
		self.frame:EnableMouse(true)
		-- Set the main frame backdrop
		self.frame:SetBackdrop({
				bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", tile = true, tileSize = 32,
				edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 20,
				insets = {left = 5, right = 6, top = 6, bottom = 5},
		})
		self.frame:SetBackdropColor(1, 1, 1, 1)
		self.frame:SetBackdropBorderColor(0, .8, 0, 1)
		self.frame:SetScript("OnShow", function() self:OnShow() end)
		
		-- Create sub-frames
		-- Editbox for search text
		self.frame.SearchBox = CreateFrame("EditBox", nil, self.frame, "InputBoxTemplate")
		self.frame.SearchBox:SetAutoFocus(false)
		self.frame.SearchBox:SetWidth(138)
		self.frame.SearchBox:SetHeight(20)
		self.frame.SearchBox:SetPoint("LEFT", self.frame, "LEFT", 20, 0)
		self.frame.SearchBox:SetBackdropColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
		self.frame.SearchBox:SetBackdropBorderColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)
		self.frame.SearchBox:SetScript("OnTextChanged", function() self:Search() end)
		self.frame.SearchBox:SetScript("OnChar", function()
			if arg1 == '/' then
				this:SetText(gsub(this:GetText(), '/', ''))
				ChatFrameEditBox:Show()
				ChatFrameEditBox:SetText('/')
				ChatFrameEditBox:SetFocus()
			end
		end)
		self.frame.SearchBox:SetScript("OnEnterPressed", function()
			this:ClearFocus()
		end)
		
		-- Reset Button
		self.frame.ResetButton = CreateFrame("Button", nil, self.frame, "GameMenuButtonTemplate")
		self.frame.ResetButton:SetWidth(20)
		self.frame.ResetButton:SetHeight(25)
		self.frame.ResetButton:SetPoint("RIGHT", self.frame, "RIGHT", -15, 0)
		self.frame.ResetButton:SetText(self.LOCALS.FRAME_RESET_TEXT)
		self.frame.ResetButton:SetScript("OnClick", function() self:Reset() end)
	
		-- SearchType dropdown button to show the menu when clicked.
		self.frame.SearchTypeButton = CreateFrame("Button", nil, self.frame, "GameMenuButtonTemplate")
		self.frame.SearchTypeButton:SetWidth(70)
		self.frame.SearchTypeButton:SetHeight(25)
		self.frame.SearchTypeButton:SetPoint("LEFT", self.frame.SearchBox, "RIGHT", 8, 0)
		self.frame.SearchTypeButton.index = 1
		self.frame.SearchTypeButton:SetScript("OnClick", function()
			this.index = mod(this.index, 3) + 1
			local new_type = self.LOCALS.FRAME_SEARCH_TYPES[this.index]
			this:SetText(new_type)
			self.setSearchType(new_type)
			self:Search()
		end)	
		
		-- Link Reagents dropdown button to show the menu when clicked.
		self.frame.LinkReagentButton = CreateFrame("Button", nil, self.frame, "GameMenuButtonTemplate")
		self.frame.LinkReagentButton:SetWidth(50)
		self.frame.LinkReagentButton:SetHeight(25)
		self.frame.LinkReagentButton:SetPoint("LEFT", self.frame.SearchTypeButton, "RIGHT", 8, 0)
		self.frame.LinkReagentButton:SetText(self.LOCALS.FRAME_LINK_REAGENTS)
		self.frame.LinkReagentButton:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
		self.frame.LinkReagentButton:SetScript("OnClick", function() 
				if dewdrop:IsOpen(self.frame.LinkReagentButton) then 
					dewdrop:Close()	
				elseif arg1 == 'RightButton' then
					dewdrop:Open(self.frame.LinkReagentButton) 
				end

				if arg1 == 'LeftButton' then
					local target = ChatEdit_GetLastTellTarget(ChatFrameEditBox) ~= '' and ChatEdit_GetLastTellTarget(ChatFrameEditBox)
					local channel = GetNumPartyMembers() == 0 and 'WHISPER' or 'PARTY'
					if channel == 'PARTY' or target then
						crafty:SendReagentsMessage(channel, target)
					end
				end
			end
		)
		
		-- Create the LinkReagents dropdown menu
		dewdrop:Register(self.frame.LinkReagentButton,
			'point', function(parent)
				return "TOPLEFT", "BOTTOMLEFT"
			end,
			'dontHook', true,
			'children', function()
				dewdrop:AddLine(
					'text', crafty.LOCALS.FRAME_LINK_REAGENTS_TITLE,
					'isTitle', true
				)
				for i,channel in self.LOCALS.FRAME_LINK_TYPES do
					-- There are two types lines: 
					-- 1. Those that are straightforward and do not require user input
					-- 2. Those that require the user to input information to take it a step further.
					-- channel[1] is the "common name"
					-- channel[2] is the "channel"
					-- channel[3] is the "desc"
					if channel[2] ~= "WHISPER" and channel[2] ~= "CHANNEL" then
						dewdrop:AddLine(
							'text', channel[1],
							'func', function(val)
								self:SendReagentsMessage(val, nil)
							end,
							'arg1', channel[2],
							'closeWhenClicked', true
						)
					else
						dewdrop:AddLine(
							'text', channel[1],
							'hasArrow', true,
							'hasEditBox', true,
							'tooltipTitle', channel[1],
							'tooltipText', channel[3],
							'editBoxFunc', function(channel, text)
								self:SendReagentsMessage(channel, text)
							end,
							'editBoxArg1', channel[2]
						)
					end
				end
			end
		)
	end
	
	-- If the mod was disabled when WoW loaded, then the main frame will not be visible. So we'll make it visible again.
	if getglobal(frames.trade.elements.Main) and getglobal(frames.trade.elements.Main):IsShown() then
		crafty:TRADE_SKILL_SHOW()
	elseif getglobal(frames.craft.elements.Main) and getglobal(frames.craft.elements.Main):IsShown() then
		crafty:CRAFT_SHOW()
	end
end

function crafty:OnDisable()
	if self.frame then
		self.frame:Hide()
	end
	
	-- Clear our search history and current search text.
	self.clearHistory()
	self.searchText = ""
	
	-- Finally, update the trade/craft windows just in case we have any lingering search results.
	if self.hooks and self.hooks[frames.trade.update] then
		getglobal(frames.trade.update)()
	end
	
	if self.hooks and self.hooks[frames.craft.update] then
		getglobal(frames.craft.update)()
	end
end

function crafty:OnShow()
	if self.searchText ~= nil then
		self.frame.SearchBox:SetText(self.searchText)
	end
	
	self:Search()
	
	-- Update the "Type" dropdown so that it reflects the current searchType or "Name" by default.
	if self.getSearchType() ~= nil then
		self.frame.SearchTypeButton:SetText(self.getSearchType())
	else
		self.frame.SearchTypeButton:SetText(self.getSearchType(1))
	end
end

function crafty:TRADE_SKILL_UPDATE()
	self.found = {}
	self:Update()
end

function crafty:CRAFT_UPDATE()
	self.found = {}
	self:Update(true)
end

function crafty:CRAFT_SHOW()
	-- first time window has been opened
	if not self.hooks or not self.hooks[frames.craft.update] then
		self:RegisterEvent("CRAFT_CLOSE", "OnClose")
		self:Hook(frames.craft.update, function () self:Update(true) end)
	end
	
	-- Have to set our current frame for the widgets that load.
	self.currentFrame = frames.craft
	
	-- Is the tradeskill window open? If so we'll need to close it.
	if getglobal(frames.trade.elements.Main) and getglobal(frames.trade.elements.Main):IsShown() then
		getglobal(frames.trade.elements.Main):Hide()
	end
	
	-- We need to dynmically position the addon because the trade/craft anchors are different.
	self.frame:ClearAllPoints()
	self.frame:SetPoint("TOPRIGHT", frames.craft.anchor, "BOTTOMRIGHT" , frames.craft.anchor_offset_x, frames.craft.anchor_offset_y)
	-- Check if the frame was already shown, which means they just changed tradeskills and no update with the OnShow.
	-- Otherwise, lets just show the frame.
	if ( self.frame:IsShown() ) then
		self:OnShow()
	else
		self.frame:Show()
	end

	-- Run our update.
	self:Update(true)
end

function crafty:TRADE_SKILL_SHOW()
	-- first time window has been opened
	if not self.hooks or not self.hooks[frames.trade.update] then
		self:RegisterEvent("TRADE_SKILL_CLOSE", "OnClose")
		self:Hook(frames.trade.update, function () self:Update() end)
		
		-- Check if AutoCraft exists, if it does we're going to have to anchor to something different.
		if AutoCraftFrame then 
			frames.trade.anchor = "AutoCraftRunAutomatically"
			frames.trade.anchor_offset_x = -7
		end
	end
		
	-- Have to set our current frame for the widgets that load.
	self.currentFrame = frames.trade
	
	-- Is the crafting window open? If so we'll need to close it.
	if getglobal(frames.craft.elements.Main) and getglobal(frames.craft.elements.Main):IsShown() then
		getglobal(frames.craft.elements.Main):Hide()
	end
	
	-- We need to dynmically position the addon because the trade/craft anchors are different.
	self.frame:ClearAllPoints()
	self.frame:SetPoint("TOPLEFT", getglobal(frames.trade.anchor), "BOTTOMLEFT" , frames.trade.anchor_offset_x, frames.trade.anchor_offset_y)
	-- Check if the frame was already shown, which means they just changed tradeskills and no update with the OnShow.
	-- Otherwise, lets just show the frame.
	if self.frame:IsShown() then
		self:OnShow()
	else
		self.frame:Show()
	end
	
	-- Run the update.
	self:Update()
end

function crafty:OnClose()
	self.frame:Hide()
	dewdrop:Close()	
end

function crafty:Update(craft) 

	-- Update the search history and searh type dropdown
	self.setHistory(self.searchText)
	-- The user has changed their trade window, reset the search text if they haven't searched before
	if not self.lastSearchTrade or self.lastSearchTrade ~= getglobal(self.currentFrame.elements.Title):GetText() then
		-- Now we update last searched to the current trade/craft type/window name
		self.lastSearchTrade = getglobal(self.currentFrame.elements.Title):GetText()
		-- Does old text for the current window exist? 
		if self.getHistory(self.lastSearchTrade) then
			self:Debug("Found history: "..self.lastSearchTrade)
			self.searchText = self.getHistory(self.lastSearchTrade)
		else
			self:Debug("No history, searchText=''")
			self.searchText = ""
		end
		-- Finally, update the actual searchbox.
		self.frame.SearchBox:SetText(self.searchText)
	end
	
	-- The user has decided to search for 
	if self.searchText ~= '' and getglobal(self.currentFrame.elements.Main):IsShown() then
		local searchType = self.getSearchType()
		local skillOffset = FauxScrollFrame_GetOffset(getglobal(self.currentFrame.elements.Scroll))	
		local skillButton = nil
		
		-- Keeps the list from being rebuilt unncessarily when the user is scrolling through search results.
		if self.found and getn(self.found) == 0 then
			if searchType == 'Reagent' then
				-- search by reagent results
				self:BuildListByReagent(self.searchText, craft)
			elseif searchType == 'Requires' then
				-- search by requires results
				self:BuildListByRequire(self.searchText, craft)
			else
				-- search by name results
				self:BuildListByName(self.searchText, craft)
			end
		end
						
		-- If we're doing tradeskills, we don't have categories, so we don't need a collapse.
		if not craft then
			getglobal(frames.trade.elements.CollapseAll):Disable();
		end
		
		-- Update the scroll frame.
		FauxScrollFrame_Update(getglobal(self.currentFrame.elements.Scroll), getn(self.found), (craft and CRAFTS_DISPLAYED or TRADE_SKILLS_DISPLAYED), (craft and CRAFT_SKILL_HEIGHT or TRADE_SKILL_HEIGHT), nil, nil, nil, getglobal(self.currentFrame.elements.Highlight), 293, 316 )
		getglobal(self.currentFrame.elements.Highlight):Hide()
		
		if getn(self.found) > 0 then
					
			-- Do the actual display of the list now.
			for i=1,craft and CRAFTS_DISPLAYED or TRADE_SKILLS_DISPLAYED, 1 do
				local skillIndex = i + skillOffset
				skillButton = getglobal((craft and "Craft" or "TradeSkillSkill")..i)
				
				if i <= getn(self.found) then
					-- Set button widths if scrollbar is shown or hidden
					if getglobal(self.currentFrame.elements.Scroll):IsVisible() then
						skillButton:SetWidth(293)
					else
						skillButton:SetWidth(323)
					end
					
					self:Debug("self.found["..skillIndex.."].type="..self.found[skillIndex].type)
					local color = (craft and CraftTypeColor[self.found[skillIndex].type] or TradeSkillTypeColor[self.found[skillIndex].type])
					if color then
						skillButton:SetTextColor(color.r, color.g, color.b)
					end
					skillButton:SetID(self.found[skillIndex].index)
					skillButton:Show()
					
					if self.found[skillIndex].name == '' then
						return
					end
					
					skillButton:SetNormalTexture('')
					getglobal((craft and "Craft" or "TradeSkillSkill")..i.."Highlight"):SetTexture("")
					if self.found[skillIndex].available == 0 then
						skillButton:SetText(" "..self.found[skillIndex].name)
					else
						skillButton:SetText(" ".. self.found[skillIndex].name .." [".. self.found[skillIndex].available .."]")
					end
					
					-- Place the highlight and lock the highlight state
					if (craft and GetCraftSelectionIndex() or GetTradeSkillSelectionIndex()) == self.found[skillIndex].index then
						getglobal(self.currentFrame.elements.Highlight):SetPoint("TOPLEFT", skillButton, "TOPLEFT", 0, 0)
						getglobal(self.currentFrame.elements.Highlight):Show()
						skillButton:LockHighlight()
						-- Setting the num avail so the create all button works for tradeskills
						if (not craft and getglobal(frames.trade.elements.Main)) then
							getglobal(self.currentFrame.elements.Main).numAvailable = self.found[skillIndex].available
						end
					else
						-- The highlight is shown, but it's on an entry that we haven't selected. Probably a remnant from a selection before we did our search,
						-- so we'll go ahead and hide the frame.
						if not self:SelectionInList(skillOffset, craft) then
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
			for i=1, (craft and CRAFTS_DISPLAYED or TRADE_SKILLS_DISPLAYED), 1 do
				skillButton = getglobal((craft and "Craft" or "TradeSkillSkill")..i)
				
				skillButton:SetWidth(323)
				skillButton:SetTextColor(1, 1, 1)
				skillButton:SetID(1)
				skillButton:SetNormalTexture("")
				getglobal((craft and "Craft" or "TradeSkillSkill")..i.."Highlight"):Hide()
				skillButton:UnlockHighlight();
				skillButton:Show()
				
				if i == 1 then
					getglobal(self.currentFrame.elements.Highlight):Hide()
					skillButton:SetText(self.LOCALS.FRAME_NO_RESULTS)
				else 
					skillButton:SetText("")
				end
			end
		end
	else
		self.hooks[ craft and frames.craft.update or frames.trade.update ].orig()
	end
end

function crafty:Search()
	self.searchText = self.frame.SearchBox:GetText()
	-- Need to reset / create our self.found array.
	self.found = {}
	
	-- We have to clear the offset on the scroll frame, otherwise we error out and it's misscrolled.
	-- self.currentFrame = (getglobal(frames.craft.elements.Main) and getglobal(frames.craft.elements.Main):IsShown() and "CraftListScrollFrame" or getglobal(frames.trade.elements.Main) and getglobal(frames.trade.elements.Main):IsShown() and "TradeSkillListScrollFrame"
	FauxScrollFrame_SetOffset(getglobal(self.currentFrame.elements.Main), 0)
	getglobal(self.currentFrame.elements.ScrollBar):SetValue(0)
	-- Finally, do the update.
	
	local craft = getglobal(frames.craft.elements.Main) and getglobal(frames.craft.elements.Main):IsShown()

	self:Update(craft)
	if getn(self.found) > 0 then
		if craft then
			CraftFrame_SetSelection(self.found[1].index)
		else
			TradeSkillFrame_SetSelection(self.found[1].index)
		end
		self:Update(craft)
	end
end

-- Reset the skill frames.
function crafty:Reset()
	self.searchText = ''
	self.frame.SearchBox:SetText('')
	self.clearHistory()
	self:Update(getglobal(frames.craft.elements.Main) and getglobal(frames.craft.elements.Main):IsShown())
end

function crafty:SelectionInList(skillOffset, craft)
	for i=skillOffset+1, skillOffset+(craft and CRAFTS_DISPLAYED or TRADE_SKILLS_DISPLAYED), 1 do
		if self.found[i] and self.found[i].index == (craft and GetCraftSelectionIndex() or GetTradeSkillSelectionIndex()) then
			return true
		end
	end
	
	return false
end

function crafty:BuildListByName(searchText, craft)
	self.found = {}

	local matcher = self:fuzzy(searchText)
	
	local skillName, skillType, numAvailable, isExpanded
	for i=1, (craft and GetNumCrafts() or GetNumTradeSkills()), 1 do
		if craft then
			skillName, _, skillType, numAvailable, isExpanded = GetCraftInfo(i)
		else
			skillName, skillType, numAvailable, isExpanded = GetTradeSkillInfo(i)
		end
		
		local rating = matcher(skillName)
		if rating and skillType ~= 'header' then
			tinsert(self.found, {
				name			= skillName,
				type 			= skillType,
				available		= numAvailable,
				index 			= i,
				rating 			= rating,
			})
		elseif skillType == 'header' and not isExpanded then
			-- We need to expand any unexpanded header types, otherwise we can't parse their sub data.
			ExpandTradeSkillSubClass(i)
		end
	end
	
	sort(self.found, function(a, b) return b.rating < a.rating or a.rating == b.rating and strlen(a.name) < strlen(b.name) end)
end

function crafty:BuildListByRequire(searchText, craft)
	local foundIndex = 0
	self.found = {}

	local skillName, skillType, numAvailable, isExpanded
	local requires 	
	for i=1, (craft and GetNumCrafts() or GetNumTradeSkills()), 1 do
		if ( craft ) then
			skillName, _, skillType, numAvailable, isExpanded = GetCraftInfo(i)
			requires = GetCraftSpellFocus(i)
		else
			skillName, skillType, numAvailable, isExpanded = GetTradeSkillInfo(i)
			requires = GetTradeSkillTools(i)
		end
		
		if requires and strfind(string.lower(BuildColoredListString(requires)), string.lower(searchText)) and skillType ~= 'header' then
			self:Debug("Found matching require for '"..searchText.."': "..requires.." ")
			foundIndex = foundIndex + 1
			self.found[foundIndex] = {}
			self.found[foundIndex] = {
				name			= skillName,
				type 			= skillType,
				available		= numAvailable,
				index 			= i
			}	
		elseif skillType == 'header' and not isExpanded then
			-- We need to expand any unexpanded header types, otherwise we can't parse their sub data.
			ExpandTradeSkillSubClass(i)
		end
	end
end

function crafty:BuildListByReagent(searchText, craft)
	local foundIndex = 0
	self.found = {}
	
	local skillName, skillType, numAvailable, isExpanded, reagentName
	for i=1, (craft and GetNumCrafts() or GetNumTradeSkills()), 1 do
		if craft then
			skillName, _, skillType, numAvailable, isExpanded = GetCraftInfo(i)
		else
			skillName, skillType, numAvailable, isExpanded = GetTradeSkillInfo(i)
		end
		
		if skillType ~= 'header' then
			for e=1,craft and GetCraftNumReagents(i) or GetTradeSkillNumReagents(i), 1 do
				if craft then
					reagentName, _, _, _ = GetCraftReagentInfo(i, e)
				else
					reagentName, _, _, _ = GetTradeSkillReagentInfo(i, e)
				end
				
				
				if reagentName and strfind(string.lower(reagentName), string.lower(searchText)) then
					foundIndex = foundIndex + 1
					self.found[foundIndex] = {}
					self.found[foundIndex] = {
						name			= skillName,
						type 			= skillType,
						available		= numAvailable,
						index 			= i
					}	
					-- Some reagents can share a similar name so if we already matched one, we can break here.
					break
				end
			end
		elseif skillType == 'header' and not isExpanded then
			-- We need to expand any unexpanded header types, otherwise we can't parse their sub data.
			ExpandTradeSkillSubClass(i)
		end
	end
end

function crafty:SendReagentsMessage(channel, who)
	local craft = getglobal(frames.craft.elements.Main) and getglobal(frames.craft.elements.Main):IsShown()

	local index = craft and GetCraftSelectionIndex() or GetTradeSkillSelectionIndex()

	local message = {}

	local message_part = (craft and GetCraftItemLink(index) or GetTradeSkillItemLink(index))..' ='
	for i=1,craft and GetCraftNumReagents(index) or GetTradeSkillNumReagents(index) do
		local reagent_link = craft and GetCraftReagentItemLink(index, i) or GetTradeSkillReagentItemLink(index, i)
		local reagent_count = (craft and { GetCraftReagentInfo(index, i) } or { GetTradeSkillReagentInfo(index, i) })[3]

		local reagent_info = format(
			'%s x %i',
			reagent_link,
			reagent_count
		)
		if strlen(message_part..reagent_info) > 255 then
			tinsert(message, message_part)
			message_part = '(cont.)'
		end
		message_part = message_part..' '..reagent_info
	end
	tinsert(message, message_part)

	for _, part in ipairs(message) do
		SendChatMessage(part, channel, GetDefaultLanguage('player'), who)
	end
end

function crafty:fuzzy(input)
	local uppercase_input = strupper(input)
	local pattern = '(.*)'
	for i=1,strlen(uppercase_input) do
		if strfind(string.sub(uppercase_input, i, i), '%w') or strfind(string.sub(uppercase_input, i, i), '%s') then
			pattern = pattern .. string.sub(uppercase_input, i, i) .. '(.*)'
 		end
	end
	return function(candidate)
		local match = { string.find(strupper(candidate), pattern) }
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