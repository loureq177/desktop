-- What belongs to one machine: keyboard, GPU, monitors, startup commands
-- (local.lua.example). Every field is here whatever local.lua has: a missing
-- or broken one leaves the defaults. (Hyprland's require reports a broken
-- file as a config error even in pcall; dofile does not.)

local ok, machine = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/local.lua")
if not ok or type(machine) ~= "table" then
	machine = {}
end

local function list(t)
	return type(t) == "table" and t or {}
end

return {
	keyboard = list(machine.keyboard),
	env = type(machine.env) == "function" and machine.env or function() end,
	laptop = type(machine.laptop) == "table" and machine.laptop or nil,
	monitors = list(machine.monitors),
	autostart = list(machine.autostart),
}
