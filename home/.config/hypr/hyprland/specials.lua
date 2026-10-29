-- Special workspaces, one app each, started when opened empty; `key` toggles it
-- with SUPER + SHIFT. The shell's names match (quickshell/Specials.js).

local bin = os.getenv("HOME") .. "/.local/bin"

local function webapp(name, url, title, key, desc)
	return {
		id = name,
		exe = bin .. "/firefox-webapp " .. name .. " " .. url,
		class = "webapps",
		title = ".*" .. title .. ".*",
		key = key,
		desc = desc or title,
	}
end

local specials = {
	calendar = webapp("calendar", "https://calendar.google.com", "Calendar", "C"),
	mail = webapp("gmail", "https://mail.google.com", "Gmail", "E", "Mail"),
	tasks = webapp("tasks", "https://tasks.google.com", "Tasks", "T"),
	whatsapp = webapp("whatsapp", "https://web.whatsapp.com", "WhatsApp", "W"),
	spotify = {
		exe = "flatpak run com.spotify.Client",
		class = "spotify",
		key = "S",
		desc = "Spotify",
	},
	btop = { exe = "ghostty +new-window -e btop", key = "B", desc = "Activity Monitor" },
	yazi = { exe = "ghostty +new-window -e yazi", key = "F", desc = "Files" },
	jolt = { exe = "ghostty +new-window -e jolt" },
}

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

-- Web apps started hidden so their notifications come early. They share one
-- Firefox (windows named after the first app), so each is moved as it opens.
local background = { "mail", "calendar", "whatsapp" }

hl.on("hyprland.start", function()
	local class = specials[background[1]].id
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
		if w.class ~= class or (w.workspace ~= nil and w.workspace.special) then
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
