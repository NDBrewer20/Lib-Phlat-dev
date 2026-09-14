local lib = LibStub("LibPhlat-1.0")
if not lib.loading then return end

lib:Module("Theme", function(UI, P, config)
	local Resolve = P.Resolve
	local Merge = P.Merge
	local WEAK = P.WEAK
	local state = P.state
	local themed = P.themed
	local Fill = P.Fill
	local Chrome = P.Chrome
	local StyleFor = P.StyleFor
	UI.colors = {
		window   = { 0.055, 0.055, 0.067, 0.97 },
		titlebar = { 0.105, 0.105, 0.130, 1 },
		sidebar  = { 0.080, 0.080, 0.098, 1 },
		control  = { 0.140, 0.140, 0.170, 1 },
		popup    = { 0.100, 0.100, 0.125, 0.98 },
		row      = { 1, 1, 1, 0.030 },
		line     = { 1, 1, 1, 0.090 },
		border   = { 0, 0, 0, 0.85 },
		text     = { 0.920, 0.920, 0.950 },
		dim      = { 0.600, 0.600, 0.660 },
		disabled = { 0.420, 0.420, 0.460 },

		hover    = { 1, 1, 1, 0.045 },
		selected = { 1, 1, 1, 0.055 },
		inset    = { 0.025, 0.025, 0.035, 0.9 },
		track    = { 0.200, 0.200, 0.240, 1 },
		scroll   = { 1, 1, 1, 0.05 },
		thumb    = { 1, 1, 1, 0.22 },
		black    = { 0, 0, 0, 1 },
		white    = { 1, 1, 1, 1 },
		onAccent = { 0.050, 0.050, 0.060, 1 },
		good     = { 0.350, 0.800, 0.450, 1 },
		warn     = { 1.000, 0.820, 0.250, 1 },
		bad      = { 0.900, 0.300, 0.300, 1 },
	}

	Merge(UI.colors, config.colors)

	-- names a style can use for font instead of a font object.
	UI.fonts = {
		title   = "GameFontNormalLarge",
		heading = "GameFontNormal",
		body    = "GameFontHighlight",
		small   = "GameFontHighlightSmall",
		caption = "GameFontNormalSmall",
		large   = "GameFontHighlightLarge",
	}

	--------------------------------------------------------------------------------
	-- Accent and colors
	--------------------------------------------------------------------------------

	local accent

	-- class color unless config.Accent gives one. cached until RefreshAccent.
	function UI.Accent()
		if not accent then
			local override = config.Accent and config.Accent()
			if override then
				accent = override.r and { override.r, override.g, override.b } or override
			else
				local _, class = UnitClass("player")
				local color = (class and C_ClassColor and C_ClassColor.GetClassColor(class))
					or (class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
				accent = color and { color.r, color.g, color.b } or { 0.55, 0.42, 0.85 }
			end
		end
		return accent[1], accent[2], accent[3]
	end

	-- "key:alpha" strings are split once and kept.
	local parsed = {}
	local function ParseKey(spec)
		local entry = parsed[spec]
		if not entry then
			local key, alpha = spec:match("^([%w_]+):([%d%.]+)$")
			entry = { key or spec, tonumber(alpha) }
			parsed[spec] = entry
		end
		return entry[1], entry[2]
	end

	-- a color is a palette key, "key:alpha", "accent", a { r, g, b, a } table, a
	-- ColorMixin, or a function returning any of those. alpha multiplies on top.
	function UI.Color(spec, alpha)
		spec = Resolve(spec)
		local r, g, b, a

		if type(spec) == "string" then
			local key, keyAlpha = ParseKey(spec)
			if key == "accent" then
				r, g, b = UI.Accent()
				a = keyAlpha or 1
			else
				local color = UI.colors[key] or UI.colors.text
				r, g, b, a = color[1], color[2], color[3], (color[4] or 1) * (keyAlpha or 1)
			end
		elseif type(spec) == "table" then
			if spec.r then
				r, g, b, a = spec.r, spec.g, spec.b, spec.a or 1
			else
				r, g, b, a = spec[1], spec[2], spec[3], spec[4] or 1
			end
		else
			r, g, b, a = 1, 1, 1, 1
		end

		return r, g, b, a * (alpha or 1)
	end

	-- whether a spec could change when the accent does.
	local function UsesAccent(spec)
		if type(spec) == "function" then return true end
		return type(spec) == "string" and spec:sub(1, 6) == "accent"
	end

	--------------------------------------------------------------------------------
	-- Painting
	--
	-- every region the kit colors is written down with the spec it was colored
	-- from, so Repaint redoes all of them and RefreshAccent the accented ones.
	--------------------------------------------------------------------------------

	local painted = setmetatable({}, WEAK)

	-- widgets with state driven colors, which repaint themselves through Refresh.
	local themed = setmetatable({}, WEAK)

	local function Apply(region, spec, how)
		local r, g, b, a = UI.Color(spec)
		if how == "text" then
			region:SetTextColor(r, g, b, a)
		elseif how == "vertex" then
			region:SetVertexColor(r, g, b, a)
		else
			region:SetColorTexture(r, g, b, a)
		end
	end

	-- how is "fill", "text" or "vertex", guessed from the region when left out.
	function UI.Paint(region, spec, how)
		how = how or (region.SetTextColor and "text" or "fill")

		local entry = painted[region]
		if entry then
			entry[1], entry[2] = spec, how
		else
			painted[region] = { spec, how }
		end

		Apply(region, spec, how)
		return region
	end

	-- stops the kit repainting a region someone else colors now.
	function UI.Unpaint(region)
		painted[region] = nil
	end

	local function RefreshThemed()
		for widget in pairs(themed) do
			if widget.Refresh then widget:Refresh() end
		end
	end

	function UI.Repaint()
		for region, entry in pairs(painted) do
			Apply(region, entry[1], entry[2])
		end
		RefreshThemed()
	end

	-- paints a texture or font string in the accent and keeps it for RefreshAccent.
	function UI.Accented(region, alpha)
		return UI.Paint(region, "accent:" .. tostring(alpha or 1))
	end

	-- re-reads the accent and repaints everything accented so far. plain fills are
	-- left alone, since an addon may have tinted those itself.
	function UI.RefreshAccent()
		accent = nil
		for region, entry in pairs(painted) do
			if UsesAccent(entry[1]) then Apply(region, entry[1], entry[2]) end
		end
		RefreshThemed()
	end

	--------------------------------------------------------------------------------
	-- Styles
	--
	-- UI.styles[kind][name] is a table of looks for one kind of widget. a widget
	-- builds from default, then the named style (and whatever that extends), then
	-- anything in opts.styleOverrides. colors in a style are color specs.
	--------------------------------------------------------------------------------

	UI.styles = {
		button = {
			default = {
				width = 150, height = 22, bg = "control", border = "border", borderSize = 1,
				highlight = "accent:0.22", selected = "accent:0.30", font = "small",
				text = "text", disabledText = "disabled", justify = "CENTER",
				padding = 10, iconSize = 14, iconGap = 5,
			},
			primary = { bg = "accent:0.80", highlight = "white:0.12", selected = "white:0.18", text = "onAccent" },
			ghost = { bg = false, border = false, highlight = "accent:0.15", text = "dim", hoverText = "text" },
			danger = { bg = "bad:0.22", border = "bad:0.55", highlight = "bad:0.25" },
			link = { bg = false, border = false, highlight = false, text = "accent", hoverText = "text", padding = 0 },
			tool = { width = 22, height = 22, padding = 4, highlight = "accent:0.18" },
		},
		glyphButton = {
			default = {
				pad = 8, color = "dim", hoverColor = "accent", activeColor = "text",
				disabledColor = "disabled", bg = false, border = false, highlight = false,
				selected = false,
			},
			boxed = { bg = "control", border = "border", highlight = "accent:0.18", color = "text" },
			wash = { highlight = "accent:0.18", selected = "accent:0.30", hoverColor = "text" },
		},
		iconButton = {
			default = {
				pad = 6, tint = true, color = "dim", hoverColor = "accent",
				disabledColor = "disabled", bg = false, border = false, highlight = false,
				selected = "accent:0.30", inset = 0, zoom = 0.08,
			},
			boxed = { tint = false, pad = 0, inset = 3, bg = "control", border = "border", highlight = "accent:0.18" },
			plain = { tint = false, highlight = "accent:0.30" },
		},
		icon = {
			default = { bg = false, border = false, inset = 0, zoom = 0.08 },
			framed = { bg = "black", border = "border", inset = 2 },
		},
		checkbox = {
			default = {
				size = 18, bg = "control", border = "border", highlight = "accent:0.20",
				mark = "accent", markInset = 4, shape = "square",
				font = "body", text = "text", disabledText = "disabled", gap = 8,
			},
			tick = { shape = "check", markInset = 2 },
			round = { shape = "round", markInset = 5 },
		},
		radio = {
			default = {
				size = 16, bg = "control", border = "border", highlight = "accent:0.20",
				mark = "accent", markInset = 4, shape = "square",
				font = "body", text = "text", disabledText = "disabled", gap = 8,
			},
			round = { shape = "round", markInset = 4 },
		},
		switch = {
			default = {
				width = 32, height = 16, track = "control", trackOn = "accent:0.45",
				border = "border", knob = "dim", knobOn = "accent", inset = 2,
				highlight = "accent:0.12", font = "body", text = "text",
				disabledText = "disabled", gap = 8,
			},
		},
		editbox = {
			default = {
				width = 200, height = 22, bg = "control", border = "border", focus = "accent",
				font = "small", text = "text", hint = "dim", inset = 7,
			},
			ghost = { bg = false, border = false, focus = false },
			underline = { bg = false, border = false, focus = false, rule = "line", focusRule = "accent" },
		},
		textarea = {
			default = {
				bg = "control", border = "border", focus = "accent", font = "small",
				text = "text", hint = "dim", inset = 7, step = 24,
			},
			code = { bg = "inset", border = false, focus = false },
		},
		slider = {
			default = {
				height = 18, track = "track", trackSize = 4, fill = "accent:0.55",
				thumb = "accent", thumbWidth = 8, thumbHeight = 16,
			},
			thin = { trackSize = 2, thumbWidth = 6, thumbHeight = 12 },
		},
		progress = {
			default = {
				height = 14, bg = "control", border = "border", fill = "accent:0.85",
				font = "small", text = "text", justify = "CENTER",
			},
			thin = { height = 4, border = false },
		},
		badge = {
			default = { height = 14, bg = "accent:0.85", text = "onAccent", font = "small", padding = 5, minWidth = 14 },
			dim = { bg = "control", text = "dim" },
			warn = { bg = "warn:0.85" },
			bad = { bg = "bad:0.85", text = "white" },
		},
		dropdown = {
			default = {
				width = 170, height = 22, bg = "control", border = "border",
				highlight = "accent:0.18", font = "small", text = "text",
				disabledText = "disabled", placeholderText = "dim", justify = "LEFT",
				padLeft = 8, padRight = 20, chevron = true, chevronSize = 10,
				chevronColor = "dim", flipChevron = false, wrap = false,
			},
			ghost = { bg = false, border = false, highlight = "accent:0.12", text = "dim", hoverText = "text" },
			underline = { bg = false, border = false, rule = "line", hoverRule = "accent" },
			compact = { height = 18, padLeft = 6, padRight = 16, chevronSize = 8 },
			button = { justify = "CENTER", padLeft = 8, padRight = 8, chevron = false },
			link = {
				bg = false, border = false, highlight = false, text = "accent",
				hoverText = "text", chevronColor = "accent", padLeft = 0, padRight = 14,
			},
		},
		menu = {
			default = {
				rowHeight = 20, pad = 4, bg = "popup", border = "border",
				highlight = "accent:0.28", font = "small", text = "text", dim = "dim",
				disabledText = "disabled", header = "accent", separator = "line",
				separatorHeight = 7, check = "accent", iconSize = 14, arrowSize = 9,
				gap = 2, minWidth = 90, maxWidth = 420, searchHeight = 20,
			},
			compact = { rowHeight = 16, pad = 2 },
			roomy = { rowHeight = 24, pad = 6 },
		},
		segmented = {
			default = {
				height = 22, bg = "control", border = "border", highlight = "accent:0.15",
				selected = "accent:0.35", divider = "line", mark = false, font = "small",
				text = "dim", activeText = "text", emptyText = "disabled",
				disabledText = "disabled", gap = 0, padding = 14, minWidth = 30,
			},
		},
		tabs = {
			default = {
				height = 24, bg = "sidebar", border = "border", highlight = "accent:0.18",
				selected = false, divider = false, mark = "accent", markSide = "TOP",
				markSize = 2, font = "small", text = "dim", activeText = "text",
				emptyText = "disabled", disabledText = "disabled", gap = 4, padding = 22,
				minWidth = 64,
			},
			underline = {
				bg = false, border = false, highlight = "accent:0.12", selected = "selected",
				markSide = "BOTTOM", gap = 3, minWidth = 46,
			},
			pill = {
				bg = false, border = false, highlight = "accent:0.15", selected = "accent:0.35",
				mark = false, gap = 4, minWidth = 40,
			},
		},
		cycle = {
			default = {
				width = 150, height = 22, bg = "control", border = "border",
				highlight = "accent:0.18", font = "small", text = "text",
				disabledText = "disabled", arrowSize = 9, arrowColor = "dim",
			},
		},
		radiogroup = {
			default = { lineHeight = 22, radio = "default", font = "body", horizontalGap = 16 },
		},
		nav = {
			default = {
				rowHeight = 34, categoryHeight = 30, indent = 14, padLeft = 18, top = 12,
				highlight = "accent:0.12", selected = "selected", marker = "accent",
				markerSize = 3, font = "body", text = "dim", activeText = "text",
				categoryFont = "caption", categoryText = "dim", categoryHover = "text",
				upper = true, chevronSize = 10, iconSize = 16,
			},
			compact = { rowHeight = 24, categoryHeight = 24, padLeft = 12, top = 6 },
		},
		list = {
			default = {
				spacing = 2, bg = "row", highlight = "accent:0.20", mark = "accent",
				markSide = "LEFT", markSize = 2, selected = false, font = "small",
				text = "text", heading = "accent", headingFont = "caption",
				iconSize = 16, padding = 6,
			},
			plain = { bg = false, spacing = 0 },
		},
		scroll = {
			default = {
				bar = 5, gap = 7, track = "scroll", thumb = "thumb",
				thumbHover = "accent:0.6", step = 36, minThumb = 24,
			},
			thin = { bar = 3, gap = 5 },
		},
		window = {
			default = {
				titleHeight = 34, bg = "window", border = "black", titlebar = "titlebar",
				stripe = "accent:0.9", stripeSize = 2, titleFont = "title",
				titleText = "text", closeSize = 12, grip = "white:0.25", strata = "HIGH",
			},
			dialog = { strata = "FULLSCREEN_DIALOG" },
		},
		panel = {
			default = { bg = "popup", border = "border" },
			inset = { bg = "inset", border = false },
			flat = { bg = "window", border = false },
			clear = { bg = false, border = false },
		},
		section = {
			default = {
				height = 24, bg = false, highlight = "hover", font = "heading",
				text = "accent", rule = "line", chevronSize = 10, chevronColor = "dim",
			},
		},
		row = {
			default = {
				height = 30, bg = "row", hover = "hover", font = "body", text = "text",
				disabledText = "disabled", padding = 12, labelWidth = 0.55, gap = 3,
			},
		},
		dialog = {
			default = { width = 340, padding = 16, font = "body", buttonWidth = 100 },
		},
	}

	for kind, names in pairs(config.styles or {}) do
		UI.styles[kind] = UI.styles[kind] or {}
		for name, def in pairs(names) do
			local existing = UI.styles[kind][name]
			if existing then Merge(existing, def) else UI.styles[kind][name] = def end
		end
	end

	function UI.RegisterStyle(kind, name, def)
		UI.styles[kind] = UI.styles[kind] or {}
		UI.styles[kind][name] = def
		return def
	end

	-- default, then the named style or a style table, then overrides on top.
	function UI.Style(kind, style, overrides)
		local set = UI.styles[kind] or {}
		local out = {}

		local function Layer(def, depth)
			if type(def) ~= "table" or depth > 8 then return end
			if def.extends then Layer(set[def.extends], depth + 1) end
			Merge(out, def)
		end

		Layer(set.default, 0)
		if type(style) == "table" then
			Layer(style, 0)
		elseif style and style ~= "default" then
			Layer(set[style], 0)
		end
		Merge(out, overrides)

		out.extends = nil
		return out
	end

	-- style for a widget out of its opts, where opts.style is a name or a table.
	local function StyleFor(kind, opts)
		return UI.Style(kind, opts and opts.style, opts and opts.styleOverrides)
	end
	UI.StyleFor = StyleFor

	--------------------------------------------------------------------------------
	-- Primitives
	--------------------------------------------------------------------------------

	-- color can be any color spec. kept for Repaint either way.
	local function Fill(frame, layer, color)
		local tex = frame:CreateTexture(nil, layer or "BACKGROUND")
		tex:SetAllPoints()
		UI.Paint(tex, color or "control", "fill")
		return tex
	end
	UI.Fill = Fill

	-- four edge textures instead of a backdrop template.
	function UI.Border(frame, color, thickness)
		local edges = {}
		for i = 1, 4 do
			edges[i] = frame:CreateTexture(nil, "BORDER")
		end

		function edges:SetThickness(size)
			size = size or 1
			self[1]:ClearAllPoints()
			self[1]:SetPoint("TOPLEFT")
			self[1]:SetPoint("TOPRIGHT")
			self[1]:SetHeight(size)
			self[2]:ClearAllPoints()
			self[2]:SetPoint("BOTTOMLEFT")
			self[2]:SetPoint("BOTTOMRIGHT")
			self[2]:SetHeight(size)
			self[3]:ClearAllPoints()
			self[3]:SetPoint("TOPLEFT")
			self[3]:SetPoint("BOTTOMLEFT")
			self[3]:SetWidth(size)
			self[4]:ClearAllPoints()
			self[4]:SetPoint("TOPRIGHT")
			self[4]:SetPoint("BOTTOMRIGHT")
			self[4]:SetWidth(size)
		end

		-- a spec, so a palette change reaches it.
		function edges:Paint(spec)
			for i = 1, 4 do UI.Paint(self[i], spec, "fill") end
		end

		-- a raw color. written down too, or Repaint would put the old one back.
		function edges:SetColor(r, g, b, a)
			self:Paint({ r, g, b, a or 1 })
		end

		function edges:SetShown(shown)
			for i = 1, 4 do self[i]:SetShown(shown) end
		end

		edges:SetThickness(thickness)
		edges:Paint(color or "border")
		return edges
	end

	-- a 1px rule along one edge, or a line to anchor yourself when side is nil.
	function UI.Divider(parent, vertical, color, layer)
		local line = parent:CreateTexture(nil, layer or "ARTWORK")
		if vertical then line:SetWidth(1) else line:SetHeight(1) end
		UI.Paint(line, color or "line", "fill")
		return line
	end

	-- background, border, hover wash and bottom rule off a style. run again by
	-- SetStyle, so it reuses what's already there and hides what's gone.
	local function Chrome(frame, style)
		if style.bg then
			frame.bg = frame.bg or frame:CreateTexture(nil, "BACKGROUND")
			frame.bg:SetAllPoints()
			UI.Paint(frame.bg, style.bg, "fill")
			frame.bg:Show()
		elseif frame.bg then
			frame.bg:Hide()
		end

		if style.border then
			frame.edges = frame.edges or UI.Border(frame, style.border, style.borderSize)
			frame.edges:SetThickness(style.borderSize)
			frame.edges:Paint(style.border)
			frame.edges:SetShown(true)
		elseif frame.edges then
			frame.edges:SetShown(false)
		end

		if style.highlight then
			frame.highlight = frame.highlight or frame:CreateTexture(nil, "HIGHLIGHT")
			frame.highlight:SetAllPoints()
			UI.Paint(frame.highlight, style.highlight, "fill")
			frame.highlight:Show()
		elseif frame.highlight then
			frame.highlight:Hide()
		end

		if style.rule then
			if not frame.rule then
				frame.rule = frame:CreateTexture(nil, "BORDER")
				frame.rule:SetPoint("BOTTOMLEFT")
				frame.rule:SetPoint("BOTTOMRIGHT")
				frame.rule:SetHeight(1)
			end
			UI.Paint(frame.rule, style.rule, "fill")
			frame.rule:Show()
		elseif frame.rule then
			frame.rule:Hide()
		end
	end
	UI.Chrome = Chrome

	P.themed = themed
	P.Fill = Fill
	P.Chrome = Chrome
	P.StyleFor = StyleFor
end)
