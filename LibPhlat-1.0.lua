--------------------------------------------------------------------------------
-- LibPhlat-1.0
--
-- flat dark widget kit for addon panels. everything is plain frames and color
-- textures so Blizzard renaming templates or atlases doesn't break it.
--
--   local UI = LibStub("LibPhlat-1.0"):New(config)
--
-- every widget takes an optional opts table last, and opts.style picks one of
-- the named looks for that kind of widget. API.md has the whole list.
--
-- the kit is split over the files in LibPhlat-1.0.xml. each one adds a module
-- and New runs them in order, so a file can use what the ones before it left in P.
--------------------------------------------------------------------------------

local MAJOR, MINOR = "LibPhlat-1.0", 9
local lib = LibStub:NewLibrary(MAJOR, MINOR)

-- a newer or equal copy is already loaded, so the rest of this copy's files
-- see loading is off and skip themselves.
if not lib then
	LibStub(MAJOR).loading = false
	return
end

lib.loading = true
lib.modules = {}

-- state every kit shares, kept across upgrades.
lib.state = lib.state or {}
local state = lib.state

function lib:Module(name, build)
	self.modules[#self.modules + 1] = { name = name, build = build }
end

-- only one menu can be open at a time, across every kit.
local function CloseMenus()
	if state.openMenu then state.openMenu:Close() end
end
lib.CloseMenus = CloseMenus
lib.CloseDropdowns = CloseMenus

--------------------------------------------------------------------------------
-- Helpers every module gets through P
--------------------------------------------------------------------------------

local util = {}

-- options can be a value or a function that returns one.
function util.Resolve(value, ...)
	if type(value) == "function" then return value(...) end
	return value
end

function util.Merge(into, from)
	if from then
		for key, value in pairs(from) do into[key] = value end
	end
	return into
end

-- snaps a value to the nearest step counted from min.
function util.Snap(value, min, step)
	if not step or step <= 0 then return value end
	min = min or 0
	return min + math.floor((value - min) / step + 0.5) * step
end

function util.Clamp(value, min, max)
	return math.min(math.max(value, min), max)
end

-- Enable and Disable exist on most things, SetEnabled doesn't.
function util.SetControlEnabled(control, enabled)
	if control.SetEnabled then
		control:SetEnabled(enabled and true or false)
	elseif enabled then
		control:Enable()
	else
		control:Disable()
	end
end

util.WEAK = { __mode = "k" }

-- style looks a module brings for its own widget kinds, with anything the
-- addon's config.styles gave for them kept on top.
function util.Defaults(UI, kind, defs)
	local set = UI.styles[kind] or {}
	for name, def in pairs(defs) do
		local given = set[name]
		set[name] = given and util.Merge(def, given) or def
	end
	UI.styles[kind] = set
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
--   config.styles            style entries to override or add, by kind and name
--   config.font              font file every kit string uses instead of its template
--   config.fontFlags         outline flags to go with it
--   config.fontScale         starting text scale
--------------------------------------------------------------------------------

function lib:New(config)
	config = config or {}

	local UI = { lib = self }
	UI.Resolve, UI.Snap, UI.Clamp = util.Resolve, util.Snap, util.Clamp
	UI.CloseMenus, UI.CloseDropdowns = CloseMenus, CloseMenus

	-- private to this kit, what one module hands the next.
	local P = setmetatable({ state = state, lib = self }, { __index = util })

	for _, module in ipairs(self.modules) do
		module.build(UI, P, config)
	end

	return UI
end
