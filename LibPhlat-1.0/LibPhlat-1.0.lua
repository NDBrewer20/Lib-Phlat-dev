--------------------------------------------------------------------------------
-- LibPhlat-1.0
--
-- Flat, dark widget kit. Everything is built from bare frames and solid colour
-- textures on purpose: Blizzard renames templates and atlases between patches,
-- and none of this should break when they do.
--
-- Lifted out of Phocus so Phocus and Phield Guide build their panels from the
-- same parts. One kit per addon:
--
--   local UI = LibStub("LibPhlat-1.0"):New({ ... })
--
-- and every UI.Thing below is called the same way it always was.
--------------------------------------------------------------------------------

local MAJOR, MINOR = "LibPhlat-1.0", 6
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

-- Only one dropdown list is ever open, across every kit built from this library,
-- so the open one is tracked out here rather than once per addon.
local openList

local function CloseOpenList()
	if openList then openList:Hide() end
end
lib.CloseDropdowns = CloseOpenList

--------------------------------------------------------------------------------
-- New
--
-- `config` wires up the things the kit cannot work out for itself:
--
--   config.Accent()          -> { r, g, b } to override the class colour, or nil
--   config.Get(key)          -> the value a row with that key should show
--   config.Set(key, value)   store it, and refresh whatever needs refreshing
--   config.colors            palette overrides, merged over the defaults
--------------------------------------------------------------------------------

