local gsettings = "gsettings set org.gnome.desktop.interface"

hl.on("hyprland.start", function()
	local cmds = {
		gsettings .. " cursor-theme 'Bibata-Modern-Classic'",
		gsettings .. " icon-theme 'Papirus-Dark'",
		gsettings .. " font-name 'Adwaita Sans 13'",
		gsettings .. " color-scheme 'prefer-dark'",
		gsettings .. " gtk-theme 'Adwaita-dark'",
		gsettings .. " monospace-font-name 'JetBrainsMono Nerd Font Mono 13'",

		"systemctl --user start hyprland-session.target",

		"systemctl --user start xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xdg-desktop-portal",

		"wl-paste --type text --watch cliphist -max-items 50 store",
		"wl-paste --type image/png --watch cliphist -max-items 10 store",
		"wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0.25",
		"waybar",
		"swaybg -i ~/.config/hypr/wallpapers/hyprland.png",
		"swaync",
		"hypridle",
		"hyprsunset",
	}

	for _, cmd in ipairs(cmds) do
		hl.exec_cmd(cmd)
	end
end)
