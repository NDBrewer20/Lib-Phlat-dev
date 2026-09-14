local lib = LibStub("LibPhlat-1.0")
if not lib.loading then return end

lib:Module("Lists", function(UI, P, config)
	local Resolve = P.Resolve
	local Clamp = P.Clamp
	local WEAK = P.WEAK
	local StyleFor = P.StyleFor
	local Chrome = P.Chrome
	local Fill = P.Fill
	local Base = P.Base
	local TextWidth = P.TextWidth
	local SelectedWash = P.SelectedWash
	local BODY = P.BODY

	P.Defaults(UI, "table", {
		default = {
			rowHeight = 20, headerHeight = 20, headerBg = "titlebar", headerFont = "caption",
			headerText = "dim", headerActive = "text", font = "small", text = "text",
			cellPad = 6, divider = "line", sortSize = 8,
		},
	})

	P.Defaults(UI, "grid", {
		default = {
			cellSize = 36, spacing = 4, bg = "black", border = "border", highlight = "accent:0.30",
			selectedBorder = "accent", inset = 2, zoom = 0.08,
		},
	})

	P.Defaults(UI, "nav", {
		tree = {
			rowHeight = 20, categoryHeight = 22, indent = 12, padLeft = 6, top = 0,
			marker = false, font = "small", text = "text", activeText = "text",
			selected = "accent:0.25", categoryFont = "caption", upper = false,
		},
	})

	local function ShowItemTooltip(owner, entry)
		if not entry or not (entry.tooltip or entry.tooltipTitle or entry.tooltipFunc) then return end
		GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
		if entry.tooltipFunc then
			if entry.tooltipFunc(GameTooltip, entry) == false then return GameTooltip:Hide() end
		else
			GameTooltip:AddLine(entry.tooltipTitle or Resolve(entry.text, entry) or "", 1, 1, 1)
			if entry.tooltip then GameTooltip:AddLine(Resolve(entry.tooltip, entry), BODY[1], BODY[2], BODY[3], true) end
		end
		GameTooltip:Show()
		owner.tipShown = true
	end

	local function HideItemTooltip(owner)
		if owner.tipShown then
			owner.tipShown = nil
			GameTooltip:Hide()
		end
	end

	--------------------------------------------------------------------------------
	-- List
	--
	-- rows are made once and reused. Build(row) makes an empty one, Fill(row, entry,
	-- index) draws an entry into it. virtual lists only make the rows that fit on
	-- screen and redraw them as it scrolls, so a few thousand entries cost nothing.
	--------------------------------------------------------------------------------

	local List = {}
	List.__index = List
	UI.ListProto = List

	-- every list, so a row height change reaches the ones on screen.
	local lists = setmetatable({}, WEAK)
	local rowScale = 1

	function UI.RowScale()
		return rowScale
	end

	function UI.SetRowScale(scale)
		rowScale = scale or 1
		for list in pairs(lists) do list:Restyle() end
	end

	-- a plain row when no Build is given: icon, label and a note on the right.
	local function DefaultBuild(row)
		local s = row.list.style
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetPoint("LEFT", s.padding, 0)
		row.label = UI.Text(row, "", s.font)
		row.label:SetWordWrap(false)
		row.note = UI.Text(row, "", s.font, "dim")
		row.note:SetPoint("RIGHT", -s.padding, 0)
		row.note:SetJustifyH("RIGHT")
	end

	local function DefaultFill(row, entry)
		local s = row.list.style
		local heading = entry.heading
		if row.bg then row.bg:SetShown(not heading) end

		local size = math.min(s.iconSize, row:GetHeight() - 2)
		local hasIcon = not heading and (entry.icon or entry.iconAtlas)
		row.icon:SetSize(size, size)
		if entry.iconAtlas then
			row.icon:SetAtlas(entry.iconAtlas)
		elseif entry.icon then
			row.icon:SetTexture(entry.icon)
			row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
		row.icon:SetShown(hasIcon and true or false)

		row.label:ClearAllPoints()
		row.label:SetPoint("LEFT", hasIcon and s.padding + size + 6 or s.padding, 0)
		row.label:SetPoint("RIGHT", row.note, "LEFT", -6, 0)
		UI.SetFontTemplate(row.label, heading and s.headingFont or s.font)
		row.label:SetText(Resolve(entry.text or entry.label, entry) or "")
		UI.Paint(row.label, heading and s.heading or entry.color or s.text, "text")

		row.note:SetText(not heading and Resolve(entry.note, entry) or "")
	end

	-- UI.List(parent, width, height, rowHeight, Build, Fill), or UI.List(parent, opts)
	-- with width, height, rowHeight, Build, Fill, style, virtual, onClick(entry,
	-- row, mouseButton), isSelected(entry) and reorder(from, to) for drag to reorder.
	function UI.List(parent, width, height, rowHeight, Build, Fill, opts)
		if type(width) == "table" then
			opts = width
			width, height, rowHeight, Build, Fill = opts.width, opts.height, opts.rowHeight, opts.Build, opts.Fill
		end
		opts = opts or {}

		local list = setmetatable({
			parent = parent,
			opts = opts,
			style = StyleFor("list", opts),
			-- what the list asked for, so the scale always applies to that.
			base = rowHeight or 20,
			Build = Build or (not Fill and DefaultBuild) or nil,
			Fill = Fill or DefaultFill,
			virtual = opts.virtual,
			rows = {},
			count = 0,
			entries = {},
		}, List)
		list.rowHeight = math.floor(list.base * rowScale + 0.5)
		lists[list] = true

		list.area = UI.ScrollArea(parent, width, height, { style = opts.scrollStyle })
		list.area:SetPoint("TOPLEFT")
		list.area.OnScroll = function()
			if list.virtual then list:Draw() end
		end
		return list
	end

	local function Step(list)
		return list.rowHeight + list.style.spacing
	end

	local function RowClick(row, mouseButton)
		local list, entry = row.list, row.entry
		if not entry or entry.heading then return end
		if list.opts.onClick then list.opts.onClick(entry, row, mouseButton) end
	end

	local function RowEnter(row)
		local list = row.list
		if list.opts.onEnter then list.opts.onEnter(row.entry, row) end
		ShowItemTooltip(row, row.entry)
	end

	local function RowLeave(row)
		local list = row.list
		if list.opts.onLeave then list.opts.onLeave(row.entry, row) end
		HideItemTooltip(row)
	end

	-- dragging a row shows where it would land, and letting go hands both indexes over.
	local function DropIndex(list)
		local content = list.area.content
		local _, cursorY = GetCursorPosition()
		cursorY = cursorY / content:GetEffectiveScale()
		local y = (content:GetTop() or 0) - cursorY
		return Clamp(math.floor(y / Step(list) + 0.5) + 1, 1, #list.entries + 1)
	end

	local function DragStart(row)
		local list = row.list
		if not row.index or not row.entry or row.entry.heading then return end
		list.dragFrom = row.index

		if not list.dropLine then
			list.dropLine = list.area.content:CreateTexture(nil, "OVERLAY")
			list.dropLine:SetHeight(2)
			UI.Paint(list.dropLine, "accent", "fill")
		end

		list.area:SetScript("OnUpdate", function()
			local to = DropIndex(list)
			local y = (to - 1) * Step(list) - list.style.spacing / 2
			list.dropLine:ClearAllPoints()
			list.dropLine:SetPoint("TOPLEFT", 0, -y)
			list.dropLine:SetPoint("TOPRIGHT", 0, -y)
			list.dropLine:Show()
		end)
	end

	local function DragStop(row)
		local list = row.list
		list.area:SetScript("OnUpdate", nil)
		if list.dropLine then list.dropLine:Hide() end

		local from = list.dragFrom
		list.dragFrom = nil
		if not from then return end

		local to = DropIndex(list)
		if to > from then to = to - 1 end
		if to ~= from and list.opts.reorder then list.opts.reorder(from, to) end
	end

	function List:Row(index)
		local row = self.rows[index]
		if row then return row end

		local s = self.style
		row = CreateFrame("Button", nil, self.area.content)
		row.list = self
		row:SetHeight(self.rowHeight)
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

		if s.bg then row.bg = Fill(row, "BACKGROUND", s.bg) end
		if s.highlight then UI.Paint(row:CreateTexture(nil, "HIGHLIGHT"), s.highlight, "fill"):SetAllPoints() end

		-- the stripe down one edge is how a row says it's the selected one.
		if s.mark then
			row.mark = row:CreateTexture(nil, "ARTWORK")
			local side = s.markSide or "LEFT"
			row.mark:SetPoint("TOP" .. side)
			row.mark:SetPoint("BOTTOM" .. side)
			row.mark:SetWidth(s.markSize)
			UI.Paint(row.mark, s.mark, "fill")
			row.mark:Hide()
		end

		row:SetScript("OnClick", RowClick)
		row:SetScript("OnEnter", RowEnter)
		row:SetScript("OnLeave", RowLeave)

		if self.opts.reorder then
			row:RegisterForDrag("LeftButton")
			row:SetScript("OnDragStart", DragStart)
			row:SetScript("OnDragStop", DragStop)
		end

		if self.Build then self.Build(row) end
		self.rows[index] = row
		return row
	end

	local function Place(list, row, index)
		local y = -(index - 1) * Step(list)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, y)
		row:SetPoint("TOPRIGHT", 0, y)
	end

	local function DrawRow(list, row, entry, index)
		row.entry, row.index = entry, index
		list.Fill(row, entry, index)

		local selected = list.IsSelected and list.IsSelected(entry) or false
		if row.mark then row.mark:SetShown(selected) end
		if list.style.selected then
			row.selectedState = selected
			SelectedWash(row, list.style.selected)
		end
		row:Show()
	end

	-- draws what the list was last given, only the rows on screen when virtual.
	function List:Draw()
		local entries = self.entries
		local count = #entries
		local step = Step(self)

		if not self.virtual then
			for index = 1, math.max(count, self.count) do
				local entry = entries[index]
				if entry then
					local row = self:Row(index)
					Place(self, row, index)
					DrawRow(self, row, entry, index)
				elseif self.rows[index] then
					self.rows[index].entry = nil
					self.rows[index]:Hide()
				end
			end
			self.count = count
			return
		end

		local offset, _, view = self.area:GetScroll()
		local first = math.floor(offset / step) + 1
		local needed = math.ceil(view / step) + 1

		for slot = 1, math.max(needed, #self.rows) do
			local index = first + slot - 1
			local entry = slot <= needed and entries[index]
			if entry then
				local row = self:Row(slot)
				Place(self, row, index)
				DrawRow(self, row, entry, index)
			elseif self.rows[slot] then
				self.rows[slot].entry = nil
				self.rows[slot]:Hide()
			end
		end
		self.count = count
	end

	-- entries is whatever Fill understands. IsSelected decides which row wears the stripe.
	function List:Update(entries, IsSelected)
		self.entries = entries or {}
		self.IsSelected = IsSelected or self.opts.isSelected
		self.area.content:SetHeight(math.max(1, #self.entries * Step(self)))
		self.area:Update()
		self:Draw()
	end

	-- redraws the marks and rows without new entries.
	function List:Refresh()
		self:Draw()
	end

	-- the row height changed under it, so every row goes back where it belongs.
	function List:Restyle()
		self.rowHeight = math.floor(self.base * rowScale + 0.5)
		for _, row in pairs(self.rows) do row:SetHeight(self.rowHeight) end
		self:Update(self.entries, self.IsSelected)
	end

	function List:Resize(width, height)
		self.area:Resize(width, height)
		self.area:Update()
		if self.virtual then self:Draw() end
	end

	-- puts the first entry Match accepts on screen.
	function List:Reveal(Match)
		for index, entry in ipairs(self.entries) do
			if Match(entry) then
				local step = Step(self)
				local offset, _, view = self.area:GetScroll()
				local top = (index - 1) * step
				if top < offset or top + step > offset + view then self.area:ScrollTo(top) end
				return index
			end
		end
	end

	function List:SetPoint(...) self.area:SetPoint(...) end
	function List:ClearAllPoints() self.area:ClearAllPoints() end
	function List:SetShown(shown) self.area:SetShown(shown) end
	function List:Show() self.area:Show() end
	function List:Hide() self.area:Hide() end

	--------------------------------------------------------------------------------
	-- Tree
	--
	-- nested nodes that fold. nodes have key (or value), text, children, category
	-- (a heading that only folds), icon, badge, disabled, tooltip, expanded and
	-- selectable. the nav style is a settings sidebar, tree is a compact file tree.
	--------------------------------------------------------------------------------

	-- opts takes style, items, value, collapsed (a table to keep folded keys in),
	-- startCollapsed, onSelect(key, node) and onToggle(key, collapsed). a height
	-- puts it in a scroll area.
	function UI.Tree(parent, width, height, opts)
		if type(height) == "table" then opts, height = height, nil end
		opts = opts or {}
		local style = StyleFor("nav", opts)

		local tree = CreateFrame("Frame", nil, parent)
		tree:SetSize(width, height or 1)
		Base(tree, opts)
		tree.style = style
		tree.collapsed = opts.collapsed or {}
		tree.rows, tree.visible, tree.depths = {}, {}, {}
		tree.parents, tree.nodes = {}, {}
		tree.OnSelect, tree.OnToggle = opts.onSelect, opts.onToggle

		local holder = tree
		if height then
			tree.area = UI.ScrollArea(tree, width, height, { style = opts.scrollStyle })
			tree.area:SetPoint("TOPLEFT")
			holder = tree.area.content
		end
		local rowWidth = height and holder:GetWidth() or width

		local function Key(node)
			if node.key ~= nil then return node.key end
			return node.value
		end

		local function IsFolded(node)
			local folded = tree.collapsed[Key(node)]
			if folded == nil then folded = node.expanded == false or (opts.startCollapsed and not node.category) end
			return folded and true or false
		end

		-- every node by key and what it hangs off, whether it's folded or not.
		local function Index(nodes, parentKey)
			for _, node in ipairs(nodes or {}) do
				local key = Key(node)
				if key ~= nil then
					tree.nodes[key] = node
					tree.parents[key] = parentKey
				end
				if node.children then Index(node.children, key) end
			end
		end

		local function Walk(nodes, depth)
			for _, node in ipairs(nodes or {}) do
				if not Resolve(node.hidden, node) then
					local index = #tree.visible + 1
					tree.visible[index], tree.depths[index] = node, depth
					if node.children and not IsFolded(node) then Walk(node.children, depth + 1) end
				end
			end
		end

		local RowClick

		local function Row(index)
			local row = tree.rows[index]
			if row then return row end
			local s = tree.style

			row = CreateFrame("Button", nil, holder)
			row:SetWidth(rowWidth)
			row.tree = tree
			row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
			row.highlight:SetAllPoints()

			row.marker = row:CreateTexture(nil, "OVERLAY")
			row.marker:SetPoint("TOPLEFT")
			row.marker:SetPoint("BOTTOMLEFT")

			row.label = UI.Text(row, "", s.font)
			row.label:SetWordWrap(false)
			row.chevron = UI.Chevron(row, s.chevronSize, s.categoryText)
			row.icon = row:CreateTexture(nil, "ARTWORK")

			row:SetScript("OnClick", RowClick)
			row:SetScript("OnEnter", function(self)
				self.hovered = true
				tree:PaintRow(self)
				ShowItemTooltip(self, self.node)
			end)
			row:SetScript("OnLeave", function(self)
				self.hovered = false
				tree:PaintRow(self)
				HideItemTooltip(self)
			end)

			tree.rows[index] = row
			return row
		end

		function tree:PaintRow(row)
			local s, node = self.style, row.node
			if not node then return end
			local key = Key(node)
			local disabled = self.disabled or Resolve(node.disabled, node)

			if node.category then
				local color = row.hovered and s.categoryHover or s.categoryText
				UI.Paint(row.label, disabled and s.disabledText or color, "text")
				row.chevron:SetColor(disabled and "disabled" or color)
				if row.selectedTex then row.selectedTex:Hide() end
				row.marker:Hide()
				return
			end

			local active = key ~= nil and key == self.value
			row.selectedState = active
			SelectedWash(row, s.selected)
			row.marker:SetShown(active and s.marker and true or false)
			local color = disabled and (s.disabledText or "disabled") or (active and s.activeText) or node.color or s.text
			UI.Paint(row.label, color, "text")
			row.chevron:SetColor(row.hovered and s.activeText or "dim")
		end

		function tree:Layout()
			local s = self.style
			wipe(self.visible)
			wipe(self.depths)
			Walk(self.source, 0)

			local y = s.top
			for index, node in ipairs(self.visible) do
				local row = Row(index)
				local depth = self.depths[index]
				local category = node.category
				local height = category and s.categoryHeight or s.rowHeight
				row.node = node

				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", 0, -y)
				row:SetSize(rowWidth, height)
				UI.Paint(row.highlight, category and "hover:0" or s.highlight, "fill")
				row.marker:SetWidth(s.markerSize or 3)
				if s.marker then UI.Paint(row.marker, s.marker, "fill") end

				UI.SetFontTemplate(row.label, category and s.categoryFont or s.font)
				local text = Resolve(node.text, node) or ""
				row.label:SetText(category and s.upper and text:upper() or text)

				local x = s.padLeft + depth * s.indent
				row.label:ClearAllPoints()
				row.chevron:ClearAllPoints()
				row.icon:Hide()

				if category then
					-- a heading's chevron trails its text.
					row.label:SetPoint("BOTTOMLEFT", x, 7)
					row.chevron:SetPoint("LEFT", row.label, "RIGHT", 6, 0)
					row.chevron:SetFacing(IsFolded(node) and "right" or "down")
					row.chevron:SetShown(node.children ~= nil)
				else
					if node.children then
						row.chevron:SetPoint("LEFT", x, 0)
						row.chevron:SetFacing(IsFolded(node) and "right" or "down")
						row.chevron:Show()
						x = x + s.chevronSize + 4
					else
						row.chevron:Hide()
					end
					if node.icon or node.iconAtlas then
						row.icon:SetSize(s.iconSize, s.iconSize)
						row.icon:SetPoint("LEFT", x, 0)
						if node.iconAtlas then row.icon:SetAtlas(node.iconAtlas) else row.icon:SetTexture(node.icon) end
						row.icon:Show()
						x = x + s.iconSize + 5
					end
					row.label:SetPoint("LEFT", x, 0)
				end
				row.label:SetPoint("RIGHT", row, "RIGHT", -8, 0)

				if node.badge ~= nil then
					row.badge = row.badge or UI.Badge(row, nil, { style = "dim", hideEmpty = true })
					row.badge:SetText(Resolve(node.badge, node))
					row.badge:ClearAllPoints()
					row.badge:SetPoint("RIGHT", -8, 0)
				elseif row.badge then
					row.badge:Hide()
				end

				self:PaintRow(row)
				row:Show()
				y = y + height
			end

			for index = #self.visible + 1, #self.rows do
				self.rows[index].node = nil
				self.rows[index]:Hide()
			end

			self.contentHeight = y
			if self.area then
				self.area:SetContentHeight(y)
			else
				self:SetHeight(math.max(1, y))
			end
			if self.OnLayout then self.OnLayout(y, self) end
		end

		function tree:Refresh()
			for _, row in ipairs(self.rows) do
				if row.node then self:PaintRow(row) end
			end
		end

		function tree:SetItems(nodes)
			self.source = Resolve(nodes) or {}
			wipe(self.nodes)
			wipe(self.parents)
			Index(self.source, nil)
			self:Layout()
		end

		function tree:IsCollapsed(key)
			local node = self.nodes[key]
			return node and IsFolded(node) or false
		end

		function tree:SetCollapsed(key, collapsed)
			self.collapsed[key] = collapsed and true or false
			self:Layout()
			if self.OnToggle then self.OnToggle(key, collapsed and true or false) end
		end

		function tree:Toggle(key)
			self:SetCollapsed(key, not self:IsCollapsed(key))
		end

		-- selecting something folded away unfolds everything above it first.
		function tree:SetValue(key)
			self.value = key
			local parent, unfolded = self.parents[key], false
			while parent ~= nil do
				if self.collapsed[parent] ~= false and self:IsCollapsed(parent) then
					self.collapsed[parent] = false
					unfolded = true
				end
				parent = self.parents[parent]
			end
			if unfolded then self:Layout() else self:Refresh() end
		end

		function tree:GetValue()
			return self.value
		end

		function tree:GetNode(key)
			return self.nodes[key]
		end

		function tree:Reveal(key)
			if not self.area then return end
			for _, row in ipairs(self.rows) do
				if row.node and Key(row.node) == (key or self.value) then
					return self.area:ScrollIntoView(row, 4)
				end
			end
		end

		RowClick = function(row)
			local node = row.node
			if not node or tree.disabled or Resolve(node.disabled, node) then return end
			local key = Key(node)

			-- a heading, or a node that can't be picked, folds.
			local overChevron = node.children and row.chevron:IsShown() and row.chevron:IsMouseOver()
			if node.category or node.selectable == false or overChevron then
				if node.children then tree:Toggle(key) end
				return
			end

			tree:SetValue(key)
			if node.func then node.func(key, node) end
			if tree.OnSelect then tree.OnSelect(key, node) end
		end

		if opts.items then tree:SetItems(opts.items) end
		if opts.value ~= nil then tree:SetValue(opts.value) end
		return tree
	end

	-- a settings sidebar is a tree with the nav look.
	function UI.Nav(parent, width, height, opts)
		if type(height) == "table" then opts, height = height, nil end
		return UI.Tree(parent, width, height, opts)
	end

	--------------------------------------------------------------------------------
	-- Table
	--------------------------------------------------------------------------------

	-- columns are { key, title, width (pixels, or under 1 for a share of what's
	-- left), align, sortable, sort(a, b), format(value, row), color(value, row) }.
	-- opts takes style, columns, rows, sortKey, ascending, onClick(row, frame,
	-- mouseButton), isSelected(row) and onSort(key, ascending).
	function UI.Table(parent, width, height, opts)
		opts = opts or {}
		local style = StyleFor("table", opts)

		local grid = CreateFrame("Frame", nil, parent)
		grid:SetSize(width, height)
		Base(grid, opts)
		grid.style = style
		grid.columns = opts.columns or {}
		grid.view = {}
		grid.sortKey, grid.ascending = opts.sortKey, opts.ascending ~= false

		local header = CreateFrame("Frame", nil, grid)
		header:SetPoint("TOPLEFT")
		header:SetPoint("TOPRIGHT")
		header:SetHeight(style.headerHeight)
		Fill(header, "BACKGROUND", style.headerBg)
		grid.header = header
		header.cells = {}

		local widths, offsets = {}, {}

		local function Measure()
			local inner = width - 12
			local fixed, shares = 0, 0
			for _, column in ipairs(grid.columns) do
				local w = column.width or 1
				if w > 1 then fixed = fixed + w else shares = shares + w end
			end
			local left = math.max(0, inner - fixed)
			local x = 0
			for index, column in ipairs(grid.columns) do
				local w = column.width or 1
				widths[index] = w > 1 and w or (shares > 0 and left * w / shares or 0)
				offsets[index] = x
				x = x + widths[index]
			end
		end

		local function Build(row)
			row.cells = {}
			for index = 1, #grid.columns do
				local cell = UI.Text(row, "", style.font)
				cell:SetWordWrap(false)
				row.cells[index] = cell
			end
		end

		local function FillRow(row, entry)
			for index, column in ipairs(grid.columns) do
				local cell = row.cells[index]
				local value = entry[column.key]
				cell:ClearAllPoints()
				cell:SetPoint("LEFT", offsets[index] + style.cellPad, 0)
				cell:SetWidth(math.max(1, widths[index] - style.cellPad * 2))
				cell:SetJustifyH(column.align or "LEFT")
				local text = column.format and column.format(value, entry) or value
				cell:SetText(text == nil and "" or tostring(text))
				UI.Paint(cell, column.color and column.color(value, entry) or style.text, "text")
			end
		end

		grid.list = UI.List(grid, {
			width = width, height = height - style.headerHeight, rowHeight = style.rowHeight,
			Build = Build, Fill = FillRow, virtual = true, style = opts.listStyle,
			onClick = opts.onClick, isSelected = opts.isSelected,
		})
		grid.list.area:ClearAllPoints()
		grid.list.area:SetPoint("TOPLEFT", 0, -style.headerHeight)

		local function Compare(a, b)
			local column
			for _, c in ipairs(grid.columns) do
				if c.key == grid.sortKey then column = c break end
			end
			if column and column.sort then
				if grid.ascending then return column.sort(a, b) end
				return column.sort(b, a)
			end

			local x, y = a[grid.sortKey], b[grid.sortKey]
			if x == y then return false end
			if x == nil then return false end
			if y == nil then return true end
			if type(x) ~= type(y) then x, y = tostring(x), tostring(y) end
			if grid.ascending then return x < y end
			return x > y
		end

		function grid:DrawHeader()
			for index, column in ipairs(self.columns) do
				local cell = header.cells[index]
				if not cell then
					cell = CreateFrame("Button", nil, header)
					cell.label = UI.Text(cell, "", style.headerFont)
					cell.label:SetWordWrap(false)
					cell.arrow = UI.Chevron(cell, style.sortSize, style.headerActive)
					UI.Paint(cell:CreateTexture(nil, "HIGHLIGHT"), "hover", "fill"):SetAllPoints()
					cell:SetScript("OnClick", function(clicked)
						local col = self.columns[clicked.index]
						if col.sortable == false then return end
						if self.sortKey == col.key then
							self.ascending = not self.ascending
						else
							self.sortKey, self.ascending = col.key, true
						end
						self:Refresh()
						if opts.onSort then opts.onSort(self.sortKey, self.ascending) end
					end)
					header.cells[index] = cell
				end
				cell.index = index
				cell:ClearAllPoints()
				cell:SetPoint("TOPLEFT", offsets[index], 0)
				cell:SetSize(math.max(1, widths[index]), style.headerHeight)

				cell.label:SetText(column.title or "")
				cell.label:ClearAllPoints()
				cell.label:SetPoint("LEFT", style.cellPad, 0)
				cell.label:SetPoint("RIGHT", -style.cellPad - style.sortSize - 2, 0)
				cell.label:SetJustifyH(column.align or "LEFT")

				local sorted = self.sortKey == column.key
				UI.Paint(cell.label, sorted and style.headerActive or style.headerText, "text")
				cell.arrow:ClearAllPoints()
				cell.arrow:SetPoint("RIGHT", -style.cellPad + 2, 0)
				cell.arrow:SetFacing(self.ascending and "up" or "down")
				cell.arrow:SetShown(sorted)
				cell:Show()
			end
			for index = #self.columns + 1, #header.cells do header.cells[index]:Hide() end
		end

		-- sorts a copy of the rows so the caller's order is left alone.
		function grid:Refresh()
			wipe(self.view)
			for index, row in ipairs(self.rows or {}) do self.view[index] = row end
			if self.sortKey ~= nil then table.sort(self.view, Compare) end
			self:DrawHeader()
			self.list:Update(self.view)
		end

		function grid:SetRows(rows)
			self.rows = rows
			self:Refresh()
		end

		function grid:SetColumns(columns)
			self.columns = columns
			Measure()
			for _, row in pairs(self.list.rows) do
				for index = #row.cells + 1, #columns do
					row.cells[index] = UI.Text(row, "", style.font)
				end
				for index = #columns + 1, #row.cells do row.cells[index]:SetText("") end
			end
			self:Refresh()
		end

		function grid:SetSort(key, ascending)
			self.sortKey, self.ascending = key, ascending ~= false
			self:Refresh()
		end

		function grid:GetSort()
			return self.sortKey, self.ascending
		end

		function grid:Resize(newWidth, newHeight)
			width, height = newWidth, newHeight
			self:SetSize(width, height)
			Measure()
			self.list:Resize(width, height - style.headerHeight)
			self:Refresh()
		end

		Measure()
		grid:SetRows(opts.rows or {})
		return grid
	end

	--------------------------------------------------------------------------------
	-- Grid
	--------------------------------------------------------------------------------

	-- square cells in rows, for icon pickers and item grids. virtual like a list.
	-- entries have icon or iconAtlas, tooltip, and whatever a custom Fill reads.
	-- opts takes style, cellSize, spacing, Build(cell), Fill(cell, entry, index),
	-- onClick(entry, cell, mouseButton) and isSelected(entry).
	function UI.Grid(parent, width, height, opts)
		opts = opts or {}
		local style = StyleFor("grid", opts)
		local size = opts.cellSize or style.cellSize
		local spacing = opts.spacing or style.spacing

		local grid = CreateFrame("Frame", nil, parent)
		grid:SetSize(width, height)
		Base(grid, opts)
		grid.style = style
		grid.cells, grid.entries = {}, {}

		local area = UI.ScrollArea(grid, width, height, { style = opts.scrollStyle, step = size + spacing })
		area:SetPoint("TOPLEFT")
		grid.area = area

		local function Columns()
			return math.max(1, math.floor((area.content:GetWidth() + spacing) / (size + spacing)))
		end

		local function Cell(slot)
			local cell = grid.cells[slot]
			if cell then return cell end

			cell = CreateFrame("Button", nil, area.content)
			cell:SetSize(size, size)
			cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			cell.grid = grid
			Chrome(cell, style)
			cell.texture = cell:CreateTexture(nil, "ARTWORK")
			cell.texture:SetPoint("TOPLEFT", style.inset, -style.inset)
			cell.texture:SetPoint("BOTTOMRIGHT", -style.inset, style.inset)

			cell:SetScript("OnClick", function(self, mouseButton)
				if self.entry and opts.onClick then opts.onClick(self.entry, self, mouseButton) end
			end)
			cell:SetScript("OnEnter", function(self) ShowItemTooltip(self, self.entry) end)
			cell:SetScript("OnLeave", HideItemTooltip)

			if opts.Build then opts.Build(cell) end
			grid.cells[slot] = cell
			return cell
		end

		local function DefaultFill(cell, entry)
			if entry.iconAtlas then
				cell.texture:SetAtlas(entry.iconAtlas)
			else
				cell.texture:SetTexture(entry.icon or UI.UNKNOWN_ICON)
				cell.texture:SetTexCoord(style.zoom, 1 - style.zoom, style.zoom, 1 - style.zoom)
			end
		end

		function grid:Draw()
			local columns = Columns()
			local step = size + spacing
			local offset, _, view = area:GetScroll()
			local firstRow = math.floor(offset / step)
			local rowsShown = math.ceil(view / step) + 1
			local needed = rowsShown * columns

			for slot = 1, math.max(needed, #self.cells) do
				local index = firstRow * columns + slot
				local entry = slot <= needed and self.entries[index]
				if entry then
					local cell = Cell(slot)
					local column = (index - 1) % columns
					local row = math.floor((index - 1) / columns)
					cell:ClearAllPoints()
					cell:SetPoint("TOPLEFT", column * step, -row * step)
					cell.entry, cell.index = entry, index;
					(opts.Fill or DefaultFill)(cell, entry, index)

					local selected = self.IsSelected and self.IsSelected(entry) or false
					if cell.edges then cell.edges:Paint(selected and style.selectedBorder or style.border) end
					cell:Show()
				elseif self.cells[slot] then
					self.cells[slot].entry = nil
					self.cells[slot]:Hide()
				end
			end
		end

		function grid:Update(entries, IsSelected)
			self.entries = entries or {}
			self.IsSelected = IsSelected or opts.isSelected
			local rows = math.ceil(#self.entries / Columns())
			area:SetContentHeight(rows * (size + spacing) - spacing)
			self:Draw()
		end

		function grid:Refresh()
			self:Draw()
		end

		function grid:Resize(newWidth, newHeight)
			self:SetSize(newWidth, newHeight)
			area:Resize(newWidth, newHeight)
			self:Update(self.entries, self.IsSelected)
		end

		function grid:Reveal(Match)
			for index, entry in ipairs(self.entries) do
				if Match(entry) then
					local row = math.floor((index - 1) / Columns())
					area:ScrollTo(row * (size + spacing))
					return index
				end
			end
		end

		area.OnScroll = function() grid:Draw() end
		return grid
	end
end)