function lib:New(config)
	config = config or {}

	local UI = {}

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
	}

	-- An addon can repaint any of these without the kit caring which.
	for key, value in pairs(config.colors or {}) do
		UI.colors[key] = value
	end

	--------------------------------------------------------------------------------
	-- Accent colour
	--------------------------------------------------------------------------------

	local accent
	local accentRegions = {}

	-- Follows the player's class colour unless the Panel tab overrides it.
	function UI.Accent()
		if not accent then
			-- Whatever the addon says it wants, if it says anything; class colour if not.
			local override = config.Accent and config.Accent()
			if override then
				accent = override
			else
				local _, class = UnitClass("player")
				local color = (class and C_ClassColor and C_ClassColor.GetClassColor(class))
					or (class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
				accent = color and { color.r, color.g, color.b } or { 0.55, 0.42, 0.85 }
			end
		end
		return accent[1], accent[2], accent[3]
	end

	-- Regions registered here re-tint on demand, so changing the accent does not
	-- mean rebuilding the panel.
	function UI.Accented(region, alpha)
		accentRegions[region] = alpha or 1
		local r, g, b = UI.Accent()
		if region.SetColorTexture then
			region:SetColorTexture(r, g, b, alpha or 1)
		else
			region:SetTextColor(r, g, b, alpha or 1)
		end
		return region
	end

	function UI.RefreshAccent()
		accent = nil
		local r, g, b = UI.Accent()
		for region, alpha in pairs(accentRegions) do
			if region.SetColorTexture then
				region:SetColorTexture(r, g, b, alpha)
			else
				region:SetTextColor(r, g, b, alpha)
			end
		end
	end

	--------------------------------------------------------------------------------
	-- Primitives
	--------------------------------------------------------------------------------

	-- Every flat fill the kit has painted, against the colour it was painted
	-- from. Same idea as the accent regions below: an addon that changes what a
	-- colour means -- how see-through the window is, say -- edits the entry in
	-- UI.colors and calls Repaint, and what is already on screen follows instead
	-- of having to be built again.
	local fills = {}

	local function Fill(frame, layer, color)
		local tex = frame:CreateTexture(nil, layer or "BACKGROUND")
		tex:SetAllPoints()
		tex:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
		fills[tex] = color
		return tex
	end
	UI.Fill = Fill

	function UI.Repaint()
		for tex, color in pairs(fills) do
			tex:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
		end
	end

	-- Four edge textures in place of a backdrop template.
	function UI.Border(frame, color, thickness)
		color = color or UI.colors.border
		thickness = thickness or 1

		local edges = {}
		for i = 1, 4 do
			edges[i] = frame:CreateTexture(nil, "BORDER")
			edges[i]:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
		end
		edges[1]:SetPoint("TOPLEFT")
		edges[1]:SetPoint("TOPRIGHT")
		edges[1]:SetHeight(thickness)
		edges[2]:SetPoint("BOTTOMLEFT")
		edges[2]:SetPoint("BOTTOMRIGHT")
		edges[2]:SetHeight(thickness)
		edges[3]:SetPoint("TOPLEFT")
		edges[3]:SetPoint("BOTTOMLEFT")
		edges[3]:SetWidth(thickness)
		edges[4]:SetPoint("TOPRIGHT")
		edges[4]:SetPoint("BOTTOMRIGHT")
		edges[4]:SetWidth(thickness)

		function edges:SetColor(r, g, b, a)
			for i = 1, 4 do
				self[i]:SetColorTexture(r, g, b, a or 1)
			end
		end
		return edges
	end

	-- Every string the kit has drawn, against the size its template asked for.
	-- The size a template gives is the one thing a font string cannot be asked
	-- for again once it has been resized, so it is written down on the way past.
	local fontScale, fonts = 1, {}

	function UI.FontScale()
		return fontScale
	end

	-- Whole-kit text size. An addon that wants roomier or denser panels sets it
	-- and everything already drawn follows; anything drawn after comes out at
	-- the same size on its own.
	function UI.SetFontScale(scale)
		fontScale = scale or 1

		for fs, size in pairs(fonts) do
			local file, _, flags = fs:GetFont()
			if file then fs:SetFont(file, size * fontScale, flags) end
		end
	end

	function UI.Text(parent, text, template, color)
		local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
		fs:SetText(text or "")
		fs:SetJustifyH("LEFT")
		local c = color or UI.colors.text
		fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)

		local file, size, flags = fs:GetFont()
		if file then
			fonts[fs] = size
			if fontScale ~= 1 then fs:SetFont(file, size * fontScale, flags) end
		end

		return fs
	end

	function UI.ShowTooltip(frame)
		if not (frame.tipTitle or frame.tipBody) then return end
		GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
		if frame.tipTitle then GameTooltip:AddLine(frame.tipTitle, 1, 1, 1) end
		if frame.tipBody then GameTooltip:AddLine(frame.tipBody, 0.72, 0.72, 0.78, true) end
		GameTooltip:Show()
	end

	function UI.HideTooltip()
		GameTooltip:Hide()
	end

	function UI.Tooltip(frame, title, body)
		frame.tipTitle, frame.tipBody = title, body
		frame:SetScript("OnEnter", UI.ShowTooltip)
		frame:SetScript("OnLeave", UI.HideTooltip)
	end

	--------------------------------------------------------------------------------
	-- Glyphs
	--
	-- Blizzard's own flat icon set, tinted to wear the panel's colours. A caller
	-- asks for a size and a colour and gets a glyph; which art is behind it is
	-- this file's business and nobody else's.
	--------------------------------------------------------------------------------

	-- Stands in for an icon we don't have yet (an empty box, or a spell name the
	-- game doesn't recognise).
	local UNKNOWN_ICON = "Interface/ICONS/INV_Misc_QuestionMark"

	-- The proper flat art the note above was waiting for turned out to already be
	-- in the game: `uitools-icon-*` is Blizzard's own flat set, white line art on
	-- nothing at 20x20, drawn in the same register as the rest of this kit. So
	-- nothing is shipped and nothing is drawn by hand -- the old `Interface/Buttons`
	-- art each one replaces is kept as `file`, for a build that ever turns up
	-- without the atlas.
	--
	-- `fill` is how much of the 20x20 cell the art actually uses. They differ --
	-- the cross uses 12 of the 20, the gear nearly all of it -- and without it a
	-- caller asking for a 10px cross would get 6px of cross with air round it.
	local GLYPHS = {
		chevron = {
			atlas = "uitools-icon-chevron-down", fill = 0.6,
			file = "Interface/Buttons/Arrow-Down-Up",
		},
		chevronRight = {
			atlas = "uitools-icon-chevron-right", fill = 0.6,
			file = "Interface/Buttons/Arrow-Down-Up",
		},
		gear = {
			atlas = "uitools-icon-settings", fill = 0.95,
			file = "Interface/Buttons/UI-OptionsButton",
		},
		cross = {
			atlas = "uitools-icon-close", fill = 0.6,
			file = "Interface/Buttons/UI-StopButton",
		},
	}

	-- A glyph is a frame around one texture rather than the texture itself, so it
	-- can be anchored, shown and recoloured as a unit -- and so a swap like this
	-- one changes nothing at the call site.
	local function Glyph(parent, size, color, glyph, facing)
		local holder = CreateFrame("Frame", nil, parent)
		holder:SetSize(size, size)

		holder.texture = holder:CreateTexture(nil, "OVERLAY")

		-- Grown past the holder by whatever padding the art carries, so the size
		-- asked for is the size drawn.
		local grow = size * (1 / glyph.fill - 1) / 2
		holder.texture:SetPoint("TOPLEFT", -grow, grow)
		holder.texture:SetPoint("BOTTOMRIGHT", grow, -grow)

		if C_Texture.GetAtlasInfo(glyph.atlas) then
			holder.texture:SetAtlas(glyph.atlas)
		else
			holder.texture:SetTexture(glyph.file)
			holder.texture:SetDesaturated(true) -- chrome, not treasure

			-- The old art is one arrow pointing down, so a sideways one is that
			-- arrow turned: the 8-coordinate form of SetTexCoord, a quarter
			-- anti-clockwise.
			if facing == "right" then
				holder.texture:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
			end
		end

		-- Art this size is being drawn at a size it was not authored at, and
		-- snapping it to whole pixels is what makes a clean line go soft.
		holder.texture:SetSnapToPixelGrid(false)
		holder.texture:SetTexelSnappingBias(0)

		-- There is no chevron pointing up in the set, so the one pointing down is
		-- turned over. A rotation rather than a flipped texture coordinate,
		-- because SetAtlas owns the coordinates and setting them again would point
		-- the texture at some other part of the sheet.
		if facing == "up" then
			holder.texture:SetRotation(math.pi)
		end

		function holder:SetColor(shade)
			self.texture:SetVertexColor(shade[1], shade[2], shade[3], shade[4] or 1)
		end

		holder:SetColor(color or UI.colors.text)
		return holder
	end

	-- `facing` is "down" (the default), "up" or "right".
	function UI.Chevron(parent, size, color, facing)
		local glyph = facing == "right" and GLYPHS.chevronRight or GLYPHS.chevron
		return Glyph(parent, size, color, glyph, facing)
	end

	function UI.Gear(parent, size, color)
		return Glyph(parent, size, color, GLYPHS.gear)
	end

	function UI.Cross(parent, size, color)
		return Glyph(parent, size, color, GLYPHS.cross)
	end

	-- A glyph that behaves like a button. Sized a little larger than the glyph it
	-- holds so there is something to aim at, and tinted the same three ways as the
	-- rest of the chrome: dim at rest, accented under the cursor, greyed when it has
	-- nothing to do.
	function UI.GlyphButton(parent, size, Build, title, body)
		local button = CreateFrame("Button", nil, parent)
		button:SetSize(size + 8, size + 8)

		button.glyph = Build(button, size, UI.colors.dim)
		button.glyph:SetPoint("CENTER")
		button.tipTitle, button.tipBody = title, body

		function button:Refresh()
			if not self:IsEnabled() then
				self.glyph:SetColor({ 0.42, 0.42, 0.46 })
			elseif self.hovered then
				self.glyph:SetColor({ UI.Accent() })
			else
				self.glyph:SetColor(UI.colors.dim)
			end
		end

		button:SetScript("OnEnter", function(self)
			self.hovered = true
			self:Refresh()
			if self.tipTitle then UI.ShowTooltip(self) end
		end)
		button:SetScript("OnLeave", function(self)
			self.hovered = false
			self:Refresh()
			UI.HideTooltip()
		end)
		button:SetScript("OnEnable", button.Refresh)
		button:SetScript("OnDisable", button.Refresh)

		button:Refresh()
		return button
	end

	--------------------------------------------------------------------------------
	-- Controls
	--------------------------------------------------------------------------------

	function UI.Button(parent, text, width, height)
		local button = CreateFrame("Button", nil, parent)
		button:SetSize(width or 150, height or 22)
		button.bg = Fill(button, "BACKGROUND", UI.colors.control)
		button.edges = UI.Border(button)

		-- Buttons show their HIGHLIGHT layer on mouseover for free.
		UI.Accented(button:CreateTexture(nil, "HIGHLIGHT"), 0.22):SetAllPoints()

		button.label = UI.Text(button, text, "GameFontHighlightSmall")
		button.label:SetPoint("CENTER")
		button.label:SetJustifyH("CENTER")

		-- The native Button:SetText needs SetFontString, which brings Blizzard's
		-- disabled-font handling with it. This is the whole of what we want.
		function button:SetText(label)
			self.label:SetText(label)
		end

		button:SetScript("OnEnable", function(self)
			self.label:SetTextColor(unpack(UI.colors.text))
		end)
		button:SetScript("OnDisable", function(self)
			self.label:SetTextColor(0.40, 0.40, 0.44)
		end)
		return button
	end

	function UI.Checkbox(parent)
		local box = CreateFrame("Button", nil, parent)
		box:SetSize(18, 18)
		box.bg = Fill(box, "BACKGROUND", UI.colors.control)
		box.edges = UI.Border(box)

		UI.Accented(box:CreateTexture(nil, "HIGHLIGHT"), 0.20):SetAllPoints()

		local mark = box:CreateTexture(nil, "ARTWORK")
		mark:SetPoint("TOPLEFT", 4, -4)
		mark:SetPoint("BOTTOMRIGHT", -4, 4)
		UI.Accented(mark, 1)
		mark:Hide()
		box.mark = mark

		function box:SetChecked(state)
			self.checked = state and true or false
			if self.checked then self.mark:Show() else self.mark:Hide() end
		end
		function box:GetChecked()
			return self.checked
		end

		box:SetScript("OnDisable", function(self) self.mark:SetAlpha(0.35) end)
		box:SetScript("OnEnable", function(self) self.mark:SetAlpha(1) end)
		return box
	end

	function UI.EditBox(parent, width, height)
		local box = CreateFrame("EditBox", nil, parent)
		box:SetSize(width or 200, height or 22)
		box:SetAutoFocus(false)
		box:SetFontObject("GameFontHighlightSmall")
		box:SetTextInsets(7, 7, 0, 0)
		box.bg = Fill(box, "BACKGROUND", UI.colors.control)
		box.edges = UI.Border(box)

		box:SetScript("OnEscapePressed", box.ClearFocus)
		box:SetScript("OnEnterPressed", box.ClearFocus)
		box:SetScript("OnEditFocusGained", function(self)
			self.edges:SetColor(UI.Accent())
		end)
		box:SetScript("OnEditFocusLost", function(self)
			local c = UI.colors.border
			self.edges:SetColor(c[1], c[2], c[3], c[4])
		end)
		return box
	end

	function UI.Slider(parent, minValue, maxValue, step)
		local slider = CreateFrame("Slider", nil, parent)
		slider:SetOrientation("HORIZONTAL")
		slider:SetHeight(18)
		slider:SetMinMaxValues(minValue, maxValue)
		slider:SetValueStep(step)
		slider:SetObeyStepOnDrag(true)
		slider:SetHitRectInsets(0, 0, -4, -4)

		local track = slider:CreateTexture(nil, "BACKGROUND")
		track:SetHeight(4)
		track:SetPoint("LEFT")
		track:SetPoint("RIGHT")
		track:SetColorTexture(0.20, 0.20, 0.24, 1)

		-- SetThumbTexture takes a texture created on the slider; the slider then
		-- positions it, which lets the fill bar simply anchor to the thumb.
		local thumb = slider:CreateTexture(nil, "OVERLAY")
		thumb:SetSize(8, 16)
		UI.Accented(thumb, 1)
		slider:SetThumbTexture(thumb)

		local fill = slider:CreateTexture(nil, "ARTWORK")
		fill:SetHeight(4)
		fill:SetPoint("LEFT", track, "LEFT")
		fill:SetPoint("RIGHT", thumb, "CENTER")
		UI.Accented(fill, 0.55)

		slider:SetScript("OnDisable", function() thumb:SetAlpha(0.35) fill:SetAlpha(0.35) end)
		slider:SetScript("OnEnable", function() thumb:SetAlpha(1) fill:SetAlpha(1) end)
		return slider
	end

	function UI.ColorSwatch(parent, width, height)
		local swatch = CreateFrame("Button", nil, parent)
		swatch:SetSize(width or 44, height or 18)
		Fill(swatch, "BACKGROUND", { 0, 0, 0, 1 })
		swatch.edges = UI.Border(swatch)

		local color = swatch:CreateTexture(nil, "ARTWORK")
		color:SetPoint("TOPLEFT", 1, -1)
		color:SetPoint("BOTTOMRIGHT", -1, 1)
		swatch.swatch = color

		UI.Accented(swatch:CreateTexture(nil, "HIGHLIGHT"), 0.25):SetAllPoints()

		function swatch:SetColor(r, g, b, a)
			self.swatch:SetColorTexture(r, g, b, a or 1)
		end
		return swatch
	end

	-- Wraps the Blizzard colour picker, which changed shape in 10.2.5. Falls back to
	-- the older field-assignment form if the current one is missing.
	function UI.OpenColorPicker(r, g, b, a, hasAlpha, callback)
		local function Apply()
			local nr, ng, nb = ColorPickerFrame:GetColorRGB()
			local na = 1
			if hasAlpha then
				if ColorPickerFrame.GetColorAlpha then
					na = ColorPickerFrame:GetColorAlpha()
				elseif OpacitySliderFrame then
					na = OpacitySliderFrame:GetValue()
				end
			end
			callback(nr, ng, nb, na)
		end

		local info = {
			swatchFunc = Apply,
			opacityFunc = Apply,
			cancelFunc = function() callback(r, g, b, a) end,
			hasOpacity = hasAlpha and true or false,
			opacity = a or 1,
			r = r, g = g, b = b,
		}

		if ColorPickerFrame.SetupColorPickerAndShow then
			ColorPickerFrame:SetupColorPickerAndShow(info)
		else
			for key, value in pairs(info) do ColorPickerFrame[key] = value end
			ColorPickerFrame:SetColorRGB(r, g, b)
			ColorPickerFrame:Show()
		end
	end

	--------------------------------------------------------------------------------
	-- Dropdown
	--
	-- An item can carry a `submenu`: a list of its own, or a function that builds
	-- one on demand. Hovering the row opens it off the side of the list, and
	-- clicking the row still picks the row itself, so a parent is one click and
	-- what sits under it is one hover away. That beats drilling in and back out,
	-- which costs a click each way and loses the rest of the list while you are
	-- in there.
	--------------------------------------------------------------------------------

	UI.CloseDropdowns = CloseOpenList

	local ENTRY_HEIGHT = 20
	local PANEL_PAD = 4

	local function PanelHeight(count)
		return math.max(8, count * ENTRY_HEIGHT + PANEL_PAD * 2)
	end

	-- One row. The list and the flyout are the same panel twice, so they are
	-- built and filled by the same pair of functions rather than two near copies.
	local function NewEntry(panel, index, OnClick, OnEnter)
		local entry = CreateFrame("Button", nil, panel)
		entry:SetHeight(ENTRY_HEIGHT)

		local y = -PANEL_PAD - (index - 1) * ENTRY_HEIGHT
		entry:SetPoint("TOPLEFT", PANEL_PAD, y)
		entry:SetPoint("TOPRIGHT", -PANEL_PAD, y)

		UI.Accented(entry:CreateTexture(nil, "HIGHLIGHT"), 0.28):SetAllPoints()
		entry.label = UI.Text(entry, "", "GameFontHighlightSmall")
		entry.label:SetPoint("LEFT", 7, 0)
		entry.label:SetPoint("RIGHT", -7, 0)

		entry.index = index
		entry:SetScript("OnClick", OnClick)
		if OnEnter then entry:SetScript("OnEnter", OnEnter) end
		return entry
	end

	-- The arrow that says a row has more under it. Made the first time a row
	-- wants one, since most rows never do, and the text gives up the space for
	-- it so a long name does not run underneath.
	local function EntryArrow(entry, wanted)
		if wanted and not entry.arrow then
			entry.arrow = UI.Chevron(entry, 9, UI.colors.dim, "right")
			entry.arrow:SetPoint("RIGHT", -5, 0)
		end
		if entry.arrow then entry.arrow:SetShown(wanted and true or false) end
		entry.label:SetPoint("RIGHT", wanted and -16 or -7, 0)
	end

	local function FillPanel(panel, items, OnClick, OnEnter)
		panel.items = items

		for i = 1, math.max(#items, #panel.entries) do
			local entry = panel.entries[i]
			if not entry and items[i] then
				entry = NewEntry(panel, i, OnClick, OnEnter)
				panel.entries[i] = entry
			end

			if entry then
				local item = items[i]
				if item then
					entry.value = item.value
					entry.submenu = item.submenu
					entry.label:SetText(item.text)
					EntryArrow(entry, item.submenu)
					entry:Show()
				else
					entry:Hide()
				end
			end
		end

		panel:SetHeight(PanelHeight(#items))
	end

	-- The text for a value, looking into submenus as well as the top list. Only
	-- a submenu that is already a table is searched: calling a builder here would
	-- mean building every one of them to draw a single label, and a caller that
	-- hands over builders has its own label anyway.
	local function FindText(items, value)
		for i = 1, #items do
			local item = items[i]
			if item.value == value then return item.text end
			if type(item.submenu) == "table" then
				local text = FindText(item.submenu, value)
				if text then return text end
			end
		end
	end

	function UI.Dropdown(parent, width)
		local dd = CreateFrame("Button", nil, parent)
		dd:SetSize(width or 170, 22)
		dd.bg = Fill(dd, "BACKGROUND", UI.colors.control)
		dd.edges = UI.Border(dd)
		UI.Accented(dd:CreateTexture(nil, "HIGHLIGHT"), 0.18):SetAllPoints()

		dd.label = UI.Text(dd, "", "GameFontHighlightSmall")
		dd.label:SetPoint("LEFT", 8, 0)
		dd.label:SetPoint("RIGHT", -20, 0)

		UI.Chevron(dd, 10, UI.colors.dim):SetPoint("RIGHT", -8, 0)

		local list = CreateFrame("Frame", nil, UIParent)
		list:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)
		list:SetPoint("TOPRIGHT", dd, "BOTTOMRIGHT", 0, -2)
		list:SetFrameStrata("FULLSCREEN_DIALOG")
		Fill(list, "BACKGROUND", UI.colors.popup)
		UI.Border(list)
		list:Hide()
		list.entries = {}
		dd.list = list

		-- The panel that opens off the side for a row with a submenu. One per
		-- dropdown, refilled for whichever row is under the cursor. It is a child
		-- of the list so it sits above the click catcher and goes away with it.
		local flyout = CreateFrame("Frame", nil, list)
		flyout:SetFrameStrata("FULLSCREEN_DIALOG")
		flyout:SetFrameLevel(list:GetFrameLevel() + 10)
		flyout:SetWidth(width or 170)
		Fill(flyout, "BACKGROUND", UI.colors.popup)
		UI.Border(flyout)
		flyout:Hide()
		flyout.entries = {}
		dd.flyout = flyout

		-- Clicking anywhere outside the list closes it.
		local catcher = CreateFrame("Button", nil, UIParent)
		catcher:SetAllPoints(UIParent)
		catcher:SetFrameStrata("FULLSCREEN_DIALOG")
		catcher:Hide()
		catcher:SetScript("OnClick", function() list:Hide() end)

		list:SetScript("OnShow", function(self)
			if openList and openList ~= self then openList:Hide() end
			openList = self
			catcher:Show()
			catcher:SetFrameLevel(math.max(1, self:GetFrameLevel() - 1))
		end)
		list:SetScript("OnHide", function(self)
			if openList == self then openList = nil end
			flyout.owner = nil
			flyout:Hide()
			catcher:Hide()
		end)
		dd:SetScript("OnHide", function() list:Hide() end)

		local function HideFlyout()
			flyout.owner = nil
			flyout:Hide()
		end

		-- Picking a row, whether it came off the list or off a flyout. keepOpen
		-- is for lists where more than one entry can be picked: the label is the
		-- caller's summary of the set, so SetValue must not overwrite it with the
		-- entry just clicked.
		local function OnEntryClick(self)
			if not dd.keepOpen then
				HideFlyout()
				list:Hide()
				dd:SetValue(self.value)
			end
			if dd.OnSelect then dd.OnSelect(self.value) end
		end

		local function OpenFlyout(entry)
			local items = entry.submenu
			if type(items) == "function" then items = items() end
			if type(items) ~= "table" or #items == 0 then return HideFlyout() end

			flyout.owner = entry
			FillPanel(flyout, items, OnEntryClick)

			-- Re-stated on every open: the list is restrata'd when it shows, and
			-- a child keeps whatever level it was given, not a relative one.
			flyout:SetFrameLevel(list:GetFrameLevel() + 10)

			-- Level with the row it belongs to, and out the left instead when
			-- there is not enough screen to the right of the list.
			local y = -(entry.index - 1) * ENTRY_HEIGHT
			flyout:ClearAllPoints()
			if (list:GetRight() or 0) + flyout:GetWidth() <= UIParent:GetRight() then
				flyout:SetPoint("TOPLEFT", list, "TOPRIGHT", 0, y)
			else
				flyout:SetPoint("TOPRIGHT", list, "TOPLEFT", 0, y)
			end
			flyout:Show()

			-- Off the bottom, so it slides up until it is not.
			local bottom = flyout:GetBottom()
			if bottom and bottom < 0 then
				local point, relative, relativePoint, x = flyout:GetPoint(1)
				flyout:SetPoint(point, relative, relativePoint, x, y - bottom)
			end
		end

		-- Only the list opens flyouts. A flyout row needs no OnEnter at all --
		-- the cursor being on it is what keeps the thing alive.
		local function OnEntryEnter(self)
			if self.submenu then OpenFlyout(self) else HideFlyout() end
		end

		-- A flyout that closed the moment the cursor left its row would be
		-- impossible to reach, so it lives while the cursor is over either it or
		-- the row that opened it, and it is checked on a slow tick rather than on
		-- every leave.
		flyout:SetScript("OnUpdate", function(self, elapsed)
			self.since = (self.since or 0) + elapsed
			if self.since < 0.1 then return end
			self.since = 0

			if self:IsMouseOver() then return end
			if self.owner and self.owner:IsMouseOver() then return end
			HideFlyout()
		end)

		dd.items, dd.entries = {}, list.entries

		function dd:SetItems(items)
			HideFlyout()
			self.items = items
			FillPanel(list, items, OnEntryClick, OnEntryEnter)
		end

		function dd:SetValue(value)
			self.value = value
			local text = FindText(self.items, value)
			self.label:SetText(text or (value and tostring(value)) or self.placeholder or "")
		end

		dd:SetScript("OnClick", function()
			if list:IsShown() then list:Hide() else list:Show() end
		end)
		dd:SetScript("OnDisable", function(self)
			self.label:SetTextColor(0.40, 0.40, 0.44)
			list:Hide()
		end)
		dd:SetScript("OnEnable", function(self)
			self.label:SetTextColor(unpack(UI.colors.text))
		end)
		return dd
	end

	--------------------------------------------------------------------------------
	-- Scrolling
	--------------------------------------------------------------------------------

	-- `SetInsetTop` reserves a strip along the top that does not scroll, for a page
	-- that wants something pinned above its rows. Everything below works off the
	-- remaining height rather than the full one.
	function UI.ScrollArea(parent, width, height)
		local area = CreateFrame("Frame", nil, parent)
		area:SetSize(width, height)

		local inset, viewHeight = 0, height

		local scroll = CreateFrame("ScrollFrame", nil, area)
		scroll:SetPoint("TOPLEFT")
		scroll:SetSize(width - 12, height)

		local content = CreateFrame("Frame", nil, scroll)
		content:SetSize(width - 12, height)
		scroll:SetScrollChild(content)

		local track = CreateFrame("Frame", nil, area)
		track:SetPoint("TOPRIGHT")
		track:SetSize(5, height)
		Fill(track, "BACKGROUND", { 1, 1, 1, 0.05 })

		local thumb = CreateFrame("Frame", nil, track)
		thumb:SetPoint("TOPLEFT")
		thumb:SetPoint("TOPRIGHT")
		thumb:SetHeight(40)
		Fill(thumb, "ARTWORK", { 1, 1, 1, 0.22 })
		thumb:EnableMouse(true)
		thumb:RegisterForDrag("LeftButton")

		area.scroll, area.content = scroll, content

		local function Range()
			return math.max(0, content:GetHeight() - viewHeight)
		end

		-- The one place that pushes width, height and inset onto the frames, so a
		-- resize and an inset change can never disagree about the geometry.
		local function Apply(keepScroll)
			viewHeight = height - inset

			area:SetSize(width, height)

			scroll:ClearAllPoints()
			scroll:SetPoint("TOPLEFT", 0, -inset)
			scroll:SetSize(width - 12, viewHeight)

			content:SetWidth(width - 12)

			track:ClearAllPoints()
			track:SetPoint("TOPRIGHT", 0, -inset)
			track:SetSize(5, viewHeight)

			area:ScrollTo(keepScroll or 0) -- clamped to whatever the new range allows
		end

		function area:SetInsetTop(value)
			value = value or 0
			if inset == value then return end

			-- Kept, not reset: the inset changes while a size slider is being dragged,
			-- and snapping to the top on every step would be unusable.
			inset = value
			Apply(scroll:GetVerticalScroll())
		end

		-- Same again for the whole area, which is what a resizable window needs.
		-- Whatever is inside still has to re-lay itself out and call Update.
		function area:Resize(newWidth, newHeight)
			if newWidth == width and newHeight == height then return end

			width, height = newWidth, newHeight
			Apply(scroll:GetVerticalScroll())
		end

		function area:Update()
			local range = Range()
			if range <= 0 then
				scroll:SetVerticalScroll(0)
				track:Hide()
				return
			end

			track:Show()
			local thumbHeight = math.max(24, viewHeight * (viewHeight / content:GetHeight()))
			local offset = (scroll:GetVerticalScroll() / range) * (viewHeight - thumbHeight)
			thumb:SetHeight(thumbHeight)
			thumb:SetPoint("TOPLEFT", track, "TOPLEFT", 0, -offset)
			thumb:SetPoint("TOPRIGHT", track, "TOPRIGHT", 0, -offset)
		end

		function area:ScrollTo(value)
			scroll:SetVerticalScroll(math.min(math.max(value, 0), Range()))
			self:Update()
		end

		scroll:EnableMouseWheel(true)
		scroll:SetScript("OnMouseWheel", function(_, delta)
			CloseOpenList()
			area:ScrollTo(scroll:GetVerticalScroll() - delta * 36)
		end)

		-- Dragging the thumb maps the cursor onto the scroll range directly.
		thumb:SetScript("OnDragStart", function(self)
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
			self:SetScript("OnUpdate", nil)
		end)

		return area
	end

	--------------------------------------------------------------------------------
	-- Window
	--------------------------------------------------------------------------------

	function UI.Window(globalName, width, height, titleText)
		local frame = CreateFrame("Frame", globalName, UIParent)
		frame:SetSize(width, height)
		frame:SetPoint("CENTER")
		frame:SetFrameStrata("HIGH")
		frame:SetToplevel(true)
		frame:EnableMouse(true)
		frame:SetMovable(true)
		frame:SetClampedToScreen(true)
		frame:Hide()

		frame.bg = Fill(frame, "BACKGROUND", UI.colors.window)
		UI.Border(frame, { 0, 0, 0, 1 })

		local bar = CreateFrame("Frame", nil, frame)
		bar:SetPoint("TOPLEFT")
		bar:SetPoint("TOPRIGHT")
		bar:SetHeight(34)
		Fill(bar, "BACKGROUND", UI.colors.titlebar)
		bar:EnableMouse(true)
		bar:RegisterForDrag("LeftButton")
		bar:SetScript("OnDragStart", function() frame:StartMoving() end)
		bar:SetScript("OnDragStop", function()
			frame:StopMovingOrSizing()
			if frame.OnMoved then frame:OnMoved() end
		end)
		frame.titlebar = bar

		local stripe = bar:CreateTexture(nil, "ARTWORK")
		stripe:SetPoint("BOTTOMLEFT")
		stripe:SetPoint("BOTTOMRIGHT")
		stripe:SetHeight(2)
		UI.Accented(stripe, 0.9)

		frame.title = UI.Text(bar, titleText, "GameFontNormalLarge")
		frame.title:SetPoint("LEFT", 14, 1)

		-- The kit's own cross rather than Blizzard's UIPanelCloseButton, which
		-- arrives gold and beveled and matches nothing else on the window. This one
		-- wears the same three tints as the rest of the chrome: dim at rest,
		-- accented under the cursor.
		local close = UI.GlyphButton(bar, 12, UI.Cross)
		close:SetPoint("RIGHT", -6, 0)
		close:SetScript("OnClick", function() frame:Hide() end)

		-- Handed out because a window registered with the UI panel system has to
		-- close through HideUIPanel, not a bare Hide, or the panel system keeps
		-- thinking the slot is still taken.
		frame.close = close

		if globalName then tinsert(UISpecialFrames, globalName) end
		return frame
	end

	--------------------------------------------------------------------------------
	-- Layout
	--
	-- Settings are stacked as uniform rows: label on the left, control on the right.
	-- Every builder returns a widget with an Update method and registers it with the
	-- layout, so a single UpdateAll re-reads the whole page after any change. That is
	-- what keeps dependent controls (disabled states, previews) honest.
	--------------------------------------------------------------------------------

	local Layout = {}
	Layout.__index = Layout

	-- Handed out so an addon can add row builders of its own to the same layout.
	UI.LayoutProto = Layout

	function UI.Layout(parent, width)
		-- `rows` keys every row by its name, which is what lets the tour point at a
		-- setting without the page it lives on having to hand anything out.
		return setmetatable({
			parent = parent, width = width, y = 0,
			widgets = {}, rows = {},
			-- Every laid-out thing, in the order it was added, so a page can be
			-- reflowed when a row hides rather than leaving a hole where it was.
			elements = {},
		}, Layout)
	end

	-- Enable/Disable rather than SetEnabled: they exist on every control type here.
	local function SetControlEnabled(control, enabled)
		if enabled then control:Enable() else control:Disable() end
	end

	local function Round(value, step)
		if step and step >= 1 then return math.floor(value + 0.5) end
		return value
	end

	-- A row with a `key` and no get/set of its own falls through to wherever the
	-- addon keeps its settings, which is all config.Get and config.Set are.
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

	function Layout:Advance(height, gap)
		self.y = self.y + height + (gap or 3)
	end

	function Layout:Gap(height)
		self.y = self.y + (height or 8)
	end

	function Layout:Height()
		return self.y
	end

	-- Records one laid-out thing and puts it in place. `place(y)` positions whatever
	-- regions it owns, `pre` is the extra gap it wants above itself when it is not
	-- the first thing on the page, and `hidden` is asked on every reflow.
	function Layout:Add(element)
		self.elements[#self.elements + 1] = element

		if element.pre and self.y > 0 then self:Gap(element.pre) end
		element.place(self.y)
		self:Advance(element.height, element.gap)
		return element
	end

	-- Re-runs the whole page top to bottom, skipping anything currently hidden and
	-- closing the gap behind it. Cheap: a page is a few dozen rows and this only
	-- happens when a control is used.
	function Layout:Reflow()
		local y = 0

		for index = 1, #self.elements do
			local element = self.elements[index]
			local hidden = element.hidden and element.hidden() or false

			for _, region in ipairs(element.regions) do
				region:SetShown(not hidden)
			end

			if not hidden then
				if element.pre and y > 0 then y = y + element.pre end
				element.place(y)
				y = y + element.height + element.gap
			end
		end

		self.y = y
		if self.OnReflow then self:OnReflow(y) end
		return y
	end

	function Layout:Register(widget)
		self.widgets[#self.widgets + 1] = widget
		widget:Update()
		return widget
	end

	-- Two layouts making up one page -- a pinned strip and the rows scrolling under
	-- it -- have to answer to each other, since a setting changed in one is often
	-- previewed in the other. Linking is mutual.
	function Layout:Link(other)
		self.linked, other.linked = other, self
	end

	function Layout:UpdateAll()
		-- A linked pair would otherwise refresh each other for ever.
		if self.updating then return end
		self.updating = true

		for i = 1, #self.widgets do
			self.widgets[i]:Update()
		end
		-- After the widgets, since whether a row hides is usually decided by the
		-- setting the widget just wrote.
		self:Reflow()

		if self.linked then self.linked:UpdateAll() end
		self.updating = false
	end

	-- `hidden` on a header or a note takes the whole section heading away with the
	-- rows under it, so a section that does not apply leaves no trace.
	function Layout:Header(text, hidden)
		local header = UI.Text(self.parent, text, "GameFontNormal")
		UI.Accented(header, 1)

		local line = self.parent:CreateTexture(nil, "ARTWORK")
		line:SetSize(self.width, 1)
		line:SetColorTexture(unpack(UI.colors.line))

		self:Add({
			regions = { header, line },
			height = 21, gap = 8, pre = 16, hidden = hidden,
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

	function Layout:Row(opts, height)
		height = height or 30

		local row = CreateFrame("Frame", nil, self.parent)
		row:SetSize(self.width, height)
		row:EnableMouse(true)
		if opts.name then self.rows[opts.name] = row end

		-- Handed back on the row so a widget that changes its own height can say so
		-- and let the next reflow close up behind it.
		row.element = self:Add({
			regions = { row },
			height = height, gap = 3, hidden = opts.hidden,
			place = function(y) row:SetPoint("TOPLEFT", 0, -y) end,
		})
		Fill(row, "BACKGROUND", UI.colors.row)

		local hover = row:CreateTexture(nil, "BORDER")
		hover:SetAllPoints()
		hover:SetColorTexture(1, 1, 1, 0.045)
		hover:Hide()

		row.label = UI.Text(row, opts.name, "GameFontHighlight")
		row.label:SetPoint("LEFT", 12, 0)
		row.label:SetWidth(self.width * 0.55)

		-- A description may be a function, for a row that describes itself
		-- differently depending on another setting.
		row.tipTitle = opts.name
		row.tipBody = type(opts.desc) == "function" and opts.desc() or opts.desc
		row:SetScript("OnEnter", function(self)
			hover:Show()
			UI.ShowTooltip(self)
		end)
		row:SetScript("OnLeave", function()
			hover:Hide()
			UI.HideTooltip()
		end)

		-- For a row that names or describes itself differently depending on another
		-- setting -- Rows or Columns, depending on which way the bar it belongs to
		-- grows. `opts.name` stays the key the row is filed under, so the tour can
		-- still find it by a name that does not move about underneath it.
		function row:SetTitle(text)
			self.label:SetText(text)
			self.tipTitle = text
		end

		function row:SetDescription(text)
			self.tipBody = text
		end

		function row:SetDisabled(disabled)
			if disabled then
				self.label:SetTextColor(0.42, 0.42, 0.46)
			else
				self.label:SetTextColor(unpack(UI.colors.text))
			end
		end

		return row
	end

	function Layout:Check(opts)
		local layout, row = self, self:Row(opts)
		local box = UI.Checkbox(row)
		box:SetPoint("RIGHT", -12, 0)

		local get, set = Getter(opts), Setter(opts)
		local function Toggle()
			set(not get())
			layout:UpdateAll()
		end

		box:SetScript("OnClick", Toggle)
		row:SetScript("OnMouseUp", function()
			if box:IsEnabled() and not box:IsMouseOver() then Toggle() end
		end)

		return layout:Register({
			Update = function()
				local disabled = opts.disabled and opts.disabled() or false
				SetControlEnabled(box, not disabled)
				row:SetDisabled(disabled)
				box:SetChecked(get())
			end,
		})
	end

	-- The number beside a slider is editable, because dragging is a poor way to land
	-- on a particular value. Typing commits on Enter or on clicking away; Escape puts
	-- the old number back. The slider and the box are two views of the same value, so
	-- each writes to the other.
	function Layout:Slider(opts)
		local layout, row = self, self:Row(opts)
		local slider = UI.Slider(row, opts.min, opts.max, opts.step)
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

		-- Only when it is not being typed into, or the caret would jump about under
		-- the player mid-edit.
		local function ShowValue(value)
			if box:HasFocus() then return end
			box:SetText(numberFormat:format(value))
			box:SetCursorPosition(0)
		end

		-- Anything unreadable, or outside the range, simply does not take -- the box
		-- is put back to the real value by the Update that follows.
		local function Commit(text)
			local value = tonumber(text)
			if not value then return end

			value = Round(math.min(math.max(value, opts.min), opts.max), opts.step)
			set(value)
			layout:UpdateAll()
		end

		box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
		box:SetScript("OnEscapePressed", function(self)
			self.reverting = true
			self:ClearFocus()
		end)

		-- Hooked rather than set, so the border still un-highlights itself.
		box:HookScript("OnEditFocusLost", function(self)
			if self.reverting then
				self.reverting = nil
			else
				Commit(self:GetText())
			end
			ShowValue(Round(get() or opts.min, opts.step))
		end)

		-- commitOnRelease is for settings that are disruptive to apply mid-drag --
		-- rescaling a window moves the slider out from under the cursor. The readout
		-- still tracks live so the drag has feedback; only the write waits.
		slider:SetScript("OnValueChanged", function(_, value)
			if applying then return end
			value = Round(value, opts.step)
			ShowValue(value)

			if opts.commitOnRelease then
				pending = value
			else
				set(value)
				-- Re-reading the page mid-drag is what makes previews track the
				-- slider. Update reapplies this value behind the `applying` guard,
				-- so it cannot feed back into the drag.
				layout:UpdateAll()
			end
		end)

		if opts.commitOnRelease then
			-- A slider captures the mouse while its thumb is held, so this fires even
			-- if the cursor has wandered off the control by the time it is released.
			slider:SetScript("OnMouseUp", function()
				if pending == nil then return end
				local value = pending
				pending = nil
				set(value)
				layout:UpdateAll()
			end)
		end

		return layout:Register({
			Update = function()
				local disabled = opts.disabled and opts.disabled() or false
				SetControlEnabled(slider, not disabled)
				SetControlEnabled(box, not disabled)
				row:SetDisabled(disabled)

				if opts.title then row:SetTitle(opts.title()) end
				if type(opts.desc) == "function" then row:SetDescription(opts.desc()) end

				applying = true
				local value = Round(get() or opts.min, opts.step)
				slider:SetValue(value)
				ShowValue(value)
				applying = false
			end,
		})
	end

	function Layout:Select(opts)
		local layout, row = self, self:Row(opts)
		local dropdown = UI.Dropdown(row, opts.controlWidth or 170)
		dropdown.placeholder = opts.placeholder
		dropdown:SetPoint("RIGHT", -12, 0)

		local get, set = Getter(opts), Setter(opts)
		dropdown.OnSelect = function(value)
			set(value)
			layout:UpdateAll()
		end

		local extra = opts.extra and opts.extra(row, dropdown, layout)

		return layout:Register({
			Update = function()
				local disabled = opts.disabled and opts.disabled() or false
				SetControlEnabled(dropdown, not disabled)
				row:SetDisabled(disabled)

				dropdown:SetItems(type(opts.items) == "function" and opts.items() or opts.items)
				dropdown:SetValue(get())

				if extra and extra.Update then extra.Update() end
			end,
		})
	end

	-- Several picks from one list, and the order they were picked in. The caller
	-- owns what a pick means and draws the standing into the item text; all this
	-- does is keep the list open and hand every click back.
	function Layout:MultiSelect(opts)
		local layout, row = self, self:Row(opts)
		local dropdown = UI.Dropdown(row, opts.controlWidth or 190)
		dropdown.keepOpen = true
		dropdown:SetPoint("RIGHT", -12, 0)

		dropdown.OnSelect = function(value)
			opts.toggle(value)
			layout:UpdateAll()
		end

		return layout:Register({
			Update = function()
				local disabled = opts.disabled and opts.disabled() or false
				SetControlEnabled(dropdown, not disabled)
				row:SetDisabled(disabled)

				dropdown:SetItems(opts.items())
				dropdown.label:SetText(opts.summary())
			end,
		})
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
					layout:UpdateAll()
				end)
		end)

		return layout:Register({
			Update = function()
				local color = get()
				swatch:SetColor(color[1], color[2], color[3], color[4] or 1)
			end,
		})
	end

	local function ChevronUp(parent, size, color)
		return UI.Chevron(parent, size, color, "up")
	end

	function Layout:Input(opts)
		local layout, row = self, self:Row(opts)
		local box = UI.EditBox(row, opts.controlWidth or 190, 22)
		box:SetPoint("RIGHT", -12, 0)

		-- Optional preview of whatever you typed (a spell icon, usually).
		--
		-- opts.browse turns that preview into the way into a browser as well, so the
		-- square you were already looking at is the thing you click, instead of
		-- cramming a fourth control into the row. It shows a question mark while the
		-- box is empty, since an empty square gives you nothing to aim at.
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

		-- opts.reorder turns the row into an entry in a list you can shuffle: move
		-- up, move down, and take it out. They take the right end of the row and
		-- push the box along, so a plain input row is left as it was. Each one is
		-- paired with a `can` that says whether it has anywhere to go, so the top
		-- entry cannot move up and the empty box at the bottom does nothing at all.
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

			-- Added right to left, so they read up, down, remove.
			Add(UI.Cross, "Remove", "Takes this entry out of the list. The ones under it move up.",
				reorder.remove, reorder.canRemove)
			Add(UI.Chevron, "Move Down", "Moves this entry one place later in the list.",
				reorder.down, reorder.canDown)
			Add(ChevronUp, "Move Up", "Moves this entry one place earlier in the list.",
				reorder.up, reorder.canUp)

			box:ClearAllPoints()
			box:SetPoint("RIGHT", previous, "LEFT", -8, 0)
		end

		local get, set = Getter(opts), Setter(opts)

		box:SetScript("OnEnterPressed", function(self)
			self:ClearFocus()
			set(self:GetText())
			layout:UpdateAll()
		end)
		box:SetScript("OnEditFocusLost", function(self)
			local c = UI.colors.border
			self.edges:SetColor(c[1], c[2], c[3], c[4])
			set(self:GetText())
			layout:UpdateAll()
		end)

		return layout:Register({
			-- Handed back so a list that grows and shrinks can show and hide its
			-- rows. Rows are only ever added to a layout, never taken out of it, so
			-- a list that has shrunk hides its tail rather than rebuilding.
			row = row,
			Update = function()
				local disabled = opts.disabled and opts.disabled() or false
				SetControlEnabled(box, not disabled)
				row:SetDisabled(disabled)

				-- Never fight the player mid-edit.
				if not box:HasFocus() then box:SetText(tostring(get() or "")) end

				-- Each reorder button is only live when it has somewhere to go.
				for index = 1, buttons and #buttons or 0 do
					local button = buttons[index]
					SetControlEnabled(button, not disabled and button.enabled())
				end

				if browse then SetControlEnabled(browse, not disabled) end

				if icon then
					local texture = opts.icon and opts.icon()
					icon:SetDesaturated(false)

					if texture then
						icon:SetTexture(texture)
						icon:Show()
					elseif browse then
						-- Nothing in the box yet, or nothing the game recognises. The
						-- square stays put because it's still the button.
						icon:SetTexture(UNKNOWN_ICON)
						icon:SetDesaturated(true)
						icon:Show()
					else
						icon:Hide()
					end

					icon:SetAlpha(disabled and 0.4 or 1)
				end
			end,
		})
	end

	-- opts.text may be a function, for captions that change with state.
	function Layout:Button(opts)
		local layout, row = self, self:Row(opts)
		local caption = type(opts.text) == "function" and opts.text() or opts.text

		local button = UI.Button(row, caption or "Open", opts.controlWidth or 150, 22)
		button:SetPoint("RIGHT", -12, 0)

		-- Only opted-in buttons take right-clicks: enabling it everywhere would let a
		-- stray right-click fire things like Reset to Defaults.
		if opts.onRightClick then
			button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		end

		button:SetScript("OnClick", function(self, mouseButton)
			if mouseButton == "RightButton" then
				opts.onRightClick(self)
			else
				opts.func(self)
			end
			layout:UpdateAll()
		end)

		return layout:Register({
			row = row,
			Update = function()
				local disabled = opts.disabled and opts.disabled() or false
				SetControlEnabled(button, not disabled)
				row:SetDisabled(disabled)

				if type(opts.text) == "function" then button:SetText(opts.text()) end
			end,
		})
	end

	-- Read-only view of generated text, e.g. a macro body. Deliberately unlike the
	-- edit box: sunken and borderless with an accent rule down the side, so it reads
	-- as output rather than as something to type in.
	--
	-- opts.icon adds the icon that output is written with beside the text, and with
	-- opts.onClick that icon doubles as the control for changing it.
	function Layout:Code(opts)
		local layout = self
		local height = opts.height or 78
		local ICON = 52

		local block = CreateFrame("Frame", nil, self.parent)
		block:SetSize(self.width, height)
		Fill(block, "BACKGROUND", { 0.025, 0.025, 0.035, 0.9 })

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
			-- Framed the same way as the icon preview elsewhere in the panel, so a
			-- macro's icon reads as an icon and not as decoration on the text.
			iconButton = CreateFrame("Button", nil, block)
			iconButton:SetSize(ICON, ICON)
			iconButton:SetPoint("RIGHT", -10, 0)
			iconButton:EnableMouse(opts.onClick ~= nil)
			Fill(iconButton, "BACKGROUND", { 0, 0, 0, 1 })
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
				iconButton:SetScript("OnClick", function(self, mouseButton)
					if mouseButton == "RightButton" then
						opts.onRightClick(self)
					else
						opts.onClick(self)
					end
					layout:UpdateAll()
				end)
			end
		end

		return self:Register({
			-- Handed back for the same reason a row is: something outside may need
			-- to know where this block starts and stops.
			block = block,
			Update = function()
				text:SetText(opts.text())
				if not icon then return end

				icon:SetTexture(opts.icon())
				-- The description says what the icon currently is, so it is re-read
				-- along with everything else rather than fixed when the row is built.
				iconButton.tipBody = type(opts.iconDesc) == "function" and opts.iconDesc()
					or opts.iconDesc
			end,
		})
	end

	-- Label on the left, a read-only value on the right.
	function Layout:Info(opts)
		local row = self:Row(opts)

		local value = UI.Text(row, "", "GameFontHighlightSmall", UI.colors.dim)
		value:SetPoint("RIGHT", -12, 0)
		value:SetJustifyH("RIGHT")
		value:SetWidth(self.width * 0.4)

		return self:Register({
			Update = function()
				value:SetText(type(opts.value) == "function" and opts.value() or opts.value or "")
			end,
		})
	end

	return UI
end
