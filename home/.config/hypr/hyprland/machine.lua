-- The machine's keyboard, GPU, monitors and startup (local.lua.example), with
-- defaults for whatever is missing; dofile, as require errors even in pcall.

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
