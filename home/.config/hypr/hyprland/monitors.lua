-- The monitors local.lua names where it puts them, anything else next to
-- them. The laptop panel is off while the lid is closed and another screen is
-- connected, and sits where the connected external monitor wants it.

local machine = require("hyprland.machine")
local laptop = machine.laptop

for _, m in ipairs(machine.monitors) do
	hl.monitor({
		output = m.output,
		mode = m.mode or "preferred",
		position = m.position or "auto",
		scale = m.scale or 1,
	})
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

-- FALLBACK is Hyprland's stand-in while no real output is left.
local function has_external()
	for _, m in ipairs(hl.get_monitors()) do
		local name = m.name or ""
		if not name:find("^eDP") and name ~= "FALLBACK" then
			return true
		end
	end
	return false
end

-- Applied again only when it changes: a rule for the panel is itself a
-- monitor change.
local laptop_applied = nil
local function place_laptop()
	if laptop == nil then
		return
	end
	local position = "auto"
	for _, m in ipairs(machine.monitors) do
		-- the output of a monitor rule ("DP-1", "desc:...") is a selector
		if m.laptop and hl.get_monitor(m.output) ~= nil then
			position = m.laptop
			break
		end
	end
	local disabled = lid_closed() and has_external()
	local state = tostring(disabled) .. " " .. position
	if state == laptop_applied then
		return
	end
	laptop_applied = state
	hl.monitor({
		output = laptop.output,
		mode = laptop.mode or "preferred",
		position = position,
		scale = laptop.scale or 1,
		disabled = disabled,
	})
end

place_laptop()
hl.on("monitor.added", place_laptop)
hl.on("monitor.removed", place_laptop)
-- At login the outputs are still coming up when the session starts.
hl.on("hyprland.start", function()
	hl.timer(place_laptop, { timeout = 1500, type = "oneshot" })
end)

hl.bind("switch:on:Lid Switch", function()
	place_laptop()
	if not has_external() then
		hl.dispatch(hl.dsp.dpms({ action = "off" }))
	end
end, { locked = true })

hl.bind("switch:off:Lid Switch", function()
	hl.dispatch(hl.dsp.dpms({ action = "on" }))
	place_laptop()
end, { locked = true })
