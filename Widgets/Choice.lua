local lib = LibStub("LibPhlat-1.0")
if not lib.loading then return end

lib:Module("Choice", function(UI, P, config)
	local Resolve = P.Resolve
	local Merge = P.Merge
	local StyleFor = P.StyleFor
	local Chrome = P.Chrome
	local Base = P.Base
	local TextWidth = P.TextWidth
	local SelectedWash = P.SelectedWash
	local FindItem = P.FindItem
	local BODY = P.BODY

	--------------------------------------------------------------------------------
	-- Choices
	--
	-- segmented, tabs, cycle and radio all take the same items a dropdown does,
	-- and the same SetItems, SetValue, GetValue, SetValues, GetValues, Reload and
	-- onSelect(value, item, values). headers, separators and submenus only mean
	-- something in a menu, so the others skip them.
	--------------------------------------------------------------------------------

	-- items that can be a button of their own. shown is the other way round to
	-- hidden, for tabs that only exist sometimes.
	local function Selectable(items, out)
		out = out or {}
		wipe(out)
		for _, item in ipairs(items or {}) do
			if not item.header and not item.separator
				and not Resolve(item.hidden, item)
				and (item.shown == nil or Resolve(item.shown, item)) then
				out[#out + 1] = item
			end
		end
		return out
	end
	P.Selectable = Selectable

	local function ItemTooltip(owner, item)
		if not (item.tooltip or item.tooltipTitle or item.tooltipFunc) then return end
		GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
		if item.tooltipFunc then
			if item.tooltipFunc(GameTooltip, item) == false then return GameTooltip:Hide() end
		else
			GameTooltip:AddLine(item.tooltipTitle or Resolve(item.text, item) or "", 1, 1, 1)
			if item.tooltip then
				GameTooltip:AddLine(Resolve(item.tooltip, item), BODY[1], BODY[2], BODY[3], true)
			end
		end
		GameTooltip:Show()
		owner.tipShown = true
	end

	--------------------------------------------------------------------------------
	-- Segmented and tabs
	--
	-- one strip of buttons. segmented splits its width evenly, tabs size to their
	-- labels and wrap onto another line when the width runs out.
	--------------------------------------------------------------------------------

	local SegmentClick, SegmentEnter, SegmentLeave

	local function PaintSegment(button)
		local strip, item = button.strip, button.item
		local s = strip.style

		local active
		if strip.multi then
			active = strip.values[item.value] == true
		else
			active = strip.value ~= nil and item.value == strip.value
		end
		local disabled = strip.disabled or Resolve(item.disabled, item) and true or false

		button.selectedState = active
		if button.selectedTex or s.selected then SelectedWash(button, s.selected) end
		if button.mark then button.mark:SetShown(active) end
		if button.highlight then button.highlight:SetAlpha(disabled and 0 or 1) end

		local color = s.text
		if disabled then
			color = s.disabledText
		elseif active then
			color = s.activeText
		elseif Resolve(item.empty, item) then
			color = s.emptyText
		elseif item.color then
			color = item.color
		elseif button.hovered and s.hoverText then
			color = s.hoverText
		end
		UI.Paint(button.label, color, "text")
		if button.icon then button.icon:SetDesaturated(disabled) end
	end

	-- each button's own chrome when there's a gap between them, the strip's when
	-- they sit flush so borders don't double up.
	local function StyleSegment(strip, button)
		local s = strip.style
		local own = s.gap > 0
		Chrome(button, {
			bg = own and s.bg, border = own and s.border,
			highlight = s.highlight, borderSize = s.borderSize,
		})

		if s.mark then
			if not button.mark then button.mark = button:CreateTexture(nil, "OVERLAY") end
			local mark = button.mark
			mark:ClearAllPoints()
			local side = s.markSide or "TOP"
			if side == "LEFT" or side == "RIGHT" then
				mark:SetPoint("TOP" .. side)
				mark:SetPoint("BOTTOM" .. side)
				mark:SetWidth(s.markSize)
			else
				mark:SetPoint(side .. "LEFT")
				mark:SetPoint(side .. "RIGHT")
				mark:SetHeight(s.markSize)
			end
			UI.Paint(mark, s.mark, "fill")
		elseif button.mark then
			button.mark:Hide()
		end

		UI.SetFontTemplate(button.label, s.font)
	end

	local function Segment(strip, index)
		local button = strip.buttons[index]
		if button then return button end

		button = CreateFrame("Button", nil, strip)
		button.strip = strip
		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

		button.label = UI.Text(button, "", strip.style.font)
		button.label:SetJustifyH("CENTER")
		button.label:SetWordWrap(false)

		button:SetScript("OnClick", SegmentClick)
		button:SetScript("OnEnter", SegmentEnter)
		button:SetScript("OnLeave", SegmentLeave)

		StyleSegment(strip, button)
		strip.buttons[index] = button
		return button
	end

	local function Strip(kind, parent, width, opts)
		if type(width) == "table" then opts, width = width, nil end
		opts = opts or {}
		local style = StyleFor(kind, opts)

		local strip = CreateFrame("Frame", nil, parent)
		strip:SetSize(width or 1, style.height)
		Base(strip, opts)
		strip.style, strip.kind = style, kind
		strip.buttons, strip.visible, strip.values = {}, {}, {}
		strip.multi = opts.multi
		strip.align = opts.align
		strip.OnSelect = opts.onSelect
		strip.OnLayout = opts.onLayout
		strip.lines = 1

		-- segmented fills its width, tabs fit their labels. no width means the strip
		-- sizes itself to what's in it.
		local fill = opts.fill
		if fill == nil then fill = kind == "segmented" and width ~= nil end
		local wrap = opts.wrap
		if wrap == nil then wrap = kind == "tabs" and width ~= nil end

		local function Chromed()
			local s = strip.style
			local flush = s.gap <= 0
			Chrome(strip, { bg = flush and s.bg, border = flush and s.border, borderSize = s.borderSize })
		end

		function strip:Layout()
			local s = self.style
			local items = self.visible
			local count = #items
			local total = self:GetWidth()
			local lineGap = s.lineGap or 2
			local each = fill and count > 0 and (total - s.gap * (count - 1)) / count

			local x, y, lines = 0, 0, 1
			for index = 1, count do
				local item = items[index]
				local button = Segment(self, index)
				button.item = item

				local text = Resolve(item.text, item) or ""
				button.label:SetText(text)

				-- icon on the left of the label, or on its own when there's no text.
				local iconRoom = 0
				if item.icon or item.iconAtlas then
					if not button.icon then
						button.icon = button:CreateTexture(nil, "ARTWORK")
						button.icon:SetSize(14, 14)
					end
					if item.iconAtlas then
						button.icon:SetAtlas(item.iconAtlas)
					else
						button.icon:SetTexture(item.icon)
					end
					button.icon:Show()
					iconRoom = text ~= "" and 18 or 14
				elseif button.icon then
					button.icon:Hide()
				end

				if item.badge ~= nil then
					button.badge = button.badge or UI.Badge(button, nil, { style = "dim", hideEmpty = true })
					button.badge:SetText(Resolve(item.badge, item))
					button.badge:ClearAllPoints()
					button.badge:SetPoint("RIGHT", -5, 0)
				elseif button.badge then
					button.badge:Hide()
				end
				local badgeRoom = button.badge and button.badge:IsShown() and button.badge:GetWidth() + 4 or 0

				local w = item.width or each
					or math.max(s.minWidth, math.ceil(TextWidth(button.label) + s.padding + iconRoom + badgeRoom))

				if wrap and x > 0 and x + w > total + 0.5 then
					x, y, lines = 0, y + s.height + lineGap, lines + 1
				end

				button:ClearAllPoints()
				button:SetSize(w, s.height)
				if self.align == "RIGHT" then
					button:SetPoint("TOPRIGHT", -x, -y)
				else
					button:SetPoint("TOPLEFT", x, -y)
				end

				button.label:ClearAllPoints()
				if button.icon and button.icon:IsShown() then
					if text == "" then
						button.icon:ClearAllPoints()
						button.icon:SetPoint("CENTER")
					else
						button.label:SetPoint("CENTER", (iconRoom - badgeRoom) / 2, 0)
						button.icon:ClearAllPoints()
						button.icon:SetPoint("RIGHT", button.label, "LEFT", -4, 0)
					end
				else
					button.label:SetPoint("CENTER", -badgeRoom / 2, 0)
				end

				-- a thin line between flush buttons.
				if s.gap <= 0 and s.divider and index > 1 then
					if not button.divider then
						button.divider = button:CreateTexture(nil, "BORDER")
						button.divider:SetWidth(1)
						button.divider:SetPoint("TOPLEFT", 0, -3)
						button.divider:SetPoint("BOTTOMLEFT", 0, 3)
					end
					UI.Paint(button.divider, s.divider, "fill")
					button.divider:Show()
				elseif button.divider then
					button.divider:Hide()
				end

				button:Show()
				x = x + w + s.gap
			end

			for index = count + 1, #self.buttons do
				self.buttons[index].item = nil
				self.buttons[index]:Hide()
			end

			self.lines = lines
			local height = lines * s.height + (lines - 1) * lineGap
			self:SetHeight(height)
			if not width and not fill then self:SetWidth(math.max(1, x - s.gap)) end

			self:Refresh()
			if self.OnLayout then self.OnLayout(lines, height, self) end
		end

		function strip:Refresh()
			for _, button in ipairs(self.buttons) do
				if button.item then PaintSegment(button) end
			end
		end

		-- resolves the items again and lays the strip out.
		function strip:Reload()
			Selectable(Resolve(self.source, self), self.visible)
			self:Layout()
		end

		function strip:SetItems(items)
			self.source = items
			if type(items) == "table" then self.items = items end
			self:Reload()
		end

		function strip:SetValue(value)
			self.value = value
			self:Refresh()
		end

		function strip:GetValue()
			return self.value
		end

		function strip:SetValues(values)
			wipe(self.values)
			for value, on in pairs(values or {}) do
				if on then self.values[value] = true end
			end
			self:Refresh()
		end

		function strip:GetValues()
			return self.values
		end

		function strip:GetLines()
			return self.lines
		end

		function strip:SetStyle(newStyle, overrides)
			self.style = UI.Style(kind, newStyle, overrides)
			Chromed()
			for _, button in ipairs(self.buttons) do StyleSegment(self, button) end
			self:Layout()
		end

		strip:SetScript("OnSizeChanged", function(self, newWidth)
			if (fill or wrap) and self.lastWidth ~= newWidth then
				self.lastWidth = newWidth
				self:Layout()
			end
		end)

		Chromed()
		if opts.items then strip:SetItems(opts.items) end
		if opts.values then strip:SetValues(opts.values) end
		if opts.value ~= nil then strip:SetValue(opts.value) end
		return strip
	end

	SegmentClick = function(button, mouseButton)
		local strip, item = button.strip, button.item
		if not item or strip.disabled or Resolve(item.disabled, item) then return end

		if item.func then item.func(item.value, item, mouseButton) end
		if strip.multi then
			strip.values[item.value] = not strip.values[item.value] or nil
		else
			strip.value = item.value
		end
		strip:Refresh()

		if strip.OnSelect then strip.OnSelect(item.value, item, strip.multi and strip.values or nil) end
	end

	SegmentEnter = function(button)
		button.hovered = true
		if button.item then
			PaintSegment(button)
			ItemTooltip(button, button.item)
		end
	end

	SegmentLeave = function(button)
		button.hovered = false
		if button.item then PaintSegment(button) end
		if button.tipShown then
			button.tipShown = nil
			GameTooltip:Hide()
		end
	end

	-- width can be skipped for opts. opts takes style, items, value, multi,
	-- values, fill, wrap, align, onSelect and onLayout(lines, height).
	function UI.Segmented(parent, width, opts)
		return Strip("segmented", parent, width, opts)
	end

	function UI.Tabs(parent, width, opts)
		return Strip("tabs", parent, width, opts)
	end

	--------------------------------------------------------------------------------
	-- Cycle
	--
	-- one button that steps through the items. left click or the right arrow goes
	-- forward, right click or the left arrow goes back.
	--------------------------------------------------------------------------------

	-- width can be skipped for opts. opts takes style, items, value, placeholder,
	-- wrap (false stops at the ends), wheel and onSelect.
	function UI.Cycle(parent, width, opts)
		if type(width) == "table" then opts, width = width, nil end
		opts = opts or {}
		local style = StyleFor("cycle", opts)

		local cycle = CreateFrame("Button", nil, parent)
		cycle:SetSize(width or style.width, style.height)
		cycle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		Base(cycle, opts)
		cycle.style = style
		Chrome(cycle, style)
		cycle.visible, cycle.values = {}, {}
		cycle.placeholder = opts.placeholder
		cycle.OnSelect = opts.onSelect

		cycle.back = UI.Chevron(cycle, style.arrowSize, style.arrowColor, "left")
		cycle.back:SetPoint("LEFT", 6, 0)
		cycle.forward = UI.Chevron(cycle, style.arrowSize, style.arrowColor, "right")
		cycle.forward:SetPoint("RIGHT", -6, 0)

		cycle.label = UI.Text(cycle, "", style.font)
		cycle.label:SetPoint("LEFT", 18, 0)
		cycle.label:SetPoint("RIGHT", -18, 0)
		cycle.label:SetJustifyH("CENTER")
		cycle.label:SetWordWrap(false)

		function cycle:Refresh()
			local s = self.style
			local enabled = self:IsEnabled()
			local item = FindItem(self.visible, self.value)
			local color = not enabled and s.disabledText or (item and item.color) or s.text
			UI.Paint(self.label, color, "text")
			local arrow = not enabled and s.disabledText or (self.hovered and "accent") or s.arrowColor
			self.back:SetColor(arrow)
			self.forward:SetColor(arrow)
		end

		function cycle:UpdateLabel()
			local item = FindItem(self.visible, self.value)
			local text = item and (item.selectedText or Resolve(item.text, item))
			self.label:SetText(text or self.placeholder or "")
			self:Refresh()
		end

		function cycle:Reload()
			Selectable(Resolve(self.source, self), self.visible)
			self:UpdateLabel()
		end

		function cycle:SetItems(items)
			self.source = items
			if type(items) == "table" then self.items = items end
			self:Reload()
		end

		function cycle:SetValue(value)
			self.value = value
			self:UpdateLabel()
		end

		function cycle:GetValue()
			return self.value
		end

		-- a cycle holds one value, these are here so it answers like the rest.
		function cycle:SetValues(values)
			for value, on in pairs(values or {}) do
				if on then return self:SetValue(value) end
			end
		end

		function cycle:GetValues()
			wipe(self.values)
			if self.value ~= nil then self.values[self.value] = true end
			return self.values
		end

		-- moves by delta, skipping disabled items.
		function cycle:Step(delta)
			local list = self.visible
			local count = #list
			if count == 0 then return end

			local index = 0
			for i = 1, count do
				if list[i].value == self.value then index = i break end
			end

			for _ = 1, count do
				index = index + delta
				if opts.wrap == false then
					if index < 1 or index > count then return end
				else
					index = (index - 1) % count + 1
				end
				local item = list[index]
				if not Resolve(item.disabled, item) then
					self:SetValue(item.value)
					if item.func then item.func(item.value, item) end
					if self.OnSelect then self.OnSelect(item.value, item) end
					return
				end
			end
		end

		function cycle:SetStyle(newStyle, overrides)
			self.style = UI.Style("cycle", newStyle, overrides)
			Chrome(self, self.style)
			self:SetHeight(self.style.height)
			self:Refresh()
		end

		cycle:SetScript("OnClick", function(self, mouseButton)
			if mouseButton == "RightButton" then return self:Step(-1) end

			-- the left third steps back, the way the arrow on it says.
			local x = GetCursorPosition() / self:GetEffectiveScale()
			local left = self:GetLeft() or 0
			self:Step(x < left + self:GetWidth() / 3 and -1 or 1)
		end)

		if opts.wheel then
			cycle:EnableMouseWheel(true)
			cycle:SetScript("OnMouseWheel", function(self, delta) self:Step(-delta) end)
		end

		cycle:SetScript("OnEnter", function(self)
			self.hovered = true
			self:Refresh()
			local item = FindItem(self.visible, self.value)
			if item and (item.tooltip or item.tooltipFunc) then
				ItemTooltip(self, item)
			else
				UI.ShowTooltip(self)
			end
		end)
		cycle:SetScript("OnLeave", function(self)
			self.hovered = false
			self.tipShown = nil
			self:Refresh()
			UI.HideTooltip(self)
		end)
		cycle:SetScript("OnEnable", cycle.Refresh)
		cycle:SetScript("OnDisable", cycle.Refresh)

		if opts.items then cycle:SetItems(opts.items) end
		cycle:SetValue(opts.value)
		return cycle
	end

	--------------------------------------------------------------------------------
	-- Radio group
	--
	-- a radio per item, stacked down or across. multi swaps them for checkboxes.
	--------------------------------------------------------------------------------

	-- width can be skipped for opts. opts takes style, items, value, multi, values,
	-- horizontal, onSelect and onLayout(height).
	function UI.RadioGroup(parent, width, opts)
		if type(width) == "table" then opts, width = width, nil end
		opts = opts or {}
		local style = StyleFor("radiogroup", opts)

		local group = CreateFrame("Frame", nil, parent)
		group:SetSize(width or 1, style.lineHeight)
		Base(group, opts)
		group.style = style
		group.boxes, group.visible, group.values = {}, {}, {}
		group.multi = opts.multi
		group.OnSelect = opts.onSelect
		group.OnLayout = opts.onLayout

		local function Box(index)
			local box = group.boxes[index]
			if box then return box end

			local build = group.multi and UI.Checkbox or UI.Radio
			box = build(group, { style = group.multi and "default" or style.radio })
			box.OnChange = function(state, clicked)
				local item = clicked.item
				if not item then return end
				if group.multi then
					group.values[item.value] = state or nil
				else
					group.value = item.value
				end
				group:Refresh()
				if item.func then item.func(item.value, item) end
				if group.OnSelect then group.OnSelect(item.value, item, group.multi and group.values or nil) end
			end
			group.boxes[index] = box
			return box
		end

		function group:Layout()
			local s = self.style
			local x, y = 0, 0
			for index, item in ipairs(self.visible) do
				local box = Box(index)
				box.item = item
				box:SetLabel(Resolve(item.text, item))
				box.tipTitle = item.tooltip and (item.tooltipTitle or item.text) or nil
				box.tipBody = item.tooltip

				box:ClearAllPoints()
				local offset = (s.lineHeight - box:GetHeight()) / 2
				box:SetPoint("TOPLEFT", x, -y - offset)
				box:Show()

				if opts.horizontal then
					x = x + box:GetWidth() + (box.text and TextWidth(box.text) + box.style.gap or 0) + s.horizontalGap
				else
					y = y + s.lineHeight
				end
			end

			for index = #self.visible + 1, #self.boxes do
				self.boxes[index].item = nil
				self.boxes[index]:Hide()
			end

			local height = opts.horizontal and s.lineHeight or math.max(s.lineHeight, y)
			self:SetHeight(height)
			if opts.horizontal and not width then self:SetWidth(math.max(1, x - s.horizontalGap)) end

			self:Refresh()
			if self.OnLayout then self.OnLayout(height, self) end
		end

		function group:Refresh()
			for _, box in ipairs(self.boxes) do
				local item = box.item
				if item then
					if self.multi then
						box:SetChecked(self.values[item.value] == true)
					else
						box:SetChecked(self.value ~= nil and item.value == self.value)
					end
					box:SetEnabled(not self.disabled and not Resolve(item.disabled, item))
				end
			end
		end

		function group:Reload()
			Selectable(Resolve(self.source, self), self.visible)
			self:Layout()
		end

		function group:SetItems(items)
			self.source = items
			if type(items) == "table" then self.items = items end
			self:Reload()
		end

		function group:SetValue(value)
			self.value = value
			self:Refresh()
		end

		function group:GetValue()
			return self.value
		end

		function group:SetValues(values)
			wipe(self.values)
			for value, on in pairs(values or {}) do
				if on then self.values[value] = true end
			end
			self:Refresh()
		end

		function group:GetValues()
			return self.values
		end

		if opts.items then group:SetItems(opts.items) end
		if opts.values then group:SetValues(opts.values) end
		if opts.value ~= nil then group:SetValue(opts.value) end
		return group
	end

	--------------------------------------------------------------------------------
	-- Choice
	--------------------------------------------------------------------------------

	-- every kind takes (parent, width, opts) with the same items, value and
	-- onSelect, so swapping how a pick looks is changing kind.
	UI.choices = {
		dropdown = UI.Dropdown,
		segmented = UI.Segmented,
		tabs = UI.Tabs,
		cycle = UI.Cycle,
		radio = UI.RadioGroup,
	}

	function UI.RegisterChoice(kind, build)
		UI.choices[kind] = build
	end

	function UI.Choice(kind, parent, width, opts)
		local build = UI.choices[kind or "dropdown"] or UI.Dropdown
		return build(parent, width, opts)
	end

	-- the dropdown gets a Reload too, so all of them answer the same.
	local Dropdown = UI.Dropdown
	function UI.Dropdown(parent, width, opts)
		local dd = Dropdown(parent, width, opts)
		function dd:Reload()
			self:UpdateLabel()
			self.menu:Redraw()
		end
		return dd
	end
	UI.choices.dropdown = UI.Dropdown
end)
