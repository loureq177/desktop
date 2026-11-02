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

-- Apps started hidden so their notifications come early, one after another, each
-- moved as it opens. Firefox web apps share one Firefox (windows named after the
-- first app), Chromium's are named after the URL's host.
local background = apps.background

local function has_window(name)
	return hl.get_windows({ workspace = "special:" .. name })[1] ~= nil
end

-- The class Firefox gives its web apps: that of whichever was opened first.
local function firefox_class()
	local first
	for _, name in ipairs(background) do
		first = first or (specials[name].firefox and name)
	end
	for _, w in ipairs(hl.get_windows()) do
		local app = w.workspace ~= nil and w.workspace.special and specials[name_of(w.workspace)]
		if app and app.firefox then
			return w.class
		end
	end
	return first
end

local function start_background()
	local firefox = firefox_class()
	local i = 0
	local sub

	local function opened_by(w, app)
		if app.host then
			return w.class:find(app.host, 1, true) ~= nil
		end
		return w.class == (app.firefox and firefox or app.class)
	end

	local function start_next()
		i = i + 1
		-- Opened by hand while the network was away.
		while background[i] ~= nil and has_window(background[i]) do
			i = i + 1
		end
		if background[i] == nil then
			sub:remove()
			return
		end
		hl.exec_cmd(specials[background[i]].exe)
	end
	sub = hl.on("window.open", function(w)
		-- one opened on a special is the user's own (workspace.created)
		if not opened_by(w, specials[background[i]]) or (w.workspace ~= nil and w.workspace.special) then
			return
		end
		hl.dispatch(hl.dsp.window.set_prop({ prop = "focus_on_activate", value = "0", window = w }))
		hl.dispatch(hl.dsp.window.move({
			workspace = "special:" .. background[i],
			follow = false,
			window = w,
		}))
		-- Back as misc:focus_on_activate has it: "unset" leaves it off.
		hl.timer(function()
			local value = hl.get_config("misc.focus_on_activate") and "1" or "0"
			hl.dispatch(hl.dsp.window.set_prop({ prop = "focus_on_activate", value = value, window = w }))
		end, { timeout = 10000, type = "oneshot" })
		start_next()
	end)
	start_next()
end

-- Once there is internet, however long that takes; the session does not wait for it.
hl.on("hyprland.start", function()
	if background[1] ~= nil then
		hl.exec_cmd([[sh -c 'until [ "$(nmcli -t -f CONNECTIVITY general || echo full)" = full ]; do sleep 2; done; hyprctl eval "require(\"hyprland.specials\").start_background()"']])
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

return { list = specials, toggle = toggle, start_background = start_background }
