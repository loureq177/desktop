hl.monitor({
	output = "desc:BOE 0x0998",
	mode = "1920x1080@165",
	position = "0x0",
})
hl.monitor({
	output = "",
	mode = "highres",
	position = "auto",
})

hl.bind(
	"switch:on:Lid Switch",
	hl.dsp.exec_cmd([=[hyprctl eval 'hl.monitor({output = "desc:BOE 0x0998", disabled = true})']=]),
	{ locked = true }
)
hl.bind(
	"switch:off:Lid Switch",
	hl.dsp.exec_cmd([=[hyprctl eval 'hl.monitor({output = "desc:BOE 0x0998", disabled = false})']=]),
	{ locked = true }
)
