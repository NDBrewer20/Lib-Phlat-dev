local lib = LibStub("LibPhlat-1.0")
if not lib.loading then return end

lib:Module("Controls", function(UI, P, config)
	local Merge = P.Merge
	local Snap = P.Snap
	local Clamp = P.Clamp
	local SetControlEnabled = P.SetControlEnabled
	local state = P.state
	local Fill = P.Fill
	local Chrome = P.Chrome
	local StyleFor = P.StyleFor
	local TrackFont = P.TrackFont
	local FontTemplate = P.FontTemplate
	local TextWidth = P.TextWidth
	local Base = P.Base
	local HoverScripts = P.HoverScripts
	local StateColor = P.StateColor
	local SelectedWash = P.SelectedWash
	--------------------------------------------------------------------------------
	-- Button
	--------------------------------------------------------------------------------

	-- width can be skipped for opts. opts takes style, icon, glyph, onClick,
	-- onRightClick, toggle, autoWidth and tooltip.
	function UI.Button(parent, text, width, height, opts)
		if type(width) == "table" then opts, width, height = width, nil, nil end
		opts = opts or {}
		local style = StyleFor("button", opts)

		local button = CreateFrame("Button", nil, parent)
		button:SetSize(width or style.width, height or style.height)
		Base(button, opts)
		button.style = style
		Chrome(button, style)

		button.label = UI.Text(button, text, style.font)
		button.label:SetJustifyH("CENTER")

		-- icon beside the label, the pair centered unless the style says LEFT.
		local function Place()
			local s = button.style
			local label, icon = button.label, button.icon
			label:ClearAllPoints()

			if icon then
				local shift = (s.iconSize + s.iconGap) / 2
				icon:SetSize(s.iconSize, s.iconSize)
				icon:ClearAllPoints()
				if s.justify == "LEFT" then
					icon:SetPoint("LEFT", s.padding, 0)
					label:SetPoint("LEFT", icon, "RIGHT", s.iconGap, 0)
				else
					label:SetPoint("CENTER", text ~= "" and shift or 0, 0)
					icon:SetPoint("RIGHT", label, "LEFT", -s.iconGap, 0)
				end
			elseif s.justify == "LEFT" then
				label:SetPoint("LEFT", s.padding, 0)
			else
				label:SetPoint("CENTER")
			end
		end

		function button:Refresh()
			local s = self.style
			UI.Paint(self.label, StateColor(self, s, s.text), "text")
			if self.icon and self.icon.SetColor then
				self.icon:SetColor(StateColor(self, s, s.text))
			end
			if self.selectedTex then self.selectedTex:SetShown(self.selectedState == true) end
		end

		-- the native SetText needs SetFontString, which drags in Blizzard's disabled font.
		function button:SetText(label)
			self.label:SetText(label)
			if opts.autoWidth then self:FitWidth() end
		end

		function button:GetText()
			return self.label:GetText()
		end

		-- sized to its label and icon, never under min.
		function button:FitWidth(min)
			local s = self.style
			local wanted = TextWidth(self.label) + s.padding * 2
			if self.icon then wanted = wanted + s.iconSize + s.iconGap end
			self:SetWidth(math.max(min or opts.minWidth or 0, math.ceil(wanted)))
		end

		-- a glyph name, or a texture / atlas.
		function button:SetIcon(source)
			if self.icon then self.icon:Hide() end
			if not source then
				self.icon = nil
			elseif UI.glyphs[source] then
				self.icon = UI.Glyph(self, source, self.style.iconSize, self.style.text)
			else
				self.icon = UI.Icon(self, self.style.iconSize, source).texture
			end
			Place()
			self:Refresh()
		end

		function button:SetSelected(state)
			self.selectedState = state and true or false
			SelectedWash(self, self.style.selected)
			self:Refresh()
		end

		function button:GetSelected()
			return self.selectedState == true
		end

		function button:SetStyle(newStyle, overrides)
			self.style = UI.Style("button", newStyle, overrides)
			Chrome(self, self.style)
			UI.SetFontTemplate(self.label, self.style.font)
			SelectedWash(self, self.style.selected)
			Place()
			self:Refresh()
		end

		HoverScripts(button)
		button:SetScript("OnEnable", button.Refresh)
		button:SetScript("OnDisable", button.Refresh)

		-- right clicks only when asked for, so a stray one can't fire something like a reset.
		if opts.onRightClick then
			button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		end
		if opts.onClick or opts.onRightClick or opts.toggle then
			button:SetScript("OnClick", function(self, mouseButton)
				if mouseButton == "RightButton" then
					if opts.onRightClick then opts.onRightClick(self) end
					return
				end
				if opts.toggle then self:SetSelected(not self.selectedState) end
				if opts.onClick then opts.onClick(self, self.selectedState) end
			end)
		end

		if opts.icon or opts.glyph then
			button:SetIcon(opts.glyph or opts.icon)
		else
			Place()
		end
		if opts.autoWidth and not width then button:FitWidth() end
		if opts.selected then button:SetSelected(true) end

		button:Refresh()
		return button
	end

	--------------------------------------------------------------------------------
	-- Checkbox, radio and switch
	--------------------------------------------------------------------------------

	local RoundMask = P.RoundMask

	-- label text beside a box, part of what's clickable.
	local function BoxLabel(box, text)
		local s = box.style
		if not box.text then
			box.text = UI.Text(box, "", s.font)
			box.text:SetPoint("LEFT", box, "RIGHT", s.gap, 0)
		end
		box.text:SetText(text or "")
		local width = text and text ~= "" and (s.gap + TextWidth(box.text)) or 0
		box:SetHitRectInsets(0, -width, 0, 0)
	end

	local function BuildBox(kind, parent, opts)
		opts = opts or {}
		local style = StyleFor(kind, opts)

		local box = CreateFrame("Button", nil, parent)
		box:SetSize(style.size, style.size)
		Base(box, opts)
		box.style, box.kind = style, kind
		Chrome(box, style)

		if style.shape == "check" then
			box.mark = UI.Glyph(box, "check", style.size - style.markInset * 2, style.mark)
			box.mark:SetPoint("CENTER")
		else
			box.mark = box:CreateTexture(nil, "ARTWORK")
			box.mark:SetPoint("TOPLEFT", style.markInset, -style.markInset)
			box.mark:SetPoint("BOTTOMRIGHT", -style.markInset, style.markInset)
			UI.Paint(box.mark, style.mark, "fill")

			if style.shape == "round" then
				if box.edges then box.edges:SetShown(false) end
				RoundMask(box, box.bg)
				if box.highlight then RoundMask(box, box.highlight) end
				RoundMask(box, box.mark)
			end
		end
		box.mark:Hide()

		function box:SetChecked(state)
			self.checked = state and true or false
			self.mark:SetShown(self.checked)
		end

		function box:GetChecked()
			return self.checked
		end

		function box:SetLabel(text)
			BoxLabel(self, text)
			self:Refresh()
		end

		function box:Refresh()
			local enabled = self:IsEnabled()
			self.mark:SetAlpha(enabled and 1 or 0.35)
			if self.text then UI.Paint(self.text, StateColor(self, self.style), "text") end
		end

		-- a checkbox flips, a radio only ever turns on.
		box:SetScript("OnClick", function(self)
			local state = true
			if self.kind ~= "radio" then state = not self.checked end
			if state == self.checked then return end
			self:SetChecked(state)
			if opts.onChange then opts.onChange(state, self) end
			if self.OnChange then self.OnChange(state, self) end
		end)

		HoverScripts(box)
		box:SetScript("OnEnable", box.Refresh)
		box:SetScript("OnDisable", box.Refresh)

		if opts.label then BoxLabel(box, opts.label) end
		box:SetChecked(opts.checked)
		box:Refresh()
		return box
	end

	-- opts takes style, label, checked, onChange and tooltip.
	function UI.Checkbox(parent, opts)
		return BuildBox("checkbox", parent, opts)
	end

	function UI.Radio(parent, opts)
		return BuildBox("radio", parent, opts)
	end

	-- a pill with a knob that sits left for off and right for on.
	function UI.Switch(parent, opts)
		opts = opts or {}
		local style = StyleFor("switch", opts)

		local switch = CreateFrame("Button", nil, parent)
		switch:SetSize(style.width, style.height)
		Base(switch, opts)
		switch.style = style

		switch.bg = switch:CreateTexture(nil, "BACKGROUND")
		switch.bg:SetAllPoints()
		if style.border then switch.edges = UI.Border(switch, style.border) end
		if style.highlight then
			switch.highlight = switch:CreateTexture(nil, "HIGHLIGHT")
			switch.highlight:SetAllPoints()
			UI.Paint(switch.highlight, style.highlight, "fill")
		end

		local knobSize = style.height - style.inset * 2
		switch.knob = switch:CreateTexture(nil, "ARTWORK")
		switch.knob:SetSize(knobSize, knobSize)

		function switch:SetChecked(state)
			self.checked = state and true or false
			local s = self.style
			self.knob:ClearAllPoints()
			if self.checked then
				self.knob:SetPoint("RIGHT", -s.inset, 0)
			else
				self.knob:SetPoint("LEFT", s.inset, 0)
			end
			UI.Paint(self.bg, self.checked and s.trackOn or s.track, "fill")
			UI.Paint(self.knob, self.checked and s.knobOn or s.knob, "fill")
		end

		function switch:GetChecked()
			return self.checked
		end

		function switch:SetLabel(text)
			BoxLabel(self, text)
			self:Refresh()
		end

		function switch:Refresh()
			local enabled = self:IsEnabled()
			self.knob:SetAlpha(enabled and 1 or 0.35)
			self.bg:SetAlpha(enabled and 1 or 0.5)
			if self.text then UI.Paint(self.text, StateColor(self, self.style), "text") end
		end

		switch:SetScript("OnClick", function(self)
			self:SetChecked(not self.checked)
			if opts.onChange then opts.onChange(self.checked, self) end
			if self.OnChange then self.OnChange(self.checked, self) end
		end)

		HoverScripts(switch)
		switch:SetScript("OnEnable", switch.Refresh)
		switch:SetScript("OnDisable", switch.Refresh)

		if opts.label then BoxLabel(switch, opts.label) end
		switch:SetChecked(opts.checked)
		switch:Refresh()
		return switch
	end

	--------------------------------------------------------------------------------
	-- Text entry
	--------------------------------------------------------------------------------

	-- border and rule follow focus when the style has a focus color.
	local function FocusChrome(box, focused)
		local s = box.style
		if box.edges and s.focus then
			box.edges:Paint(focused and s.focus or s.border or "border")
		end
		if box.rule and s.focusRule then
			UI.Paint(box.rule, focused and s.focusRule or s.rule, "fill")
		end
	end

	-- width can be skipped for opts. opts takes style, placeholder, clearButton,
	-- search, numeric, maxLetters, onChange (typing only), debounce, onEnter,
	-- onEscape and keepFocus.
	function UI.EditBox(parent, width, height, opts)
		if type(width) == "table" then opts, width, height = width, nil, nil end
		opts = opts or {}
		local style = StyleFor("editbox", opts)

		local box = CreateFrame("EditBox", nil, parent)
		box:SetSize(width or style.width, height or style.height)
		box:SetAutoFocus(false)
		box:SetFontObject(FontTemplate(style.font))
		Base(box, opts)
		box.style = style
		Chrome(box, style)
		UI.Paint(box, style.text, "text")
		TrackFont(box)

		local left, right = style.inset, style.inset

		if opts.search then
			box.searchGlyph = UI.Glyph(box, "search", 11, style.hint)
			box.searchGlyph:SetPoint("LEFT", 6, 0)
			left = left + 12
		end

		if opts.clearButton then
			box.clear = UI.GlyphButton(box, 9, "cross", opts.clearTitle or "Clear")
			box.clear:SetPoint("RIGHT", -1, 0)
			box.clear:Hide()
			box.clear:SetScript("OnClick", function()
				box:SetText("")
				box:ClearFocus()
				if opts.onChange then opts.onChange("", box) end
				if opts.onClear then opts.onClear(box) end
			end)
			right = right + 11
		end

		box:SetTextInsets(left, right, 0, 0)
		if opts.numeric then box:SetNumeric(true) end
		if opts.maxLetters then box:SetMaxLetters(opts.maxLetters) end

		local function UpdateHint(self)
			local empty = (self:GetText() or "") == ""
			if self.hintText then self.hintText:SetShown(empty and not self:HasFocus()) end
			if self.clear then self.clear:SetShown(not empty) end
		end

		-- grey text in the box while it's empty.
		function box:SetPlaceholder(text)
			if not self.hintText then
				self.hintText = UI.Text(self, "", self.style.font, self.style.hint)
				self.hintText:SetPoint("LEFT", left + 1, 0)
				self.hintText:SetPoint("RIGHT", -right, 0)
				self.hintText:SetWordWrap(false)
			end
			self.hintText:SetText(text or "")
			UpdateHint(self)
		end

		-- sets the text without firing onChange.
		function box:SetValue(value)
			self:SetText(value == nil and "" or tostring(value))
			UpdateHint(self)
		end

		function box:GetValue()
			local text = self:GetText()
			if opts.numeric then return tonumber(text) end
			return text
		end

		function box:SetStyle(newStyle, overrides)
			self.style = UI.Style("editbox", newStyle, overrides)
			Chrome(self, self.style)
			UI.Paint(self, self.style.text, "text")
			FocusChrome(self, self:HasFocus())
		end

		local timer
		local function Changed(self)
			if not opts.onChange then return end
			if not opts.debounce then return opts.onChange(self:GetText(), self) end

			if timer then timer:Cancel() end
			timer = C_Timer.NewTimer(opts.debounce, function()
				timer = nil
				opts.onChange(box:GetText(), box)
			end)
		end

		box:SetScript("OnEscapePressed", function(self)
			if opts.onEscape then opts.onEscape(self) end
			self:ClearFocus()
		end)
		box:SetScript("OnEnterPressed", function(self)
			if opts.onEnter then opts.onEnter(self:GetText(), self) end
			if not opts.keepFocus then self:ClearFocus() end
		end)
		box:SetScript("OnEditFocusGained", function(self)
			FocusChrome(self, true)
			if self.hintText then self.hintText:Hide() end
		end)
		box:SetScript("OnEditFocusLost", function(self)
			FocusChrome(self, false)
			UpdateHint(self)
		end)
		box:SetScript("OnTextChanged", function(self, userInput)
			UpdateHint(self)
			if userInput then Changed(self) end
		end)

		box:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
		box:SetScript("OnDisable", function(self) self:SetAlpha(0.5) end)

		if opts.placeholder then box:SetPlaceholder(opts.placeholder) end
		if opts.text then box:SetValue(opts.text) end
		return box
	end

	-- edit box with the magnifier, a hint and a clear button.
	function UI.SearchBox(parent, width, height, opts)
		if type(width) == "table" then opts, width, height = width, nil, nil end
		opts = Merge({ search = true, clearButton = true, placeholder = "Search" }, opts)
		return UI.EditBox(parent, width, height, opts)
	end

	-- scrolling multi line box. opts takes style, readOnly, selectOnFocus,
	-- placeholder, maxLetters and onChange. the box itself is area.edit.
	function UI.TextArea(parent, width, height, opts)
		opts = opts or {}
		local style = StyleFor("textarea", opts)

		local area = CreateFrame("Frame", nil, parent)
		area:SetSize(width, height)
		area:EnableMouse(true)
		Base(area, opts)
		area.style = style
		Chrome(area, style)
		area.readOnly = opts.readOnly

		local scroll = CreateFrame("ScrollFrame", nil, area)
		scroll:SetPoint("TOPLEFT", style.inset, -style.inset)
		scroll:SetPoint("BOTTOMRIGHT", -style.inset - 4, style.inset)
		scroll:EnableMouseWheel(true)
		area.scroll = scroll

		local edit = CreateFrame("EditBox", nil, scroll)
		edit:SetMultiLine(true)
		edit:SetAutoFocus(false)
		edit:SetMaxLetters(opts.maxLetters or 0)
		edit:SetFontObject(FontTemplate(style.font))
		edit:SetWidth(width - style.inset * 2 - 4)
		edit:SetHeight(height - style.inset * 2)
		UI.Paint(edit, style.text, "text")
		TrackFont(edit)
		scroll:SetScrollChild(edit)
		area.edit = edit

		local thumb = area:CreateTexture(nil, "OVERLAY")
		thumb:SetWidth(3)
		UI.Paint(thumb, "thumb", "fill")

		local function Range()
			return math.max(0, edit:GetHeight() - scroll:GetHeight())
		end

		local function UpdateBar()
			local range, view = Range(), scroll:GetHeight()
			if range <= 0 then
				scroll:SetVerticalScroll(0)
				return thumb:Hide()
			end
			local size = math.max(16, view * view / edit:GetHeight())
			local offset = scroll:GetVerticalScroll() / range * (view - size)
			thumb:ClearAllPoints()
			thumb:SetPoint("TOPRIGHT", -2, -style.inset - offset)
			thumb:SetHeight(size)
			thumb:Show()
		end

		function area:ScrollTo(value)
			scroll:SetVerticalScroll(Clamp(value, 0, Range()))
			UpdateBar()
		end

		function area:SetText(text)
			self.value = text or ""
			edit:SetText(self.value)
		end

		function area:GetText()
			return edit:GetText()
		end

		function area:SetFocus() edit:SetFocus() end
		function area:ClearFocus() edit:ClearFocus() end
		function area:HighlightText(...) edit:HighlightText(...) end

		function area:Resize(newWidth, newHeight)
			self:SetSize(newWidth, newHeight)
			edit:SetWidth(newWidth - style.inset * 2 - 4)
			UpdateBar()
		end

		function area:Refresh()
			SetControlEnabled(edit, self:IsEnabled())
			edit:SetAlpha(self:IsEnabled() and 1 or 0.5)
		end

		scroll:SetScript("OnMouseWheel", function(_, delta)
			area:ScrollTo(scroll:GetVerticalScroll() - delta * style.step)
		end)
		area:SetScript("OnMouseDown", function() edit:SetFocus() end)

		-- keeps the cursor in view as it moves or the text grows.
		edit:SetScript("OnCursorChanged", function(_, _, y, _, lineHeight)
			local top, view = -y, scroll:GetHeight()
			local offset = scroll:GetVerticalScroll()
			if top < offset then
				area:ScrollTo(top)
			elseif top + lineHeight > offset + view then
				area:ScrollTo(top + lineHeight - view)
			end
		end)

		edit:SetScript("OnTextChanged", function(self, userInput)
			-- read only puts back whatever was typed over it.
			if area.readOnly and userInput then
				self:SetText(area.value or "")
				self:HighlightText()
				return
			end
			if area.hintText then area.hintText:SetShown(self:GetText() == "" and not self:HasFocus()) end
			UpdateBar()
			if userInput and opts.onChange then opts.onChange(self:GetText(), area) end
		end)

		edit:SetScript("OnSizeChanged", UpdateBar)
		edit:SetScript("OnEscapePressed", edit.ClearFocus)
		edit:SetScript("OnEditFocusGained", function(self)
			FocusChrome(area, true)
			if area.hintText then area.hintText:Hide() end
			if opts.selectOnFocus or area.readOnly then self:HighlightText() end
		end)
		edit:SetScript("OnEditFocusLost", function(self)
			FocusChrome(area, false)
			if area.hintText then area.hintText:SetShown(self:GetText() == "") end
			if opts.onCommit then opts.onCommit(self:GetText(), area) end
		end)

		if opts.placeholder then
			area.hintText = UI.Text(area, opts.placeholder, style.font, style.hint)
			area.hintText:SetPoint("TOPLEFT", style.inset + 1, -style.inset)
		end

		area:SetText(opts.text)
		UpdateBar()
		return area
	end

	--------------------------------------------------------------------------------
	-- Slider
	--------------------------------------------------------------------------------

	-- opts takes style, orientation ("VERTICAL"), width and onChange.
	function UI.Slider(parent, minValue, maxValue, step, opts)
		opts = opts or {}
		local style = StyleFor("slider", opts)
		local vertical = opts.orientation == "VERTICAL"

		local slider = CreateFrame("Slider", nil, parent)
		slider:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
		if vertical then
			slider:SetWidth(style.height)
			slider:SetHitRectInsets(-4, -4, 0, 0)
		else
			slider:SetHeight(style.height)
			slider:SetHitRectInsets(0, 0, -4, -4)
		end
		if opts.width then slider:SetWidth(opts.width) end
		slider:SetMinMaxValues(minValue, maxValue)
		slider:SetValueStep(step or 1)
		slider:SetObeyStepOnDrag(true)
		Base(slider, opts)
		slider.style = style

		local track = slider:CreateTexture(nil, "BACKGROUND")
		UI.Paint(track, style.track, "fill")

		-- the slider positions the thumb itself, so the fill can just anchor to it.
		local thumb = slider:CreateTexture(nil, "OVERLAY")
		UI.Paint(thumb, style.thumb, "fill")
		slider:SetThumbTexture(thumb)

		local fill = slider:CreateTexture(nil, "ARTWORK")
		UI.Paint(fill, style.fill, "fill")

		if vertical then
			track:SetWidth(style.trackSize)
			track:SetPoint("TOP")
			track:SetPoint("BOTTOM")
			thumb:SetSize(style.thumbHeight, style.thumbWidth)
			fill:SetWidth(style.trackSize)
			fill:SetPoint("TOP", track, "TOP")
			fill:SetPoint("BOTTOM", thumb, "CENTER")
		else
			track:SetHeight(style.trackSize)
			track:SetPoint("LEFT")
			track:SetPoint("RIGHT")
			thumb:SetSize(style.thumbWidth, style.thumbHeight)
			fill:SetHeight(style.trackSize)
			fill:SetPoint("LEFT", track, "LEFT")
			fill:SetPoint("RIGHT", thumb, "CENTER")
		end
		slider.track, slider.thumb, slider.fill = track, thumb, fill

		function slider:SetRange(min, max, newStep)
			self:SetMinMaxValues(min, max)
			if newStep then self:SetValueStep(newStep) end
		end

		function slider:Refresh()
			local alpha = self:IsEnabled() and 1 or 0.35
			thumb:SetAlpha(alpha)
			fill:SetAlpha(alpha)
		end

		slider:SetScript("OnDisable", slider.Refresh)
		slider:SetScript("OnEnable", slider.Refresh)
		if opts.onChange then
			slider:SetScript("OnValueChanged", function(self, value, userInput)
				opts.onChange(Snap(value, minValue, step), self, userInput)
			end)
		end
		return slider
	end

	--------------------------------------------------------------------------------
	-- Color
	--------------------------------------------------------------------------------

	-- opts.get and opts.set make it open the picker on its own. hasAlpha adds opacity.
	function UI.ColorSwatch(parent, width, height, opts)
		opts = opts or {}
		local swatch = CreateFrame("Button", nil, parent)
		swatch:SetSize(width or 44, height or 18)
		Base(swatch, opts)
		Fill(swatch, "BACKGROUND", "black")
		swatch.edges = UI.Border(swatch)

		local color = swatch:CreateTexture(nil, "ARTWORK")
		color:SetPoint("TOPLEFT", 1, -1)
		color:SetPoint("BOTTOMRIGHT", -1, 1)
		swatch.swatch = color

		UI.Accented(swatch:CreateTexture(nil, "HIGHLIGHT"), 0.25):SetAllPoints()

		function swatch:SetColor(r, g, b, a)
			self.swatch:SetColorTexture(r, g, b, a or 1)
		end

		function swatch:Refresh()
			self:SetAlpha(self:IsEnabled() and 1 or 0.5)
			if opts.get then
				local c = opts.get()
				if c then self:SetColor(c[1] or c.r, c[2] or c.g, c[3] or c.b, c[4] or c.a or 1) end
			end
		end

		if opts.get and opts.set then
			swatch:SetScript("OnClick", function(self)
				local c = opts.get() or { 1, 1, 1, 1 }
				UI.OpenColorPicker(c[1], c[2], c[3], c[4] or 1, opts.hasAlpha, function(r, g, b, a)
					opts.set({ r, g, b, a })
					self:Refresh()
				end)
			end)
		end

		HoverScripts(swatch)
		swatch:Refresh()
		return swatch
	end

	-- ColorPickerFrame changed in 10.2.5. older clients get the field setup, where
	-- the opacity slider runs backwards from alpha.
	function UI.OpenColorPicker(r, g, b, a, hasAlpha, callback)
		local modern = ColorPickerFrame.SetupColorPickerAndShow ~= nil

		local function Apply()
			local nr, ng, nb = ColorPickerFrame:GetColorRGB()
			local na = 1
			if hasAlpha then
				if modern then
					na = ColorPickerFrame:GetColorAlpha()
				---@diagnostic disable-next-line: undefined-global
				elseif OpacitySliderFrame then
					---@diagnostic disable-next-line: undefined-global
					na = 1 - OpacitySliderFrame:GetValue()
				end
			end
			callback(nr, ng, nb, na)
		end

		local cancel = function() callback(r, g, b, a) end

		if modern then
			ColorPickerFrame:SetupColorPickerAndShow({
				swatchFunc = Apply,
				opacityFunc = Apply,
				cancelFunc = cancel,
				hasOpacity = hasAlpha and true or false,
				opacity = a or 1,
				r = r, g = g, b = b,
			})
		else
			-- color goes in before func, or setting it fires the callback straight away.
			ColorPickerFrame.func = nil
			ColorPickerFrame:SetColorRGB(r, g, b)
			ColorPickerFrame.func = Apply
			ColorPickerFrame.opacityFunc = Apply
			ColorPickerFrame.cancelFunc = cancel
			ColorPickerFrame.hasOpacity = hasAlpha and true or false
			ColorPickerFrame.opacity = 1 - (a or 1)

			-- reshown so OnShow picks up the opacity fields.
			ColorPickerFrame:Hide()
			ColorPickerFrame:Show()
		end
	end

	--------------------------------------------------------------------------------
	-- Progress bar and badge
	--------------------------------------------------------------------------------

	-- opts.format is a format string for value and max, "percent", or a function
	-- (value, max, percent) returning the text.
	function UI.ProgressBar(parent, width, height, opts)
		opts = opts or {}
		local style = StyleFor("progress", opts)

		local bar = CreateFrame("Frame", nil, parent)
		bar:SetSize(width or 150, height or style.height)
		Base(bar, opts)
		bar.style = style
		Chrome(bar, style)
		bar.min, bar.max, bar.value = 0, 1, 0

		local fill = bar:CreateTexture(nil, "ARTWORK")
		fill:SetPoint("TOPLEFT", 1, -1)
		fill:SetPoint("BOTTOMLEFT", 1, 1)
		UI.Paint(fill, style.fill, "fill")
		bar.fill = fill

		if style.font then
			bar.label = UI.Text(bar, "", style.font, style.text)
			bar.label:SetPoint("CENTER")
			bar.label:SetJustifyH(style.justify)
		end

		local function Draw()
			local range = bar.max - bar.min
			local percent = range > 0 and Clamp((bar.value - bar.min) / range, 0, 1) or 0
			local inner = bar:GetWidth() - 2

			fill:SetShown(percent > 0 and inner > 0)
			fill:SetWidth(math.max(0.001, inner * percent))

			if bar.label and not bar.fixedText then
				local format = opts.format
				local text = ""
				if type(format) == "function" then
					text = format(bar.value, bar.max, percent) or ""
				elseif format == "percent" then
					text = ("%d%%"):format(percent * 100 + 0.5)
				elseif format then
					text = format:format(bar.value, bar.max)
				end
				bar.label:SetText(text)
			end
		end

		function bar:SetMinMax(min, max)
			self.min, self.max = min or 0, max or 1
			Draw()
		end

		function bar:SetValue(value, max)
			self.value = value or 0
			if max then self.max = max end
			Draw()
		end

		function bar:GetValue()
			return self.value, self.min, self.max
		end

		-- fixed text instead of the format. nil hands it back.
		function bar:SetText(text)
			self.fixedText = text ~= nil
			if self.label then self.label:SetText(text or "") end
			if not self.fixedText then Draw() end
		end

		function bar:SetFillColor(spec)
			UI.Paint(fill, spec, "fill")
		end

		bar:SetScript("OnSizeChanged", Draw)
		Draw()
		return bar
	end

	-- small pill for a count or a tag. opts.hideEmpty hides it on "", nil or 0.
	function UI.Badge(parent, text, opts)
		opts = opts or {}
		local style = StyleFor("badge", opts)

		local badge = CreateFrame("Frame", nil, parent)
		badge:SetHeight(style.height)
		Base(badge, opts)
		badge.style = style
		Chrome(badge, style)

		badge.label = UI.Text(badge, "", style.font, style.text)
		badge.label:SetPoint("CENTER", 0, 0)
		badge.label:SetJustifyH("CENTER")

		function badge:SetText(value)
			self.label:SetText(value == nil and "" or tostring(value))
			self:SetWidth(math.max(self.style.minWidth, math.ceil(TextWidth(self.label) + self.style.padding * 2)))
			if opts.hideEmpty then
				self:SetShown(value ~= nil and value ~= "" and value ~= 0)
			end
		end

		function badge:SetStyle(newStyle, overrides)
			self.style = UI.Style("badge", newStyle, overrides)
			Chrome(self, self.style)
			UI.Paint(self.label, self.style.text, "text")
			self:SetText(self.label:GetText())
		end

		badge:SetText(text)
		return badge
	end

	--------------------------------------------------------------------------------
	-- Keybind
	--------------------------------------------------------------------------------

	local MODIFIER_KEYS = {
		LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
		LALT = true, RALT = true, LMETA = true, RMETA = true, UNKNOWN = true,
	}

	-- click, then press a key with any modifiers. escape cancels, right click
	-- clears. opts.onChange gets "ALT-CTRL-SHIFT-KEY" style strings or nil.
	function UI.Keybind(parent, width, height, opts)
		opts = opts or {}
		local button = UI.Button(parent, "", width or 150, height or 22, { style = opts.style })
		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		button:EnableKeyboard(false)
		local capturing = false

		local function Show()
			if capturing then
				button:SetText(opts.promptText or "Press a key...")
			elseif button.value then
				button:SetText(GetBindingText and GetBindingText(button.value) or button.value)
			else
				button:SetText(opts.emptyText or "Not bound")
			end
		end

		local function Fire(value)
			button.value = value
			Show()
			if opts.onChange then opts.onChange(value, button) end
			if button.OnChange then button.OnChange(value, button) end
		end

		local function Stop()
			if not capturing then return end
			capturing = false
			button:EnableKeyboard(false)
			button:SetSelected(false)
			Show()
		end

		function button:SetValue(value)
			self.value = value
			Show()
		end

		function button:GetValue()
			return self.value
		end

		button:SetScript("OnKeyDown", function(_, key)
			if not capturing then return end
			if key == "ESCAPE" then return Stop() end
			if MODIFIER_KEYS[key] then return end

			local combo = key
			if IsShiftKeyDown() then combo = "SHIFT-" .. combo end
			if IsControlKeyDown() then combo = "CTRL-" .. combo end
			if IsAltKeyDown() then combo = "ALT-" .. combo end

			Stop()
			Fire(combo)
		end)

		button:SetScript("OnClick", function(self, mouseButton)
			if mouseButton == "RightButton" then
				Stop()
				return Fire(nil)
			end
			if capturing then return Stop() end
			-- taking the keyboard in combat can be blocked, so it waits.
			if InCombatLockdown() then return end

			capturing = true
			self:EnableKeyboard(true)
			self:SetSelected(true)
			Show()
		end)

		button:HookScript("OnHide", Stop)
		button:SetValue(opts.value)
		return button
	end
end)
