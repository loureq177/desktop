-- Window rules. The special workspaces' own are in specials.lua.

local ui = require("ui")

hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

hl.window_rule({
	name = "picture-in-picture",
	match = { title = "^(Picture-in-Picture)$" },
	float = true,
	pin = true,
	idle_inhibit = "always",
})

hl.window_rule({
	name = "webcam-overlay",
	match = { title = "^(WebcamOverlay)$" },
	float = true,
	pin = true,
	no_initial_focus = true,
	no_dim = true,
})

hl.window_rule({
	-- Steam places its toasts by X11 coordinates, which xwayland-satellite
	-- drops, so without this they float in the middle of the screen.
	name = "steam-toasts",
	match = { class = "^(steam)$", title = "^(notificationtoasts_.*)$" },
	float = true,
	pin = true,
	move = string.format(
		"monitor_w-window_w-%d monitor_h-window_h-%d",
		ui.spacing.gaps_out,
		ui.spacing.gaps_out
	),
	no_initial_focus = true,
	no_dim = true,
})

hl.window_rule({
	-- The screenshot editor: over the desktop, big enough to see the detail
	-- being drawn on.
	name = "screenshot-editor",
	match = { class = "^(com.gabm.satty)$" },
	float = true,
	size = "monitor_w*0.8 monitor_h*0.8",
	center = true,
})

hl.window_rule({
	name = "idle-inhibit-fullscreen",
	match = { class = ".*" },
	idle_inhibit = "fullscreen",
})

hl.window_rule({
	-- Small tools and the file picker; GNOME's apps tile like the rest.
	name = "small-tools",
	match = {
		class = "^(org.gnome.Calculator|com.saivert.pwvucontrol|xdg-desktop-portal-gtk)$",
	},
	float = true,
	center = true,
})

-- Bitwarden's popout (unlock, passkeys): a small dialog over the browser, not a tile that
-- halves it. Helium names an extension's window by its id; the title covers other browsers.
-- 630 px tall, as it asks, scrolls under Helium's title strip: room for it all.
local bitwarden = { class = "^(chrome-nngceckbapebfimnlniiiahkandclblb-.*)$", title = "^(Bitwarden)$" }
for key, pattern in pairs(bitwarden) do
	hl.window_rule({
		name = "bitwarden-popout-" .. key,
		match = { [key] = pattern },
		float = true,
		size = "400 700",
		center = true,
	})
end

-- The pointer to its middle: with focus following the mouse, the least move sent the typing
-- back to the browser.
hl.on("window.open", function(w)
	if not (w.class:find("^chrome%-nngceckbapebfimnlniiiahkandclblb%-") or w.title == "Bitwarden") then
		return
	end
	hl.dispatch(hl.dsp.cursor.move({ x = w.at.x + w.size.x / 2, y = w.at.y + w.size.y / 2 }))
end)
