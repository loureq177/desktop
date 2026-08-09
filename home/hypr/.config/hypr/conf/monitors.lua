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
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = 1,
})

hl.bind(
	"switch:on:Lid Switch",
	function()
		local mons = hl.get_monitors()
		if #mons > 1 then
			hl.dsp.dpms("off", laptop_output)
		end
	end,
	{ locked = true }
)

hl.bind(
	"switch:off:Lid Switch",
	function()
		hl.dsp.dpms("on")
	end,
	{ locked = true }
)

