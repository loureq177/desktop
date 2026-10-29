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
local first_firefox
for _, name in ipairs(background) do
	if first_firefox == nil and specials[name].firefox then
		first_firefox = name
	end
end

local function opened_by(w, app)
	if app.host then
		return w.class:find(app.host, 1, true) ~= nil
	end
	return w.class == (app.firefox and first_firefox or app.class)
end

hl.on("hyprland.start", function()
	if background[1] == nil then
		return
	end
	local i = 0
	local sub
	local function start_next()
		i = i + 1
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
		-- Back on, as misc:focus_on_activate is (look.lua): "unset" leaves it off.
		hl.timer(function()
			hl.dispatch(hl.dsp.window.set_prop({ prop = "focus_on_activate", value = "1", window = w }))
		end, { timeout = 10000, type = "oneshot" })
		start_next()
	end)
	start_next()
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
			hl.dispatch(hl.dsp.workspace.toggle_special(name_of(last.workspace)))
		end
	end,
})

hl.gesture({
	fingers = 3,
	direction = "down",
	action = function()
		local ws = hl.get_active_special_workspace()
		if ws ~= nil then
			hl.dispatch(hl.dsp.workspace.toggle_special(name_of(ws)))
		end
	end,
})

return specials
