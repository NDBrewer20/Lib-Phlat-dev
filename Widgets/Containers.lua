local lib = LibStub("LibPhlat-1.0")
if not lib.loading then return end

lib:Module("Containers", function(UI, P)
	local Resolve = P.Resolve
	local Merge = P.Merge
	local Clamp = P.Clamp
	local state = P.state
	local StyleFor = P.StyleFor
	local Chrome = P.Chrome
	local Fill = P.Fill

	--------------------------------------------------------------------------------
	-- Scrolling
	--------------------------------------------------------------------------------

	-- SetInsetTop keeps a strip along the top that doesn't scroll. opts takes style,
	-- step, hideBar and onScroll(offset).
	function UI.ScrollArea(parent, width, height, opts)
		opts = opts or {}
		local style = StyleFor("scroll", opts)
		local side = style.bar + style.gap

		local area = CreateFrame("Frame", nil, parent)
		area:SetSize(width, height)
		area.style = style
		area.OnScroll = opts.onScroll

		local inset, viewHeight = 0, height

		local scroll = CreateFrame("ScrollFrame", nil, area)
		scroll:SetPoint("TOPLEFT")
		scroll:SetSize(width - side, height)

		local content = CreateFrame("Frame", nil, scroll)
		content:SetSize(width - side, height)
		scroll:SetScrollChild(content)

		local track = CreateFrame("Frame", nil, area)
		track:SetPoint("TOPRIGHT")
		track:SetSize(style.bar, height)
		Fill(track, "BACKGROUND", style.track)
		track:EnableMouse(true)

		local thumb = CreateFrame("Frame", nil, track)
		thumb:SetPoint("TOPLEFT")
		thumb:SetPoint("TOPRIGHT")
		thumb:SetHeight(40)
		thumb.tex = Fill(thumb, "ARTWORK", style.thumb)
		thumb:EnableMouse(true)
		thumb:RegisterForDrag("LeftButton")

		area.scroll, area.content, area.track, area.thumb = scroll, content, track, thumb

		local function Range()
			return math.max(0, content:GetHeight() - viewHeight)
		end

		-- one spot that pushes size and inset onto the frames so they can't disagree.
		local function Apply(keepScroll)
			viewHeight = height - inset

			area:SetSize(width, height)

			scroll:ClearAllPoints()
			scroll:SetPoint("TOPLEFT", 0, -inset)
			scroll:SetSize(width - side, viewHeight)

			content:SetWidth(width - side)

			track:ClearAllPoints()
			track:SetPoint("TOPRIGHT", 0, -inset)
			track:SetSize(style.bar, viewHeight)

			area:ScrollTo(keepScroll or 0)
		end

		-- keeps the scroll position, the inset can change on every step of a slider drag.
		function area:SetInsetTop(value)
			value = value or 0
			if inset == value then return end

			inset = value
			Apply(scroll:GetVerticalScroll())
		end

		-- for resizable windows. the content still has to lay itself out and call Update.
		function area:Resize(newWidth, newHeight)
			if newWidth == width and newHeight == height then return end

			width, height = newWidth, newHeight
			Apply(scroll:GetVerticalScroll())
		end

		function area:Update()
			local range = Range()
			if scroll:GetVerticalScroll() > range then scroll:SetVerticalScroll(range) end

			if range <= 0 or opts.hideBar then
				if range <= 0 then scroll:SetVerticalScroll(0) end
				track:Hide()
				return
			end

			track:Show()
			local thumbHeight = math.max(style.minThumb, viewHeight * (viewHeight / content:GetHeight()))
			local offset = (scroll:GetVerticalScroll() / range) * (viewHeight - thumbHeight)
			thumb:SetHeight(thumbHeight)
			thumb:SetPoint("TOPLEFT", track, "TOPLEFT", 0, -offset)
			thumb:SetPoint("TOPRIGHT", track, "TOPRIGHT", 0, -offset)
		end

		function area:ScrollTo(value)
			local before = scroll:GetVerticalScroll()
			scroll:SetVerticalScroll(Clamp(value, 0, Range()))
			self:Update()

			local after = scroll:GetVerticalScroll()
			if after ~= before and self.OnScroll then self.OnScroll(after, self) end
		end

		function area:ScrollBy(delta)
			self:ScrollTo(scroll:GetVerticalScroll() + delta)
		end

		function area:GetScroll()
			return scroll:GetVerticalScroll(), Range(), viewHeight
		end

		function area:ScrollToBottom()
			self:ScrollTo(Range())
		end

		-- sets the content height and redraws the bar in one go.
		function area:SetContentHeight(value)
			content:SetHeight(math.max(1, value))
			self:Update()
		end

		-- scrolls just enough to put a region inside the content on screen.
		function area:ScrollIntoView(region, pad)
			pad = pad or 0
			local contentTop, top = content:GetTop(), region:GetTop()
			if not contentTop or not top then return end

			local y = contentTop - top
			local bottom = y + region:GetHeight()
			local offset = scroll:GetVerticalScroll()
			if y - pad < offset then
				self:ScrollTo(y - pad)
			elseif bottom + pad > offset + viewHeight then
				self:ScrollTo(bottom + pad - viewHeight)
			end
		end

		scroll:EnableMouseWheel(true)
		scroll:SetScript("OnMouseWheel", function(_, delta)
			UI.CloseMenus()
			area:ScrollBy(-delta * (opts.step or style.step))
		end)

		-- a click on the track pages toward it.
		track:SetScript("OnMouseDown", function()
			local _, cursorY = GetCursorPosition()
			cursorY = cursorY / track:GetEffectiveScale()
			local page = viewHeight * 0.9
			if cursorY > (thumb:GetTop() or 0) then area:ScrollBy(-page) else area:ScrollBy(page) end
		end)

		thumb:SetScript("OnEnter", function(self) UI.Paint(self.tex, style.thumbHover, "fill") end)
		thumb:SetScript("OnLeave", function(self)
			if not self.dragging then UI.Paint(self.tex, style.thumb, "fill") end
		end)

		-- dragging the thumb maps the cursor straight onto the scroll range.
		thumb:SetScript("OnDragStart", function(self)
			self.dragging = true
			self:SetScript("OnUpdate", function(bar)
				local range = Range()
				local travel = viewHeight - bar:GetHeight()
				if range <= 0 or travel <= 0 then return end

				local _, cursorY = GetCursorPosition()
				cursorY = cursorY / track:GetEffectiveScale()
				local percent = (track:GetTop() - cursorY - bar:GetHeight() / 2) / travel
				area:ScrollTo(percent * range)
			end)
		end)
		thumb:SetScript("OnDragStop", function(self)
			self.dragging = false
			self:SetScript("OnUpdate", nil)
			if not self:IsMouseOver() then UI.Paint(self.tex, style.thumb, "fill") end
		end)

		return area
	end

	--------------------------------------------------------------------------------
	-- Panel, section and accordion
	--------------------------------------------------------------------------------

	-- a flat box. styles are default, inset, flat and clear.
	function UI.Panel(parent, width, height, opts)
		opts = opts or {}
		local style = StyleFor("panel", opts)
		local panel = CreateFrame("Frame", nil, parent)
		if width then panel:SetWidth(width) end
		if height then panel:SetHeight(height) end
		panel.style = style
		Chrome(panel, style)

		function panel:SetStyle(newStyle, overrides)
			self.style = UI.Style("panel", newStyle, overrides)
			Chrome(self, self.style)
		end
		return panel
	end

	-- a header that folds its body away. put things in section.body and tell it
	-- how tall they are with SetBodyHeight. opts takes style, expanded, note,
	-- gap, onToggle(expanded), and get/set to keep the folded state.
	function UI.Section(parent, width, title, opts)
		opts = opts or {}
		local style = StyleFor("section", opts)

		local section = CreateFrame("Frame", nil, parent)
		section:SetWidth(width)
		section.style = style
		section.bodyHeight = 0
		section.OnToggle = opts.onToggle

		local header = CreateFrame("Button", nil, section)
		header:SetPoint("TOPLEFT")
		header:SetPoint("TOPRIGHT")
		header:SetHeight(style.height)
		Chrome(header, style)
		section.header = header

		header.chevron = UI.Chevron(header, style.chevronSize, style.chevronColor)
		header.chevron:SetPoint("LEFT", 4, 0)

		section.title = UI.Text(header, title, style.font, style.text)
		section.title:SetPoint("LEFT", header.chevron, "RIGHT", 6, 0)

		if opts.note then
			section.note = UI.Text(header, opts.note, "small", "dim")
			section.note:SetPoint("RIGHT", -6, 0)
		end

		local gap = opts.gap or 4
		local body = CreateFrame("Frame", nil, section)
		body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -gap)
		body:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -gap)
		body:SetHeight(1)
		section.body = body

		local function Height()
			return style.height + (section.expanded and gap + section.bodyHeight or 0)
		end

		function section:SetExpanded(expanded, silent)
			self.expanded = expanded and true or false
			body:SetShown(self.expanded)
			header.chevron:SetFacing(self.expanded and "down" or "right")
			self:SetHeight(Height())

			if silent then return end
			if opts.set then opts.set(self.expanded) end
			if self.OnToggle then self.OnToggle(self.expanded, self) end
		end

		function section:Toggle()
			self:SetExpanded(not self.expanded)
		end

		function section:IsExpanded()
			return self.expanded
		end

		function section:SetBodyHeight(value)
			self.bodyHeight = math.max(0, value or 0)
			body:SetHeight(math.max(1, self.bodyHeight))
			self:SetHeight(Height())
		end

		-- the height it takes with its body how it is now.
		function section:GetFullHeight()
			return Height()
		end

		function section:SetTitle(text)
			self.title:SetText(text)
		end

		header:SetScript("OnClick", function() section:Toggle() end)

		local expanded = opts.expanded ~= false
		if opts.get then expanded = opts.get() ~= false end
		section:SetExpanded(expanded, true)
		return section
	end

	-- sections stacked under each other. opts.single keeps one open at a time,
	-- opts.spacing is the gap between them, onLayout(height) fires as it changes.
	function UI.Accordion(parent, width, opts)
		opts = opts or {}
		local accordion = CreateFrame("Frame", nil, parent)
		accordion:SetSize(width, 1)
		accordion.sections = {}
		accordion.OnLayout = opts.onLayout

		function accordion:Layout()
			local y = 0
			for index, section in ipairs(self.sections) do
				section:ClearAllPoints()
				section:SetPoint("TOPLEFT", 0, -y)
				y = y + section:GetFullHeight() + (index < #self.sections and (opts.spacing or 4) or 0)
			end
			self:SetHeight(math.max(1, y))
			if self.OnLayout then self.OnLayout(y, self) end
			return y
		end

		function accordion:Add(title, bodyHeight, sectionOpts)
			local section = UI.Section(self, width, title, sectionOpts)
			section:SetBodyHeight(bodyHeight)
			local own = section.OnToggle

			section.OnToggle = function(expanded, toggled)
				if expanded and opts.single then
					for _, other in ipairs(self.sections) do
						if other ~= toggled and other.expanded then other:SetExpanded(false, true) end
					end
				end
				self:Layout()
				if own then own(expanded, toggled) end
			end

			if opts.single and section.expanded then
				for _, other in ipairs(self.sections) do
					if other.expanded then section:SetExpanded(false, true) break end
				end
			end

			self.sections[#self.sections + 1] = section
			self:Layout()
			return section
		end

		return accordion
	end

	--------------------------------------------------------------------------------
	-- Splitter
	--------------------------------------------------------------------------------

	-- two panes with a bar between them that drags. opts takes vertical (stack
	-- them instead of side by side), size (the first pane), min, max, thickness
	-- and onChange(size). the panes are split.first and split.second.
	function UI.Splitter(parent, width, height, opts)
		opts = opts or {}
		local vertical = opts.vertical
		local thickness = opts.thickness or 6

		local split = CreateFrame("Frame", nil, parent)
		split:SetSize(width, height)
		split.first = CreateFrame("Frame", nil, split)
		split.second = CreateFrame("Frame", nil, split)
		split.size = opts.size or math.floor((vertical and height or width) / 2)

		local bar = CreateFrame("Button", nil, split)
		split.bar = bar
		local line = UI.Divider(bar, not vertical, "line")
		if vertical then
			line:SetPoint("LEFT")
			line:SetPoint("RIGHT")
		else
			line:SetPoint("TOP")
			line:SetPoint("BOTTOM")
		end
		UI.Accented(bar:CreateTexture(nil, "HIGHLIGHT"), 0.25):SetAllPoints()

		local function Total()
			return vertical and split:GetHeight() or split:GetWidth()
		end

		function split:Layout()
			local total = Total()
			local size = Clamp(self.size, opts.min or 20, math.max(opts.min or 20, (opts.max or total) - thickness))
			size = math.min(size, math.max(0, total - thickness - (opts.minSecond or 20)))
			self.size = size

			self.first:ClearAllPoints()
			self.second:ClearAllPoints()
			bar:ClearAllPoints()

			if vertical then
				self.first:SetPoint("TOPLEFT")
				self.first:SetPoint("TOPRIGHT")
				self.first:SetHeight(math.max(1, size))
				bar:SetPoint("TOPLEFT", 0, -size)
				bar:SetPoint("TOPRIGHT", 0, -size)
				bar:SetHeight(thickness)
				self.second:SetPoint("TOPLEFT", 0, -size - thickness)
				self.second:SetPoint("BOTTOMRIGHT")
			else
				self.first:SetPoint("TOPLEFT")
				self.first:SetPoint("BOTTOMLEFT")
				self.first:SetWidth(math.max(1, size))
				bar:SetPoint("TOPLEFT", size, 0)
				bar:SetPoint("BOTTOMLEFT", size, 0)
				bar:SetWidth(thickness)
				self.second:SetPoint("TOPLEFT", size + thickness, 0)
				self.second:SetPoint("BOTTOMRIGHT")
			end

			if self.OnLayout then self.OnLayout(size, self) end
		end

		function split:SetSplit(size)
			self.size = size
			self:Layout()
		end

		function split:GetSplit()
			return self.size
		end

		bar:SetScript("OnMouseDown", function()
			bar:SetScript("OnUpdate", function()
				local x, y = GetCursorPosition()
				local scale = split:GetEffectiveScale()
				local size
				if vertical then
					size = (split:GetTop() or 0) - y / scale - thickness / 2
				else
					size = x / scale - (split:GetLeft() or 0) - thickness / 2
				end
				split.size = math.floor(size + 0.5)
				split:Layout()
			end)
		end)
		bar:SetScript("OnMouseUp", function()
			bar:SetScript("OnUpdate", nil)
			if opts.onChange then opts.onChange(split.size, split) end
		end)

		split:SetScript("OnSizeChanged", function(self) self:Layout() end)
		split:Layout()
		return split
	end

	--------------------------------------------------------------------------------
	-- Window
	--------------------------------------------------------------------------------

	-- opts takes style, strata, movable (default true), closable (default true),
	-- escape (default true, needs a globalName), noTitle, resizable, minWidth,
	-- minHeight, maxWidth, maxHeight, onResized(width, height), and position, a
	-- table the window keeps its point, size and offsets in.
	function UI.Window(globalName, width, height, titleText, opts)
		opts = opts or {}
		local style = StyleFor("window", opts)

		local frame = CreateFrame("Frame", globalName, opts.parent or UIParent)
		frame:SetSize(width, height)
		frame:SetPoint("CENTER")
		frame:SetFrameStrata(opts.strata or style.strata)
		frame:SetToplevel(true)
		frame:EnableMouse(true)
		frame:SetMovable(opts.movable ~= false)
		frame:SetClampedToScreen(true)
		frame:Hide()
		frame.style = style

		frame.bg = Fill(frame, "BACKGROUND", style.bg)
		frame.edges = UI.Border(frame, style.border)

		local titleHeight = opts.noTitle and 0 or style.titleHeight

		local bar = CreateFrame("Frame", nil, frame)
		bar:SetPoint("TOPLEFT")
		bar:SetPoint("TOPRIGHT")
		bar:SetHeight(math.max(1, titleHeight))
		Fill(bar, "BACKGROUND", style.titlebar)
		bar:EnableMouse(true)
		bar:RegisterForDrag("LeftButton")
		frame.titlebar = bar

		local function StartMoving()
			if frame:IsMovable() then frame:StartMoving() end
		end
		local function StopMoving()
			frame:StopMovingOrSizing()
			if opts.position then frame:SavePosition() end
			if frame.OnMoved then frame:OnMoved() end
		end

		bar:SetScript("OnDragStart", StartMoving)
		bar:SetScript("OnDragStop", StopMoving)

		local stripe = bar:CreateTexture(nil, "ARTWORK")
		stripe:SetPoint("BOTTOMLEFT")
		stripe:SetPoint("BOTTOMRIGHT")
		stripe:SetHeight(style.stripeSize)
		UI.Paint(stripe, style.stripe, "fill")
		frame.stripe = stripe

		frame.title = UI.Text(bar, titleText, style.titleFont, style.titleText)
		frame.title:SetPoint("LEFT", 14, 1)

		-- the kit's cross instead of UIPanelCloseButton, which is gold and doesn't match.
		local close = UI.GlyphButton(bar, style.closeSize, "cross")
		close:SetPoint("RIGHT", -6, 0)
		close:SetScript("OnClick", function() frame:Hide() end)
		close:SetShown(opts.closable ~= false)

		-- exposed so a window in the UI panel system can close with HideUIPanel instead.
		frame.close = close
		frame.titleButtons = {}

		-- no title bar, so the window drags from anywhere.
		if opts.noTitle then
			bar:Hide()
			frame:RegisterForDrag("LeftButton")
			frame:SetScript("OnDragStart", StartMoving)
			frame:SetScript("OnDragStop", StopMoving)
		end

		frame.body = CreateFrame("Frame", nil, frame)
		frame.body:SetPoint("TOPLEFT", 0, -titleHeight)
		frame.body:SetPoint("BOTTOMRIGHT")

		function frame:SetTitle(text)
			self.title:SetText(text or "")
		end

		-- a glyph button in the title bar, laid right to left from the close.
		function frame:AddTitleButton(glyph, title, body, onClick)
			local previous = self.titleButtons[#self.titleButtons]
				or (close:IsShown() and close) or nil
			local button = UI.GlyphButton(bar, 12, glyph, title, body)
			if previous then
				button:SetPoint("RIGHT", previous, "LEFT", 0, 0)
			else
				button:SetPoint("RIGHT", -6, 0)
			end
			if onClick then button:SetScript("OnClick", onClick) end
			self.titleButtons[#self.titleButtons + 1] = button
			return button
		end

		function frame:Toggle()
			self:SetShown(not self:IsShown())
		end

		function frame:SavePosition()
			local saved = Resolve(opts.position)
			if not saved then return end
			local point, _, relativePoint, x, y = self:GetPoint(1)
			saved.point, saved.relativePoint, saved.x, saved.y = point, relativePoint, x, y
			if opts.resizable then
				saved.width, saved.height = math.floor(self:GetWidth() + 0.5), math.floor(self:GetHeight() + 0.5)
			end
		end

		function frame:RestorePosition()
			local saved = Resolve(opts.position)
			if not saved or not saved.point then return end
			self:ClearAllPoints()
			self:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
			if opts.resizable and saved.width then self:SetSize(saved.width, saved.height) end
		end

		function frame:ResetPosition()
			local saved = Resolve(opts.position)
			if saved then wipe(saved) end
			self:ClearAllPoints()
			self:SetPoint("CENTER")
			self:SetSize(width, height)
		end

		if opts.resizable then
			frame:SetResizable(true)
			if frame.SetResizeBounds then
				frame:SetResizeBounds(opts.minWidth or 200, opts.minHeight or 120, opts.maxWidth, opts.maxHeight)
			end

			-- three stacked lines rather than Blizzard's art so it wears the window's colors.
			local grip = CreateFrame("Button", nil, frame)
			grip:SetSize(16, 16)
			grip:SetPoint("BOTTOMRIGHT", -2, 2)
			grip:SetFrameLevel(frame:GetFrameLevel() + 20)
			for i = 1, 3 do
				local line = grip:CreateTexture(nil, "OVERLAY")
				line:SetSize(4 + (i - 1) * 4, 2)
				line:SetPoint("BOTTOMRIGHT", -2, 1 + (i - 1) * 4)
				UI.Paint(line, style.grip, "fill")
			end
			frame.grip = grip

			grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
			grip:SetScript("OnMouseUp", function()
				frame:StopMovingOrSizing()
				if opts.position then frame:SavePosition() end
				local w, h = frame:GetWidth(), frame:GetHeight()
				if opts.onResized then opts.onResized(w, h, frame) end
				if frame.OnResized then frame:OnResized(w, h) end
			end)
		end

		if globalName and opts.escape ~= false then tinsert(UISpecialFrames, globalName) end
		if opts.position then frame:RestorePosition() end
		return frame
	end

	--------------------------------------------------------------------------------
	-- Popover
	--------------------------------------------------------------------------------

	-- a floating panel off a frame that closes on a click outside it. put things
	-- in popover.content. opts takes style (a panel style), side ("BOTTOM", "TOP",
	-- "LEFT", "RIGHT"), align, gap, onOpen and onClose.
	function UI.Popover(width, height, opts)
		opts = opts or {}
		local pop = UI.Panel(UIParent, width, height, { style = opts.style or "default" })
		pop:SetFrameStrata("FULLSCREEN_DIALOG")
		pop:SetClampedToScreen(true)
		pop:EnableMouse(true)
		pop:Hide()
		pop.content = pop

		local catcher = CreateFrame("Button", nil, UIParent)
		catcher:SetAllPoints(UIParent)
		catcher:SetFrameStrata("FULLSCREEN_DIALOG")
		catcher:RegisterForClicks("AnyUp")
		catcher:Hide()
		catcher:SetScript("OnClick", function() pop:Hide() end)

		pop:SetScript("OnShow", function(self)
			UI.CloseMenus()
			catcher:Show()
			catcher:SetFrameLevel(math.max(1, self:GetFrameLevel() - 1))
			if opts.onOpen then opts.onOpen(self) end
		end)
		pop:SetScript("OnHide", function(self)
			catcher:Hide()
			if opts.onClose then opts.onClose(self) end
		end)

		local OPPOSITE = { TOP = "BOTTOM", BOTTOM = "TOP", LEFT = "RIGHT", RIGHT = "LEFT" }

		function pop:Open(anchor)
			local side = opts.side or "BOTTOM"
			local gap = opts.gap or 4
			local align = opts.align or (side == "TOP" or side == "BOTTOM") and "LEFT" or "TOP"
			local x = side == "RIGHT" and gap or side == "LEFT" and -gap or 0
			local y = side == "TOP" and gap or side == "BOTTOM" and -gap or 0

			self:ClearAllPoints()
			if align == "CENTER" then
				self:SetPoint(OPPOSITE[side], anchor, side, x, y)
			else
				self:SetPoint(OPPOSITE[side] .. align, anchor, side .. align, x, y)
			end
			self:Show()
			self:Raise()
		end

		function pop:Close() self:Hide() end
		function pop:IsOpen() return self:IsShown() end

		function pop:Toggle(anchor)
			if self:IsShown() then self:Hide() else self:Open(anchor) end
		end

		return pop
	end

	--------------------------------------------------------------------------------
	-- Dialogs
	--
	-- flat stand ins for StaticPopup. a free one is reused, so they can stack.
	--------------------------------------------------------------------------------

	local dialogs = {}

	local function BuildDialog()
		state.dialogs = (state.dialogs or 0) + 1
		local style = UI.Style("dialog")
		local name = "LibPhlatDialog" .. state.dialogs

		local dialog = UI.Window(name, style.width, 140, "", { style = "dialog" })
		dialog.style = style

		dialog.text = UI.Text(dialog.body, "", style.font)
		dialog.text:SetPoint("TOPLEFT", style.padding, -style.padding)
		dialog.text:SetWidth(style.width - style.padding * 2)
		dialog.text:SetJustifyV("TOP")

		dialog.input = UI.EditBox(dialog.body, style.width - style.padding * 2, 22, {
			onEnter = function() dialog:Press(1) end,
			onEscape = function() dialog:Hide() end,
			keepFocus = true,
		})
		dialog.input:Hide()

		dialog.buttons = {}

		-- a button's onClick returning true keeps the dialog up.
		function dialog:Press(index)
			local spec = self.specs and self.specs[index]
			if not spec then return end
			self.answered = true
			local text = (self.area and self.area:IsShown() and self.area:GetText())
				or (self.input:IsShown() and self.input:GetText()) or nil
			local keep = spec.onClick and spec.onClick(self, text)
			if not keep then self:Hide() end
		end

		dialog:HookScript("OnHide", function(self)
			if not self.answered and self.onCancel then self.onCancel(self) end
			self.onCancel = nil
			self.input:ClearFocus()
			if self.area then self.area:ClearFocus() end
		end)

		dialogs[#dialogs + 1] = dialog
		return dialog
	end

	-- opts takes title, text, input (true, or the text to start with), buttons
	-- ({ text, style, onClick(dialog, inputText) }, first is rightmost and what
	-- enter presses), width, onCancel and onShow. multiline makes the input a
	-- scrolling box that wraps, inputHeight tall (120), capped at maxLetters.
	function UI.Dialog(opts)
		opts = opts or {}
		local dialog
		for _, free in ipairs(dialogs) do
			if not free:IsShown() then dialog = free break end
		end
		dialog = dialog or BuildDialog()

		local s = dialog.style
		local width = opts.width or s.width
		dialog:SetWidth(width)
		dialog.text:SetWidth(width - s.padding * 2)
		dialog.input:SetWidth(width - s.padding * 2)

		dialog:SetTitle(opts.title or "")
		dialog.text:SetText(opts.text or "")
		dialog.specs = opts.buttons or { { text = "Okay", style = "primary" } }
		dialog.onCancel = opts.onCancel
		dialog.answered = false

		local y = s.padding + math.max(14, dialog.text:GetStringHeight())

		if opts.input and opts.multiline then
			-- a scrolling box that wraps, for anything longer than a line. made the first
			-- time one's asked for. enter's a new line in here, so the buttons answer.
			local boxWidth, boxHeight = width - s.padding * 2, opts.inputHeight or 120
			if not dialog.area then
				dialog.area = UI.TextArea(dialog.body, boxWidth, boxHeight)
			end

			dialog.area:Resize(boxWidth, boxHeight)
			dialog.area:ClearAllPoints()
			dialog.area:SetPoint("TOPLEFT", s.padding, -y - 10)
			dialog.area.edit:SetMaxLetters(opts.maxLetters or 0)
			dialog.area:SetText(type(opts.input) == "string" and opts.input or "")
			dialog.area:Show()
			dialog.input:Hide()
			y = y + boxHeight + 20
		elseif opts.input then
			dialog.input:ClearAllPoints()
			dialog.input:SetPoint("TOPLEFT", s.padding, -y - 10)
			dialog.input:SetText(type(opts.input) == "string" and opts.input or "")
			dialog.input:Show()
			if dialog.area then dialog.area:Hide() end
			y = y + 32
		else
			dialog.input:Hide()
			if dialog.area then dialog.area:Hide() end
		end

		local previous
		for index, spec in ipairs(dialog.specs) do
			local button = dialog.buttons[index]
			if not button then
				button = UI.Button(dialog.body, "", s.buttonWidth, 22)
				button:SetScript("OnClick", function() dialog:Press(index) end)
				dialog.buttons[index] = button
			end
			button:SetText(spec.text or "Okay")
			button:SetStyle(spec.style or "default")
			button:ClearAllPoints()
			if previous then
				button:SetPoint("RIGHT", previous, "LEFT", -6, 0)
			else
				button:SetPoint("BOTTOMRIGHT", -s.padding, s.padding)
			end
			button:Show()
			previous = button
		end
		for index = #dialog.specs + 1, #dialog.buttons do dialog.buttons[index]:Hide() end

		dialog:SetHeight(34 + y + 16 + 22 + s.padding)
		dialog:ClearAllPoints()
		dialog:SetPoint("CENTER", 0, 120)
		dialog:Show()
		dialog:Raise()

		if opts.input then
			if opts.multiline then dialog.area:SetFocus() else dialog.input:SetFocus() end
		end
		if opts.onShow then opts.onShow(dialog) end
		return dialog
	end

	-- opts takes title, acceptText, cancelText, danger and onCancel.
	function UI.Confirm(text, onAccept, opts)
		opts = opts or {}
		return UI.Dialog(Merge({
			text = text,
			buttons = {
				{ text = opts.acceptText or "Okay", style = opts.danger and "danger" or "primary", onClick = function(dialog)
					if onAccept then return onAccept(dialog) end
				end },
				{ text = opts.cancelText or "Cancel", onClick = function(dialog)
					if opts.onCancel then opts.onCancel(dialog) end
				end },
			},
		}, { title = opts.title, width = opts.width }))
	end

	-- onAccept(text) gets what was typed. opts.default is the text it starts with,
	-- multiline, inputHeight and maxLetters go through to the dialog.
	function UI.Prompt(text, onAccept, opts)
		opts = opts or {}
		return UI.Dialog({
			title = opts.title, text = text, width = opts.width,
			input = opts.default or true,
			multiline = opts.multiline, inputHeight = opts.inputHeight, maxLetters = opts.maxLetters,
			onCancel = opts.onCancel,
			buttons = {
				{ text = opts.acceptText or "Okay", style = "primary", onClick = function(dialog, value)
					if onAccept then return onAccept(value, dialog) end
				end },
				{ text = opts.cancelText or "Cancel", onClick = function(dialog)
					if opts.onCancel then opts.onCancel(dialog) end
				end },
			},
		})
	end

	function UI.Alert(text, opts)
		opts = opts or {}
		return UI.Dialog({
			title = opts.title, text = text, width = opts.width,
			buttons = { { text = opts.acceptText or "Okay", style = "primary", onClick = opts.onAccept } },
		})
	end

	--------------------------------------------------------------------------------
	-- Links
	--
	-- shift click to chat for rows, and a frame answering for the hyperlinks in
	-- its own text.
	--------------------------------------------------------------------------------

	-- ChatFrameUtil is the current name for this, ChatEdit_InsertLink the old one.
	-- nothing happens with no chat box open, same as Blizzard.
	function UI.InsertLink(link)
		if ChatFrameUtil and ChatFrameUtil.InsertLink then
			if ChatFrameUtil.GetActiveWindow and not ChatFrameUtil.GetActiveWindow() then return end
			return ChatFrameUtil.InsertLink(link)
		end
		if ChatEdit_InsertLink then return ChatEdit_InsertLink(link) end
	end

	-- true when the click was a link click and the caller should stop. items go
	-- through Blizzard's handler so ctrl still dresses up.
	function UI.LinkClick(link)
		if not link then return false end
		if link:find("|Hitem:", 1, true) then
			return HandleModifiedItemClick(link) and true or false
		end
		if IsModifiedClick("CHATLINK") then
			UI.InsertLink(link)
			return true
		end
		return false
	end

	-- rows are pooled, so the link is set every draw and cleared when there's none.
	function UI.HookLink(frame, link)
		frame.link = link
		if not link then
			frame:SetScript("OnClick", nil)
			return
		end
		frame:SetScript("OnClick", function(self) UI.LinkClick(self.link) end)
	end

	-- extra is a function returning more SetHyperlink arguments, like a difficulty.
	function UI.HookHyperlinks(frame, extra)
		frame:SetHyperlinksEnabled(true)
		frame:SetScript("OnHyperlinkEnter", function(self, link)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			if extra then
				GameTooltip:SetHyperlink(link, extra(link))
			else
				GameTooltip:SetHyperlink(link)
			end
			GameTooltip:Show()
		end)
		frame:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
		frame:SetScript("OnHyperlinkClick", function(_, link, text, button)
			if UI.LinkClick(text) then return end
			SetItemRef(link, text, button)
		end)
	end
end)
