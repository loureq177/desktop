-- Options set in the shell's settings (SUPER + S), from ~/.config/hypr/settings.lua
-- ({ ["input:sensitivity"] = -0.2 }), each on its own so an unknown one is skipped.

local ok, options = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/settings.lua")
if not ok or type(options) ~= "table" then
	return
end

for name, value in pairs(options) do
	-- "decoration:blur:passes" -> { decoration = { blur = { passes = value } } },
	-- and "general:col.inactive_border" -> { general = { col = { ... } } }
	local tree = value
	local parts = {}
	for part in string.gmatch(name, "[^:.]+") do
		table.insert(parts, part)
	end
	for i = #parts, 1, -1 do
		tree = { [parts[i]] = tree }
	end
	pcall(hl.config, tree)
end
