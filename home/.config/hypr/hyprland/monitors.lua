-- Monitors where local.lua puts them, the rest beside. With the lid closed the panel goes
-- dark and, with another screen connected, out of reach, but it is never disabled: an
-- unplug would leave no outputs, whose flapping kills clients, and a dock's outputs
-- coming up during its modeset lost their signal.

local machine = require("hyprland.machine")
local laptop = machine.laptop

-- Left of everything: "auto" monitors go right of the last one, and no edge touches it.
local PARKED = "-20000x-20000"

local M = {}

-- The panel's name while it is parked: the row of workspaces leaves it out.
M.parked = nil

-- The mode, scale and place set in the shell's settings (SUPER + S), by output, over local.lua's.
-- Read each time: the shell writes them while this runs.
local function displays()
	local ok, saved = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/displays.lua")
	return ok and type(saved) == "table" and saved or {}
end

local function rule(m, position)
	local chosen = displays()[m.output] or {}
	hl.monitor({
		output = m.output,
		mode = chosen.mode or m.mode or "preferred",
		-- Parked stays parked: the arrangement is for a panel in use.
		position = position ~= PARKED and chosen.position or position,
		scale = chosen.scale or m.scale or 1,
	})
end

local listed = {}
if laptop then
	listed[laptop.output] = true
end
for _, m in ipairs(machine.monitors) do
	listed[m.output] = true
	rule(m, m.position or "auto")
end
for output in pairs(displays()) do
	if not listed[output] then
		rule({ output = output }, "auto")
	end
end
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

local function lid_closed()
	local f = io.popen("cat /proc/acpi/button/lid/*/state 2>/dev/null")
	if f == nil then
		return false
	end
	local out = f:read("*a") or ""
	f:close()
	return out:find("closed", 1, true) ~= nil
end

local function panel()
	return laptop and hl.get_monitor(laptop.output)
end

-- FALLBACK is Hyprland's stand-in while no real output is left.
local function externals()
	local p, out = panel(), {}
	for _, m in ipairs(hl.get_monitors()) do
		if m.name ~= "FALLBACK" and (p == nil or m.name ~= p.name) then
			table.insert(out, m)
		end
	end
	return out
end

local function panel_position()
	for _, m in ipairs(machine.monitors) do
		-- the output of a monitor rule ("DP-1", "desc:...") is a selector
		if m.laptop and hl.get_monitor(m.output) ~= nil then
			return m.laptop
		end
	end
	return "auto"
end

-- Applied again only when it changes: a rule for the panel is itself a monitor change.
local applied = nil
local function place()
	if laptop == nil then
		return
	end
	local p, others = panel(), externals()
	local closed = lid_closed()
	local parked = closed and others[1] ~= nil
	local position = parked and PARKED or panel_position()
	if position ~= applied then
		applied = position
		rule(laptop, position)
	end
	M.parked = parked and p and p.name or nil
	if p == nil then
		return
	end
	if parked then
		for _, ws in ipairs(hl.get_workspaces()) do
			if not ws.special and ws.windows > 0 and ws.monitor ~= nil and ws.monitor.name == p.name then
				hl.dispatch(hl.dsp.workspace.move({ workspace = ws.id, monitor = others[1].name }))
			end
		end
		if p.focused then
			hl.dispatch(hl.dsp.focus({ monitor = others[1].name }))
		end
	end
	if closed then
		hl.dispatch(hl.dsp.dpms({ action = "off", monitor = p.name }))
	end
end

local function dpms(action, name)
	hl.dispatch(hl.dsp.dpms({ action = action, monitor = name }))
end

-- A dock's outputs share one link: turned on together, the second one keeps no picture while
-- the driver says it is on. One at a time they all get one.
local GAP = 1500
local function one_by_one(names, step)
	for i, name in ipairs(names) do
		hl.timer(function()
			step(name)
		end, { timeout = 1 + (i - 1) * GAP, type = "oneshot" })
	end
end

local function reconnect(names)
	one_by_one(names, function(name)
		dpms("off", name)
		-- Longer than the fade to black: only its end really turns the screen off.
		hl.timer(function()
			dpms("on", name)
		end, { timeout = 800, type = "oneshot" })
	end)
end

local function external_names()
	local names = {}
	for _, m in ipairs(externals()) do
		table.insert(names, m.name)
	end
	return names
end

