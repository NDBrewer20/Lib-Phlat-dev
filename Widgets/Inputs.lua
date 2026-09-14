local lib = LibStub("LibPhlat-1.0")
if not lib.loading then return end

lib:Module("Inputs", function(UI, P)
	local Resolve = P.Resolve
	local Merge = P.Merge
	local Snap = P.Snap
	local Clamp = P.Clamp
	local StyleFor = P.StyleFor
	local Chrome = P.Chrome
	local Base = P.Base
	local TextWidth = P.TextWidth
	local SelectedWash = P.SelectedWash
	local SetControlEnabled = P.SetControlEnabled

	P.Defaults(UI, "stepper", {
		default = {
			width = 90, height = 22, bg = "control", border = "border", font = "small",
			text = "text", glyphSize = 8, glyphPad = 8,
		},
	})

	P.Defaults(UI, "range", {
		default = {
			height = 18, track = "track", trackSize = 4, fill = "accent:0.55",
			thumb = "accent", thumbWidth = 8, thumbHeight = 16,
		},
	})

	P.Defaults(UI, "tag", {
		default = {
			height = 18, bg = "accent:0.25", border = false, text = "text", font = "small",
			padding = 6, gap = 4, closeSize = 7, lineGap = 4, inset = 4, boxWidth = 60,
		},
	})

	P.Defaults(UI, "rating", {
		default = { size = 12, gap = 3, on = "accent", off = "track", hover = "accent:0.6" },
	})

	P.Defaults(UI, "calendar", {
		default = {
			cell = 24, gap = 2, pad = 6, headerHeight = 22, bg = "popup", border = "border",
			font = "small", text = "text", dim = "disabled", weekday = "dim", today = "accent",
			selected = "accent:0.35", highlight = "accent:0.18",
		},
	})

	--------------------------------------------------------------------------------
	-- Stepper
	--------------------------------------------------------------------------------

	-- a number with minus and plus either side. shift steps by bigStep, holding a
	-- button repeats, the wheel steps too. opts takes min, max, step, bigStep,
	-- value, format, style and onChange(value).
	function UI.Stepper(parent, width, opts)
		if type(width) == "table" then opts, width = width, nil end
		opts = opts or {}
		local style = StyleFor("stepper", opts)
		local min, max, step = opts.min or 0, opts.max or 100, opts.step or 1
		local numberFormat = opts.format or "%d"

		local stepper = CreateFrame("Frame", nil, parent)
		stepper:SetSize(width or style.width, style.height)
		stepper:EnableMouseWheel(true)
		Base(stepper, opts)
		stepper.style = style
		Chrome(stepper, style)

		local buttonSize = style.glyphSize + style.glyphPad
		stepper.minus = UI.GlyphButton(stepper, style.glyphSize, "minus")
		stepper.minus:SetPoint("LEFT", 2, 0)
		stepper.plus = UI.GlyphButton(stepper, style.glyphSize, "plus")
		stepper.plus:SetPoint("RIGHT", -2, 0)

		local box = UI.EditBox(stepper, (width or style.width) - buttonSize * 2 - 4, style.height - 2, { style = "ghost" })
		box:SetPoint("CENTER")
		box:SetJustifyH("CENTER")
		box:SetTextInsets(0, 0, 0, 0)
		stepper.box = box

		local function Show()
			if not box:HasFocus() then box:SetText(numberFormat:format(stepper.value)) end
			local enabled = stepper:IsEnabled()
			SetControlEnabled(stepper.minus, enabled and stepper.value > min)
			SetControlEnabled(stepper.plus, enabled and stepper.value < max)
			SetControlEnabled(box, enabled)
		end

		function stepper:SetValue(value, silent)
			value = Clamp(Snap(tonumber(value) or min, min, step), min, max)
			local changed = value ~= self.value
			self.value = value
			Show()
			if changed and not silent and opts.onChange then opts.onChange(value, self) end
		end

		function stepper:GetValue()
			return self.value
		end

		function stepper:SetRange(newMin, newMax, newStep)
			min, max, step = newMin or min, newMax or max, newStep or step
			self:SetValue(self.value, true)
		end

		function stepper:Step(direction)
			local amount = IsShiftKeyDown() and (opts.bigStep or step * 10) or step
			self:SetValue(self.value + direction * amount)
		end

		function stepper:Refresh()
			Show()
		end

		-- holding a button repeats after a short wait.
		local ticker
		local function Hold(button, direction)
			button:SetScript("OnMouseDown", function(self)
				if not self:IsEnabled() then return end
				stepper:Step(direction)
				ticker = C_Timer.NewTimer(0.4, function()
					ticker = C_Timer.NewTicker(0.06, function() stepper:Step(direction) end)
				end)
			end)
			button:SetScript("OnMouseUp", function()
				if ticker then ticker:Cancel() ticker = nil end
			end)
			button:HookScript("OnHide", function()
				if ticker then ticker:Cancel() ticker = nil end
			end)
		end
		Hold(stepper.minus, -1)
		Hold(stepper.plus, 1)

		stepper:SetScript("OnMouseWheel", function(self, delta)
			if self:IsEnabled() then self:Step(delta) end
		end)

		box:SetScript("OnEnterPressed", box.ClearFocus)
		box:HookScript("OnEditFocusLost", function(self)
			stepper:SetValue(self:GetText())
			Show()
		end)

		stepper.value = min
		stepper:SetValue(opts.value or min, true)
		return stepper
	end

	--------------------------------------------------------------------------------
	-- Range slider
	--------------------------------------------------------------------------------

	-- two thumbs for a low and a high end. opts takes min, max, step, low, high,
	-- minGap, style, live (report while dragging) and onChange(low, high).
	function UI.RangeSlider(parent, width, opts)
		opts = opts or {}
		local style = StyleFor("range", opts)
		local min, max, step = opts.min or 0, opts.max or 100, opts.step or 1

		local range = CreateFrame("Frame", nil, parent)
		range:SetSize(width, style.height)
		range:EnableMouse(true)
		range:SetHitRectInsets(0, 0, -4, -4)
		Base(range, opts)
		range.style = style

		local track = range:CreateTexture(nil, "BACKGROUND")
		track:SetHeight(style.trackSize)
		track:SetPoint("LEFT")
		track:SetPoint("RIGHT")
		UI.Paint(track, style.track, "fill")

		local fill = range:CreateTexture(nil, "ARTWORK")
		fill:SetHeight(style.trackSize)
		UI.Paint(fill, style.fill, "fill")

		local thumbs = {}
		for i = 1, 2 do
			thumbs[i] = range:CreateTexture(nil, "OVERLAY")
			thumbs[i]:SetSize(style.thumbWidth, style.thumbHeight)
			UI.Paint(thumbs[i], style.thumb, "fill")
		end
		range.thumbs = thumbs

		local function X(value)
			local span = max - min
			local travel = range:GetWidth() - style.thumbWidth
			return span > 0 and (value - min) / span * travel or 0
		end

		local function Draw()
			thumbs[1]:ClearAllPoints()
			thumbs[1]:SetPoint("LEFT", X(range.low), 0)
			thumbs[2]:ClearAllPoints()
			thumbs[2]:SetPoint("LEFT", X(range.high), 0)
			fill:ClearAllPoints()
			fill:SetPoint("LEFT", thumbs[1], "CENTER")
			fill:SetPoint("RIGHT", thumbs[2], "CENTER")
		end

		function range:SetValue(low, high, silent)
			local gap = opts.minGap or 0
			low = Clamp(Snap(low or min, min, step), min, max)
			high = Clamp(Snap(high or max, min, step), min, max)
			if high - low < gap then high = math.min(max, low + gap) low = high - gap end
			self.low, self.high = low, high
			Draw()
			if not silent and opts.onChange then opts.onChange(low, high, self) end
		end

		function range:GetValue()
			return self.low, self.high
		end

		function range:SetBounds(newMin, newMax, newStep)
			min, max, step = newMin or min, newMax or max, newStep or step
			self:SetValue(self.low, self.high, true)
		end

		function range:Refresh()
			local alpha = self:IsEnabled() and 1 or 0.35
			thumbs[1]:SetAlpha(alpha)
			thumbs[2]:SetAlpha(alpha)
			fill:SetAlpha(alpha)
		end

		local function CursorValue()
			local x = GetCursorPosition() / range:GetEffectiveScale()
			local travel = range:GetWidth() - style.thumbWidth
			local percent = travel > 0 and (x - (range:GetLeft() or 0) - style.thumbWidth / 2) / travel or 0
			return min + Clamp(percent, 0, 1) * (max - min)
		end

		-- takes whichever thumb is nearer and drags it until the mouse comes up.
		range:SetScript("OnMouseDown", function(self)
			if not self:IsEnabled() then return end
			local value = CursorValue()
			local which = math.abs(value - self.low) <= math.abs(value - self.high) and 1 or 2
			if self.low == self.high then which = value < self.low and 1 or 2 end

			self:SetScript("OnUpdate", function()
				local v = CursorValue()
				if which == 1 then
					self:SetValue(math.min(v, self.high), self.high, not opts.live)
				else
					self:SetValue(self.low, math.max(v, self.low), not opts.live)
				end
			end)
		end)
		range:SetScript("OnMouseUp", function(self)
			if not self:GetScript("OnUpdate") then return end
			self:SetScript("OnUpdate", nil)
			if opts.onChange then opts.onChange(self.low, self.high, self) end
		end)
		range:SetScript("OnSizeChanged", Draw)

		range:SetValue(opts.low or min, opts.high or max, true)
		return range
	end

	--------------------------------------------------------------------------------
	-- Combo box
	--------------------------------------------------------------------------------

	-- type, or pick from what matches. items is a list, or a function(text)
	-- returning the matches itself. opts takes items, value, placeholder, maxRows,
	-- strict (only listed values), minChars, style, menuStyle, onChange(text) and
	-- onSelect(value, item).
	function UI.ComboBox(parent, width, opts)
		opts = opts or {}

		local combo = CreateFrame("Frame", nil, parent)
		combo:SetSize(width, 22)
		Base(combo, opts)
		combo.matches = {}

		local menu = UI.NewMenu({
			style = opts.menuStyle, maxRows = opts.maxRows or 8,
			noMatchText = opts.noMatchText,
		})
		combo.menu = menu

		local function Items(text)
			if type(opts.items) == "function" then return opts.items(text) or {} end
			local out = wipe(combo.matches)
			local query = text and text ~= "" and text:lower()
			for _, item in ipairs(combo.items or opts.items or {}) do
				local label = item.text and tostring(item.text):lower()
				if not query or item.header or (label and label:find(query, 1, true)) then
					out[#out + 1] = item
				end
			end
			return out
		end

		local box = UI.EditBox(combo, width, 22, {
			style = opts.style, placeholder = opts.placeholder,
			onChange = function(text)
				combo.value = nil
				if opts.onChange then opts.onChange(text, combo) end
				if #text < (opts.minChars or 0) then return menu:Close() end
				local matches = Items(text)
				if #matches > 0 then menu:Open(matches) else menu:Close() end
			end,
			onEnter = function(text)
				if menu:IsOpen() then
					for _, item in ipairs(menu.panels[1].visible or {}) do
						if not item.header and not item.separator then return menu:Pick(item) end
					end
				end
				if opts.onCommit then opts.onCommit(text, combo) end
			end,
			onEscape = function() menu:Close() end,
		})
		box:SetPoint("LEFT")
		box:SetTextInsets(7, 22, 0, 0)
		combo.box = box
		menu:AnchorTo(box)

		combo.arrow = UI.GlyphButton(box, 9, "chevron")
		combo.arrow:SetPoint("RIGHT", -2, 0)
		combo.arrow:SetScript("OnClick", function()
			if menu:IsOpen() then return menu:Close() end
			menu:Open(Items(nil))
		end)

		menu.OnPick = function(value, item)
			combo.value = value
			box:SetText(item.selectedText or item.text or "")
			box:ClearFocus()
			if opts.onSelect then opts.onSelect(value, item, combo) end
		end

		-- strict puts the last good pick back when what was typed isn't one.
		box:HookScript("OnEditFocusLost", function(self)
			if not opts.strict or combo.value ~= nil then return end
			local typed = self:GetText():lower()
			for _, item in ipairs(combo.items or (type(opts.items) == "table" and opts.items) or {}) do
				if item.text and tostring(item.text):lower() == typed then
					combo.value = item.value
					return
				end
			end
			combo:SetValue(combo.lastValue)
		end)

		function combo:SetItems(items)
			self.items = items
		end

		function combo:SetValue(value)
			self.value, self.lastValue = value, value
			local item = UI.FindItem(self.items or (type(opts.items) == "table" and opts.items) or {}, value)
			box:SetText(item and (item.selectedText or item.text) or (value ~= nil and tostring(value)) or "")
		end

		function combo:GetValue()
			return self.value
		end

		function combo:GetText()
			return box:GetText()
		end

		function combo:Refresh()
			SetControlEnabled(box, self:IsEnabled())
			SetControlEnabled(self.arrow, self:IsEnabled())
		end

		if opts.value ~= nil then combo:SetValue(opts.value) end
		return combo
	end

	--------------------------------------------------------------------------------
	-- Tag input
	--------------------------------------------------------------------------------

	-- tags as chips with a cross each and a box on the end for more. enter or a
	-- comma adds one, backspace in an empty box takes the last. opts takes tags,
	-- max, unique (default true), placeholder, style and onChange(tags).
	function UI.TagInput(parent, width, opts)
		opts = opts or {}
		local style = StyleFor("tag", opts)
		local boxStyle = UI.Style("editbox")

		local input = CreateFrame("Frame", nil, parent)
		input:SetSize(width, style.height + style.inset * 2)
		input:EnableMouse(true)
		Base(input, opts)
		input.style = style
		Chrome(input, { bg = boxStyle.bg, border = boxStyle.border })
		input.tags, input.chips = {}, {}

		local box = UI.EditBox(input, style.boxWidth, style.height, { style = "ghost", placeholder = opts.placeholder })
		box:SetTextInsets(2, 2, 0, 0)
		input.box = box

		local function Changed()
			input:Layout()
			if opts.onChange then opts.onChange(input.tags, input) end
		end

		local function Chip(index)
			local chip = input.chips[index]
			if chip then return chip end

			chip = CreateFrame("Frame", nil, input)
			chip:SetHeight(style.height)
			Chrome(chip, style)
			chip.label = UI.Text(chip, "", style.font, style.text)
			chip.label:SetPoint("LEFT", style.padding, 0)
			chip.close = UI.GlyphButton(chip, style.closeSize, "cross", "Remove")
			chip.close:SetPoint("RIGHT", -1, 0)
			chip.close:SetScript("OnClick", function() input:RemoveTag(chip.index) end)

			input.chips[index] = chip
			return chip
		end

		function input:Layout()
			local x, y = style.inset, style.inset
			local right = width - style.inset

			for index, tag in ipairs(self.tags) do
				local chip = Chip(index)
				chip.index = index
				chip.label:SetText(tag)
				local w = math.ceil(TextWidth(chip.label) + style.padding + style.closeSize + 10)
				if x > style.inset and x + w > right then
					x, y = style.inset, y + style.height + style.lineGap
				end
				chip:SetWidth(w)
				chip:ClearAllPoints()
				chip:SetPoint("TOPLEFT", x, -y)
				chip:Show()
				x = x + w + style.gap
			end
			for index = #self.tags + 1, #self.chips do self.chips[index]:Hide() end

			-- the box takes the rest of the line, or starts a new one.
			if x > style.inset and x + style.boxWidth > right then
				x, y = style.inset, y + style.height + style.lineGap
			end
			box:ClearAllPoints()
			box:SetPoint("TOPLEFT", x, -y)
			box:SetWidth(math.max(style.boxWidth, right - x))
			box:SetShown(not opts.max or #self.tags < opts.max)
			if box.hintText then box.hintText:SetShown(#self.tags == 0 and box:GetText() == "" and not box:HasFocus()) end

			local height = y + style.height + style.inset
			self:SetHeight(height)
			if self.OnLayout then self.OnLayout(height, self) end
		end

		function input:AddTag(text)
			text = text and strtrim(text) or ""
			if text == "" then return false end
			if opts.max and #self.tags >= opts.max then return false end
			if opts.unique ~= false then
				for _, tag in ipairs(self.tags) do
					if tag:lower() == text:lower() then return false end
				end
			end
			self.tags[#self.tags + 1] = text
			Changed()
			return true
		end

		function input:RemoveTag(index)
			if not self.tags[index] then return end
			table.remove(self.tags, index)
			Changed()
		end

		-- copied in, so the caller's list is left alone.
		function input:SetTags(tags)
			wipe(self.tags)
			for index, tag in ipairs(tags or {}) do self.tags[index] = tag end
			self:Layout()
		end

		function input:GetTags()
			return self.tags
		end

		box:SetScript("OnEnterPressed", function(self)
			if input:AddTag(self:GetText()) then self:SetText("") end
		end)
		box:SetScript("OnChar", function(self, char)
			if char ~= "," then return end
			local text = self:GetText():gsub(",", "")
			if input:AddTag(text) then self:SetText("") else self:SetText(text) end
		end)
		box:SetScript("OnKeyDown", function(self, key)
			if key == "BACKSPACE" and self:GetText() == "" and #input.tags > 0 then
				input:RemoveTag(#input.tags)
			end
		end)
		input:SetScript("OnMouseDown", function() box:SetFocus() end)

		input:SetTags(opts.tags)
		return input
	end

	--------------------------------------------------------------------------------
	-- Split button
	--------------------------------------------------------------------------------

	-- a button for the main action with an arrow beside it for the rest. opts takes
	-- style, onClick, items, onSelect(value, item) and anything a menu takes.
	function UI.SplitButton(parent, text, width, opts)
		opts = opts or {}
		local height = opts.height or UI.Style("button", opts.style).height
		local arrowWidth = opts.arrowWidth or 20

		local split = CreateFrame("Frame", nil, parent)
		split:SetSize(width or 150, height)
		Base(split, opts)

		split.button = UI.Button(split, text, (width or 150) - arrowWidth + 1, height, { style = opts.style, onClick = opts.onClick })
		split.button:SetPoint("LEFT")
		split.arrow = UI.Button(split, "", arrowWidth, height, { style = opts.style, glyph = "chevron" })
		split.arrow:SetPoint("RIGHT")

		split.menu = UI.NewMenu(Merge({ width = "auto", align = "RIGHT" }, opts.menu))
		split.menu:AnchorTo(split)
		split.menu.OnPick = function(value, item)
			if opts.onSelect then opts.onSelect(value, item, split) end
		end
		split.arrow:SetScript("OnClick", function() split.menu:Toggle(opts.items) end)

		function split:SetText(label) self.button:SetText(label) end
		function split:SetItems(items) opts.items = items self.menu:SetItems(items) end
		function split:Refresh()
			SetControlEnabled(self.button, self:IsEnabled())
			SetControlEnabled(self.arrow, self:IsEnabled())
		end
		return split
	end

	--------------------------------------------------------------------------------
	-- Rating
	--------------------------------------------------------------------------------

	-- a row of pips for a score out of max. opts takes max, value, readOnly,
	-- clearable (clicking the current score clears it), style and onChange(value).
	function UI.Rating(parent, opts)
		opts = opts or {}
		local style = StyleFor("rating", opts)
		local max = opts.max or 5

		local rating = CreateFrame("Frame", nil, parent)
		rating:SetSize(max * (style.size + style.gap) - style.gap, style.size)
		Base(rating, opts)
		rating.style = style
		rating.value = opts.value or 0
		rating.pips = {}

		function rating:Refresh()
			local shown = self.hoverValue or self.value
			for index, pip in ipairs(self.pips) do
				local spec = style.off
				if index <= shown then spec = self.hoverValue and style.hover or style.on end
				UI.Paint(pip.tex, spec, "fill")
				pip.tex:SetAlpha(self:IsEnabled() and 1 or 0.5)
			end
		end

		function rating:SetValue(value)
			self.value = Clamp(value or 0, 0, max)
			self:Refresh()
		end

		function rating:GetValue()
			return self.value
		end

		for index = 1, max do
			local pip = CreateFrame("Button", nil, rating)
			pip:SetSize(style.size, style.size)
			pip:SetPoint("LEFT", (index - 1) * (style.size + style.gap), 0)
			pip.tex = pip:CreateTexture(nil, "ARTWORK")
			pip.tex:SetAllPoints()

			if not opts.readOnly then
				pip:SetScript("OnEnter", function()
					if not rating:IsEnabled() then return end
					rating.hoverValue = index
					rating:Refresh()
				end)
				pip:SetScript("OnLeave", function()
					rating.hoverValue = nil
					rating:Refresh()
				end)
				pip:SetScript("OnClick", function()
					if not rating:IsEnabled() then return end
					local value = index
					if opts.clearable and rating.value == index then value = 0 end
					rating:SetValue(value)
					if opts.onChange then opts.onChange(value, rating) end
				end)
			else
				pip:EnableMouse(false)
			end
			rating.pips[index] = pip
		end

		rating:Refresh()
		return rating
	end

	--------------------------------------------------------------------------------
	-- Calendar and date picker
	--------------------------------------------------------------------------------

	local WEEKDAYS = { "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" }
	local MONTHS = {
		"January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December",
	}

	local function MonthName(month)
		---@diagnostic disable-next-line: undefined-global
		local names = CALENDAR_FULLDATE_MONTH_NAMES
		return names and names[month] or MONTHS[month]
	end

	local function DaysIn(year, month)
		return date("*t", time({ year = year, month = month + 1, day = 0, hour = 12 })).day
	end

	local function Key(value)
		return value and (value.year * 10000 + value.month * 100 + value.day) or nil
	end

	-- a month of days. dates are { year, month, day } tables. opts takes value,
	-- minDate, maxDate, weekStart (1 Sunday, 2 Monday), style and onChange(date).
	function UI.Calendar(parent, opts)
		opts = opts or {}
		local style = StyleFor("calendar", opts)
		local step = style.cell + style.gap
		local width = style.pad * 2 + step * 7 - style.gap
		local height = style.pad * 2 + style.headerHeight * 2 + step * 6 - style.gap

		local cal = CreateFrame("Frame", nil, parent)
		cal:SetSize(width, height)
		cal:EnableMouse(true)
		Base(cal, opts)
		cal.style = style
		Chrome(cal, style)
		cal.cells = {}

		local today = date("*t")
		cal.year, cal.month = today.year, today.month
		if opts.value then cal.year, cal.month = opts.value.year, opts.value.month end
		cal.value = opts.value

		cal.back = UI.GlyphButton(cal, 9, "chevron", nil, nil, { facing = "left" })
		cal.back:SetPoint("TOPLEFT", style.pad - 4, -style.pad + 1)
		cal.forward = UI.GlyphButton(cal, 9, "chevron", nil, nil, { facing = "right" })
		cal.forward:SetPoint("TOPRIGHT", -style.pad + 4, -style.pad + 1)

		cal.title = UI.Text(cal, "", "caption", "text")
		cal.title:SetPoint("TOP", 0, -style.pad - 5)
		cal.title:SetJustifyH("CENTER")

		local weekStart = opts.weekStart or 1
		for column = 1, 7 do
			local label = UI.Text(cal, WEEKDAYS[(column + weekStart - 2) % 7 + 1], style.font, style.weekday)
			label:SetWidth(style.cell)
			label:SetJustifyH("CENTER")
			label:SetPoint("TOPLEFT", style.pad + (column - 1) * step, -style.pad - style.headerHeight - 4)
		end

		local top = style.pad + style.headerHeight * 2
		for index = 1, 42 do
			local cell = CreateFrame("Button", nil, cal)
			cell:SetSize(style.cell, style.cell)
			cell:SetPoint("TOPLEFT", style.pad + (index - 1) % 7 * step, -top - math.floor((index - 1) / 7) * step)
			UI.Paint(cell:CreateTexture(nil, "HIGHLIGHT"), style.highlight, "fill"):SetAllPoints()
			cell.label = UI.Text(cell, "", style.font)
			cell.label:SetPoint("CENTER")
			cell:SetScript("OnClick", function(self)
				if not self.date or self.blocked then return end
				cal:SetValue(self.date)
				if opts.onChange then opts.onChange(self.date, cal) end
			end)
			cal.cells[index] = cell
		end

		local minKey, maxKey = Key(opts.minDate), Key(opts.maxDate)

		function cal:Draw()
			self.title:SetText(("%s %d"):format(MonthName(self.month), self.year))

			local first = date("*t", time({ year = self.year, month = self.month, day = 1, hour = 12 })).wday
			local lead = (first - weekStart) % 7
			local days = DaysIn(self.year, self.month)
			local prevYear, prevMonth = self.month == 1 and self.year - 1 or self.year, self.month == 1 and 12 or self.month - 1
			local nextYear, nextMonth = self.month == 12 and self.year + 1 or self.year, self.month == 12 and 1 or self.month + 1
			local prevDays = DaysIn(prevYear, prevMonth)
			local now = date("*t")
			local selected, todayKey = Key(self.value), Key(now)

			for index, cell in ipairs(self.cells) do
				local day, year, month, inside = index - lead, self.year, self.month, true
				if day < 1 then
					day, year, month, inside = prevDays + day, prevYear, prevMonth, false
				elseif day > days then
					day, year, month, inside = day - days, nextYear, nextMonth, false
				end

				cell.date = cell.date or {}
				cell.date.year, cell.date.month, cell.date.day = year, month, day
				local key = Key(cell.date)
				cell.blocked = (minKey and key < minKey) or (maxKey and key > maxKey) or false

				cell.label:SetText(day)
				local color = style.text
				if cell.blocked or not inside then color = style.dim end
				if key == todayKey and not cell.blocked then color = style.today end
				UI.Paint(cell.label, color, "text")

				cell.selectedState = key == selected
				SelectedWash(cell, style.selected)
			end
		end

		function cal:SetMonth(year, month)
			self.year, self.month = year, month
			self:Draw()
		end

		function cal:Shift(months)
			local total = self.year * 12 + (self.month - 1) + months
			self:SetMonth(math.floor(total / 12), total % 12 + 1)
		end

		-- a copy, since the cells reuse their date tables.
		function cal:SetValue(value)
			self.value = value and { year = value.year, month = value.month, day = value.day } or nil
			if value then self.year, self.month = value.year, value.month end
			self:Draw()
		end

		function cal:GetValue()
			return self.value
		end

		cal.back:SetScript("OnClick", function() cal:Shift(-1) end)
		cal.forward:SetScript("OnClick", function() cal:Shift(1) end)
		cal:EnableMouseWheel(true)
		cal:SetScript("OnMouseWheel", function(self, delta) self:Shift(-delta) end)

		cal:Draw()
		return cal
	end

	-- a dropdown looking button that opens a calendar. opts takes value, format
	-- (a date() format), placeholder, style, calendar (its opts) and onChange(date).
	function UI.DatePicker(parent, width, opts)
		opts = opts or {}
		local picker = UI.Dropdown(parent, width, { style = opts.style, placeholder = opts.placeholder or "Pick a date" })
		local popover, calendar

		local function Label()
			local value = picker.date
			if not value then return picker:SetLabel(nil) end
			local stamp = time({ year = value.year, month = value.month, day = value.day, hour = 12 })
			picker:SetLabel(date(opts.format or "%Y-%m-%d", stamp))
		end

		function picker:SetDate(value)
			self.date = value and { year = value.year, month = value.month, day = value.day } or nil
			if calendar then calendar:SetValue(self.date) end
			Label()
		end

		function picker:GetDate()
			return self.date
		end

		picker:SetScript("OnClick", function(self)
			if not popover then
				calendar = UI.Calendar(UIParent, Merge({
					value = self.date,
					onChange = function(value)
						self:SetDate(value)
						popover:Close()
						if opts.onChange then opts.onChange(self.date, self) end
					end,
				}, opts.calendar))
				popover = UI.Popover(calendar:GetWidth(), calendar:GetHeight(), { style = "clear" })
				calendar:SetParent(popover)
				calendar:ClearAllPoints()
				calendar:SetPoint("TOPLEFT")
			end
			popover:Toggle(self)
		end)

		picker:SetDate(opts.value)
		return picker
	end
end)
