local lib = LibStub("LibPhlat-1.0")
if not lib.loading then return end

lib:Module("Widget", function(UI, P, config)
	local Resolve = P.Resolve
	local WEAK = P.WEAK
	local state = P.state
	local themed = P.themed
	local Fill = P.Fill
	local TrackFont = P.TrackFont
	local FontTemplate = P.FontTemplate
	local TextWidth = P.TextWidth
	local BODY = P.BODY
	local Base = P.Base
	local HoverScripts = P.HoverScripts
	local StateColor = P.StateColor
	--------------------------------------------------------------------------------
	-- Fonts
	--
	-- every font string and its template size, since the original size can't be
	-- read back once it's been scaled.
	--------------------------------------------------------------------------------

	local fontScale = config.fontScale or 1
	local fontFace, fontFlags = config.font, config.fontFlags
	local fonts = setmetatable({}, WEAK)

	local function ApplyFont(fs, info)
		fs:SetFont(fontFace or info.file, info.size * fontScale, fontFlags or info.flags or "")
	end

	local function TrackFont(fs, size)
		local file, templateSize, flags = fs:GetFont()
		if not file then return end

		local info = { file = file, size = size or templateSize, flags = flags }
		fonts[fs] = info
		if size or fontScale ~= 1 or fontFace or fontFlags then ApplyFont(fs, info) end
	end
	UI.TrackFont = TrackFont

	local function FontTemplate(name)
		return name and UI.fonts[name] or name or "GameFontHighlight"
	end
	UI.FontTemplate = FontTemplate

	function UI.FontScale()
		return fontScale
	end

	-- scales all kit text, including what's already on screen.
	function UI.SetFontScale(scale)
		fontScale = scale or 1
		for fs, info in pairs(fonts) do ApplyFont(fs, info) end
	end

	-- swaps the font file on all kit text. nil goes back to each template's own.
	function UI.SetFontFace(file, flags)
		fontFace, fontFlags = file, flags
		for fs, info in pairs(fonts) do ApplyFont(fs, info) end
	end

	-- a size of its own for one string, still scaled with the rest.
	function UI.SetFontSize(fs, size)
		local info = fonts[fs]
		if not info then return end
		info.size = size
		ApplyFont(fs, info)
	end

	-- changes the template of a kit string without losing track of it.
	function UI.SetFontTemplate(fs, template)
		fs:SetFontObject(FontTemplate(template))
		TrackFont(fs)
	end

	-- template is a font object name or a UI.fonts name. passing a table instead
	-- takes font, size, color, justify, justifyV, wrap, width and layer.
	function UI.Text(parent, text, template, color)
		local opts
		if type(template) == "table" then
			opts, template = template, template.font
			color = color or opts.color
		end

		local fs = parent:CreateFontString(nil, opts and opts.layer or "OVERLAY", FontTemplate(template))
		fs:SetText(text or "")
		fs:SetJustifyH(opts and opts.justify or "LEFT")

		-- plain tables are set once like they always were, a spec is kept for Repaint.
		if color == nil or (type(color) == "table" and not color.r) then
			local c = color or UI.colors.text
			fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
		else
			UI.Paint(fs, color, "text")
		end

		TrackFont(fs, opts and opts.size)

		if opts then
			if opts.wrap == false then fs:SetWordWrap(false) end
			if opts.width then fs:SetWidth(opts.width) end
			if opts.justifyV then fs:SetJustifyV(opts.justifyV) end
		end
		return fs
	end

	-- width a string wants, not what it's been squeezed into.
	local function TextWidth(fs)
		if fs.GetUnboundedStringWidth then return fs:GetUnboundedStringWidth() end
		return fs:GetStringWidth()
	end
	UI.TextWidth = TextWidth

	--------------------------------------------------------------------------------
	-- Tooltips
	--
	-- read off the frame: tipTitle and tipBody (values or functions of the frame),
	-- tipLines for more, tipAnchor, or tipFunc(frame, tooltip) to fill it yourself.
	--------------------------------------------------------------------------------

	local BODY = { 0.72, 0.72, 0.78 }

	function UI.ShowTooltip(frame)
		if frame.tipFunc then
			GameTooltip:SetOwner(frame, frame.tipAnchor or "ANCHOR_RIGHT")
			if frame.tipFunc(frame, GameTooltip) == false then
				GameTooltip:Hide()
				return
			end
			GameTooltip:Show()
			return
		end

		local title, body = Resolve(frame.tipTitle, frame), Resolve(frame.tipBody, frame)
		local lines = Resolve(frame.tipLines, frame)
		if not (title or body or lines) then return end

		GameTooltip:SetOwner(frame, frame.tipAnchor or "ANCHOR_RIGHT")
		if title then GameTooltip:AddLine(title, 1, 1, 1) end
		if body then GameTooltip:AddLine(body, BODY[1], BODY[2], BODY[3], true) end

		for _, line in ipairs(lines or {}) do
			if type(line) ~= "table" then
				GameTooltip:AddLine(line, BODY[1], BODY[2], BODY[3], true)
			elseif line.right then
				local r, g, b = UI.Color(line.color or BODY)
				local rr, rg, rb = UI.Color(line.rightColor or "text")
				GameTooltip:AddDoubleLine(line.text or line[1], line.right, r, g, b, rr, rg, rb)
			else
				local r, g, b = UI.Color(line.color or BODY)
				GameTooltip:AddLine(line.text or line[1], r, g, b, line.wrap ~= false)
			end
		end
		GameTooltip:Show()
	end

	-- as a script handler it only hides a tooltip this frame owns.
	function UI.HideTooltip(frame)
		if type(frame) == "table" and GameTooltip.IsOwned and not GameTooltip:IsOwned(frame) then
			return
		end
		GameTooltip:Hide()
	end

	-- kit widgets show it from their own hover scripts. anything else gets the
	-- scripts set, or hooked when it already has some.
	local function HookTooltipScripts(frame)
		if frame.tipAware then return end
		if frame:GetScript("OnEnter") then
			if frame.tipHooked then return end
			frame.tipHooked = true
			frame:HookScript("OnEnter", UI.ShowTooltip)
			frame:HookScript("OnLeave", UI.HideTooltip)
		else
			frame:SetScript("OnEnter", UI.ShowTooltip)
			frame:SetScript("OnLeave", UI.HideTooltip)
		end
	end

	-- opts takes anchor and lines.
	function UI.Tooltip(frame, title, body, opts)
		frame.tipTitle, frame.tipBody = title, body
		if opts then
			frame.tipAnchor, frame.tipLines = opts.anchor, opts.lines
		end
		HookTooltipScripts(frame)
		return frame
	end

	-- for tooltips off the game itself, an item or a spell. return false from Fill
	-- and nothing shows.
	function UI.HookTooltip(frame, Fill, anchor)
		frame.tipFunc, frame.tipAnchor = Fill, anchor
		HookTooltipScripts(frame)
		return frame
	end

	--------------------------------------------------------------------------------
	-- Widget base
	--------------------------------------------------------------------------------

	local function SetEnabledFallback(self, enabled)
		self.disabled = not enabled
		if self.Refresh then self:Refresh() end
	end

	local function IsEnabledFallback(self)
		return not self.disabled
	end

	local function SetTooltipMethod(self, title, body, opts)
		return UI.Tooltip(self, title, body, opts)
	end

	-- what every kit widget gets. themed ones repaint through Refresh.
	local function Base(frame, opts)
		frame.tipAware = true
		if not frame.SetEnabled then frame.SetEnabled = SetEnabledFallback end
		if not frame.IsEnabled then frame.IsEnabled = IsEnabledFallback end
		frame.SetTooltip = SetTooltipMethod
		themed[frame] = true

		if opts and opts.tooltip then
			local tip = opts.tooltip
			if type(tip) == "table" then
				frame.tipTitle, frame.tipBody = tip.title or tip[1], tip.body or tip[2]
				frame.tipLines, frame.tipAnchor = tip.lines, tip.anchor
			else
				frame.tipBody = tip
			end
			frame.tipTitle = frame.tipTitle or opts.tooltipTitle
		end
		return frame
	end
	UI.Base = Base

	-- hover state, a Refresh and the tooltip, the way most controls want it.
	local function HoverScripts(frame)
		frame:SetScript("OnEnter", function(self)
			self.hovered = true
			if self.Refresh then self:Refresh() end
			UI.ShowTooltip(self)
			if self.OnHover then self:OnHover(true) end
		end)
		frame:SetScript("OnLeave", function(self)
			self.hovered = false
			if self.Refresh then self:Refresh() end
			UI.HideTooltip(self)
			if self.OnHover then self:OnHover(false) end
		end)
	end
	UI.HoverScripts = HoverScripts

	-- the color a label should be for a widget's state.
	local function StateColor(frame, style, base, active)
		if frame.IsEnabled and not frame:IsEnabled() then return style.disabledText or "disabled" end
		if active and style.activeText then return style.activeText end
		if frame.hovered and style.hoverText then return style.hoverText end
		return base or style.text or "text"
	end
	UI.StateColor = StateColor

	P.TrackFont = TrackFont
	P.FontTemplate = FontTemplate
	P.TextWidth = TextWidth
	P.BODY = BODY
	P.Base = Base
	P.HoverScripts = HoverScripts
	P.StateColor = StateColor
end)
