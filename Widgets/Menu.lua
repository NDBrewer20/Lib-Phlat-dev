local lib = LibStub("LibPhlat-1.0")
if not lib.loading then return end

lib:Module("Menu", function(UI, P, config)
	local Resolve = P.Resolve
	local Merge = P.Merge
	local Clamp = P.Clamp
	local state = P.state
	local Fill = P.Fill
	local Chrome = P.Chrome
	local StyleFor = P.StyleFor
	local TextWidth = P.TextWidth
	local BODY = P.BODY
	local Base = P.Base
	local HoverScripts = P.HoverScripts
	local StateColor = P.StateColor
	local FindItem = P.FindItem
	--------------------------------------------------------------------------------
	-- Menus
	--
	-- one engine behind every dropdown, menu button and right click menu. an item
	-- can have any of:
	--
	--   text, value, func(value, item, mouseButton), submenu (list or function),
	--   header, separator, checked, radio, disabled, hidden, icon, iconAtlas,
	--   iconCoords, color, note, tooltip, tooltipTitle, tooltipFunc(tooltip, item),
	--   keepOpen, selectedText (what a dropdown shows once it's picked), searchText
	--
	-- hovering an item with a submenu opens it off the side, any depth, and
	-- clicking still picks the item itself.
	--------------------------------------------------------------------------------

	local MENU_STRATA = "FULLSCREEN_DIALOG"
	local FULL_COORDS = { 0, 1, 0, 1 }

	-- the item holding a value, submenus included. builder functions are skipped
	-- so drawing one label doesn't build every submenu.
	local function FindItem(items, value)
		if type(items) ~= "table" then return end
		for i = 1, #items do
			local item = items[i]
			if item.value == value and not item.header and not item.separator then return item end
			if type(item.submenu) == "table" then
				local found = FindItem(item.submenu, value)
				if found then return found end
			end
		end
	end
	UI.FindItem = FindItem

	local Menu = {}
	Menu.__index = Menu
	UI.MenuProto = Menu

	-- hidden items dropped, and a search flattens table submenus into one list
	-- with where each came from as its note.
	local function Collect(out, items, query, parentText, depth)
		for i = 1, #items do
			local item = items[i]
			if not item.header and not item.separator and not Resolve(item.hidden, item) then
				local text = item.searchText or item.text
				if text and tostring(text):lower():find(query, 1, true) then
					if parentText and not item.note then
						out[#out + 1] = setmetatable({ note = parentText }, { __index = item })
					else
						out[#out + 1] = item
					end
				end
				if type(item.submenu) == "table" and depth < 4 then
					Collect(out, item.submenu, query, item.text, depth + 1)
				end
			end
		end
	end

	local function Visible(panel, items)
		local out = panel.visible or {}
		wipe(out)
		panel.visible = out

		local query = panel.depth == 1 and panel.menu.query
		if query then
			Collect(out, items, query, nil, 0)
		else
			for i = 1, #items do
				local item = items[i]
				if not Resolve(item.hidden, item) then out[#out + 1] = item end
			end
		end
		return out
	end

	function Menu:CheckedFor(item)
		if item.header or item.separator then return nil end
		if item.checked ~= nil then return Resolve(item.checked, item) end
		if self.Checked then return self.Checked(item) end
	end

	local EntryClick, EntryEnter, EntryLeave

	local function NewEntry(panel)
		local s = panel.menu.style
		local entry = CreateFrame("Button", nil, panel)
		entry.panel = panel

		entry.highlight = entry:CreateTexture(nil, "HIGHLIGHT")
		entry.highlight:SetAllPoints()
		UI.Paint(entry.highlight, s.highlight, "fill")

		entry.label = UI.Text(entry, "", s.font)
		-- rows are one line high, so long text gets cut off instead of spilling over.
		entry.label:SetWordWrap(false)

		entry:SetScript("OnClick", EntryClick)
		entry:SetScript("OnEnter", EntryEnter)
		entry:SetScript("OnLeave", EntryLeave)
		return entry
	end

	local function HideParts(entry)
		if entry.check then entry.check:Hide() end
		if entry.dot then entry.dot:Hide() end
		if entry.icon then entry.icon:Hide() end
		if entry.note then entry.note:Hide() end
		if entry.arrow then entry.arrow:Hide() end
	end

	-- lays one row out and says how wide it would like to be.
	local function StyleEntry(entry, item, ticks, icons)
		local menu = entry.panel.menu
		local s = menu.style

		entry.item, entry.value, entry.submenu = item, item.value, item.submenu

		if item.separator then
			if not entry.line then
				entry.line = entry:CreateTexture(nil, "ARTWORK")
				entry.line:SetHeight(1)
				entry.line:SetPoint("LEFT", 4, 0)
				entry.line:SetPoint("RIGHT", -4, 0)
			end
			UI.Paint(entry.line, s.separator, "fill")
			entry.line:Show()
			entry.label:Hide()
			HideParts(entry)
			entry:EnableMouse(false)
			entry.wants = 0
			return
		end

		if entry.line then entry.line:Hide() end
		entry.label:Show()

		local header = item.header == true
		local disabled = not header and Resolve(item.disabled, item) and true or false
		entry.disabled = disabled
		entry:EnableMouse(not header)
		entry.highlight:SetAlpha(disabled and 0 or 1)

		local x = 7
		local checked = menu:CheckedFor(item)

		-- a tick at the front, and once any row has one every row leaves the room
		-- so the text lines up.
		if ticks and not header then
			if item.radio then
				if not entry.dot then
					entry.dot = entry:CreateTexture(nil, "ARTWORK")
					entry.dot:SetSize(6, 6)
					entry.dot:SetPoint("LEFT", 8, 0)
				end
				UI.Paint(entry.dot, s.check, "fill")
				entry.dot:SetShown(checked == true)
				if entry.check then entry.check:Hide() end
			else
				if checked and not entry.check then
					entry.check = UI.Check(entry, 10, s.check)
					entry.check:SetPoint("LEFT", 6, 0)
				end
				if entry.check then entry.check:SetShown(checked == true) end
				if entry.dot then entry.dot:Hide() end
			end
			x = 22
		else
			if entry.check then entry.check:Hide() end
			if entry.dot then entry.dot:Hide() end
		end

		if icons and not header then
			if not entry.icon then entry.icon = entry:CreateTexture(nil, "ARTWORK") end
			local icon = entry.icon
			icon:SetSize(s.iconSize, s.iconSize)
			icon:ClearAllPoints()
			icon:SetPoint("LEFT", x, 0)
			if item.iconAtlas then
				icon:SetAtlas(item.iconAtlas)
			else
				icon:SetTexture(item.icon)
				icon:SetTexCoord(unpack(item.iconCoords or FULL_COORDS))
			end
			icon:SetDesaturated(disabled)
			icon:SetShown(item.icon ~= nil or item.iconAtlas ~= nil)
			x = x + s.iconSize + 5
		elseif entry.icon then
			entry.icon:Hide()
		end

		local right = 7
		if item.submenu and not header then
			if not entry.arrow then
				entry.arrow = UI.Chevron(entry, s.arrowSize, s.dim, "right")
				entry.arrow:SetPoint("RIGHT", -5, 0)
			end
			entry.arrow:Show()
			right = 16
		elseif entry.arrow then
			entry.arrow:Hide()
		end

		if item.note and not header then
			if not entry.note then
				entry.note = UI.Text(entry, "", s.font, s.dim)
				entry.note:SetJustifyH("RIGHT")
				entry.note:SetWordWrap(false)
			end
			entry.note:SetText(Resolve(item.note, item))
			entry.note:ClearAllPoints()
			entry.note:SetPoint("RIGHT", -right, 0)
			entry.note:Show()
			right = right + TextWidth(entry.note) + 8
		elseif entry.note then
			entry.note:Hide()
		end

		entry.label:SetPoint("LEFT", x, 0)
		entry.label:SetPoint("RIGHT", -right, 0)
		entry.label:SetText(Resolve(item.text, item) or "")

		local color = s.text
		if header then
			color = s.header
		elseif disabled then
			color = s.disabledText
		elseif item.color then
			color = item.color
		elseif checked == false and (item.checked == false or menu.dimUnchecked) then
			-- unticked text is dimmed.
			color = s.dim
		end
		UI.Paint(entry.label, color, "text")

		entry.wants = x + TextWidth(entry.label) + right
	end

	local function FillPanel(panel, items)
		local menu = panel.menu
		local s = menu.style
		local visible = Visible(panel, items)
		panel.items = items

		local ticks, icons = false, false
		for i = 1, #visible do
			local item = visible[i]
			if not item.header and not item.separator then
				if menu:CheckedFor(item) ~= nil then ticks = true end
				if item.icon or item.iconAtlas then icons = true end
			end
		end

		-- long lists draw a window of rows and scroll it with the wheel.
		local count = #visible
		local maxRows = menu.opts.maxRows
		local shown = count
		if maxRows and count > maxRows then
			shown = maxRows
			panel.offset = Clamp(panel.offset or 0, 0, count - maxRows)
		else
			panel.offset = 0
		end

		local y = s.pad
		if panel.searchBox and panel.searchBox:IsShown() then
			y = y + s.searchHeight + 4
		end

		local widest = 0
		for i = 1, math.max(shown, #panel.entries) do
			local entry = panel.entries[i]
			local item = i <= shown and visible[panel.offset + i]

			if item then
				if not entry then
					entry = NewEntry(panel)
					panel.entries[i] = entry
				end

				local height = item.separator and s.separatorHeight or s.rowHeight
				entry:ClearAllPoints()
				entry:SetPoint("TOPLEFT", s.pad, -y)
				entry:SetPoint("TOPRIGHT", -s.pad, -y)
				entry:SetHeight(height)
				entry.y, entry.index = y, i

				StyleEntry(entry, item, ticks, icons)
				if entry.wants > widest then widest = entry.wants end
				entry:Show()
				y = y + height
			elseif entry then
				entry.item = nil
				entry:Hide()
			end
		end

		-- says so when a search or a list comes back empty.
		local emptyText = count == 0 and (menu.query and (menu.opts.noMatchText or "No matches") or menu.opts.emptyText)
		if emptyText then
			if not panel.empty then
				panel.empty = UI.Text(panel, "", s.font, s.dim)
				panel.empty:SetWordWrap(false)
			end
			panel.empty:ClearAllPoints()
			panel.empty:SetPoint("TOPLEFT", s.pad + 7, -y - 4)
			panel.empty:SetText(emptyText)
			panel.empty:Show()
			widest = math.max(widest, TextWidth(panel.empty) + 14)
			y = y + s.rowHeight
		elseif panel.empty then
			panel.empty:Hide()
		end

		if shown < count then
			if not panel.thumb then
				panel.thumb = panel:CreateTexture(nil, "OVERLAY")
				panel.thumb:SetWidth(2)
				UI.Paint(panel.thumb, "thumb", "fill")
			end
			local top = s.pad + (panel.searchBox and panel.searchBox:IsShown() and s.searchHeight + 4 or 0)
			local track = shown * s.rowHeight
			local size = math.max(10, track * shown / count)
			panel.thumb:ClearAllPoints()
			panel.thumb:SetPoint("TOPRIGHT", -1, -top - (track - size) * panel.offset / (count - shown))
			panel.thumb:SetHeight(size)
			panel.thumb:Show()
		elseif panel.thumb then
			panel.thumb:Hide()
		end

		panel.widest = widest + s.pad * 2
		panel:SetHeight(math.max(8, y + s.pad))
	end

	local function PanelWheel(panel, delta)
		local maxRows = panel.menu.opts.maxRows
		if not maxRows or not panel.visible or #panel.visible <= maxRows then return end
		panel.offset = (panel.offset or 0) - delta
		panel.menu:CloseFrom(panel.depth + 1)
		FillPanel(panel, panel.items)
	end

	-- stays open while the mouse is on it, the row that opened it, or anything
	-- opened off it. a few checks a second, and only while one is showing.
	local function FlyoutWatch(panel, elapsed)
		panel.since = (panel.since or 0) + elapsed
		if panel.since < 0.1 then return end
		panel.since = 0

		local panels = panel.menu.panels
		for depth = panel.depth, #panels do
			local other = panels[depth]
			if other:IsShown() and other:IsMouseOver() then return end
		end
		if panel.owner and panel.owner:IsMouseOver() then return end
		panel.menu:CloseFrom(panel.depth)
	end

	local function NewPanel(menu, depth, parent)
		local s = menu.style
		local panel = CreateFrame("Frame", nil, parent)
		panel:SetFrameStrata(MENU_STRATA)
		panel:EnableMouse(true)
		panel:EnableMouseWheel(true)
		panel:SetScript("OnMouseWheel", PanelWheel)
		Fill(panel, "BACKGROUND", s.bg)
		UI.Border(panel, s.border)
		panel:Hide()

		panel.menu, panel.depth = menu, depth
		panel.entries, panel.offset = {}, 0
		return panel
	end

	-- opts takes style, width ("auto" or a number), flyoutWidth, align ("RIGHT"),
	-- direction ("UP" or "AUTO"), maxRows, search (true, or a count of items it
	-- takes to show one), searchText, emptyText, noMatchText and keepOpen.
	function UI.NewMenu(opts)
		opts = opts or {}
		local menu = setmetatable({
			opts = opts,
			panels = {},
			style = UI.Style("menu", opts.style, opts.styleOverrides),
			keepOpen = opts.keepOpen,
		}, Menu)
		return menu
	end

	function Menu:Root()
		local root = self.panels[1]
		if root then return root end

		root = NewPanel(self, 1, UIParent)
		root:SetClampedToScreen(true)
		self.panels[1] = root

		-- clicking anywhere outside the menu closes it.
		local catcher = CreateFrame("Button", nil, UIParent)
		catcher:SetAllPoints(UIParent)
		catcher:SetFrameStrata(MENU_STRATA)
		catcher:RegisterForClicks("AnyUp")
		catcher:Hide()
		catcher:SetScript("OnClick", function() self:Close() end)
		root.catcher = catcher

		root:SetScript("OnShow", function(panel)
			if state.openMenu and state.openMenu ~= self then state.openMenu:Close() end
			state.openMenu = self
			catcher:Show()
			catcher:SetFrameLevel(math.max(1, panel:GetFrameLevel() - 1))
		end)

		root:SetScript("OnHide", function()
			if state.openMenu == self then state.openMenu = nil end
			self:CloseFrom(2)
			catcher:Hide()
			if self.searchBox then
				self.query = nil
				self.searchBox:SetText("")
				self.searchBox:ClearFocus()
			end
			if self.OnClose then self.OnClose(self) end
		end)

		return root
	end

	-- panel for a submenu, one per depth and refilled per row. parented to the
	-- one before it so it sits above the click catcher and closes with it.
	function Menu:Panel(depth)
		local panel = self.panels[depth]
		if panel then return panel end

		panel = NewPanel(self, depth, self:Panel(depth - 1))
		panel:SetScript("OnUpdate", FlyoutWatch)
		self.panels[depth] = panel
		return panel
	end

	function Menu:CloseFrom(depth)
		for index = #self.panels, math.max(depth, 2), -1 do
			local panel = self.panels[index]
			panel.owner, panel.ownerItem = nil, nil
			panel:Hide()
		end
		if depth <= 1 and self.panels[1] then self.panels[1]:Hide() end
	end

	function Menu:Close()
		self:CloseFrom(1)
	end

	function Menu:IsOpen()
		return self.panels[1] ~= nil and self.panels[1]:IsShown()
	end

	-- under a frame, the width of it unless the menu has a width of its own.
	function Menu:AnchorTo(frame, direction)
		local root, opts = self:Root(), self.opts
		local gap = self.style.gap
		direction = direction or opts.direction
		local up = direction == "UP"
		local vpoint, vrelative = up and "BOTTOM" or "TOP", up and "TOP" or "BOTTOM"
		local y = up and gap or -gap

		root:ClearAllPoints()
		if opts.width then
			local side = opts.align == "RIGHT" and "RIGHT" or "LEFT"
			root:SetPoint(vpoint .. side, frame, vrelative .. side, 0, y)
		else
			root:SetPoint(vpoint .. "LEFT", frame, vrelative .. "LEFT", 0, y)
			root:SetPoint(vpoint .. "RIGHT", frame, vrelative .. "RIGHT", 0, y)
		end
		self.anchorFrame = frame
	end

	function Menu:AnchorCursor()
		local root = self:Root()
		local x, y = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		root:ClearAllPoints()
		root:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
		self.anchorFrame = nil
	end

	local function ApplyWidth(menu)
		local root, opts, s = menu.panels[1], menu.opts, menu.style
		local width = opts.width
		if width == "auto" or (not width and not menu.anchorFrame) then
			local floor = math.max(s.minWidth, menu.anchorFrame and menu.anchorFrame:GetWidth() or 0)
			root:SetWidth(Clamp(root.widest or 0, floor, math.max(floor, s.maxWidth)))
		elseif type(width) == "number" then
			root:SetWidth(width)
		end
	end

	local function SearchBox(menu, root)
		if menu.searchBox then return menu.searchBox end
		local s = menu.style

		local box = UI.SearchBox(root, 100, s.searchHeight, {
			placeholder = menu.opts.searchText or "Search",
			onChange = function(text) menu:SetQuery(text) end,
			onEscape = function() menu:Close() end,
			-- return picks the first thing that can be picked.
			onEnter = function()
				for _, item in ipairs(root.visible or {}) do
					if not item.header and not item.separator and not Resolve(item.disabled, item) then
						return menu:Pick(item, "LeftButton")
					end
				end
			end,
		})
		box:SetPoint("TOPLEFT", s.pad, -s.pad)
		box:SetPoint("TOPRIGHT", -s.pad, -s.pad)
		menu.searchBox, root.searchBox = box, box
		return box
	end

	function Menu:SetQuery(text)
		self.query = text and text ~= "" and text:lower() or nil
		local root = self:Root()
		root.offset = 0
		self:CloseFrom(2)
		FillPanel(root, self.items or {})
		ApplyWidth(self)
	end

	-- items is a list or a function returning one, called every time it opens.
	function Menu:Open(items)
		local root = self:Root()
		if items ~= nil then self.source = items end
		self.items = Resolve(self.source) or {}
		root.offset = 0

		local search = self.opts.search
		local useSearch = search == true or (type(search) == "number" and #self.items >= search)
		if useSearch then
			SearchBox(self, root):Show()
		elseif self.searchBox then
			self.searchBox:Hide()
		end

		FillPanel(root, self.items)
		ApplyWidth(self)

		if self.opts.direction == "AUTO" and self.anchorFrame then
			self:AnchorTo(self.anchorFrame, "DOWN")
			root:Show()
			local bottom = root:GetBottom()
			if bottom and bottom < 0 then self:AnchorTo(self.anchorFrame, "UP") end
		else
			root:Show()
		end

		if useSearch and self.opts.searchFocus ~= false then self.searchBox:SetFocus() end
		if self.OnOpen then self.OnOpen(self) end
	end

	function Menu:Toggle(items)
		if self:IsOpen() then self:Close() else self:Open(items) end
	end

	-- new items. an open menu redraws, and flyouts close since their rows moved.
	function Menu:SetItems(items)
		self.source = items
		if not self:IsOpen() then return end
		self.items = Resolve(items) or {}
		self:CloseFrom(2)
		FillPanel(self.panels[1], self.items)
		ApplyWidth(self)
	end

	-- draws what's open again, for ticks that changed under it.
	function Menu:Redraw()
		if not self:IsOpen() then return end
		if type(self.source) == "function" then self.items = self.source() or {} end
		FillPanel(self.panels[1], self.items)
		ApplyWidth(self)

		for depth = 2, #self.panels do
			local panel = self.panels[depth]
			if not panel:IsShown() or not panel.ownerItem then break end
			local items = Resolve(panel.ownerItem.submenu, panel.ownerItem)
			if type(items) ~= "table" then
				self:CloseFrom(depth)
				break
			end
			FillPanel(panel, items)
		end
	end

	function Menu:OpenFlyout(entry)
		local parent = entry.panel
		local depth = parent.depth + 1
		local panel = self.panels[depth]

		-- already open for this row.
		if panel and panel:IsShown() and panel.ownerItem == entry.item then return end

		local items = Resolve(entry.item.submenu, entry.item)
		if type(items) ~= "table" or #items == 0 then return self:CloseFrom(depth) end

		panel = self:Panel(depth)
		self:CloseFrom(depth + 1)
		panel.owner, panel.ownerItem, panel.offset, panel.since = entry, entry.item, 0, 0
		FillPanel(panel, items)

		-- set again every open since the parent's level can change when it shows.
		panel:SetFrameLevel(parent:GetFrameLevel() + 10)

		local s = self.style
		local width = self.opts.flyoutWidth
			or Clamp(panel.widest, math.max(s.minWidth, self.panels[1]:GetWidth()), math.max(s.minWidth, s.maxWidth))
		panel:SetWidth(width)

		-- level with its row, and out the other side if there's no room.
		local y = -(entry.y - s.pad)
		local side = parent.side or "RIGHT"
		local screen = UIParent:GetRight() or 0
		if side == "RIGHT" and (parent:GetRight() or 0) + width > screen then side = "LEFT" end
		if side == "LEFT" and (parent:GetLeft() or 0) - width < 0 then side = "RIGHT" end
		panel.side = side

		panel:ClearAllPoints()
		if side == "RIGHT" then
			panel:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, y)
		else
			panel:SetPoint("TOPRIGHT", parent, "TOPLEFT", 0, y)
		end
		panel:Show()

		-- slide it back up if it runs off the bottom of the screen.
		local bottom = panel:GetBottom()
		if bottom and bottom < 0 then
			local point, relative, relativePoint, x = panel:GetPoint(1)
			panel:SetPoint(point, relative, relativePoint, x, y - bottom)
		end
	end

	function Menu:Pick(item, mouseButton)
		local keep = item.keepOpen
		if keep == nil then
			if self.owner then keep = self.owner.keepOpen else keep = self.keepOpen end
		end

		if not keep then self:Close() end
		if item.func then item.func(item.value, item, mouseButton) end
		if self.OnPick then self.OnPick(item.value, item, keep) end
		if keep then self:Redraw() end
	end

	EntryClick = function(entry, mouseButton)
		local item = entry.item
		if not item or entry.disabled or item.header or item.separator then return end
		entry.panel.menu:Pick(item, mouseButton)
	end

	EntryEnter = function(entry)
		local item, panel = entry.item, entry.panel
		if not item then return end

		local menu = panel.menu
		if item.submenu and not entry.disabled then
			menu:OpenFlyout(entry)
		else
			menu:CloseFrom(panel.depth + 1)
		end

		if item.tooltip or item.tooltipTitle or item.tooltipFunc then
			GameTooltip:SetOwner(entry, item.submenu and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
			if item.tooltipFunc then
				if item.tooltipFunc(GameTooltip, item) == false then return GameTooltip:Hide() end
			else
				GameTooltip:AddLine(item.tooltipTitle or Resolve(item.text, item) or "", 1, 1, 1)
				if item.tooltip then
					GameTooltip:AddLine(Resolve(item.tooltip, item), BODY[1], BODY[2], BODY[3], true)
				end
			end
			GameTooltip:Show()
			entry.tipShown = true
		end
	end

	EntryLeave = function(entry)
		if entry.tipShown then
			entry.tipShown = nil
			GameTooltip:Hide()
		end
	end

	--------------------------------------------------------------------------------
	-- Dropdown
	--------------------------------------------------------------------------------

	-- width can be skipped for opts. opts takes style, menuStyle, menuWidth, align,
	-- direction, maxRows, search, placeholder, label(value, items, dropdown),
	-- multi, summary(values, items), showSelected, keepOpen, items, value,
	-- onSelect(value, item) and tooltip. anything in NewMenu's opts goes too.
	function UI.Dropdown(parent, width, opts)
		if type(width) == "table" then opts, width = width, nil end
		opts = opts or {}
		local style = StyleFor("dropdown", opts)

		local dd = CreateFrame("Button", nil, parent)
		dd:SetSize(width or style.width, style.height)
		Base(dd, opts)
		dd.style = style
		Chrome(dd, style)

		dd.label = UI.Text(dd, "", style.font)
		dd.placeholder = opts.placeholder
		dd.multi = opts.multi
		dd.keepOpen = opts.keepOpen or opts.multi
		dd.showSelected = opts.showSelected
		dd.values = {}
		dd.OnSelect = opts.onSelect

		local menu = UI.NewMenu({
			style = opts.menuStyle, styleOverrides = opts.menuStyleOverrides,
			width = opts.menuWidth, flyoutWidth = opts.flyoutWidth, align = opts.align,
			direction = opts.direction, maxRows = opts.maxRows, search = opts.search,
			searchText = opts.searchText, searchFocus = opts.searchFocus,
			emptyText = opts.emptyText, noMatchText = opts.noMatchText,
		})
		menu.owner = dd
		menu.dimUnchecked = dd.multi
		dd.menu = menu

		dd.list = menu:Root()
		dd.entries = dd.list.entries
		dd.flyout = menu:Panel(2)
		menu:AnchorTo(dd)

		menu.Checked = function(item)
			if dd.multi then return dd.values[item.value] == true end
			if dd.showSelected then return item.value == dd.value end
		end

		-- keepOpen is for lists that pick several. the caller owns the label there,
		-- so it isn't replaced with the entry that was clicked.
		menu.OnPick = function(value, item, keep)
			if dd.multi then
				if item.checked == nil and item.toggle ~= false and not item.func then
					dd.values[value] = not dd.values[value] or nil
					dd:UpdateLabel()
				end
			elseif not keep then
				dd:SetValue(value)
			end
			if dd.OnSelect then dd.OnSelect(value, item, dd.multi and dd.values or nil) end
		end

		menu.OnClose = function() dd:Refresh() end
		menu.OnOpen = function() dd:Refresh() end

		dd.items = {}

		local function Items()
			if dd.items and dd.source == dd.items then return dd.items end
			return Resolve(dd.source) or {}
		end

		local function Place()
			local s = dd.style
			dd.label:ClearAllPoints()
			dd.label:SetPoint("LEFT", s.padLeft, 0)
			dd.label:SetPoint("RIGHT", -s.padRight, 0)
			dd.label:SetJustifyH(s.justify)
			dd.label:SetWordWrap(s.wrap ~= false)

			if s.chevron then
				if not dd.chevron then dd.chevron = UI.Chevron(dd, s.chevronSize, s.chevronColor) end
				dd.chevron:SetGlyphSize(s.chevronSize)
				dd.chevron:ClearAllPoints()
				dd.chevron:SetPoint("RIGHT", -(s.chevronInset or math.max(2, (s.padRight - s.chevronSize) / 2 + 3)), 0)
				dd.chevron:Show()
			elseif dd.chevron then
				dd.chevron:Hide()
			end
		end

		function dd:Refresh()
			local s = self.style
			local color = StateColor(self, s, self.showingPlaceholder and s.placeholderText or s.text)
			UI.Paint(self.label, color, "text")

			if self.chevron then
				self.chevron:SetColor(self:IsEnabled() and (self.hovered and s.hoverText or s.chevronColor) or s.disabledText)
				if s.flipChevron then self.chevron:SetFacing(menu:IsOpen() and "up" or "down") end
			end
			if self.rule and s.hoverRule then
				UI.Paint(self.rule, (self.hovered or menu:IsOpen()) and s.hoverRule or s.rule, "fill")
			end
		end

		function dd:UpdateLabel()
			local text
			if self.fixedLabel then
				text = self.fixedLabel
			elseif opts.label then
				text = opts.label(self.multi and self.values or self.value, Items(), self)
			elseif self.multi then
				if opts.summary then
					text = opts.summary(self.values, Items(), self)
				else
					local count, last = 0, nil
					for value in pairs(self.values) do
						count, last = count + 1, value
					end
					if count == 1 then
						local item = FindItem(Items(), last)
						text = item and (item.selectedText or item.text) or tostring(last)
					elseif count > 1 then
						text = ("%d selected"):format(count)
					end
				end
			else
				local item = FindItem(Items(), self.value)
				text = item and (item.selectedText or item.text) or (self.value and tostring(self.value))
			end

			self.showingPlaceholder = text == nil or text == ""
			self.label:SetText(self.showingPlaceholder and (self.placeholder or "") or text)
			self:Refresh()
		end

		function dd:SetItems(items)
			self.source = items
			if type(items) == "table" then self.items = items end
			menu:SetItems(items)
		end

		function dd:SetValue(value)
			self.value = value
			self:UpdateLabel()
		end

		function dd:GetValue()
			return self.value
		end

		-- for multi, a set of value = true. copied, so the dropdown can toggle it.
		function dd:SetValues(values)
			wipe(self.values)
			for value, on in pairs(values or {}) do
				if on then self.values[value] = true end
			end
			self:UpdateLabel()
			menu:Redraw()
		end

		function dd:GetValues()
			return self.values
		end

		-- fixed text on the button whatever is picked. nil hands it back.
		function dd:SetLabel(text)
			self.fixedLabel = text
			self:UpdateLabel()
		end

		function dd:SetPlaceholder(text)
			self.placeholder = text
			self:UpdateLabel()
		end

		function dd:Open()
			if self:IsEnabled() then menu:Open(self.source) end
		end

		function dd:Close() menu:Close() end
		function dd:IsOpen() return menu:IsOpen() end

		function dd:Toggle()
			if menu:IsOpen() then menu:Close() else self:Open() end
		end

		function dd:SetStyle(newStyle, overrides)
			self.style = UI.Style("dropdown", newStyle, overrides)
			Chrome(self, self.style)
			UI.SetFontTemplate(self.label, self.style.font)
			self:SetHeight(self.style.height)
			Place()
			self:Refresh()
		end

		dd:SetScript("OnClick", dd.Toggle)
		dd:SetScript("OnHide", function() menu:Close() end)
		dd:SetScript("OnDisable", function(self)
			menu:Close()
			self:Refresh()
		end)
		dd:SetScript("OnEnable", dd.Refresh)
		HoverScripts(dd)

		Place()
		if opts.items then dd:SetItems(opts.items) end
		if opts.values then dd:SetValues(opts.values) end
		dd:SetValue(opts.value)
		return dd
	end

	-- a button that opens a menu and keeps its own text.
	function UI.MenuButton(parent, text, width, opts)
		opts = Merge({ style = "button" }, opts)
		local dd = UI.Dropdown(parent, width, opts)
		dd:SetLabel(text)
		return dd
	end

	-- a menu at the cursor, or under opts.anchor. one per style, reused.
	local contextMenus = {}

	function UI.ContextMenu(items, onSelect, opts)
		opts = opts or {}
		local key = type(opts.style) == "string" and opts.style or "default"
		local menu = contextMenus[key]
		if not menu then
			menu = UI.NewMenu({ style = opts.style })
			contextMenus[key] = menu
		end

		menu.opts = Merge({ style = opts.style }, opts)
		menu.keepOpen = opts.keepOpen
		menu.Checked = opts.checked
		menu.OnPick = function(value, item) if onSelect then onSelect(value, item) end end

		if opts.anchor then menu:AnchorTo(opts.anchor) else menu:AnchorCursor() end
		menu:Open(items)
		return menu
	end

	-- clicking the frame opens a menu under it. opts.mouseButton picks which button,
	-- opts.atCursor opens it at the cursor instead. hooked, so its own clicks stay.
	function UI.AttachMenu(frame, items, onSelect, opts)
		opts = opts or {}
		local menu = UI.NewMenu(opts)
		menu.keepOpen = opts.keepOpen
		menu.Checked = opts.checked
		menu.OnPick = function(value, item) if onSelect then onSelect(value, item, frame) end end

		local wanted = opts.mouseButton or "LeftButton"
		frame:EnableMouse(true)
		frame:HookScript("OnMouseUp", function(self, mouseButton)
			if mouseButton ~= wanted or not self:IsMouseOver() then return end
			if self.IsEnabled and not self:IsEnabled() then return end
			if menu:IsOpen() then return menu:Close() end

			if opts.atCursor then menu:AnchorCursor() else menu:AnchorTo(self) end
			menu:Open(items)
		end)
		return menu
	end

	function UI.AttachContextMenu(frame, items, onSelect, opts)
		return UI.AttachMenu(frame, items, onSelect, Merge({ mouseButton = "RightButton", atCursor = true }, opts))
	end

	P.FindItem = FindItem
end)
