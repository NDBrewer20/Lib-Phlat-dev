local lib = LibStub("LibPhlat-1.0")
if not lib.loading then return end

lib:Module("Glyphs", function(UI, P, config)
	local state = P.state
	local Chrome = P.Chrome
	local StyleFor = P.StyleFor
	local Base = P.Base
	local HoverScripts = P.HoverScripts
	local UNKNOWN_ICON = P.UNKNOWN_ICON
	local HasAtlas = P.HasAtlas
	local SelectedWash = P.SelectedWash
	--------------------------------------------------------------------------------
	-- Glyphs
	--
	-- Blizzard's flat uitools icons tinted to match the panel. clients without the
	-- atlas fall back to the old button art.
	--------------------------------------------------------------------------------

	-- placeholder for an icon that's missing or unknown.
	local UNKNOWN_ICON = "Interface/ICONS/INV_Misc_QuestionMark"
	UI.UNKNOWN_ICON = UNKNOWN_ICON

	local ARROW_FILE = "Interface/Buttons/Arrow-Down-Up"

	-- fill is how much of the 20x20 atlas cell the art covers, so it can be grown
	-- to draw at the size asked for. facings are sideways atlases where there's one.
	UI.glyphs = {
		chevron = {
			atlas = "uitools-icon-chevron-down", fill = 0.6, file = ARROW_FILE,
			facings = { right = "uitools-icon-chevron-right", left = "uitools-icon-chevron-left" },
		},
		chevronRight = { atlas = "uitools-icon-chevron-right", fill = 0.6, file = ARROW_FILE, fileFacing = "right" },
		chevronLeft = { atlas = "uitools-icon-chevron-left", fill = 0.6, file = ARROW_FILE, fileFacing = "left" },
		gear = { atlas = "uitools-icon-settings", fill = 0.95, file = "Interface/Buttons/UI-OptionsButton" },
		cross = { atlas = "uitools-icon-close", fill = 0.6, file = "Interface/Buttons/UI-StopButton" },
		check = { atlas = "uitools-icon-checkmark", fill = 0.7, file = "Interface/Buttons/UI-CheckBox-Check" },
		plus = { atlas = "uitools-icon-plus", fill = 0.7, file = "Interface/Buttons/UI-PlusButton-Up" },
		minus = { atlas = "uitools-icon-minus", fill = 0.7, file = "Interface/Buttons/UI-MinusButton-Up" },
		search = { atlas = "uitools-icon-search", fill = 0.8, file = "Interface/Common/UI-Searchbox-Icon" },
		refresh = { atlas = "uitools-icon-refresh", fill = 0.8, file = "Interface/Buttons/UI-RefreshButton" },
		warning = { atlas = "uitools-icon-warning", fill = 0.85, file = "Interface/DialogFrame/UI-Dialog-Icon-AlertNew" },
		error = { atlas = "uitools-icon-error", fill = 0.85, file = "Interface/DialogFrame/UI-Dialog-Icon-AlertOther" },
		minimize = { atlas = "uitools-icon-minimize", fill = 0.6, file = "Interface/Buttons/UI-Panel-HideButton-Up" },
		resize = { atlas = "uitools-icon-window-resize", fill = 1, file = "Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up" },
	}

	-- adds or replaces a glyph every Glyph and GlyphButton can use by name.
	function UI.RegisterGlyph(name, spec)
		UI.glyphs[name] = spec
		return spec
	end

	-- the down arrow file turned by its coords, since a file can take them.
	local FILE_COORDS = {
		down = { 0, 1, 0, 1 },
		up = { 0, 1, 1, 0 },
		right = { 1, 0, 0, 0, 1, 1, 0, 1 },
		left = { 1, 1, 0, 1, 1, 0, 0, 0 },
	}

	-- no up chevron in the set so the down one is turned. SetAtlas owns the tex
	-- coords so they can't be flipped instead.
	local ROTATIONS = { down = 0, up = math.pi, right = math.pi / 2, left = math.pi * 1.5 }

	local atlasKnown = {}
	local function HasAtlas(name)
		if not name then return false end
		local known = atlasKnown[name]
		if known == nil then
			known = (C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name)) and true or false
			atlasKnown[name] = known
		end
		return known
	end
	UI.HasAtlas = HasAtlas

	local function GlyphSetFacing(self, facing)
		local glyph, tex = self.spec, self.texture
		facing = facing or "down"
		self.facing = facing

		if self.usesAtlas then
			local sideways = glyph.facings and glyph.facings[facing]
			if sideways and HasAtlas(sideways) then
				tex:SetAtlas(sideways)
				tex:SetRotation(0)
			else
				tex:SetAtlas(glyph.atlas)
				tex:SetRotation(ROTATIONS[facing] or 0)
			end
		else
			local coords = FILE_COORDS[glyph.fileFacing or facing] or FILE_COORDS.down
			tex:SetTexCoord(unpack(coords))
		end
	end

	-- grow past the holder by the art's padding.
	local function GlyphSetSize(self, size)
		self:SetSize(size, size)
		local grow = size * (1 / (self.spec.fill or 1) - 1) / 2
		self.texture:ClearAllPoints()
		self.texture:SetPoint("TOPLEFT", -grow, grow)
		self.texture:SetPoint("BOTTOMRIGHT", grow, -grow)
	end

	local function GlyphSetColor(self, shade)
		UI.Paint(self.texture, shade, "vertex")
	end

	-- name is a key in UI.glyphs or a glyph table. the texture sits in a frame so
	-- it can be anchored, shown and tinted as one.
	function UI.Glyph(parent, name, size, color, facing)
		local glyph = type(name) == "table" and name or UI.glyphs[name] or UI.glyphs.cross

		local holder = CreateFrame("Frame", nil, parent)
		holder.spec = glyph
		holder.texture = holder:CreateTexture(nil, "OVERLAY")

		holder.SetFacing = GlyphSetFacing
		holder.SetGlyphSize = GlyphSetSize
		holder.SetColor = GlyphSetColor

		holder.usesAtlas = HasAtlas(glyph.atlas)
		if holder.usesAtlas then
			holder.texture:SetAtlas(glyph.atlas)
		else
			holder.texture:SetTexture(glyph.file or UNKNOWN_ICON)
			holder.texture:SetDesaturated(true)
		end

		-- pixel snapping blurs art drawn away from its native size.
		holder.texture:SetSnapToPixelGrid(false)
		holder.texture:SetTexelSnappingBias(0)

		holder:SetGlyphSize(size)
		if facing or glyph.fileFacing then holder:SetFacing(facing) end
		holder:SetColor(color or UI.colors.text)
		return holder
	end

	-- facing is "down" (default), "up", "left" or "right".
	function UI.Chevron(parent, size, color, facing)
		return UI.Glyph(parent, "chevron", size, color, facing)
	end

	function UI.Gear(parent, size, color) return UI.Glyph(parent, "gear", size, color) end
	function UI.Cross(parent, size, color) return UI.Glyph(parent, "cross", size, color) end
	function UI.Check(parent, size, color) return UI.Glyph(parent, "check", size, color) end
	function UI.Plus(parent, size, color) return UI.Glyph(parent, "plus", size, color) end
	function UI.Minus(parent, size, color) return UI.Glyph(parent, "minus", size, color) end

	-- a builder for GlyphButton and friends, for any glyph and facing.
	function UI.GlyphBuilder(name, facing)
		return function(parent, size, color)
			return UI.Glyph(parent, name, size, color, facing)
		end
	end

	--------------------------------------------------------------------------------
	-- Glyph and icon buttons
	--------------------------------------------------------------------------------

	-- selected wash for any button, made the first time it's needed.
	local function SelectedWash(button, spec)
		if not spec then
			if button.selectedTex then button.selectedTex:Hide() end
			return
		end
		if not button.selectedTex then
			button.selectedTex = button:CreateTexture(nil, "ARTWORK", nil, -1)
			button.selectedTex:SetAllPoints()
		end
		UI.Paint(button.selectedTex, spec, "fill")
		button.selectedTex:SetShown(button.selectedState == true)
	end

	-- Build is a glyph name or a function(parent, size, color) like UI.Gear. dim at
	-- rest, accent on hover, grey when disabled. padded so it's easier to hit.
	function UI.GlyphButton(parent, size, Build, title, body, opts)
		local style = StyleFor("glyphButton", opts)

		local button = CreateFrame("Button", nil, parent)
		button:SetSize(size + style.pad, size + style.pad)
		Base(button, opts)
		button.style = style
		Chrome(button, style)

		if type(Build) == "function" then
			button.glyph = Build(button, size, style.color)
		else
			button.glyph = UI.Glyph(button, Build or "cross", size, style.color, opts and opts.facing)
		end
		button.glyph:SetPoint("CENTER")
		if title or body then button.tipTitle, button.tipBody = title, body end

		function button:Refresh()
			local s = self.style
			local color = s.color
			if not self:IsEnabled() then
				color = s.disabledColor
			elseif self.hovered then
				color = s.hoverColor
			elseif self.selectedState then
				color = s.activeColor or s.hoverColor
			end
			if self.glyph.SetColor then self.glyph:SetColor(color) end
			if self.selectedTex then self.selectedTex:SetShown(self.selectedState == true) end
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
			self.style = UI.Style("glyphButton", newStyle, overrides)
			Chrome(self, self.style)
			SelectedWash(self, self.style.selected)
			self:Refresh()
		end

		HoverScripts(button)
		button:SetScript("OnEnable", button.Refresh)
		button:SetScript("OnDisable", button.Refresh)

		if opts and opts.onClick then
			button:SetScript("OnClick", opts.onClick)
		end

		button:Refresh()
		return button
	end

	local function IconSetTexture(texture, source, atlas, zoom)
		if source and (atlas or (type(source) == "string" and HasAtlas(source) and not source:find("[/\\]"))) then
			texture:SetAtlas(source)
		else
			texture:SetTexture(source or UNKNOWN_ICON)
			zoom = zoom or 0
			texture:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
		end
	end

	-- texture is a file, a file id or an atlas name. style framed gives it a black
	-- box and a border. zoom trims the default icon border off.
	function UI.Icon(parent, size, texture, opts)
		local style = StyleFor("icon", opts)

		local holder = CreateFrame("Frame", nil, parent)
		holder:SetSize(size, size)
		holder.style = style
		Chrome(holder, style)

		local icon = holder:CreateTexture(nil, "ARTWORK")
		icon:SetPoint("TOPLEFT", style.inset, -style.inset)
		icon:SetPoint("BOTTOMRIGHT", -style.inset, style.inset)
		holder.texture = icon

		function holder:SetIcon(source, atlas)
			IconSetTexture(icon, source, atlas or (opts and opts.atlas), self.style.zoom)
		end

		function holder:SetDesaturated(state)
			icon:SetDesaturated(state and true or false)
		end

		holder:SetIcon(texture)
		return holder
	end

	-- an icon as a button. the default style tints it like a glyph, boxed puts it
	-- in a control box, plain keeps its own colors with a hover wash.
	function UI.IconButton(parent, size, texture, title, body, opts)
		local style = StyleFor("iconButton", opts)

		local button = CreateFrame("Button", nil, parent)
		button:SetSize(size + style.pad, size + style.pad)
		Base(button, opts)
		button.style = style
		Chrome(button, style)

		local icon = button:CreateTexture(nil, "ARTWORK")
		button.icon = icon
		if style.inset > 0 then
			icon:SetPoint("TOPLEFT", style.inset, -style.inset)
			icon:SetPoint("BOTTOMRIGHT", -style.inset, style.inset)
		else
			icon:SetSize(size, size)
			icon:SetPoint("CENTER")
		end
		if title or body then button.tipTitle, button.tipBody = title, body end

		function button:SetIcon(source, atlas)
			IconSetTexture(icon, source, atlas or (opts and opts.atlas), self.style.tint and 0 or self.style.zoom)
			self:Refresh()
		end

		function button:Refresh()
			local s = self.style
			if s.tint then
				icon:SetDesaturated(true)
				local color = s.color
				if not self:IsEnabled() then
					color = s.disabledColor
				elseif self.hovered or self.selectedState then
					color = s.hoverColor
				end
				UI.Paint(icon, color, "vertex")
			else
				UI.Unpaint(icon)
				icon:SetVertexColor(1, 1, 1, 1)
				icon:SetDesaturated(not self:IsEnabled())
				icon:SetAlpha(self:IsEnabled() and 1 or 0.5)
			end
			if self.selectedTex then self.selectedTex:SetShown(self.selectedState == true) end
		end

		function button:SetSelected(state)
			self.selectedState = state and true or false
			SelectedWash(self, self.style.selected)
			self:Refresh()
		end

		function button:SetStyle(newStyle, overrides)
			self.style = UI.Style("iconButton", newStyle, overrides)
			Chrome(self, self.style)
			self:Refresh()
		end

		HoverScripts(button)
		button:SetScript("OnEnable", button.Refresh)
		button:SetScript("OnDisable", button.Refresh)
		if opts and opts.onClick then button:SetScript("OnClick", opts.onClick) end

		button:SetIcon(texture)
		return button
	end

	P.UNKNOWN_ICON = UNKNOWN_ICON
	P.HasAtlas = HasAtlas
	P.SelectedWash = SelectedWash
end)
