local laptop_output = "desc:BOE 0x0998"
local laptop_mode = "1920x1080@165"
local laptop_pos = "320x1440" -- down position
local laptop_scale = 1

hl.monitor({
	output = laptop_output,
	mode = laptop_mode,
	position = laptop_pos,
	scale = laptop_scale,
})
hl.monitor({
	output = "DP-1",
	mode = "2560x1440@59.95",
	position = "0x0", -- down position
	scale = 1,
})

hl.bind(
	"switch:on:Lid Switch",
	hl.dsp.exec_cmd(string.format([=[hyprctl eval 'hl.monitor({output = "%s", disabled = true})']=], laptop_output)),
	{ locked = true }
)
hl.bind(
	"switch:off:Lid Switch",
	hl.dsp.exec_cmd(string.format(
		[=[hyprctl eval 'hl.monitor({output = "%s", mode = "%s", position = "%s", scale = %d, disabled = false})']=],
		laptop_output,
		laptop_mode,
		laptop_pos,
		laptop_scale
	)),
	{ locked = true }
)
