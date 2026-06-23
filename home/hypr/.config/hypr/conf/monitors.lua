local function update_laptop_scale()
	local monitors = hl.get_monitors()

	hl.monitor({
		output = "desc:BOE 0x0998",
		mode = "1920x1080@165",
		position = "0x0",
		scale = (#monitors > 1) and 1.05 or 1,
	})
end

local function restart_waybar()
	hl.exec_cmd("pkill -x waybar || true")
	hl.exec_cmd("sleep 0.3 && waybar &")
end

local function restart_swaybg()
	hl.exec_cmd("pkill -x swaybg || true")
	hl.exec_cmd("bash -c 'swaybg -i ~/Pictures/Wallpapers/hyprland-dark.png -m fill >/dev/null 2>&1 & disown'")
end

hl.on("monitor.added", function()
	update_laptop_scale()
	restart_swaybg()
	restart_waybar()
end)

hl.on("monitor.removed", function()
	update_laptop_scale()
	restart_swaybg()
	restart_waybar()
end)

update_laptop_scale()
