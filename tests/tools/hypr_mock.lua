-- Runs hyprland.lua against a fake `hl` API and prints what it registered, one
-- tab-separated record per line:
--   BIND <keys> <description> <dispatcher> <command>
--   EXEC <command>              (hl.exec_cmd, including the hyprland.start hook)
--   ENV  <name> <value>
--   UI   <path> <value|MISSING> (every ui.x.y the config reads)
-- Usage: HOME=<dir with .config/hypr> lua hypr_mock.lua

local hypr = os.getenv("HOME") .. "/.config/hypr"

local function emit(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = (tostring((select(i, ...))):gsub("[\t\n]", " "))
	end
	print(table.concat(parts, "\t"))
end

-- hl.dsp.a.b(arg) -> { dsp = "a.b", arg = arg }
local function dispatcher_tree(path)
	return setmetatable({}, {
		__index = function(_, key)
			return dispatcher_tree(path == "" and key or (path .. "." .. key))
		end,
		__call = function(_, arg)
			return { dsp = path, arg = arg }
		end,
	})
end

local handlers = {}
local api = {
	dsp = dispatcher_tree(""),
	bind = function(keys, action, opts)
		local name, command = type(action), ""
		if type(action) == "table" then
			name = action.dsp or "table"
			if name == "exec_cmd" then
				command = action.arg
			end
		end
		emit("BIND", keys, opts and opts.description or "", name, command)
	end,
	exec_cmd = function(cmd)
		emit("EXEC", cmd)
	end,
	env = function(name, value)
		emit("ENV", name, value)
	end,
	on = function(event, fn)
		handlers[event] = handlers[event] or {}
		table.insert(handlers[event], fn)
	end,
	timer = function()
		return {}
	end,
}

hl = setmetatable(api, {
	__index = function(_, key)
		if key:match("^get_") then
			-- plural getters return lists, singular ones "nothing active"
			return function()
				if key:match("s$") then
					return {}
				end
				return nil
			end
		end
		return function() end
	end,
})

-- Every ui.<section>.<key> the config mentions must exist in ui.lua.
local ui = dofile(hypr .. "/ui.lua")
local source = assert(io.open(hypr .. "/hyprland.lua")):read("a")
local seen = {}
for section, key in source:gmatch("%f[%w_]ui%.([%a_]+)%.([%a_][%w_]*)") do
	local path = section .. "." .. key
	if not seen[path] then
		seen[path] = true
		local value = type(ui[section]) == "table" and ui[section][key] or nil
		emit("UI", path, value == nil and "MISSING" or value)
	end
end

dofile(hypr .. "/hyprland.lua")

for _, fn in ipairs(handlers["hyprland.start"] or {}) do
	fn()
end
