# LibPhlat-1.0

A flat, dark widget kit for World of Warcraft addon panels. Everything is built out of plain frames and color textures, so it doesn't break when Blizzard renames templates or atlases between patches. The accent follows your class color unless you give it one.

It covers what a settings panel or a tool window usually needs: buttons, toggles, text entry, sliders and steppers, dropdowns with nested flyouts, context menus, menu bars, tabs, segmented controls, trees, sortable tables, virtual lists and grids, windows, dialogs, popovers, toasts and a row based settings layout. Every widget has named styles you can swap or add to, and every choice control takes the same items, so a dropdown can become tabs or a radio group by changing one word.

## Embedding

Needs [LibStub](https://www.wowace.com/projects/libstub). If you release with the [BigWigs packager](https://github.com/BigWigsMods/packager), add it to your `.pkgmeta` and it gets pulled in at build time:

```yaml
externals:
  Libs/LibPhlat-1.0:
    url: https://github.com/NDBrewer20/Lib-Phlat-dev
    tag: latest
```

Otherwise copy this repo into your addon's `Libs\LibPhlat-1.0`. Either way, load the xml after LibStub. The library is split over several files and the xml loads them in order:

```xml
<Include file="Libs\LibPhlat-1.0\LibPhlat-1.0.xml"/>
```

## Usage

Each addon makes its own kit with `New`. The config is optional:

- `Get(key)` / `Set(key, value)` read and write settings for layout rows that have a `key`
- `Accent()` returns `{ r, g, b }` to use instead of the class color
- `colors` overrides entries in the palette, `styles` overrides or adds named styles
- `font`, `fontFlags` and `fontScale` change the text on everything the kit draws

```lua
local UI = LibStub("LibPhlat-1.0"):New({
	Get = function(key) return MyAddonDB[key] end,
	Set = function(key, value) MyAddonDB[key] = value end,
})

local window = UI.Window("MyAddonOptions", 520, 420, "My Addon", { resizable = true, position = MyAddonDB.window })

local area = UI.ScrollArea(window, 500, 370)
area:SetPoint("TOPLEFT", 10, -42)

local layout = UI.Layout(area.content, 488)
layout:Header("General")
layout:Check({ name = "Enabled", key = "enabled", desc = "Turns the addon on or off." })
layout:Slider({ name = "Scale", key = "scale", min = 50, max = 200, step = 5 })
layout:Select({
	name = "Anchor", key = "anchor", control = "segmented",
	items = { { text = "Left", value = "LEFT" }, { text = "Right", value = "RIGHT" } },
})

area:SetContentHeight(layout:Height())
```

[API.md](API.md) lists every widget, its options and methods, the shared item format and the style fields.

## Versioning

LibStub loads whichever embedded copy has the highest `MINOR`, so bump it in `LibPhlat-1.0.lua` on every change. The other files check that their own copy won before they register anything.

## License

MIT
