local lib = LibStub("LibPhlat-1.0")
if not lib.loading then return end

lib:Module("Bars", function(UI, P)
	local Resolve = P.Resolve
	local StyleFor = P.StyleFor
	local Chrome = P.Chrome
	local Base = P.Base
	local TextWidth = P.TextWidth
	local SetControlEnabled = P.SetControlEnabled

	P.Defaults(UI, "toolbar", {
		default = { height = 26, bg = "titlebar", border = false, gap = 2, pad = 4, separator = "line", glyphSize = 12, iconSize = 16 },
		clear = { bg = false },
	})

	P.Defaults(UI, "menubar", {
		default = {
			height = 22, bg = "titlebar", border = false, font = "small", text = "dim",
			activeText = "text", highlight = "accent:0.15", open = "accent:0.25", padding = 16,
		},
	})

	P.Defaults(UI, "breadcrumb", {
		default = { height = 20, font = "small", text = "dim", current = "text", hover = "accent", separatorSize = 8, gap = 4 },
	})

	P.Defaults(UI, "pagination", {
		default = { height = 20, size = 20, gap = 2, font = "small", text = "dim" },
	})

	P.Defaults(UI, "steps", {
		default = {
			dot = 18, lineSize = 2, todo = "track", done = "accent:0.6", current = "accent",
			font = "small", number = "onAccent", todoNumber = "dim", text = "dim",
			activeText = "text", labelGap = 4,
		},
	})

	P.Defaults(UI, "spinner", {
		default = { size = 16, glyph = "refresh", color = "accent", speed = 1 },
	})

	P.Defaults(UI, "toast", {
		default = {
			width = 280, bg = "popup", border = "border", stripeSize = 3, font = "small",
			titleFont = "body", title = "text", text = "dim", pad = 10, duration = 4,
			spacing = 6, strata = "FULLSCREEN_DIALOG",
			kinds = { info = "accent", good = "good", warn = "warn", bad = "bad" },
		},
	})

	--------------------------------------------------------------------------------
	-- Toolbar
	--------------------------------------------------------------------------------

	-- a strip of tools. items take key, glyph, icon, text, tooltip, tooltipTitle,
	-- onClick(control, item), toggle, selected, disabled, width, menu (items for a
	-- menu button), onSelect, plus separator and spacer (pushes the rest right).
	function UI.Toolbar(parent, width, opts)
		opts = opts or {}
		local style = StyleFor("toolbar", opts)

		local bar = CreateFrame("Frame", nil, parent)
		bar:SetSize(width or 1, style.height)
		Base(bar, opts)
		bar.style = style
		Chrome(bar, style)
		bar.controls, bar.byKey = {}, {}

		local inner = style.height - style.pad * 2

		local function Build(item)
			local control
			if item.separator then
				control = UI.Divider(bar, true, style.separator)
				control:SetHeight(inner - 4)
			elseif item.spacer then
				control = false
			elseif item.menu then
				control = UI.MenuButton(bar, Resolve(item.text, item) or "", item.width or 90, {
					style = "ghost", styleOverrides = { height = inner }, menuWidth = "auto",
					items = item.menu, onSelect = function(value, picked) if item.onSelect then item.onSelect(value, picked) end end,
				})
			elseif item.glyph and not item.text then
				control = UI.GlyphButton(bar, style.glyphSize, item.glyph, item.tooltipTitle or item.title, item.tooltip, { style = "wash" })
			elseif item.icon and not item.text then
				control = UI.IconButton(bar, style.iconSize, item.icon, item.tooltipTitle or item.title, item.tooltip)
			else
				control = UI.Button(bar, Resolve(item.text, item) or "", item.width, inner, {
					style = "ghost", autoWidth = not item.width, glyph = item.glyph, icon = item.icon,
				})
				if item.tooltip then control.tipTitle, control.tipBody = item.tooltipTitle or item.text, item.tooltip end
			end

			if control and control.SetScript and not item.menu and not item.separator then
				control:SetScript("OnClick", function(self)
					if item.toggle then self:SetSelected(not self:GetSelected()) end
					if item.onClick then item.onClick(self, item) end
				end)
			end
			return control
		end

		function bar:Layout()
			local left, right = style.pad, style.pad
			local pushing = false
			for index, item in ipairs(self.items or {}) do
				local control = self.controls[index]
				if item.spacer then
					pushing = true
				elseif control then
					local shown = not Resolve(item.hidden, item)
					control:SetShown(shown)
					if shown then
						control:ClearAllPoints()
						if pushing then
							control:SetPoint("RIGHT", -right, 0)
							right = right + control:GetWidth() + style.gap
						else
							control:SetPoint("LEFT", left, 0)
							left = left + control:GetWidth() + style.gap
						end
					end
				end
			end
			-- spaced from the right in reverse, so the last item sits on the edge.
			if pushing then
				right = style.pad
				for index = #(self.items or {}), 1, -1 do
					local item, control = self.items[index], self.controls[index]
					if item.spacer then break end
					if control and control:IsShown() then
						control:ClearAllPoints()
						control:SetPoint("RIGHT", -right, 0)
						right = right + control:GetWidth() + style.gap
					end
				end
			end
			if not width then self:SetWidth(left + style.pad) end
		end

		function bar:Refresh()
			for index, item in ipairs(self.items or {}) do
				local control = self.controls[index]
				if control and control.SetEnabled then
					SetControlEnabled(control, self:IsEnabled() and not Resolve(item.disabled, item))
					if item.selected ~= nil and control.SetSelected then
						control:SetSelected(Resolve(item.selected, item))
					end
				end
			end
		end

		function bar:SetItems(items)
			for _, control in pairs(self.controls) do
				if control then control:Hide() end
			end
			wipe(self.controls)
			wipe(self.byKey)
			self.items = items
			for index, item in ipairs(items or {}) do
				local control = Build(item)
				self.controls[index] = control
				if item.key and control then self.byKey[item.key] = control end
			end
			self:Layout()
			self:Refresh()
		end

		function bar:Get(key)
			return self.byKey[key]
		end

		if opts.items then bar:SetItems(opts.items) end
		return bar
	end

	--------------------------------------------------------------------------------
	-- Menu bar
	--------------------------------------------------------------------------------

	-- File, Edit, View. menus are { text, items, onSelect(value, item) }. once one
	-- is open, moving across the bar opens the others.
	function UI.MenuBar(parent, width, opts)
		opts = opts or {}
		local style = StyleFor("menubar", opts)

		local bar = CreateFrame("Frame", nil, parent)
		bar:SetSize(width or 1, style.height)
		Base(bar, opts)
		bar.style = style
		Chrome(bar, style)
		bar.titles = {}

		local function Paint(title)
			local open = bar.openIndex == title.index
			if title.openTex then title.openTex:SetShown(open) end
			UI.Paint(title.label, (open or title.hovered) and style.activeText or style.text, "text")
		end

		local function Watch()
			-- the menu's click catcher covers the bar, so the mouse is checked by hand.
			for _, title in ipairs(bar.titles) do
				if title:IsShown() and title.index ~= bar.openIndex and title:IsMouseOver() then
					return bar:Open(title.index)
				end
			end
		end

		function bar:Open(index)
			local title = self.titles[index]
			if not title then return end
			if self.openIndex and self.openIndex ~= index then
				local previous = self.titles[self.openIndex]
				self.openIndex = nil
				previous.menu:Close()
				Paint(previous)
			end
			self.openIndex = index
			title.menu:Open(title.spec.items)
			Paint(title)
			self:SetScript("OnUpdate", Watch)
		end

		function bar:Close()
			if self.openIndex then self.titles[self.openIndex].menu:Close() end
		end

		function bar:SetMenus(menus)
			local x = 0
			for index, spec in ipairs(menus or {}) do
				local title = self.titles[index]
				if not title then
					title = CreateFrame("Button", nil, bar)
					title.index = index
					title.label = UI.Text(title, "", style.font)
					title.label:SetPoint("CENTER")
					UI.Paint(title:CreateTexture(nil, "HIGHLIGHT"), style.highlight, "fill"):SetAllPoints()
					title.openTex = UI.Paint(title:CreateTexture(nil, "ARTWORK"), style.open, "fill")
					title.openTex:SetAllPoints()
					title.openTex:Hide()

					title.menu = UI.NewMenu({ width = "auto", style = opts.menuStyle })
					title.menu:AnchorTo(title)
					title.menu.OnClose = function()
						if bar.openIndex == title.index then
							bar.openIndex = nil
							bar:SetScript("OnUpdate", nil)
						end
						Paint(title)
					end

					title:SetScript("OnClick", function(self)
						if bar.openIndex == self.index then return bar:Close() end
						bar:Open(self.index)
					end)
					title:SetScript("OnEnter", function(self) self.hovered = true Paint(self) end)
					title:SetScript("OnLeave", function(self) self.hovered = false Paint(self) end)
					self.titles[index] = title
				end

				title.spec = spec
				title.menu.OnPick = function(value, item)
					if spec.onSelect then spec.onSelect(value, item) end
					if opts.onSelect then opts.onSelect(index, value, item) end
				end
				title.label:SetText(spec.text or "")
				title:SetSize(math.ceil(TextWidth(title.label) + style.padding), style.height)
				title:ClearAllPoints()
				title:SetPoint("LEFT", x, 0)
				title:Show()
				Paint(title)
				x = x + title:GetWidth()
			end
			for index = #(menus or {}) + 1, #self.titles do self.titles[index]:Hide() end
			if not width then self:SetWidth(math.max(1, x)) end
		end

		if opts.menus then bar:SetMenus(opts.menus) end
		return bar
	end

	--------------------------------------------------------------------------------
	-- Breadcrumb
	--------------------------------------------------------------------------------

	-- a path of { text, value } where the last is where you are. when it doesn't
	-- fit, the front folds into a "..." that lists what it hid.
	function UI.Breadcrumb(parent, width, opts)
		opts = opts or {}
		local style = StyleFor("breadcrumb", opts)

		local crumbs = CreateFrame("Frame", nil, parent)
		crumbs:SetSize(width, style.height)
		Base(crumbs, opts)
		crumbs.style = style
		crumbs.buttons, crumbs.arrows, crumbs.hidden = {}, {}, {}

		local function Crumb(index)
			local button = crumbs.buttons[index]
			if button then return button end
			button = CreateFrame("Button", nil, crumbs)
			button:SetHeight(style.height)
			button.label = UI.Text(button, "", style.font)
			button.label:SetPoint("LEFT")
			button.label:SetWordWrap(false)
			button:SetScript("OnEnter", function(self)
				if not self.current then UI.Paint(self.label, style.hover, "text") end
			end)
			button:SetScript("OnLeave", function(self)
				UI.Paint(self.label, self.current and style.current or style.text, "text")
			end)
			button:SetScript("OnClick", function(self)
				if self.current then return end
				if self.ellipsis then
					return UI.ContextMenu(crumbs.hidden, function(value, item)
						if opts.onSelect then opts.onSelect(value, item) end
					end, { anchor = self, width = "auto" })
				end
				if opts.onSelect then opts.onSelect(self.item.value, self.item, self.index) end
			end)
			crumbs.buttons[index] = button
			return button
		end

		local function Arrow(index)
			local arrow = crumbs.arrows[index]
			if not arrow then
				arrow = UI.Chevron(crumbs, style.separatorSize, style.text, "right")
				crumbs.arrows[index] = arrow
			end
			return arrow
		end

		function crumbs:SetItems(items)
			self.items = items or {}
			local count = #self.items

			local widths, total = {}, 0
			local measure = Crumb(1)
			for index, item in ipairs(self.items) do
				measure.label:SetText(Resolve(item.text, item) or "")
				widths[index] = math.ceil(TextWidth(measure.label))
				total = total + widths[index] + (index > 1 and style.separatorSize + style.gap * 2 or 0)
			end

			-- fold from the front, keeping the last one whatever happens.
			wipe(self.hidden)
			local first = 1
			measure.label:SetText("...")
			local ellipsisWidth = TextWidth(measure.label) + style.separatorSize + style.gap * 2
			while total + (first > 1 and ellipsisWidth or 0) > width and first < count do
				total = total - widths[first] - style.separatorSize - style.gap * 2
				self.hidden[#self.hidden + 1] = self.items[first]
				first = first + 1
			end

			local x, slot = 0, 0
			local function Place(text, item, index, isEllipsis)
				slot = slot + 1
				local button = Crumb(slot)
				if slot > 1 then
					local arrow = Arrow(slot - 1)
					arrow:ClearAllPoints()
					arrow:SetPoint("LEFT", x + style.gap, 0)
					arrow:Show()
					x = x + style.separatorSize + style.gap * 2
				end
				button.label:SetText(text)
				button.item, button.index, button.ellipsis = item, index, isEllipsis
				button.current = index == count
				local w = math.min(TextWidth(button.label), math.max(20, width - x))
				button:SetWidth(math.ceil(w))
				button.label:SetWidth(math.ceil(w))
				button:ClearAllPoints()
				button:SetPoint("LEFT", x, 0)
				UI.Paint(button.label, button.current and style.current or style.text, "text")
				button:Show()
				x = x + w
			end

			if first > 1 then Place("...", nil, 0, true) end
			for index = first, count do
				local item = self.items[index]
				Place(Resolve(item.text, item) or "", item, index, false)
			end

			for index = slot + 1, #self.buttons do self.buttons[index]:Hide() end
			for index = math.max(slot, 1), #self.arrows do self.arrows[index]:Hide() end
		end

		if opts.items then crumbs:SetItems(opts.items) end
		return crumbs
	end

	--------------------------------------------------------------------------------
	-- Pagination
	--------------------------------------------------------------------------------

	-- page numbers between a back and a forward arrow, with gaps folded into "...".
	-- opts takes pages, page, around (numbers shown either side, 1) and onChange(page).
	function UI.Pagination(parent, opts)
		opts = opts or {}
		local style = StyleFor("pagination", opts)

		local pager = CreateFrame("Frame", nil, parent)
		pager:SetHeight(style.height)
		Base(pager, opts)
		pager.style = style
		pager.pages, pager.page = opts.pages or 1, opts.page or 1
		pager.numbers, pager.gaps, pager.sequence = {}, {}, {}

		pager.back = UI.GlyphButton(pager, 9, "chevron", nil, nil, { facing = "left" })
		pager.forward = UI.GlyphButton(pager, 9, "chevron", nil, nil, { facing = "right" })

		local function Go(page)
			page = math.max(1, math.min(pager.pages, page))
			if page == pager.page then return end
			pager.page = page
			pager:Layout()
			if opts.onChange then opts.onChange(page, pager) end
		end

		pager.back:SetScript("OnClick", function() Go(pager.page - 1) end)
		pager.forward:SetScript("OnClick", function() Go(pager.page + 1) end)

		function pager:Layout()
			local around = opts.around or 1
			local seq = wipe(self.sequence)
			local last = 0
			for page = 1, self.pages do
				if page == 1 or page == self.pages or math.abs(page - self.page) <= around then
					if page - last > 1 then seq[#seq + 1] = false end
					seq[#seq + 1] = page
					last = page
				end
			end

			local x = 0
			self.back:ClearAllPoints()
			self.back:SetPoint("LEFT", x, 0)
			x = x + self.back:GetWidth() + style.gap
			SetControlEnabled(self.back, self.page > 1)

			local numbers, gaps = 0, 0
			for _, page in ipairs(seq) do
				if page then
					numbers = numbers + 1
					local button = self.numbers[numbers]
					if not button then
						button = UI.Button(self, "", style.size, style.height, { style = "ghost", autoWidth = true, minWidth = style.size, styleOverrides = { padding = 5 } })
						button:SetScript("OnClick", function(clicked) Go(clicked.page) end)
						self.numbers[numbers] = button
					end
					button.page = page
					button:SetText(tostring(page))
					button:SetSelected(page == self.page)
					button:ClearAllPoints()
					button:SetPoint("LEFT", x, 0)
					button:Show()
					x = x + button:GetWidth() + style.gap
				else
					gaps = gaps + 1
					local gap = self.gaps[gaps]
					if not gap then
						gap = UI.Text(self, "...", style.font, style.text)
						self.gaps[gaps] = gap
					end
					gap:ClearAllPoints()
					gap:SetPoint("LEFT", x, 0)
					gap:Show()
					x = x + TextWidth(gap) + style.gap
				end
			end
			for index = numbers + 1, #self.numbers do self.numbers[index]:Hide() end
			for index = gaps + 1, #self.gaps do self.gaps[index]:Hide() end

			self.forward:ClearAllPoints()
			self.forward:SetPoint("LEFT", x, 0)
			SetControlEnabled(self.forward, self.page < self.pages)
			self:SetWidth(x + self.forward:GetWidth())
		end

		function pager:SetPages(pages)
			self.pages = math.max(1, pages or 1)
			self.page = math.min(self.page, self.pages)
			self:Layout()
		end

		function pager:SetPage(page)
			self.page = math.max(1, math.min(self.pages, page or 1))
			self:Layout()
		end

		function pager:GetPage()
			return self.page, self.pages
		end

		pager:Layout()
		return pager
	end

	--------------------------------------------------------------------------------
	-- Steps
	--------------------------------------------------------------------------------

	-- numbered dots joined by a line for a flow in stages. opts takes steps (a list
	-- of labels), current, clickable (done steps can be gone back to) and onSelect(index).
	function UI.Steps(parent, width, opts)
		opts = opts or {}
		local style = StyleFor("steps", opts)

		local steps = CreateFrame("Frame", nil, parent)
		steps:SetWidth(width)
		Base(steps, opts)
		steps.style = style
		steps.dots, steps.lines = {}, {}
		steps.current = opts.current or 1

		function steps:Layout()
			local list = self.steps or {}
			local count = #list
			local span = count > 1 and (width - style.dot) / (count - 1) or 0
			local labels = false

			for index, text in ipairs(list) do
				local dot = self.dots[index]
				if not dot then
					dot = CreateFrame("Button", nil, self)
					dot:SetSize(style.dot, style.dot)
					dot.bg = dot:CreateTexture(nil, "ARTWORK")
					dot.bg:SetAllPoints()
					dot.number = UI.Text(dot, "", style.font)
					dot.number:SetPoint("CENTER", 0, 0)
					dot.label = UI.Text(self, "", style.font)
					dot.label:SetJustifyH("CENTER")
					dot:SetScript("OnClick", function(clicked)
						if opts.clickable and clicked.index < self.current then
							self:SetCurrent(clicked.index)
							if opts.onSelect then opts.onSelect(clicked.index, self) end
						end
					end)
					self.dots[index] = dot
				end
				dot.index = index

				local x = count > 1 and (index - 1) * span or (width - style.dot) / 2
				dot:ClearAllPoints()
				dot:SetPoint("TOPLEFT", x, 0)
				dot.number:SetText(index)

				local state = index < self.current and "done" or index == self.current and "current" or "todo"
				UI.Paint(dot.bg, style[state], "fill")
				UI.Paint(dot.number, state == "todo" and style.todoNumber or style.number, "text")

				dot.label:SetText(text or "")
				dot.label:ClearAllPoints()
				dot.label:SetPoint("TOP", dot, "BOTTOM", 0, -style.labelGap)
				UI.Paint(dot.label, state == "current" and style.activeText or style.text, "text")
				dot.label:Show()
				if text and text ~= "" then labels = true end
				dot:Show()

				if index > 1 then
					local line = self.lines[index - 1]
					if not line then
						line = self:CreateTexture(nil, "BACKGROUND")
						self.lines[index - 1] = line
					end
					line:ClearAllPoints()
					line:SetHeight(style.lineSize)
					line:SetPoint("LEFT", self.dots[index - 1], "RIGHT", 2, 0)
					line:SetPoint("RIGHT", dot, "LEFT", -2, 0)
					UI.Paint(line, index <= self.current and style.done or style.todo, "fill")
					line:Show()
				end
			end

			for index = count + 1, #self.dots do
				self.dots[index]:Hide()
				self.dots[index].label:Hide()
			end
			for index = math.max(count, 1), #self.lines do self.lines[index]:Hide() end

			self:SetHeight(style.dot + (labels and style.labelGap + 14 or 0))
		end

		function steps:SetSteps(list)
			self.steps = list
			self:Layout()
		end

		function steps:SetCurrent(index)
			self.current = index
			self:Layout()
		end

		function steps:GetCurrent()
			return self.current
		end

		steps:SetSteps(opts.steps)
		return steps
	end

	--------------------------------------------------------------------------------
	-- Spinner
	--------------------------------------------------------------------------------

	-- a glyph that turns while something loads. the animation only runs while it's shown.
	function UI.Spinner(parent, size, opts)
		opts = opts or {}
		local style = StyleFor("spinner", opts)

		local spinner = UI.Glyph(parent, opts.glyph or style.glyph, size or style.size, opts.color or style.color)
		local group = spinner.texture:CreateAnimationGroup()
		local turn = group:CreateAnimation("Rotation")
		turn:SetDegrees(-360)
		turn:SetDuration(style.speed)
		turn:SetOrigin("CENTER", 0, 0)
		group:SetLooping("REPEAT")
		spinner.animation = group

		function spinner:Start() self:Show() group:Play() end
		function spinner:Stop() group:Stop() self:Hide() end

		spinner:SetScript("OnShow", function() group:Play() end)
		spinner:SetScript("OnHide", function() group:Stop() end)
		if spinner:IsVisible() then group:Play() end
		return spinner
	end

	--------------------------------------------------------------------------------
	-- Toasts
	--------------------------------------------------------------------------------

	local toasts, spare = {}, {}

	local function Restack(style)
		local previous
		for _, toast in ipairs(toasts) do
			toast:ClearAllPoints()
			if previous then
				toast:SetPoint("TOP", previous, "BOTTOM", 0, -style.spacing)
			else
				local anchor = toast.anchor
				toast:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
			end
			previous = toast
		end
	end

	local function Dismiss(toast)
		if toast.timer then toast.timer:Cancel() toast.timer = nil end
		toast:Hide()
		for index, shown in ipairs(toasts) do
			if shown == toast then table.remove(toasts, index) break end
		end
		spare[#spare + 1] = toast
		Restack(toast.style)
	end

	-- a short note that stacks at the top of the screen and goes by itself. opts
	-- takes title, kind (info, good, warn, bad), icon, duration (0 stays until
	-- closed), anchor ({ point, relativeTo, relativePoint, x, y }) and onClick.
	function UI.Toast(text, opts)
		opts = opts or {}
		local style = StyleFor("toast", opts)

		local toast = table.remove(spare)
		if not toast then
			toast = CreateFrame("Button", nil, UIParent)
			toast:SetFrameStrata(style.strata)
			Chrome(toast, style)
			toast.stripe = toast:CreateTexture(nil, "ARTWORK")
			toast.stripe:SetPoint("TOPLEFT")
			toast.stripe:SetPoint("BOTTOMLEFT")
			toast.icon = toast:CreateTexture(nil, "ARTWORK")
			toast.icon:SetSize(24, 24)
			toast.title = UI.Text(toast, "", style.titleFont, style.title)
			toast.text = UI.Text(toast, "", style.font, style.text)
			toast.text:SetJustifyV("TOP")
			toast.close = UI.GlyphButton(toast, 9, "cross", "Dismiss")
			toast.close:SetPoint("TOPRIGHT", -2, -2)
			toast.close:SetScript("OnClick", function() Dismiss(toast) end)
			toast:SetScript("OnClick", function(self)
				if self.onClick then self.onClick(self) end
				Dismiss(self)
			end)
			-- hovering holds it, leaving starts the clock again.
			toast:SetScript("OnEnter", function(self)
				if self.timer then self.timer:Cancel() self.timer = nil end
			end)
			toast:SetScript("OnLeave", function(self)
				if self.duration > 0 and self:IsShown() and not self.timer then
					self.timer = C_Timer.NewTimer(self.duration, function() self.timer = nil Dismiss(self) end)
				end
			end)
		end

		toast.style = style
		toast.onClick = opts.onClick
		toast.duration = opts.duration or style.duration
		toast.anchor = opts.anchor or { "TOP", UIParent, "TOP", 0, -120 }
		toast:SetWidth(style.width)

		toast.stripe:SetWidth(style.stripeSize)
		UI.Paint(toast.stripe, style.kinds[opts.kind or "info"] or opts.kind or "accent", "fill")

		local left = style.pad + style.stripeSize
		if opts.icon then
			toast.icon:SetTexture(opts.icon)
			toast.icon:ClearAllPoints()
			toast.icon:SetPoint("TOPLEFT", left, -style.pad)
			toast.icon:Show()
			left = left + 30
		else
			toast.icon:Hide()
		end

		local textWidth = style.width - left - style.pad - 10
		local y = style.pad
		toast.title:SetText(opts.title or "")
		toast.title:SetShown(opts.title ~= nil)
		if opts.title then
			toast.title:ClearAllPoints()
			toast.title:SetPoint("TOPLEFT", left, -y)
			toast.title:SetWidth(textWidth)
			y = y + toast.title:GetStringHeight() + 3
		end

		toast.text:ClearAllPoints()
		toast.text:SetPoint("TOPLEFT", left, -y)
		toast.text:SetWidth(textWidth)
		toast.text:SetText(text or "")
		y = y + toast.text:GetStringHeight() + style.pad

		toast:SetHeight(math.max(y, opts.icon and 24 + style.pad * 2 or 0))

		toasts[#toasts + 1] = toast
		Restack(style)
		toast:Show()

		if toast.timer then toast.timer:Cancel() toast.timer = nil end
		if toast.duration > 0 then
			toast.timer = C_Timer.NewTimer(toast.duration, function() toast.timer = nil Dismiss(toast) end)
		end

		function toast:Dismiss() Dismiss(self) end
		return toast
	end
end)
