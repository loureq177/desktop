local gsettings = "gsettings set org.gnome.desktop.interface"

hl.on("hyprland.start", function()
	local cmds = {
		-- gsettings .. " cursor-theme 'Bibata-Modern-Classic'",
		gsettings .. " icon-theme 'Papirus-Dark'",
		gsettings .. " font-name 'Adwaita Sans 12'",
		gsettings .. " color-scheme 'prefer-dark'",
		gsettings .. " gtk-theme 'Adwaita-dark'",
		gsettings .. " monospace-font-name 'JetBrainsMono Nerd Font Mono 12'",
		-- "hyprctl setcursor Bibata-Modern-Classic 24",

		"dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE",
		"systemctl --user start hyprland-session.target",

		"wl-paste --type text --watch cliphist -max-items 50 store",
		"wl-paste --type image/png --watch cliphist -max-items 10 store",
		"wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0.25",
		"waybar",
		"swaybg -i ~/.config/hypr/wallpapers/hyprland.png",
		"swaync",
		"hyprsunset",
	}

	for _, cmd in ipairs(cmds) do
		hl.exec_cmd(cmd)
	end
end)
