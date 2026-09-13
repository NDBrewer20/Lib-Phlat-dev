# LibPhlat-1.0

A flat, dark widget kit for World of Warcraft addon panels. Everything is built out of plain frames and color textures, so it doesn't break when Blizzard renames templates or atlases between patches. The accent follows your class color unless you give it one.

It's what [Phocus](https://github.com/NDBrewer20/Phocus) and [Phield Guide](https://github.com/NDBrewer20/Phield-Guide) build their windows with.

## Embedding

Needs [LibStub](https://www.wowace.com/projects/libstub). If you release with the [BigWigs packager](https://github.com/BigWigsMods/packager), add it to your `.pkgmeta` and it gets pulled in at build time:

```yaml
externals:
  Libs/LibPhlat-1.0:
    url: https://github.com/NDBrewer20/Lib-Phlat-dev
    tag: latest
```

Otherwise copy this repo into your addon's `Libs\LibPhlat-1.0`. Either way, load it after LibStub:

```xml
<Include file="Libs\LibPhlat-1.0\LibPhlat-1.0.xml"/>
```

## Usage

Each addon makes its own kit with `New`. The config is optional:

- `Get(key)` / `Set(key, value)` read and write settings for layout rows that have a `key`
- `Accent()` returns `{ r, g, b }` to use instead of the class color
- `colors` overrides entries in the palette

```lua
local UI = LibStub("LibPhlat-1.0"):New({
	Get = function(key) return MyAddonDB[key] end,
	Set = function(key, value) MyAddonDB[key] = value end,
})

local window = UI.Window("MyAddonOptions", 520, 420, "My Addon")

local area = UI.ScrollArea(window, 500, 370)
area:SetPoint("TOPLEFT", 10, -42)

local layout = UI.Layout(area.content, 488)
layout:Header("General")
layout:Check({ name = "Enabled", key = "enabled", desc = "Turns the addon on or off." })
layout:Slider({ name = "Scale", key = "scale", min = 50, max = 200, step = 5 })
layout:Select({
	name = "Anchor", key = "anchor",
	items = { { text = "Left", value = "LEFT" }, { text = "Right", value = "RIGHT" } },
})

area.content:SetHeight(layout:Height())
area:Update()
```

## What's in it

**Primitives:** `Fill`, `Border`, `Text`, `Tooltip`, and the `Chevron`, `Gear` and `Cross` glyphs.

**Controls:** `Button`, `GlyphButton`, `Checkbox`, `EditBox`, `Slider`, `ColorSwatch`, `Dropdown` (items can have submenus), `ScrollArea`, `Window`.

**Layout rows:** `Header`, `Note`, `Check`, `Slider`, `Select`, `MultiSelect`, `Color`, `Input`, `Button`, `Code`, `Info`. Every row registers an `Update`, and `layout:UpdateAll()` re-reads the whole page, so disabled states and hidden rows stay in sync after a change. Most options can be a value or a function. Add your own row types to `UI.LayoutProto`.

**Restyling:** change an entry in `UI.colors` and call `UI.Repaint()`, call `UI.RefreshAccent()` after the accent changes, or `UI.SetFontScale(scale)` to resize all kit text. It all applies to what's already on screen.

## Versioning

LibStub loads whichever embedded copy has the highest `MINOR`, so bump it on every change.

## License

MIT
