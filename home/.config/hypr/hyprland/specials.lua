-- Special workspaces, one app each, started when opened empty; `key` toggles it
-- with SUPER + SHIFT. Chosen with apply-apps (hyprland/apps.lua).

local apps = require("hyprland.apps")
local specials = apps.specials

for name, app in pairs(specials) do
	local ws = "special:" .. name
	hl.workspace_rule({ workspace = ws, gaps_out = 48 })
	if app.class then
		hl.window_rule({ match = { class = app.class, title = app.title }, workspace = ws })
	end
end

local function name_of(ws)
	return (ws.name:gsub("^special:", ""))
end

-- Hiding one over an empty workspace leaves the keyboard on its window, and the next
-- panel to close brings it back, unless the cursor is over no surface: for that moment, it is.
local function toggle(name)
	local showing = hl.get_active_special_workspace()
	local ws = hl.get_active_workspace()
	if showing == nil or name_of(showing) ~= name or ws == nil or ws.windows > 0 then
		hl.dispatch(hl.dsp.workspace.toggle_special(name))
		return
	end
	local at, m = hl.get_cursor_pos(), ws.monitor
	hl.dispatch(hl.dsp.cursor.move({ x = m.x + m.width / m.scale / 2, y = m.y + m.height / m.scale / 2 }))
	hl.dispatch(hl.dsp.workspace.toggle_special(name))
	hl.dispatch(hl.dsp.cursor.move({ x = at.x, y = at.y }))
end

-- A swipe skips hide_special_on_workspace_change (input.lua): the special goes as with the keys.
hl.on("workspace.active", function(ws)
	local showing, current = hl.get_active_special_workspace(), hl.get_active_workspace()
	if showing ~= nil and current ~= nil and current.id == ws.id then
		toggle(name_of(showing))
	end
end)

-- A special workspace opened empty starts its app. The event comes once the
-- workspace is set up, so one that a window was sent to is not empty.
hl.on("workspace.created", function(ws)
	local app = ws.special and ws.is_empty and specials[name_of(ws)]
	if app then
		hl.exec_cmd(app.exe)
	end
end)

-- Three fingers up bring back the special workspace used last, down put away
-- the one that is showing.
hl.gesture({
	fingers = 3,
	direction = "up",
	action = function()
		if hl.get_active_special_workspace() ~= nil then
			return
		end
		local last
		for _, w in ipairs(hl.get_windows()) do
			local age = w.focus_history_id
			if w.workspace ~= nil and w.workspace.special and age ~= nil and age >= 0 then
				if last == nil or age < last.focus_history_id then
					last = w
				end
			end
		end
		if last ~= nil then
			toggle(name_of(last.workspace))
		end
	end,
})

hl.gesture({
	fingers = 3,
	direction = "down",
	action = function()
		local ws = hl.get_active_special_workspace()
		if ws ~= nil then
			toggle(name_of(ws))
		end
	end,
})

return { list = specials, toggle = toggle }
