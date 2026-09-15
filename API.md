# LibPhlat-1.0 API

Everything below hangs off the kit you get from `LibStub("LibPhlat-1.0"):New(config)`, written here as `UI`.

- [Conventions](#conventions)
- [Colors, styles and fonts](#colors-styles-and-fonts)
- [Items](#items)
- [Primitives](#primitives)
- [Buttons](#buttons)
- [Toggles](#toggles)
- [Text entry](#text-entry)
- [Numbers](#numbers)
- [Pickers](#pickers)
- [Menus](#menus)
- [Choices](#choices)
- [Containers](#containers)
- [Lists, trees, tables and grids](#lists-trees-tables-and-grids)
- [Bars and feedback](#bars-and-feedback)
- [Layout](#layout)
- [Links](#links)
- [Extending the kit](#extending-the-kit)

## Conventions

- **Options go last.** Every constructor takes an optional `opts` table as its last argument. Where a width comes before it, the width can be skipped: `UI.Button(parent, "Save", { style = "primary" })`.
- **Values or functions.** Most options can be a value or a function returning one. Functions are read again whenever the widget refreshes.
- **Styles.** `opts.style` is the name of a style for that kind of widget, or a style table. `opts.styleOverrides` changes single fields on top.
- **Shared methods.** Every widget has `SetEnabled(enabled)`, `IsEnabled()` and `SetTooltip(title, body, opts)`. Most have `SetStyle(style, overrides)` and `Refresh()`.
- **Tooltips.** `opts.tooltip` is a body string, or `{ title, body, lines, anchor }`.
- **Callbacks are fields.** Choice controls call `widget.OnSelect(value, item, values)`. Toggles call `widget.OnChange(value, widget)`. The matching `opts.onSelect` and `opts.onChange` set them up at build time.
- **Frames stay frames.** Widgets are the real frames, so `SetPoint`, `Hide` and the rest work as usual.

## Colors, styles and fonts

### Color specs

Anywhere a color is taken, it can be:

| Spec | Meaning |
| --- | --- |
| `"control"` | a key in `UI.colors` |
| `"line:0.5"` | a key with its alpha multiplied |
| `"accent"`, `"accent:0.2"` | the accent, class color unless `config.Accent` says otherwise |
| `{ r, g, b, a }` | a plain color |
| a `ColorMixin` | anything with `.r`, `.g`, `.b` |
| a function | returns any of the above |

The palette keys are `window`, `titlebar`, `sidebar`, `control`, `popup`, `row`, `line`, `border`, `text`, `dim`, `disabled`, `hover`, `selected`, `inset`, `track`, `scroll`, `thumb`, `black`, `white`, `onAccent`, `good`, `warn` and `bad`.

| Function | Does |
| --- | --- |
| `UI.Color(spec, alpha)` | returns `r, g, b, a` |
| `UI.Paint(region, spec, how)` | colors a texture (`"fill"`), a font string (`"text"`) or a texture's vertex color (`"vertex"`), and remembers it |
| `UI.Unpaint(region)` | forgets a region you want to color yourself |
| `UI.Accented(region, alpha)` | `Paint` with the accent |
| `UI.Repaint()` | paints everything again after you change `UI.colors` |
| `UI.RefreshAccent()` | reads the accent again and repaints only what uses it |

### Styles

`UI.styles[kind][name]` holds the looks for each kind of widget. A widget starts from `default`, layers the named style on top (following `extends` if the style has one), then applies `opts.styleOverrides`.

| Function | Does |
| --- | --- |
| `UI.Style(kind, style, overrides)` | the merged table |
| `UI.RegisterStyle(kind, name, def)` | adds a style every widget of that kind can use |
| `config.styles = { button = { default = { height = 24 }, mine = { ... } } }` | changes or adds styles when the kit is made |

| Kind | Named styles |
| --- | --- |
| `button` | `default`, `primary`, `ghost`, `danger`, `link`, `tool` |
| `glyphButton` | `default`, `boxed`, `wash` |
| `iconButton` | `default`, `boxed`, `plain`, `round` |
| `icon` | `default`, `framed` |
| `checkbox` | `default`, `tick`, `round` |
| `radio` | `default`, `round` |
| `switch` | `default` |
| `editbox` | `default`, `ghost`, `underline` |
| `textarea` | `default`, `code` |
| `slider` | `default`, `thin` |
| `range` | `default` |
| `stepper` | `default` |
| `progress` | `default`, `thin` |
| `badge` | `default`, `dim`, `warn`, `bad` |
| `dropdown` | `default`, `ghost`, `underline`, `compact`, `button`, `link` |
| `menu` | `default`, `compact`, `roomy` |
| `segmented` | `default` |
| `tabs` | `default`, `underline`, `pill` |
| `cycle` | `default` |
| `radiogroup` | `default` |
| `nav` | `default`, `compact`, `tree` |
| `list` | `default`, `plain` |
| `table` | `default` |
| `grid` | `default` |
| `scroll` | `default`, `thin` |
| `window` | `default`, `dialog` |
| `panel` | `default`, `inset`, `flat`, `clear` |
| `section` | `default` |
| `row` | `default` |
| `dialog` | `default` |
| `tag`, `rating`, `calendar` | `default` |
| `toolbar` | `default`, `clear` |
| `menubar`, `breadcrumb`, `pagination`, `steps`, `spinner` | `default` |
| `toast` | `default`, `celebrate` |

**Common style fields**

- `bg`, `border`, `borderSize`, `highlight` (hover wash), `selected` (active wash) and `rule` (1px bottom line) build the chrome.
- `text`, `hoverText`, `activeText` and `disabledText` color the label for each state.
- `font` is a font object name or one of `UI.fonts`: `title`, `heading`, `body`, `small`, `caption`, `large`.
- The rest are sizes and paddings named for what they do, like `height`, `padding` and `iconSize`. Read `UI.styles` for the exact fields a kind uses.

### Fonts

| Function | Does |
| --- | --- |
| `UI.SetFontScale(scale)`, `UI.FontScale()` | scales every string the kit made |
| `UI.SetFontFace(file, flags)` | swaps the font file on all of them, `nil` goes back to each template |
| `UI.SetFontSize(fontString, size)` | gives one string its own size, still scaled |
| `UI.SetFontTemplate(fontString, template)` | changes a kit string's template without losing track of it |
| `UI.TextWidth(fontString)` | the width the text wants, not what it was squeezed into |

## Items

Menus, dropdowns and every choice control take the same list of items. Fields a control doesn't use are ignored.

| Field | Used by | Meaning |
| --- | --- | --- |
| `text` | all | label, or a function of the item |
| `value` | all | what gets picked |
| `func(value, item, mouseButton)` | all | runs when it's picked |
| `disabled`, `hidden` | all | value or function of the item |
| `shown` | choices | the opposite of hidden, for tabs that come and go |
| `tooltip`, `tooltipTitle`, `tooltipFunc(tooltip, item)` | all | hover help |
| `color` | all | label color spec |
| `icon`, `iconAtlas`, `iconCoords` | menus, strips, trees | a texture before the label |
| `iconColor` | menus | tints that icon, a color spec like `"good"` |
| `selectedText` | dropdown, cycle, combo | what the closed control shows once it's picked |
| `header`, `separator` | menus | a caption, or a line |
| `submenu` | menus | a list or a function returning one, opens off the side at any depth |
| `checked`, `radio` | menus | a tick, or a dot for radio style |
| `note` | menus | dim text on the right |
| `actions` | menus | small buttons on the right that don't pick the row: a list, or a function of the item returning one, of `{ atlas or icon, color, tooltipTitle, tooltip, onClick(value, item, mouseButton), keepOpen }`. `color` tints the art, a missing atlas falls back to `icon`. They read left to right in the order given and close the menu unless `keepOpen`. The style's `actionSize` sizes them, 14 by default |
| `keepOpen` | menus | picking it doesn't close the menu |
| `searchText` | menus | what search matches instead of text |
| `badge`, `empty`, `width` | tabs, segmented | a count pill, greyed text, fixed width |

## Primitives

| Function | Returns |
| --- | --- |
| `UI.Fill(frame, layer, color)` | a texture covering the frame |
| `UI.Border(frame, color, thickness)` | four edges with `Paint(spec)`, `SetColor(r, g, b, a)`, `SetThickness(n)` and `SetShown(shown)` |
| `UI.Divider(parent, vertical, color)` | a 1px line to anchor yourself |
| `UI.Chrome(frame, style)` | builds `bg`, `edges`, `highlight` and `rule` off a style |
| `UI.RoundMask(frame, region, anchor)` | masks a texture into a circle covering `anchor` (the texture by default). Only masks a texture once |
| `UI.Text(parent, text, template, color)` | a font string. `template` can instead be a table of `font`, `size`, `color`, `justify`, `justifyV`, `wrap`, `width` and `layer` |
| `UI.Tooltip(frame, title, body, opts)` | hover tooltip. Hooks instead of replacing when the frame already has scripts |
| `UI.HookTooltip(frame, Fill, anchor)` | tooltip filled by `Fill(frame, GameTooltip)`, which can return `false` to skip it |
| `UI.ShowTooltip(frame)`, `UI.HideTooltip(frame)` | read `tipTitle`, `tipBody`, `tipLines`, `tipAnchor` and `tipFunc` off the frame |

### Glyphs and icons

| Function | Returns |
| --- | --- |
| `UI.Glyph(parent, name, size, color, facing)` | a tinted flat icon. Methods: `SetColor(spec)`, `SetFacing("down" \| "up" \| "left" \| "right")`, `SetGlyphSize(size)` |
| `UI.Chevron`, `UI.Gear`, `UI.Cross`, `UI.Check`, `UI.Plus`, `UI.Minus` | shortcuts with the `(parent, size, color)` shape |
| `UI.GlyphBuilder(name, facing)` | a builder function for `GlyphButton` |
| `UI.RegisterGlyph(name, { atlas, fill, file, facings })` | adds a glyph. `fill` is how much of its atlas cell the art covers, `file` is the fallback texture |
| `UI.Icon(parent, size, texture, opts)` | a texture holder. Methods: `SetIcon(texture, isAtlas)`, `SetDesaturated`. The `framed` style boxes it |

Glyphs are `chevron`, `chevronLeft`, `chevronRight`, `gear`, `cross`, `check`, `plus`, `minus`, `search`, `refresh`, `warning`, `error`, `minimize` and `resize`.

## Buttons

**`UI.Button(parent, text, width, height, opts)`**

- `opts`: `style`, `icon` (a texture) or `glyph` (a name), `onClick(button, selected)`, `onRightClick(button)`, `toggle`, `selected`, `autoWidth`, `minWidth`, `tooltip`
- Methods: `SetText`, `GetText`, `FitWidth(min)`, `SetIcon(glyphOrTexture)`, `SetSelected`, `GetSelected`, `SetStyle`

**`UI.GlyphButton(parent, size, glyph, title, body, opts)`**

- `glyph` is a glyph name or a builder like `UI.Gear`. The button is dim at rest, accent on hover and grey when disabled.
- `opts`: `style`, `facing`, `onClick`
- Methods: `SetSelected`, `GetSelected`, `SetStyle`

**`UI.IconButton(parent, size, texture, title, body, opts)`**

- The same as a glyph button, but for any texture. The default style tints it, `boxed` puts it in a control box, `plain` keeps its own colors, and `round` keeps its own colors cut into a circle like a portrait.
- Methods: `SetIcon`, `SetSelected`, `SetStyle`

**`UI.SplitButton(parent, text, width, opts)`**

- A main action with an arrow beside it for the rest.
- `opts`: `style`, `onClick`, `items`, `onSelect(value, item)`, `menu` (menu opts)
- Fields and methods: `.button`, `.arrow`, `.menu`, `SetText`, `SetItems`

**`UI.MenuButton(parent, text, width, opts)`**

- A button that opens a menu and keeps its own label.
- Takes the same `opts` as `Dropdown`.

## Toggles

**`UI.Checkbox(parent, opts)`, `UI.Radio(parent, opts)`**

- `opts`: `style`, `label` (clickable text beside it), `checked`, `onChange(checked)`
- Methods: `SetChecked`, `GetChecked`, `SetLabel`
- A radio only ever turns itself on.

**`UI.Switch(parent, opts)`**

- A pill with a knob, taking the same options and methods as a checkbox.

## Text entry

**`UI.EditBox(parent, width, height, opts)`**

- `opts`: `style`, `placeholder`, `clearButton`, `search`, `numeric`, `maxLetters`, `text`, `onChange(text)` (typing only), `debounce` (seconds), `onEnter(text)`, `onEscape`, `onClear`, `keepFocus`
- Methods: `SetPlaceholder`, `SetValue` (doesn't fire `onChange`), `GetValue`, `SetStyle`

**`UI.SearchBox(parent, width, height, opts)`**

- An edit box with the magnifier, a "Search" hint and a clear button.

**`UI.TextArea(parent, width, height, opts)`**

- A scrolling multi-line box.
- `opts`: `style`, `readOnly`, `selectOnFocus`, `placeholder`, `maxLetters`, `text`, `onChange(text)`, `onCommit(text)` (on focus lost)
- Fields and methods: `.edit`, `SetText`, `GetText`, `SetFocus`, `ClearFocus`, `HighlightText`, `ScrollTo`, `Resize`

**`UI.ComboBox(parent, width, opts)`**

- Type, or pick from the matches below.
- `opts`: `items` (a list filtered by what's typed, or a `function(text)` returning matches), `value`, `placeholder`, `maxRows`, `strict` (only listed values stick), `minChars`, `onChange(text)`, `onSelect(value, item)`, `onCommit(text)`
- Fields and methods: `.box`, `.menu`, `SetItems`, `SetValue`, `GetValue`, `GetText`

**`UI.TagInput(parent, width, opts)`**

- Chips with a cross each. Enter or a comma adds a tag, and backspace in an empty box removes the last.
- `opts`: `tags`, `max`, `unique` (default `true`), `placeholder`, `onChange(tags)`
- Methods: `AddTag`, `RemoveTag(index)`, `SetTags`, `GetTags`, `OnLayout(height)`

## Numbers

**`UI.Slider(parent, min, max, step, opts)`**

- `opts`: `style`, `orientation` (`"VERTICAL"`), `width`, `onChange(value)`
- Methods: `SetRange(min, max, step)`, plus the native slider methods

**`UI.RangeSlider(parent, width, opts)`**

- Two thumbs for a low and a high end.
- `opts`: `min`, `max`, `step`, `low`, `high`, `minGap`, `live`, `onChange(low, high)`
- Methods: `SetValue(low, high, silent)`, `GetValue()`, `SetBounds(min, max, step)`

**`UI.Stepper(parent, width, opts)`**

- A number between minus and plus buttons. Holding a button repeats, shift uses `bigStep`, and the mouse wheel steps too.
- `opts`: `min`, `max`, `step`, `bigStep`, `value`, `format`, `onChange(value)`
- Methods: `SetValue(value, silent)`, `GetValue`, `SetRange`, `Step(direction)`

**`UI.ProgressBar(parent, width, height, opts)`**

- `opts`: `style`, `format` (a format string for value and max, `"percent"`, or a `function(value, max, percent)`)
- Methods: `SetValue(value, max)`, `SetMinMax`, `GetValue`, `SetText(text)` (fixed text, `nil` hands it back to the format), `SetFillColor(spec)`

**`UI.Rating(parent, opts)`**

- A row of pips for a score.
- `opts`: `max` (5), `value`, `readOnly`, `clearable`, `onChange(value)`
- Methods: `SetValue`, `GetValue`

## Pickers

**`UI.ColorSwatch(parent, width, height, opts)`**

- With `opts.get` and `opts.set` it opens the color picker itself. `hasAlpha` adds opacity.
- Methods: `SetColor(r, g, b, a)`

**`UI.OpenColorPicker(r, g, b, a, hasAlpha, callback)`**

- Works on both the pre and post 10.2.5 color picker.

**`UI.Keybind(parent, width, height, opts)`**

- Click it, then press a key with any modifiers. Escape cancels, a right click clears, and it won't start capturing in combat.
- `opts`: `value`, `emptyText`, `promptText`, `onChange(binding)`
- Methods: `SetValue`, `GetValue`

**`UI.Calendar(parent, opts)`**

- A month of days, where dates are `{ year, month, day }` tables.
- `opts`: `value`, `minDate`, `maxDate`, `weekStart` (1 Sunday, 2 Monday), `onChange(date)`
- Methods: `SetValue`, `GetValue`, `SetMonth(year, month)`, `Shift(months)`

**`UI.DatePicker(parent, width, opts)`**

- A dropdown-looking button that opens a calendar in a popover.
- `opts`: `value`, `format` (a `date()` format), `placeholder`, `calendar` (calendar opts), `onChange(date)`
- Methods: `SetDate`, `GetDate`

## Menus

**`UI.NewMenu(opts)`**

The menu engine the rest are built on. Build your own trigger on it when none of the ready-made ones fit.

- `opts`: `style`, `width` (`"auto"` or a number, otherwise it matches its anchor), `flyoutWidth`, `align` (`"RIGHT"`), `direction` (`"UP"` or `"AUTO"`), `maxRows` (scrolls past it), `search` (`true`, or how many items it takes to show one), `searchText`, `searchFocus`, `emptyText`, `noMatchText`, `keepOpen`
- Methods: `Open(items)`, `Close`, `Toggle(items)`, `IsOpen`, `SetItems`, `Redraw`, `AnchorTo(frame, direction)`, `AnchorCursor()`, `SetQuery(text)`, `Pick(item)`
- Fields to set: `menu.OnPick(value, item, keptOpen)`, `menu.Checked(item)` (ticks items that don't say themselves), `menu.OnOpen`, `menu.OnClose`
- Only one menu is open at a time across every kit. `UI.CloseMenus()` closes it.

**`UI.Dropdown(parent, width, opts)`**

- `opts`: `style`, `menuStyle`, `menuWidth`, `flyoutWidth`, `align`, `direction`, `maxRows`, `search`, `placeholder`, `items`, `value`, `values`, `multi`, `summary(values, items)`, `label(value, items, dropdown)`, `showSelected` (ticks the current value), `keepOpen`, `emptyText`, `onSelect(value, item, values)`, `tooltip`
- Methods: `SetItems`, `SetValue`, `GetValue`, `SetValues(set)`, `GetValues`, `SetLabel(text)` (fixed text, `nil` hands it back), `SetPlaceholder`, `UpdateLabel`, `Open`, `Close`, `Toggle`, `IsOpen`, `Reload`, `SetStyle`
- Fields: `.label`, `.menu`, `.list` (the menu panel), `.flyout`

**`UI.ContextMenu(items, onSelect, opts)`**

- Opens at the cursor, or under `opts.anchor`.
- Also takes `style`, `keepOpen`, `checked(item)` and menu opts.

**`UI.AttachMenu(frame, items, onSelect, opts)`**

- Clicking the frame opens a menu under it. The click is hooked, so the frame's own click still works.
- `opts.mouseButton` and `opts.atCursor` change which button opens it and where.

**`UI.AttachContextMenu(frame, items, onSelect, opts)`**

- The same, on right click at the cursor.

**`UI.MenuBar(parent, width, opts)`**

- File, Edit, View style titles. Once one menu is open, moving across the bar opens the others.
- `opts.menus` is a list of `{ text, items, onSelect }`, and `opts.onSelect(menuIndex, value, item)` sees every pick.
- Methods: `SetMenus`, `Open(index)`, `Close`

## Choices

A dropdown, segmented control, tab strip, cycle button and radio group all take the same `items`, `value`, `values`, `multi` and `onSelect(value, item, values)`. They also share `SetItems`, `SetValue`, `GetValue`, `SetValues`, `GetValues`, `Reload` and `SetEnabled`. Swapping how a pick looks is changing one word:

```lua
local kind = MyAddonDB.compact and "dropdown" or "segmented"
local picker = UI.Choice(kind, parent, 200, { items = items, value = current, onSelect = Pick })
```

| Kind | Constructor | Notes |
| --- | --- | --- |
| `dropdown` | `UI.Dropdown(parent, width, opts)` | see [Menus](#menus) |
| `segmented` | `UI.Segmented(parent, width, opts)` | buttons sharing the width evenly |
| `tabs` | `UI.Tabs(parent, width, opts)` | sized to their labels, wrapping onto more lines once `width` runs out |
| `cycle` | `UI.Cycle(parent, width, opts)` | one button that steps through. Left click or the right third goes forward, right click or the left third goes back, `opts.wheel` adds the wheel, `opts.wrap = false` stops at the ends |
| `radio` | `UI.RadioGroup(parent, width, opts)` | a radio per item, checkboxes with `multi`, `horizontal` lays them across |

Segmented and tabs also take `fill`, `wrap`, `align` and `onLayout(lines, height)`, and have `GetLines()`. Radio groups call `onLayout(height)`.

**`UI.RegisterChoice(kind, build)`**

- Adds your own kind, which `Layout:Select` can then use too.

## Containers

**`UI.Window(globalName, width, height, title, opts)`**

- `opts`: `style`, `strata`, `parent`, `movable`, `closable`, `escape`, `noTitle`, `resizable`, `minWidth`, `minHeight`, `maxWidth`, `maxHeight`, `onResized(width, height)`, `position` (a table the window keeps its point and size in)
- Fields: `.titlebar`, `.title`, `.close`, `.body` (the area under the title bar), `.grip`
- Methods: `SetTitle`, `AddTitleButton(glyph, title, body, onClick)` (laid right to left from the close), `Toggle`, `SavePosition`, `RestorePosition`, `ResetPosition`
- Hooks you can define: `frame:OnMoved()`, `frame:OnResized(width, height)`

**`UI.Panel(parent, width, height, opts)`**

- A flat box. The styles are `default`, `inset`, `flat` and `clear`.

**`UI.Section(parent, width, title, opts)`**

- A header that folds its body away. Put things in `section.body` and tell it their height.
- `opts`: `expanded`, `note`, `gap`, `get`, `set`, `onToggle(expanded)`
- Methods: `SetBodyHeight`, `SetExpanded(expanded, silent)`, `Toggle`, `IsExpanded`, `GetFullHeight`, `SetTitle`

**`UI.Accordion(parent, width, opts)`**

- Stacked sections. `opts.single` keeps only one open, and `opts.spacing` sets the gap.
- Methods: `Add(title, bodyHeight, sectionOpts)`, `Layout`, `OnLayout(height)`

**`UI.Splitter(parent, width, height, opts)`**

- Two panes, `.first` and `.second`, with a bar between them that drags.
- `opts`: `vertical`, `size`, `min`, `max`, `minSecond`, `thickness`, `onChange(size)`
- Methods: `SetSplit`, `GetSplit`

**`UI.ScrollArea(parent, width, height, opts)`**

- Put things in `area.content`.
- `opts`: `style`, `step`, `hideBar`, `onScroll(offset)`
- Methods: `SetContentHeight`, `Update`, `ScrollTo`, `ScrollBy`, `ScrollToBottom`, `ScrollIntoView(region, pad)`, `GetScroll()` (offset, range and view height), `SetInsetTop` (a strip along the top that doesn't scroll), `Resize`

**`UI.Popover(width, height, opts)`**

- A floating panel that closes on a click outside it.
- `opts`: `style`, `side` (`"BOTTOM"`, `"TOP"`, `"LEFT"`, `"RIGHT"`), `align`, `gap`, `onOpen`, `onClose`
- Methods: `Open(anchor)`, `Close`, `Toggle(anchor)`, `IsOpen`

**`UI.Dialog(opts)`**

- A flat stand-in for StaticPopup. Several can stack, and escape cancels.
- `opts`: `title`, `text`, `input` (`true` or starting text), `multiline`, `inputHeight`, `maxLetters`, `width`, `buttons` (a list of `{ text, style, onClick(dialog, inputText) }`), `onCancel`, `onShow`
- `multiline` makes the input a scrolling box that wraps, `inputHeight` tall (120 by default) and capped at `maxLetters`. Enter makes a new line in it, so only the buttons answer.
- The first button is the rightmost and is what Enter presses. Returning `true` from `onClick` keeps the dialog up.

**`UI.Confirm(text, onAccept, opts)`, `UI.Prompt(text, onAccept(text), opts)`, `UI.Alert(text, opts)`**

- The common dialogs.
- `opts`: `title`, `acceptText`, `cancelText`, `danger`, `default` (for prompts), `onCancel`, and for prompts `multiline`, `inputHeight`, `maxLetters`

## Lists, trees, tables and grids

**`UI.List(parent, width, height, rowHeight, Build, Fill)` or `UI.List(parent, opts)`**

- Pooled rows. `Build(row)` makes an empty row once and `Fill(row, entry, index)` draws an entry into it. With no `Build` and no `Fill`, rows show `entry.text`, `entry.icon`, `entry.note` and `entry.color`, and `entry.heading` rows are captions.
- `opts`: `style`, `virtual` (only the rows on screen exist, for thousands of entries), `onClick(entry, row, mouseButton)`, `onEnter`, `onLeave`, `isSelected(entry)`, `reorder(from, to)` (drag to reorder), `scrollStyle`
- Methods: `Update(entries, IsSelected)`, `Refresh`, `Reveal(match)`, `Resize`, `Restyle`, plus `SetPoint`, `Show` and `Hide` passed on to `.area`
- `UI.SetRowScale(scale)` and `UI.RowScale()` resize the rows of every list on screen.

**`UI.Tree(parent, width, height, opts)`, `UI.Nav(parent, width, height, opts)`**

- Nested nodes that fold. A height puts the tree in a scroll area.
- Nodes: `key` or `value`, `text`, `children`, `category` (a heading that only folds), `icon`, `iconAtlas`, `badge`, `color`, `disabled`, `hidden`, `tooltip`, `expanded`, `selectable`, `func`
- `opts`: `style` (`default` is a settings sidebar, `compact`, `tree`), `items`, `value`, `collapsed` (a table to keep folded keys in, like your saved variables), `startCollapsed`, `onSelect(key, node)`, `onToggle(key, collapsed)`
- Methods: `SetItems`, `SetValue` (unfolds whatever it's inside), `GetValue`, `GetNode`, `SetCollapsed`, `IsCollapsed`, `Toggle`, `Reveal`, `Layout`, `OnLayout(height)`

**`UI.Table(parent, width, height, opts)`**

- Sortable columns over a virtual list.
- Columns: `{ key, title, width (pixels, or under 1 for a share of what's left), align, sortable, sort(a, b), format(value, row), color(value, row) }`
- `opts`: `columns`, `rows`, `sortKey`, `ascending`, `onClick(row, frame, mouseButton)`, `isSelected(row)`, `onSort(key, ascending)`
- Methods: `SetRows`, `SetColumns`, `SetSort`, `GetSort`, `Refresh`, `Resize`
- Sorting works on a copy, so your rows keep their order.

**`UI.Grid(parent, width, height, opts)`**

- Square cells for icon pickers and item grids, virtual like a list.
- `opts`: `style`, `cellSize`, `spacing`, `Build(cell)`, `Fill(cell, entry, index)`, `onClick(entry, cell, mouseButton)`, `isSelected(entry)`
- Methods: `Update(entries, IsSelected)`, `Refresh`, `Reveal(match)`, `Resize`

## Bars and feedback

**`UI.Toolbar(parent, width, opts)`**

- `opts.items` is a list. An item has `key`, `glyph`, `icon`, `text`, `tooltip`, `onClick(control, item)`, `toggle`, `selected`, `disabled`, `hidden`, `width` and `menu` (items for a menu button, with `onSelect`).
- `{ separator = true }` draws a line, and `{ spacer = true }` pushes the rest to the right.
- Methods: `SetItems`, `Get(key)`, `Refresh`

**`UI.Breadcrumb(parent, width, opts)`**

- A path of `{ text, value }`, where the last one is where you are. When it doesn't fit, the front folds into a "..." that lists what it hid.
- `opts.onSelect(value, item, index)`
- Methods: `SetItems`

**`UI.Pagination(parent, opts)`**

- `opts`: `pages`, `page`, `around`, `onChange(page)`
- Methods: `SetPages`, `SetPage`, `GetPage`

**`UI.Steps(parent, width, opts)`**

- Numbered dots for a flow in stages.
- `opts`: `steps` (labels), `current`, `clickable`, `onSelect(index)`
- Methods: `SetSteps`, `SetCurrent`, `GetCurrent`

**`UI.Badge(parent, text, opts)`**

- A small pill for a count.
- `opts`: `style`, `hideEmpty`
- Methods: `SetText`, `SetStyle`

**`UI.Spinner(parent, size, opts)`**

- A turning glyph. It only animates while shown.
- Methods: `Start`, `Stop`

**`UI.Toast(text, opts)`**

- A note that stacks at the top of the screen and goes away by itself. Hovering holds it.
- `opts`: `style`, `title`, `kind` (`info`, `good`, `warn`, `bad`), `icon`, `duration` (0 stays until closed), `anchor`, `onClick`
- Left click runs `onClick` and then dismisses it. Right click only dismisses it. Without `onClick`, either click just dismisses it.
- The `celebrate` style is for something worth a fuss: a bigger icon that flashes once when it lands, and it stays longer. The flash is the style's `flash` atlas and only shows with an icon.
- Returns the toast, which has `Dismiss()`.

## Layout

`UI.Layout(parent, width, opts)` stacks settings rows with the label on the left and the control on the right.

- `opts`: `rowStyle`, `rowStyleOverrides`
- Every row registers an `Update`, and `layout:UpdateAll()` reads the whole page again after a change. Size your scroll content off `layout:Height()`, or set `layout.OnReflow = function(self, height) end`.

**Options every row understands**

| Option | Meaning |
| --- | --- |
| `name` | label, and the key the row is filed under in `layout.rows` |
| `title` | a label that changes, value or function |
| `desc` | tooltip body, value or function |
| `key` | read and written through `config.Get` and `config.Set` |
| `get`, `set` | read and write it yourself instead |
| `disabled`, `hidden` | functions, read on every update |
| `onChange(value)` | runs after `set` |
| `indent`, `height`, `controlWidth` | layout |

**Rows**

| Method | Control and its own options |
| --- | --- |
| `Header(text, hidden)` | accent caption with a rule |
| `Note(text, hidden)` | dim wrapped text |
| `Divider(opts)` | a line |
| `Group(opts)` / `EndGroup()` | folds the rows between them. `collapsed`, `key` or `get`/`set` keep the state, and there's `onToggle`. Returns a group with `SetCollapsed` |
| `Check(opts)` | checkbox, the whole row toggles. `control = "switch"` for a switch |
| `Switch(opts)` | the same with a switch |
| `Slider(opts)` | slider with a typed number. `min`, `max`, `step`, `format`, `commitOnRelease` |
| `Select(opts)` | one pick. `items`, `control` (`dropdown`, `segmented`, `cycle`, `radio` or a registered kind), `placeholder`, `search`, `maxRows`, `menuWidth`, `showSelected`, `horizontal`, `controlOpts`, `extra(row, control, layout)` |
| `Radio(opts)`, `Segmented(opts)` | `Select` with that control |
| `MultiSelect(opts)` | several picks. `get` returns a set of `value = true` and `set` gets a new one. `control` works like `Select`, `summary(values, items)`. The older `toggle(value)` and `summary()` pair still works |
| `Stepper(opts)` | `min`, `max`, `step`, `bigStep`, `format` |
| `Range(opts)` | low and high, where `get` returns both and `set` takes both. `min`, `max`, `step`, `minGap` |
| `Color(opts)` | swatch and color picker, `hasAlpha` |
| `Input(opts)` | edit box. `placeholder`, `numeric`, `icon()`, `browse()`, `reorder = { up, down, remove, canUp, canDown, canRemove }` |
| `Keybind(opts)` | key capture, `emptyText` |
| `Date(opts)` | date picker, `format` |
| `Button(opts)` | `text`, `func`, `onRightClick`, `style` |
| `Buttons(opts)` | several buttons, `buttons = { { text, func, style, width, disabled, tooltip } }` |
| `Progress(opts)` | `value()` returns value, max and optional text |
| `TextArea(opts)` | full width under its label. Saves on focus lost. `height`, `readOnly`, `placeholder`, `selectOnFocus` |
| `Tags(opts)` | full width tag input. `get` returns a list. `max`, `unique`, `placeholder` |
| `Info(opts)` | read only `value` on the right |
| `Code(opts)` | sunken read only text with an optional clickable icon |
| `Custom(opts)` | `build(frame, layout)` fills a full width frame of `height` and can return `{ Update = ... }` |

**Page methods**

| Method | Does |
| --- | --- |
| `UpdateAll()` | reads every row again and reflows |
| `Reflow()` | lays the page out again, closing gaps left by hidden rows |
| `Filter(text)` | shows only rows whose name or description matches, keeping their headers. `nil` clears it |
| `Find(name)` | a row by name |
| `Link(other)` | two layouts that update each other, like a pinned strip over a scrolling page |
| `Gap(height)`, `Height()` | spacing and total height |
| `Row(opts, height)`, `Add(element)`, `Register(widget, opts, row)` | the pieces for your own rows |

## Links

| Function | Does |
| --- | --- |
| `UI.LinkClick(link)` | shift-click to chat, and ctrl-click dressing up for items. Returns `true` when it handled the click |
| `UI.HookLink(frame, link)` | a pooled row that links whatever it's showing |
| `UI.HookHyperlinks(frame, extra)` | makes the hyperlinks inside a frame's text work. `extra(link)` returns more `SetHyperlink` arguments |
| `UI.InsertLink(link)` | puts a link in the open chat box |

## Extending the kit

- **New rows.** Add methods to `UI.LayoutProto`. Build the row with `self:Row(opts, height)`, then return `self:Register({ Update = ... }, opts, row)`.
- **New menus.** Add methods to `UI.MenuProto`.
- **New list behavior.** Add methods to `UI.ListProto`.
- **New looks.** Styles, glyphs and choice kinds all register at runtime: `UI.RegisterStyle`, `UI.RegisterGlyph` and `UI.RegisterChoice`.

The library is split into modules, loaded in the order `LibPhlat-1.0.xml` lists them. Each file registers with `lib:Module(name, function(UI, P, config) ... end)`, where `P` carries the helpers one module hands the next. A module only registers when its own copy of `LibPhlat-1.0.lua` won the LibStub version check.

### Performance

- **Built on demand, pooled.** Nothing heavy is made until it's first used: menus, flyouts, dialogs and rows. Rows, entries and cells are pooled and reused.
- **Virtual lists.** Virtual lists, tables and grids only have frames for what's on screen.
- **Timers only while needed.** The only per-frame work is while a submenu is open (a few checks a second), while a scroll thumb, splitter or range thumb is being dragged, and while a menu bar has a menu open.
- **Cheap hover.** Colors are strings resolved when painted, so hovering doesn't allocate tables.
- **Layout pages.** `Select` rows only hand a control new items when the list changed, so dragging a slider doesn't re-lay out every strip on the page.
