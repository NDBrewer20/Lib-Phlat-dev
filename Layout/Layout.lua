local lib = LibStub("LibPhlat-1.0")
if not lib.loading then return end

lib:Module("Layout", function(UI, P, config)
	local Resolve = P.Resolve
	local Merge = P.Merge
	local Snap = P.Snap
	local SetControlEnabled = P.SetControlEnabled
	local Fill = P.Fill

	--------------------------------------------------------------------------------
	-- Layout
	--
	-- settings stacked as rows, label on the left and control on the right. every
	-- builder registers an Update so UpdateAll can re-read the page after a change.
	--
	-- options every row understands: name (label and the key rows are filed under),
	-- title (label that changes), desc (tooltip, value or function), key or get/set,
	-- disabled, hidden, onChange(value), indent, height and controlWidth.
	--------------------------------------------------------------------------------

	local Layout = {}
	Layout.__index = Layout

	-- exposed so an addon can add its own row builders.
	UI.LayoutProto = Layout

	-- opts takes rowStyle and rowStyleOverrides.
	function UI.Layout(parent, width, opts)
		opts = opts or {}
		return setmetatable({
			parent = parent, width = width, y = 0,
			widgets = {},
			-- rows by name, so other code can find a setting's row.
			rows = {},
			-- everything added in order, so Reflow can close gaps left by hidden rows.
			elements = {},
			rowStyle = UI.Style("row", opts.rowStyle, opts.rowStyleOverrides),
		}, Layout)
	end

	-- a row with a key and no get/set of its own goes through config.Get and config.Set.
	local function Getter(opts)
		return opts.get or function()
			return config.Get and config.Get(opts.key)
		end
	end

	local function Setter(opts)
		return opts.set or function(value)
			if config.Set then config.Set(opts.key, value) end
		end
	end

	local function Changed(opts, ...)
		if opts.onChange then opts.onChange(...) end
	end

	local function Disabled(opts)
		return opts.disabled and opts.disabled() or false
	end

	-- what a filter looks through for a row.
	local function SearchText(opts)
		local name = Resolve(opts.title) or opts.name
		local desc = type(opts.desc) == "string" and opts.desc or nil
		if not name and not desc then return nil end
		return (name or "") .. " " .. (desc or "")
	end

	function Layout:Advance(height, gap)
		self.y = self.y + height + (gap or 3)
	end

	function Layout:Gap(height)
		self.y = self.y + (height or 8)
	end

	function Layout:Height()
		return self.y
	end

	function Layout:Find(name)
		return self.rows[name]
	end

	-- adds one element and places it. place(y) positions its regions, pre is extra
	-- space above it when it isn't first, and hidden is checked on every reflow.
	function Layout:Add(element)
		self.elements[#self.elements + 1] = element
		if self.group and not element.isGroup then element.group = self.group end

		if element.pre and self.y > 0 then self:Gap(element.pre) end
		element.place(self.y)
		self:Advance(element.height, element.gap)
		return element
	end

	local function Hit(text, query)
		return text and text:lower():find(query, 1, true) and true or false
	end

	-- with a filter on, a header stays when anything under it matched, and
	-- everything under a header or group that matched stays with it.
	local function FilterKeep(self, query)
		local keep = {}
		local header, headerHit = nil, false
		local groupHit = false

		for _, element in ipairs(self.elements) do
			if element.isHeader then
				header, headerHit, groupHit = element, Hit(element.search, query), false
				if headerHit then keep[element] = true end
			elseif element.isGroup then
				groupHit = headerHit or Hit(element.search, query)
				if groupHit then
					keep[element] = true
					if header then keep[header] = true end
				end
			else
				local inGroupHit = element.group and groupHit
				if headerHit or inGroupHit or Hit(element.search, query) then
					keep[element] = true
					if header then keep[header] = true end
					if element.group then keep[element.group.element] = true end
				end
			end
		end
		return keep
	end

	-- lays the page out again top to bottom, skipping hidden elements.
	function Layout:Reflow()
		local y = 0
		local keep = self.filterText and FilterKeep(self, self.filterText:lower())

		for index = 1, #self.elements do
			local element = self.elements[index]
			local hidden = element.hidden and element.hidden() or false

			if not hidden and keep then
				hidden = not keep[element]
			elseif not hidden and element.group and element.group.collapsed then
				hidden = true
			end

			for _, region in ipairs(element.regions) do
				region:SetShown(not hidden)
			end

			if not hidden then
				if element.pre and y > 0 then y = y + element.pre end
				element.place(y)
				y = y + element.height + (element.gap or 3)
			end
		end

		self.y = y
		if self.OnReflow then self:OnReflow(y) end
		return y
	end

	-- shows only rows whose name or description has the text. nil or "" clears it.
	function Layout:Filter(text)
		self.filterText = text and text ~= "" and text or nil
		return self:Reflow()
	end

	-- opts and row are optional. with them the row's title and description
	-- functions are read on every update too.
	function Layout:Register(widget, opts, row)
		self.widgets[#self.widgets + 1] = widget

		if opts and row then
			local Update = widget.Update
			widget.Update = function()
				if opts.title then row:SetTitle(Resolve(opts.title)) end
				if type(opts.desc) == "function" then row:SetDescription(opts.desc()) end
				Update()
			end
		end

		-- a row that grew while it drew itself pushes what comes after it down.
		local before = row and row.element and row.element.height
		widget:Update()
		if before and row.element.height ~= before and self.elements[#self.elements] == row.element then
			self.y = self.y + row.element.height - before
		end
		return widget
	end

	-- two layouts on one page that update each other, like a pinned strip over a
	-- scrolling list.
	function Layout:Link(other)
		self.linked, other.linked = other, self
	end

	function Layout:UpdateAll()
		-- stops a linked pair from updating each other forever.
		if self.updating then return end
		self.updating = true

		for i = 1, #self.widgets do
			self.widgets[i]:Update()
		end
		-- reflow after the widgets since a new value can decide what's hidden.
		self:Reflow()

		if self.linked then self.linked:UpdateAll() end
		self.updating = false
	end

	-- sets a row's height after it's built, like a control that grew.
	local function Grow(layout, row, height)
		if row.element.height == height then return end
		row.element.height = height
		row:SetHeight(height)
		if not layout.updating then layout:Reflow() end
	end

	--------------------------------------------------------------------------------
	-- Headings, notes and dividers
	--------------------------------------------------------------------------------

	function Layout:Header(text, hidden)
		local header = UI.Text(self.parent, text, "GameFontNormal")
		UI.Accented(header, 1)

		local line = self.parent:CreateTexture(nil, "ARTWORK")
		line:SetSize(self.width, 1)
		UI.Paint(line, "line", "fill")

		self:Add({
			regions = { header, line },
			height = 21, gap = 8, pre = 16, hidden = hidden,
			isHeader = true, search = text,
			place = function(y)
				header:SetPoint("TOPLEFT", 2, -y)
				line:SetPoint("TOPLEFT", 0, -y - 19)
			end,
		})
		return header
	end

	function Layout:Note(text, hidden)
		local note = UI.Text(self.parent, text, "GameFontHighlightSmall", UI.colors.dim)
		note:SetWidth(self.width - 6)
		note:SetJustifyV("TOP")

		self:Add({
			regions = { note },
			height = math.max(14, note:GetStringHeight()), gap = 8, hidden = hidden,
			place = function(y) note:SetPoint("TOPLEFT", 2, -y) end,
		})
		return note
	end

	function Layout:Divider(opts)
		opts = opts or {}
		local line = self.parent:CreateTexture(nil, "ARTWORK")
		line:SetSize(self.width, 1)
		UI.Paint(line, opts.color or "line", "fill")

		self:Add({
			regions = { line }, height = 1, gap = opts.gap or 8, pre = opts.pre or 5, hidden = opts.hidden,
			place = function(y) line:SetPoint("TOPLEFT", 0, -y) end,
		})
		return line
	end

	-- a heading that folds the rows after it until EndGroup. opts takes name,
	-- collapsed, and key or get/set to keep the folded state.
	function Layout:Group(opts)
		local layout = self
		local s = self.rowStyle
		local group = { collapsed = opts.collapsed or false }
		if opts.get or opts.key then
			local stored = Getter(opts)()
			if stored ~= nil then group.collapsed = stored and true or false end
		end
		local set = (opts.set or opts.key) and Setter(opts)

		local button = CreateFrame("Button", nil, self.parent)
		button:SetSize(self.width, 24)
		UI.Paint(button:CreateTexture(nil, "HIGHLIGHT"), s.hover, "fill"):SetAllPoints()

		local chevron = UI.Chevron(button, 10, "dim")
		chevron:SetPoint("LEFT", 4, 0)
		local label = UI.Text(button, opts.name, "GameFontNormal", "text")
		label:SetPoint("LEFT", chevron, "RIGHT", 6, 0)

		function group:SetCollapsed(collapsed)
			self.collapsed = collapsed and true or false
			chevron:SetFacing(self.collapsed and "right" or "down")
			if set then set(self.collapsed) end
			if opts.onToggle then opts.onToggle(self.collapsed) end
			layout:Reflow()
		end

		button:SetScript("OnClick", function() group:SetCollapsed(not group.collapsed) end)
		chevron:SetFacing(group.collapsed and "right" or "down")

		group.button = button
		group.element = self:Add({
			regions = { button }, height = 24, gap = 4, pre = 6, hidden = opts.hidden,
			isGroup = true, search = opts.name,
			place = function(y) button:SetPoint("TOPLEFT", 0, -y) end,
		})

		self.group = group
		if opts.name then self.rows[opts.name] = button end
		return group
	end

	function Layout:EndGroup()
		self.group = nil
	end

	--------------------------------------------------------------------------------
	-- Rows
	--------------------------------------------------------------------------------

	function Layout:Row(opts, height)
		local s = self.rowStyle
		height = height or opts.height or s.height

		local row = CreateFrame("Frame", nil, self.parent)
		row:SetSize(self.width, height)
		row:EnableMouse(true)
		if opts.name then self.rows[opts.name] = row end

		-- kept on the row so a widget that changes height can reflow behind itself.
		row.element = self:Add({
			regions = { row },
			height = height, gap = s.gap, hidden = opts.hidden,
			search = SearchText(opts),
			place = function(y) row:SetPoint("TOPLEFT", 0, -y) end,
		})
		if s.bg then Fill(row, "BACKGROUND", s.bg) end

		local hover = row:CreateTexture(nil, "BORDER")
		hover:SetAllPoints()
		UI.Paint(hover, s.hover, "fill")
		hover:Hide()

		row.label = UI.Text(row, Resolve(opts.title) or opts.name, s.font)
		row.label:SetPoint("LEFT", s.padding + (opts.indent or 0), 0)
		row.label:SetWidth(self.width * s.labelWidth - (opts.indent or 0))

		row.tipTitle = Resolve(opts.title) or opts.name
		row.tipBody = Resolve(opts.desc)
		row:SetScript("OnEnter", function(self)
			hover:Show()
			UI.ShowTooltip(self)
		end)
		row:SetScript("OnLeave", function()
			hover:Hide()
			UI.HideTooltip()
		end)

		-- for a label that depends on another setting. opts.name stays the key the
		-- row is filed under.
		function row:SetTitle(text)
			self.label:SetText(text)
			self.tipTitle = text
		end

		function row:SetDescription(text)
			self.tipBody = text
		end

		function row:SetDisabled(disabled)
			UI.Paint(self.label, disabled and s.disabledText or s.text, "text")
		end

		return row
	end

	-- opts.control = "switch" draws a switch instead of a box.
	function Layout:Check(opts)
		local layout, row = self, self:Row(opts)
		local box
		if opts.control == "switch" then
			box = UI.Switch(row, { style = opts.style })
		else
			box = UI.Checkbox(row, { style = opts.style })
		end
		box:SetPoint("RIGHT", -12, 0)

		local get, set = Getter(opts), Setter(opts)
		local function Toggle()
			local value = not get()
			set(value)
			Changed(opts, value)
			layout:UpdateAll()
		end

		-- the whole row toggles, not just the box.
		box:SetScript("OnClick", Toggle)
		row:SetScript("OnMouseUp", function()
			if box:IsEnabled() and not box:IsMouseOver() then Toggle() end
		end)

		return layout:Register({
			box = box, row = row,
			Update = function()
				local disabled = Disabled(opts)
				SetControlEnabled(box, not disabled)
				row:SetDisabled(disabled)
				box:SetChecked(get())
			end,
		}, opts, row)
	end

	function Layout:Switch(opts)
		return self:Check(Merge({ control = "switch" }, opts))
	end

	-- slider with an editable number beside it. typing commits on enter or clicking
	-- away, escape puts the old number back.
	function Layout:Slider(opts)
		local layout, row = self, self:Row(opts)
		local slider = UI.Slider(row, opts.min, opts.max, opts.step, { style = opts.style })
		slider:SetWidth(opts.controlWidth or 150)
		slider:SetPoint("RIGHT", -62, 0)

		local box = UI.EditBox(row, 48, 18)
		box:SetPoint("LEFT", slider, "RIGHT", 8, 0)
		box:SetJustifyH("CENTER")
		box:SetMaxLetters(8)
		box:SetTextInsets(2, 2, 0, 0)

		local get, set = Getter(opts), Setter(opts)
		local numberFormat = opts.format or "%d"
		local applying = false
		local pending

		local function Current()
			return Snap(get() or opts.min, opts.min, opts.step)
		end

		-- skipped while typing so the cursor doesn't jump around.
		local function ShowValue(value)
			if box:HasFocus() then return end
			box:SetText(numberFormat:format(value))
			box:SetCursorPosition(0)
		end

		local function Write(value)
			set(value)
			Changed(opts, value)
			layout:UpdateAll()
		end

		-- clamped to the range, anything that isn't a number is ignored.
		local function Commit(text)
			local value = tonumber(text)
			if not value then return end
			Write(Snap(math.min(math.max(value, opts.min), opts.max), opts.min, opts.step))
		end

		box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
		box:SetScript("OnEscapePressed", function(self)
			self.reverting = true
			self:ClearFocus()
		end)

		-- hooked so the edit box still resets its own border.
		box:HookScript("OnEditFocusLost", function(self)
			if self.reverting then
				self.reverting = nil
			else
				Commit(self:GetText())
			end
			ShowValue(Current())
		end)

		-- commitOnRelease holds the write until the mouse is let go, for settings
		-- that move the slider out from under the cursor. the number still follows.
		slider:SetScript("OnValueChanged", function(_, value)
			if applying then return end
			value = Snap(value, opts.min, opts.step)
			ShowValue(value)

			if opts.commitOnRelease then
				pending = value
			else
				-- update mid drag so previews follow. applying stops it feeding back.
				Write(value)
			end
		end)

		if opts.commitOnRelease then
			-- the slider holds the mouse while dragging so this fires even off the control.
			slider:SetScript("OnMouseUp", function()
				if pending == nil then return end
				local value = pending
				pending = nil
				Write(value)
			end)
		end

		return layout:Register({
			slider = slider, box = box, row = row,
			Update = function()
				local disabled = Disabled(opts)
				SetControlEnabled(slider, not disabled)
				SetControlEnabled(box, not disabled)
				row:SetDisabled(disabled)

				applying = true
				local value = Current()
				slider:SetValue(value)
				ShowValue(value)
				applying = false
			end,
		}, opts, row)
	end

	-- the options a choice control takes out of a row's opts.
	local function ChoiceOpts(opts, extra)
		return Merge(Merge({
			style = opts.style, styleOverrides = opts.styleOverrides,
			placeholder = opts.placeholder, menuWidth = opts.menuWidth, menuStyle = opts.menuStyle,
			maxRows = opts.maxRows, search = opts.search, showSelected = opts.showSelected,
			summary = opts.summary, horizontal = opts.horizontal,
		}, extra), opts.controlOpts)
	end

	-- a choice on the right of the row. a radio group down the side grows the row.
	local function PlaceChoice(layout, row, control, kind, opts)
		if kind == "radio" and not opts.horizontal then
			control:SetPoint("TOPRIGHT", -12, -4)
			control.OnLayout = function(height)
				Grow(layout, row, math.max(layout.rowStyle.height, height + 8))
			end
			control.OnLayout(control:GetHeight())
		else
			control:SetPoint("RIGHT", -12, 0)
		end
	end

	-- opts.control picks how it's drawn: dropdown (default), segmented, cycle, radio
	-- or anything added with UI.RegisterChoice.
	function Layout:Select(opts)
		local layout, row = self, self:Row(opts)
		local kind = opts.control or "dropdown"
		local width = opts.controlWidth or (kind ~= "radio" and 170 or nil)

		local control = UI.Choice(kind, row, width, ChoiceOpts(opts))
		control.placeholder = opts.placeholder
		PlaceChoice(layout, row, control, kind, opts)

		local get, set = Getter(opts), Setter(opts)
		control.OnSelect = function(value)
			set(value)
			Changed(opts, value)
			layout:UpdateAll()
		end

		local extra = opts.extra and opts.extra(row, control, layout)

		return layout:Register({
			control = control, dropdown = control, row = row,
			Update = function()
				local disabled = Disabled(opts)
				SetControlEnabled(control, not disabled)
				row:SetDisabled(disabled)

				-- only handed over when it changed, so a strip isn't laid out on every drag.
				local items = Resolve(opts.items) or {}
				if items ~= control.lastItems then
					control.lastItems = items
					control:SetItems(items)
				end
				control:SetValue(get())

				if extra and extra.Update then extra.Update() end
			end,
		}, opts, row)
	end

	function Layout:Radio(opts)
		return self:Select(Merge({ control = "radio" }, opts))
	end

	function Layout:Segmented(opts)
		return self:Select(Merge({ control = "segmented" }, opts))
	end

	-- several picks from one list. with opts.toggle the caller tracks the picks
	-- and writes the label through opts.summary. without it get returns a set of
	-- value = true and set is handed a fresh one.
	function Layout:MultiSelect(opts)
		local layout, row = self, self:Row(opts)
		local kind = opts.control or "dropdown"
		local manual = opts.toggle ~= nil

		local control
		if manual then
			control = UI.Dropdown(row, opts.controlWidth or 190, ChoiceOpts(opts, { summary = false }))
			control.keepOpen = true
		else
			control = UI.Choice(kind, row, opts.controlWidth or (kind ~= "radio" and 190 or nil),
				ChoiceOpts(opts, { multi = true, summary = type(opts.summary) == "function" and function(values, items)
					return opts.summary(values, items)
				end or nil }))
		end
		PlaceChoice(layout, row, control, kind, opts)

		local get, set = Getter(opts), Setter(opts)
		control.OnSelect = function(value, _, values)
			if manual then
				opts.toggle(value)
			else
				local copy = {}
				for picked in pairs(values or {}) do copy[picked] = true end
				set(copy)
				Changed(opts, copy)
			end
			layout:UpdateAll()
		end

		return layout:Register({
			control = control, dropdown = control, row = row,
			Update = function()
				local disabled = Disabled(opts)
				SetControlEnabled(control, not disabled)
				row:SetDisabled(disabled)

				local items = Resolve(opts.items) or {}
				if items ~= control.lastItems then
					control.lastItems = items
					control:SetItems(items)
				end

				if manual then
					control.label:SetText(Resolve(opts.summary) or "")
				else
					control:SetValues(get() or {})
				end
			end,
		}, opts, row)
	end

	function Layout:Color(opts)
		local layout, row = self, self:Row(opts)
		local swatch = UI.ColorSwatch(row, 46, 18)
		swatch:SetPoint("RIGHT", -12, 0)

		local get, set = Getter(opts), Setter(opts)
		swatch:SetScript("OnClick", function()
			local color = get()
			UI.OpenColorPicker(color[1], color[2], color[3], color[4] or 1, opts.hasAlpha,
				function(r, g, b, a)
					set({ r, g, b, a })
					Changed(opts, { r, g, b, a })
					layout:UpdateAll()
				end)
		end)

		return layout:Register({
			swatch = swatch, row = row,
			Update = function()
				local disabled = Disabled(opts)
				SetControlEnabled(swatch, not disabled)
				row:SetDisabled(disabled)
				local color = get()
				swatch:SetColor(color[1], color[2], color[3], color[4] or 1)
			end,
		}, opts, row)
	end

	local ChevronUp = UI.GlyphBuilder("chevron", "up")

	function Layout:Input(opts)
		local layout, row = self, self:Row(opts)
		local box = UI.EditBox(row, opts.controlWidth or 190, 22, { placeholder = opts.placeholder, numeric = opts.numeric })
		box:SetPoint("RIGHT", -12, 0)

		-- opts.icon previews what was typed beside the box, usually a spell icon.
		-- opts.browse makes that preview a button, with a question mark while empty.
		local icon, browse
		if opts.icon or opts.browse then
			local holder = row

			if opts.browse then
				browse = CreateFrame("Button", nil, row)
				browse:SetSize(24, 24)
				browse:SetPoint("RIGHT", box, "LEFT", -6, 0)
				UI.Accented(browse:CreateTexture(nil, "HIGHLIGHT"), 0.30):SetAllPoints()
				UI.Tooltip(browse, opts.browseTitle or "Browse", opts.browseDesc)
				browse:SetScript("OnClick", function()
					opts.browse()
					layout:UpdateAll()
				end)
				holder = browse
			end

			icon = holder:CreateTexture(nil, "ARTWORK")
			icon:SetSize(20, 20)
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			if browse then
				icon:SetPoint("CENTER")
			else
				icon:SetPoint("RIGHT", box, "LEFT", -8, 0)
			end
		end

		-- opts.reorder adds up, down and remove buttons to the end of the row. each
		-- one's can function decides if it's enabled.
		local buttons
		if opts.reorder then
			local reorder, previous = opts.reorder, nil
			buttons = {}

			local function Add(Build, title, body, func, enabled)
				local button = UI.GlyphButton(row, 12, Build, title, body)
				if previous then
					button:SetPoint("RIGHT", previous, "LEFT", 0, 0)
				else
					button:SetPoint("RIGHT", -8, 0)
				end

				button.enabled = enabled
				button:SetScript("OnClick", function()
					func()
					layout:UpdateAll()
				end)

				buttons[#buttons + 1] = button
				previous = button
			end

			-- added right to left so they read up, down, remove.
			Add(UI.Cross, "Remove", "Takes this entry out of the list.",
				reorder.remove, reorder.canRemove)
			Add(UI.Chevron, "Move Down", "Moves this entry down one.",
				reorder.down, reorder.canDown)
			Add(ChevronUp, "Move Up", "Moves this entry up one.",
				reorder.up, reorder.canUp)

			box:ClearAllPoints()
			box:SetPoint("RIGHT", previous, "LEFT", -8, 0)
		end

		local get, set = Getter(opts), Setter(opts)

		-- enter and escape already clear focus, so losing focus is the one place it saves.
		box:HookScript("OnEditFocusLost", function(self)
			local text = self:GetText()
			set(text)
			Changed(opts, text)
			layout:UpdateAll()
		end)

		return layout:Register({
			-- returned so a list that shrinks can hide the rows it doesn't need.
			row = row, box = box,
			Update = function()
				local disabled = Disabled(opts)
				SetControlEnabled(box, not disabled)
				row:SetDisabled(disabled)

				-- don't overwrite what the player is typing.
				if not box:HasFocus() then box:SetText(tostring(get() or "")) end

				for index = 1, buttons and #buttons or 0 do
					local button = buttons[index]
					local canMove = not button.enabled or button.enabled()
					SetControlEnabled(button, not disabled and canMove)
				end

				if browse then SetControlEnabled(browse, not disabled) end

				if icon then
					local texture = opts.icon and opts.icon()
					icon:SetDesaturated(false)

					if texture then
						icon:SetTexture(texture)
						icon:Show()
					elseif browse then
						-- keep the question mark up since it's still the button.
						icon:SetTexture(UI.UNKNOWN_ICON)
						icon:SetDesaturated(true)
						icon:Show()
					else
						icon:Hide()
					end

					icon:SetAlpha(disabled and 0.4 or 1)
				end
			end,
		}, opts, row)
	end

	-- opts.text can be a function for a caption that changes. opts.style is a button style.
	function Layout:Button(opts)
		local layout, row = self, self:Row(opts)

		local button = UI.Button(row, Resolve(opts.text) or "Open", opts.controlWidth or 150, 22, { style = opts.style })
		button:SetPoint("RIGHT", -12, 0)

		-- right clicks only when asked for, so a stray one can't fire something like a reset.
		if opts.onRightClick then
			button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		end

		button:SetScript("OnClick", function(clicked, mouseButton)
			if mouseButton == "RightButton" then
				opts.onRightClick(clicked)
			else
				opts.func(clicked)
			end
			layout:UpdateAll()
		end)

		return layout:Register({
			row = row, button = button,
			Update = function()
				local disabled = Disabled(opts)
				SetControlEnabled(button, not disabled)
				row:SetDisabled(disabled)

				if type(opts.text) == "function" then button:SetText(opts.text() or "Open") end
			end,
		}, opts, row)
	end

	-- several buttons on one row, right to left from the edge. buttons are
	-- { text, func, style, width, disabled, tooltip }. no name leaves the label off.
	function Layout:Buttons(opts)
		local layout, row = self, self:Row(opts)
		local controls, previous = {}, nil

		for index = #opts.buttons, 1, -1 do
			local spec = opts.buttons[index]
			local button = UI.Button(row, Resolve(spec.text) or "", spec.width, 22, {
				style = spec.style, autoWidth = not spec.width, minWidth = 70,
			})
			if previous then
				button:SetPoint("RIGHT", previous, "LEFT", -6, 0)
			else
				button:SetPoint("RIGHT", -12, 0)
			end
			if spec.tooltip then button.tipTitle, button.tipBody = Resolve(spec.text), spec.tooltip end
			button:SetScript("OnClick", function(clicked)
				if spec.func then spec.func(clicked) end
				layout:UpdateAll()
			end)
			controls[index] = button
			previous = button
		end

		return layout:Register({
			row = row, buttons = controls,
			Update = function()
				local disabled = Disabled(opts)
				row:SetDisabled(disabled)
				for index, spec in ipairs(opts.buttons) do
					SetControlEnabled(controls[index], not disabled and not (spec.disabled and spec.disabled()))
					if type(spec.text) == "function" then controls[index]:SetText(spec.text()) end
				end
			end,
		}, opts, row)
	end

	-- a number with minus and plus. takes min, max, step, bigStep and format.
	function Layout:Stepper(opts)
		local layout, row = self, self:Row(opts)
		local get, set = Getter(opts), Setter(opts)

		local stepper = UI.Stepper(row, opts.controlWidth or 90, {
			min = opts.min, max = opts.max, step = opts.step, bigStep = opts.bigStep, format = opts.format,
			onChange = function(value)
				set(value)
				Changed(opts, value)
				layout:UpdateAll()
			end,
		})
		stepper:SetPoint("RIGHT", -12, 0)

		return layout:Register({
			row = row, stepper = stepper,
			Update = function()
				local disabled = Disabled(opts)
				stepper:SetEnabled(not disabled)
				row:SetDisabled(disabled)
				stepper:SetValue(get(), true)
			end,
		}, opts, row)
	end

	-- low and high on one slider. get returns both, set takes both.
	function Layout:Range(opts)
		local layout, row = self, self:Row(opts)
		local get, set = Getter(opts), Setter(opts)

		local range = UI.RangeSlider(row, opts.controlWidth or 170, {
			min = opts.min, max = opts.max, step = opts.step, minGap = opts.minGap,
			onChange = function(low, high)
				set(low, high)
				Changed(opts, low, high)
				layout:UpdateAll()
			end,
		})
		range:SetPoint("RIGHT", -12, 0)

		return layout:Register({
			row = row, range = range,
			Update = function()
				local disabled = Disabled(opts)
				range:SetEnabled(not disabled)
				row:SetDisabled(disabled)
				local low, high = get()
				range:SetValue(low, high, true)
			end,
		}, opts, row)
	end

	function Layout:Keybind(opts)
		local layout, row = self, self:Row(opts)
		local get, set = Getter(opts), Setter(opts)

		local bind = UI.Keybind(row, opts.controlWidth or 150, 22, {
			emptyText = opts.emptyText,
			onChange = function(value)
				set(value)
				Changed(opts, value)
				layout:UpdateAll()
			end,
		})
		bind:SetPoint("RIGHT", -12, 0)

		return layout:Register({
			row = row, keybind = bind,
			Update = function()
				local disabled = Disabled(opts)
				SetControlEnabled(bind, not disabled)
				row:SetDisabled(disabled)
				bind:SetValue(get())
			end,
		}, opts, row)
	end

	-- a { year, month, day } picked off a calendar.
	function Layout:Date(opts)
		local layout, row = self, self:Row(opts)
		local get, set = Getter(opts), Setter(opts)

		local picker = UI.DatePicker(row, opts.controlWidth or 150, {
			format = opts.format, placeholder = opts.placeholder, calendar = opts.calendar,
			onChange = function(value)
				set(value)
				Changed(opts, value)
				layout:UpdateAll()
			end,
		})
		picker:SetPoint("RIGHT", -12, 0)

		return layout:Register({
			row = row, picker = picker,
			Update = function()
				local disabled = Disabled(opts)
				SetControlEnabled(picker, not disabled)
				row:SetDisabled(disabled)
				picker:SetDate(get())
			end,
		}, opts, row)
	end

	-- label on the left, a bar on the right. opts.value returns value, max and
	-- optional text.
	function Layout:Progress(opts)
		local row = self:Row(opts)
		local bar = UI.ProgressBar(row, opts.controlWidth or 150, 12, { style = opts.style, format = opts.format })
		bar:SetPoint("RIGHT", -12, 0)

		return self:Register({
			row = row, bar = bar,
			Update = function()
				local value, max, text = Resolve(opts.value)
				bar:SetValue(value or 0, max or 1)
				if text then bar:SetText(text) end
			end,
		}, opts, row)
	end

	-- full width blocks with the label over the control.
	local function Block(layout, opts, height)
		local block = CreateFrame("Frame", nil, layout.parent)
		block:SetSize(layout.width, height)
		if opts.name then layout.rows[opts.name] = block end

		block.element = layout:Add({
			regions = { block }, height = height, gap = 6, hidden = opts.hidden,
			search = SearchText(opts),
			place = function(y) block:SetPoint("TOPLEFT", 0, -y) end,
		})

		local top = 0
		if opts.name or opts.title then
			block.label = UI.Text(block, Resolve(opts.title) or opts.name, "body")
			block.label:SetPoint("TOPLEFT", 2, 0)
			block.tipTitle, block.tipBody = Resolve(opts.title) or opts.name, Resolve(opts.desc)
			top = 20
		end

		function block:SetTitle(text)
			if self.label then self.label:SetText(text) end
		end
		function block:SetDescription(text)
			self.tipBody = text
		end
		function block:SetDisabled(disabled)
			if self.label then UI.Paint(self.label, disabled and "disabled" or "text", "text") end
		end
		return block, top
	end

	-- a scrolling text box under its label. saves when it loses focus. takes
	-- height, readOnly, placeholder and selectOnFocus.
	function Layout:TextArea(opts)
		local layout = self
		local boxHeight = opts.height or 80
		local block, top = Block(self, opts, boxHeight + 20)
		if top == 0 then
			block.element.height = boxHeight
			block:SetHeight(boxHeight)
		end

		local get, set = Getter(opts), Setter(opts)
		local area = UI.TextArea(block, self.width, boxHeight, {
			readOnly = opts.readOnly, placeholder = opts.placeholder, selectOnFocus = opts.selectOnFocus,
			onCommit = not opts.readOnly and function(text)
				set(text)
				Changed(opts, text)
				layout:UpdateAll()
			end or nil,
		})
		area:SetPoint("TOPLEFT", 0, -top)

		return self:Register({
			row = block, area = area,
			Update = function()
				local disabled = Disabled(opts)
				area:SetEnabled(not disabled)
				block:SetDisabled(disabled)
				if not area.edit:HasFocus() then area:SetText(tostring(get() or "")) end
			end,
		}, opts, block)
	end

	-- tags under their label. get returns a list, set gets the list back.
	function Layout:Tags(opts)
		local layout = self
		local block, top = Block(self, opts, 50)
		local get, set = Getter(opts), Setter(opts)

		local input = UI.TagInput(block, self.width, {
			max = opts.max, unique = opts.unique, placeholder = opts.placeholder,
			onChange = function(tags)
				local copy = {}
				for index, tag in ipairs(tags) do copy[index] = tag end
				set(copy)
				Changed(opts, copy)
				layout:UpdateAll()
			end,
		})
		input:SetPoint("TOPLEFT", 0, -top)
		input.OnLayout = function(height) Grow(layout, block, top + height) end

		return self:Register({
			row = block, tags = input,
			Update = function()
				local disabled = Disabled(opts)
				input:SetEnabled(not disabled)
				block:SetDisabled(disabled)
				if not input.box:HasFocus() then input:SetTags(get()) end
			end,
		}, opts, block)
	end

	-- anything else. opts.build(frame, layout) fills a full width frame of
	-- opts.height and can return a table with its own Update.
	function Layout:Custom(opts)
		local block = CreateFrame("Frame", nil, self.parent)
		block:SetSize(self.width, opts.height or 30)
		if opts.name then self.rows[opts.name] = block end

		block.element = self:Add({
			regions = { block }, height = opts.height or 30, gap = opts.gap or 3, pre = opts.pre,
			hidden = opts.hidden, search = SearchText(opts),
			place = function(y) block:SetPoint("TOPLEFT", 0, -y) end,
		})

		local widget = opts.build and opts.build(block, self) or {}
		widget.row = widget.row or block
		widget.Update = widget.Update or function() end
		return self:Register(widget)
	end

	-- read only text like a generated macro. sunken with an accent rule so it reads
	-- as output, not something to type in. opts.icon adds an icon beside it and
	-- opts.onClick makes that icon clickable.
	function Layout:Code(opts)
		local layout = self
		local height = opts.height or 78
		local ICON = 52

		local block = CreateFrame("Frame", nil, self.parent)
		block:SetSize(self.width, height)
		Fill(block, "BACKGROUND", "inset")

		self:Add({
			regions = { block },
			height = height, gap = 3, hidden = opts.hidden,
			place = function(y) block:SetPoint("TOPLEFT", 0, -y) end,
		})

		local rule = block:CreateTexture(nil, "ARTWORK")
		rule:SetPoint("TOPLEFT")
		rule:SetPoint("BOTTOMLEFT")
		rule:SetWidth(2)
		UI.Accented(rule, 0.55)

		local text = UI.Text(block, "", "GameFontHighlightSmall", UI.colors.dim)
		text:SetPoint("TOPLEFT", 12, -8)
		text:SetPoint("BOTTOMRIGHT", -(opts.icon and ICON + 20 or 10), 8)
		text:SetJustifyV("TOP")

		local icon, iconButton
		if opts.icon then
			iconButton = CreateFrame("Button", nil, block)
			iconButton:SetSize(ICON, ICON)
			iconButton:SetPoint("RIGHT", -10, 0)
			iconButton:EnableMouse(opts.onClick ~= nil)
			Fill(iconButton, "BACKGROUND", "black")
			UI.Border(iconButton)

			icon = iconButton:CreateTexture(nil, "ARTWORK")
			icon:SetPoint("TOPLEFT", 2, -2)
			icon:SetPoint("BOTTOMRIGHT", -2, 2)
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

			if opts.onClick then
				UI.Accented(iconButton:CreateTexture(nil, "HIGHLIGHT"), 0.30):SetAllPoints()
				iconButton.tipTitle = opts.iconName or "Icon"
				iconButton:SetScript("OnEnter", UI.ShowTooltip)
				iconButton:SetScript("OnLeave", UI.HideTooltip)

				if opts.onRightClick then
					iconButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
				end
				iconButton:SetScript("OnClick", function(clicked, mouseButton)
					if mouseButton == "RightButton" then
						opts.onRightClick(clicked)
					else
						opts.onClick(clicked)
					end
					layout:UpdateAll()
				end)
			end
		end

		return self:Register({
			-- returned so outside code can find where the block sits.
			block = block,
			Update = function()
				text:SetText(opts.text())
				if not icon then return end

				icon:SetTexture(opts.icon())
				iconButton.tipBody = Resolve(opts.iconDesc)
			end,
		})
	end

	-- label on the left, read only value on the right.
	function Layout:Info(opts)
		local row = self:Row(opts)

		local value = UI.Text(row, "", "GameFontHighlightSmall", UI.colors.dim)
		value:SetPoint("RIGHT", -12, 0)
		value:SetJustifyH("RIGHT")
		value:SetWidth(self.width * 0.4)

		return self:Register({
			row = row,
			Update = function()
				value:SetText(Resolve(opts.value) or "")
			end,
		}, opts, row)
	end
end)
