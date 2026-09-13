--------------------------------------------------------------------------------
-- LibPhlat-1.0
--
-- flat dark widget kit for addon panels. everything is plain frames and color
-- textures so Blizzard renaming templates or atlases doesn't break it.
--
--   local UI = LibStub("LibPhlat-1.0"):New(config)
--------------------------------------------------------------------------------

local MAJOR, MINOR = "LibPhlat-1.0", 7
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

-- only one dropdown list can be open at a time, across every kit.
local openList

local function CloseOpenList()
	if openList then openList:Hide() end
end
lib.CloseDropdowns = CloseOpenList

-- options can be a value or a function that returns one.
local function Resolve(value)
	if type(value) == "function" then return value() end
	return value
end

--------------------------------------------------------------------------------
-- New
--
-- config is optional and so is everything in it:
--
--   config.Accent()          returns { r, g, b } to use instead of class color
--   config.Get(key)          returns the stored value for a layout row
--   config.Set(key, value)   stores the value from a layout row
--   config.colors            palette entries to override
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
		disabled = { 0.420, 0.420, 0.460 },
	}

	for key, value in pairs(config.colors or {}) do
		UI.colors[key] = value
	end

	--------------------------------------------------------------------------------
	-- Accent
	--------------------------------------------------------------------------------

	local accent
	local accentRegions = {}

	-- class color unless config.Accent gives one. cached until RefreshAccent.
	function UI.Accent()
		if not accent then
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

	local function Tint(region, alpha)
		local r, g, b = UI.Accent()
		if region.SetColorTexture then
			region:SetColorTexture(r, g, b, alpha)
		else
			region:SetTextColor(r, g, b, alpha)
		end
	end

	-- paints a texture or font string in the accent and keeps it for RefreshAccent.
	function UI.Accented(region, alpha)
		alpha = alpha or 1
		accentRegions[region] = alpha
		Tint(region, alpha)
		return region
	end

	-- re-reads the accent and repaints everything accented so far.
	function UI.RefreshAccent()
		accent = nil
		for region, alpha in pairs(accentRegions) do
			Tint(region, alpha)
		end
	end

	--------------------------------------------------------------------------------
	-- Primitives
	--------------------------------------------------------------------------------

	-- every fill and the color table it came from, so Repaint can redo them after
	-- an entry in UI.colors changes.
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

	-- four edge textures instead of a backdrop template.
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

	-- every font string and its template size, since the original size can't be
	-- read back once it's been scaled.
	local fontScale, fonts = 1, {}

	function UI.FontScale()
		return fontScale
	end

	-- scales all kit text, including what's already on screen.
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

	-- tooltips read tipTitle and tipBody off the frame.
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
	-- Blizzard's flat uitools icons tinted to match the panel. clients without the
	-- atlas fall back to the old button art.
	--------------------------------------------------------------------------------

	-- placeholder for an icon that's missing or unknown.
	local UNKNOWN_ICON = "Interface/ICONS/INV_Misc_QuestionMark"

	-- fill is how much of the 20x20 atlas cell the art covers, so it can be grown
	-- to draw at the size asked for.
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

	-- the texture sits in a frame so it can be anchored, shown and tinted as one.
	local function Glyph(parent, size, color, glyph, facing)
		local holder = CreateFrame("Frame", nil, parent)
		holder:SetSize(size, size)

		holder.texture = holder:CreateTexture(nil, "OVERLAY")

		-- grow past the holder by the art's padding.
		local grow = size * (1 / glyph.fill - 1) / 2
		holder.texture:SetPoint("TOPLEFT", -grow, grow)
		holder.texture:SetPoint("BOTTOMRIGHT", grow, -grow)

		if C_Texture.GetAtlasInfo(glyph.atlas) then
			holder.texture:SetAtlas(glyph.atlas)
		else
			holder.texture:SetTexture(glyph.file)
			holder.texture:SetDesaturated(true)

			-- old arrow only points down, turn the coords a quarter for right.
			if facing == "right" then
				holder.texture:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
			end
		end

		-- pixel snapping blurs art drawn away from its native size.
		holder.texture:SetSnapToPixelGrid(false)
		holder.texture:SetTexelSnappingBias(0)

		-- no up chevron in the set so the down one is rotated. SetAtlas owns the
		-- tex coords so they can't be flipped instead.
		if facing == "up" then
			holder.texture:SetRotation(math.pi)
		end

		function holder:SetColor(shade)
			self.texture:SetVertexColor(shade[1], shade[2], shade[3], shade[4] or 1)
		end

		holder:SetColor(color or UI.colors.text)
		return holder
	end

	-- facing is "down" (default), "up" or "right".
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

	-- glyph as a button, padded so it's easier to hit. dim at rest, accent on
	-- hover, grey when disabled.
	function UI.GlyphButton(parent, size, Build, title, body)
		local button = CreateFrame("Button", nil, parent)
		button:SetSize(size + 8, size + 8)

		button.glyph = Build(button, size, UI.colors.dim)
		button.glyph:SetPoint("CENTER")
		button.tipTitle, button.tipBody = title, body

		function button:Refresh()
			if not self:IsEnabled() then
				self.glyph:SetColor(UI.colors.disabled)
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

		-- the HIGHLIGHT layer shows on mouseover by itself.
		UI.Accented(button:CreateTexture(nil, "HIGHLIGHT"), 0.22):SetAllPoints()

		button.label = UI.Text(button, text, "GameFontHighlightSmall")
		button.label:SetPoint("CENTER")
		button.label:SetJustifyH("CENTER")

		-- the native SetText needs SetFontString, which drags in Blizzard's disabled font.
		function button:SetText(label)
			self.label:SetText(label)
		end

		button:SetScript("OnEnable", function(self)
			self.label:SetTextColor(unpack(UI.colors.text))
		end)
		button:SetScript("OnDisable", function(self)
			self.label:SetTextColor(unpack(UI.colors.disabled))
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
			self.mark:SetShown(self.checked)
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

		-- the slider positions the thumb itself, so the fill can just anchor to it.
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
	-- Dropdown
	--
	-- an item can have a submenu, a list or a function that builds one. hovering
	-- the item opens it off the side and clicking still picks the item itself.
	--------------------------------------------------------------------------------

	UI.CloseDropdowns = CloseOpenList

	local ENTRY_HEIGHT = 20
	local PANEL_PAD = 4

	local function PanelHeight(count)
		return math.max(8, count * ENTRY_HEIGHT + PANEL_PAD * 2)
	end

	-- one row, used by both the list and the flyout.
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

	-- arrow for rows with a submenu, made the first time one needs it. the label
	-- gives up the space so long text doesn't run under it.
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

	-- the text for a value, submenus included. builder functions are skipped so
	-- drawing one label doesn't build every submenu.
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

		-- panel for a submenu, one per dropdown and refilled per row. parented to
		-- the list so it sits above the click catcher and closes with it.
		local flyout = CreateFrame("Frame", nil, list)
		flyout:SetFrameStrata("FULLSCREEN_DIALOG")
		flyout:SetFrameLevel(list:GetFrameLevel() + 10)
		flyout:SetWidth(width or 170)
		Fill(flyout, "BACKGROUND", UI.colors.popup)
		UI.Border(flyout)
		flyout:Hide()
		flyout.entries = {}
		dd.flyout = flyout

		-- clicking anywhere outside the list closes it.
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

		-- keepOpen is for multi pick lists. the caller owns the label there, so it
		-- isn't replaced with the entry that was clicked.
		local function OnEntryClick(self)
			if not dd.keepOpen then
				HideFlyout()
				list:Hide()
				dd:SetValue(self.value)
			end
			if dd.OnSelect then dd.OnSelect(self.value) end
		end

		local function OpenFlyout(entry)
			local items = Resolve(entry.submenu)
			if type(items) ~= "table" or #items == 0 then return HideFlyout() end

			flyout.owner = entry
			FillPanel(flyout, items, OnEntryClick)

			-- set again every open since the list's level can change when it shows.
			flyout:SetFrameLevel(list:GetFrameLevel() + 10)

			-- level with its row, and out the left side if there's no room on the right.
			local y = -(entry.index - 1) * ENTRY_HEIGHT
			flyout:ClearAllPoints()
			if (list:GetRight() or 0) + flyout:GetWidth() <= UIParent:GetRight() then
				flyout:SetPoint("TOPLEFT", list, "TOPRIGHT", 0, y)
			else
				flyout:SetPoint("TOPRIGHT", list, "TOPLEFT", 0, y)
			end
			flyout:Show()

			-- slide it back up if it runs off the bottom of the screen.
			local bottom = flyout:GetBottom()
			if bottom and bottom < 0 then
				local point, relative, relativePoint, x = flyout:GetPoint(1)
				flyout:SetPoint(point, relative, relativePoint, x, y - bottom)
			end
		end

		-- only rows on the main list open a flyout.
		local function OnEntryEnter(self)
			if self.submenu then OpenFlyout(self) else HideFlyout() end
		end

		-- stays open while the mouse is on the flyout or the row that opened it.
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
			list:SetShown(not list:IsShown())
		end)
		dd:SetScript("OnDisable", function(self)
			self.label:SetTextColor(unpack(UI.colors.disabled))
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

	-- SetInsetTop keeps a strip along the top that doesn't scroll.
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

		-- one spot that pushes size and inset onto the frames so they can't disagree.
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

		-- dragging the thumb maps the cursor straight onto the scroll range.
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

		-- the kit's cross instead of UIPanelCloseButton, which is gold and doesn't match.
		local close = UI.GlyphButton(bar, 12, UI.Cross)
		close:SetPoint("RIGHT", -6, 0)
		close:SetScript("OnClick", function() frame:Hide() end)

		-- exposed so a window in the UI panel system can close with HideUIPanel instead.
		frame.close = close

		if globalName then tinsert(UISpecialFrames, globalName) end
		return frame
	end

	--------------------------------------------------------------------------------
	-- Layout
	--
	-- settings stacked as rows, label on the left and control on the right. every
	-- builder registers an Update so UpdateAll can re-read the page after a change.
	--------------------------------------------------------------------------------

	local Layout = {}
	Layout.__index = Layout

	-- exposed so an addon can add its own row builders.
	UI.LayoutProto = Layout

	function UI.Layout(parent, width)
		return setmetatable({
			parent = parent, width = width, y = 0,
			widgets = {},
			-- rows by name, so other code can find a setting's row.
			rows = {},
			-- everything added in order, so Reflow can close gaps left by hidden rows.
			elements = {},
		}, Layout)
	end

	-- Enable and Disable exist on every control here, SetEnabled doesn't.
	local function SetControlEnabled(control, enabled)
		if enabled then control:Enable() else control:Disable() end
	end

	-- snaps a value to the nearest step counted from min.
	local function Snap(value, min, step)
		if not step or step <= 0 then return value end
		min = min or 0
		return min + math.floor((value - min) / step + 0.5) * step
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

	function Layout:Advance(height, gap)
		self.y = self.y + height + (gap or 3)
	end

	function Layout:Gap(height)
		self.y = self.y + (height or 8)
	end

	function Layout:Height()
		return self.y
	end

	-- adds one element and places it. place(y) positions its regions, pre is extra
	-- space above it when it isn't first, and hidden is checked on every reflow.
	function Layout:Add(element)
		self.elements[#self.elements + 1] = element

		if element.pre and self.y > 0 then self:Gap(element.pre) end
		element.place(self.y)
		self:Advance(element.height, element.gap)
		return element
	end

	-- lays the page out again top to bottom, skipping hidden elements.
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
				y = y + element.height + (element.gap or 3)
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

		-- kept on the row so a widget that changes height can reflow behind itself.
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

		row.tipTitle = opts.name
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
			self.label:SetTextColor(unpack(disabled and UI.colors.disabled or UI.colors.text))
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

		-- the whole row toggles, not just the box.
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

	-- slider with an editable number beside it. typing commits on enter or clicking
	-- away, escape puts the old number back.
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

		local function Current()
			return Snap(get() or opts.min, opts.min, opts.step)
		end

		-- skipped while typing so the cursor doesn't jump around.
		local function ShowValue(value)
			if box:HasFocus() then return end
			box:SetText(numberFormat:format(value))
			box:SetCursorPosition(0)
		end

		-- clamped to the range, anything that isn't a number is ignored.
		local function Commit(text)
			local value = tonumber(text)
			if not value then return end

			value = Snap(math.min(math.max(value, opts.min), opts.max), opts.min, opts.step)
			set(value)
			layout:UpdateAll()
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
				set(value)
				-- update mid drag so previews follow. applying stops it feeding back.
				layout:UpdateAll()
			end
		end)

		if opts.commitOnRelease then
			-- the slider holds the mouse while dragging so this fires even off the control.
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
				local value = Current()
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

				dropdown:SetItems(Resolve(opts.items) or {})
				dropdown:SetValue(get())

				if extra and extra.Update then extra.Update() end
			end,
		})
	end

	-- several picks from one list. the caller tracks the picks and writes the label,
	-- this just keeps the list open and hands back each click.
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

				dropdown:SetItems(Resolve(opts.items) or {})
				dropdown.label:SetText(Resolve(opts.summary) or "")
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
			set(self:GetText())
			layout:UpdateAll()
		end)

		return layout:Register({
			-- returned so a list that shrinks can hide the rows it doesn't need.
			row = row,
			Update = function()
				local disabled = opts.disabled and opts.disabled() or false
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

	-- opts.text can be a function for a caption that changes.
	function Layout:Button(opts)
		local layout, row = self, self:Row(opts)

		local button = UI.Button(row, Resolve(opts.text) or "Open", opts.controlWidth or 150, 22)
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
			row = row,
			Update = function()
				local disabled = opts.disabled and opts.disabled() or false
				SetControlEnabled(button, not disabled)
				row:SetDisabled(disabled)

				if type(opts.text) == "function" then button:SetText(opts.text() or "Open") end
			end,
		})
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
			Update = function()
				value:SetText(Resolve(opts.value) or "")
			end,
		})
	end

	return UI
end
