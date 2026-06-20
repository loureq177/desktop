local function update_laptop_scale()
	local monitors = hl.get_monitors()

	hl.monitor({
		output = "desc:BOE 0x0998",
		mode = "1920x1080@165",
		position = "0x0",
		scale = (#monitors > 1) and 1.2 or 1,
	})
end

hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})

hl.on("monitor.added", update_laptop_scale)
hl.on("monitor.removed", update_laptop_scale)

update_laptop_scale()