-- After sleep: the way out of a black or frozen screen. Going back to the VT after sleep can
-- leave the panel on its last frame; only this makes it draw again.
function M.reconnect()
	reconnect(external_names())
end

local asleep_since = nil

function M.note_sleep()
	asleep_since = os.time()
end

-- After a long sleep the panel can stay on its last frame until it is turned off once; every
-- case so far slept 10 minutes or more. With no fade and at once, it falls within the waking up.
function M.refresh_panel()
	local p = panel()
	local short = asleep_since ~= nil and os.time() - asleep_since < 300
	asleep_since = nil
	if p == nil or short or lid_closed() then
		return
	end
	hl.animation({ leaf = "fadeDpms", enabled = false })
	dpms("off", p.name)
	hl.timer(function()
		dpms("on", p.name)
		hl.animation({ leaf = "fadeDpms", enabled = true, speed = 4, bezier = "default" })
	end, { timeout = 30, type = "oneshot" })
end

-- What brings the screens back (hypridle.conf), all but a panel under a closed lid.
function M.wake()
	local p = panel()
	if p ~= nil then
		dpms(lid_closed() and "off" or "on", p.name)
	end
	one_by_one(external_names(), function(name)
		dpms("on", name)
	end)
end

-- Taken out of displays.lua: a reload leaves a screen under the catch-all rule as it was.
function M.forget(output)
	if laptop and output == laptop.output then
		return rule(laptop, applied or "auto")
	end
	for _, m in ipairs(machine.monitors) do
		if m.output == output then
			return rule(m, m.position or "auto")
		end
	end
	rule({ output = output }, "auto")
end

-- For the row of workspaces, which starts with it.
function M.panel_name()
	local p = panel()
	return p and p.name
end

-- Screens with nothing on them take workspaces from those holding several, left to right
-- and in order, the last one all that is left; each screen keeps its first. A workspace is
-- known by a window of it: moving one renumbers the row (workspaces.lua).
local function spread()
	local screens, held = {}, {}
	for _, m in ipairs(hl.get_monitors()) do
		if m.name ~= "FALLBACK" and m.name ~= M.parked then
			table.insert(screens, m)
			held[m.name] = {}
		end
	end
	table.sort(screens, function(a, b)
		if a.x ~= b.x then
			return a.x < b.x
		end
		return a.y < b.y
	end)
	local seen = {}
	for _, w in ipairs(hl.get_windows({ mapped = true })) do
		local ws = w.workspace
		if ws ~= nil and not ws.special and not seen[ws.id] and ws.monitor ~= nil and held[ws.monitor.name] ~= nil then
			seen[ws.id] = true
			table.insert(held[ws.monitor.name], { id = ws.id, window = w })
		end
	end
	local empty, spare = {}, {}
	for _, m in ipairs(screens) do
		local items = held[m.name]
		table.sort(items, function(a, b)
			return a.id < b.id
		end)
		if items[1] == nil then
			table.insert(empty, m.name)
		end
		for i = 2, #items do
			table.insert(spare, items[i].window)
		end
	end
	if empty[1] == nil or spare[1] == nil then
		return
	end
	local active = hl.get_active_window()
	for i, name in ipairs(empty) do
		local shown
		while spare[1] ~= nil and (shown == nil or i == #empty) do
			local w = table.remove(spare, 1)
			shown = shown or w
			hl.dispatch(hl.dsp.workspace.move({ workspace = w.workspace.id, monitor = name }))
		end
		if shown ~= nil then
			hl.dispatch(hl.dsp.focus({ workspace = shown.workspace.id }))
		end
	end
	if active ~= nil then
		hl.dispatch(hl.dsp.focus({ window = active }))
	end
end

local settling = 0
hl.on("monitor.added", function()
	place()
	settling = settling + 1
	local mine = settling
	hl.timer(function()
		if mine == settling then
			spread()
		end
	end, { timeout = 1000, type = "oneshot" })
end)

-- At the event the monitor is still listed.
hl.on("monitor.removed", function()
	hl.timer(place, { timeout = 100, type = "oneshot" })
end)

place()
-- At login the outputs are still coming up when the session starts.
hl.on("hyprland.start", function()
	hl.timer(place, { timeout = 1500, type = "oneshot" })
end)

hl.bind("switch:on:Lid Switch", place, { locked = true })

hl.bind("switch:off:Lid Switch", function()
	place()
	M.wake()
end, { locked = true })

return M
