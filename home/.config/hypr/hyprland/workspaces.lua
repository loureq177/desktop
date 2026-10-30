-- The workspaces are one row across the monitors: SUPER + 1..9 count along it, H / L
-- go past a workspace's last window (past the row's end, to one new workspace),
-- SHIFT takes the window along. Swipes do the same along each monitor.

local nowhere = { x = math.huge, y = math.huge }
local opposite = { left = "right", right = "left" }

local function row()
	local out = {}
	for _, ws in ipairs(hl.get_workspaces()) do
		if not ws.special then
			table.insert(out, ws)
		end
	end
	table.sort(out, function(a, b)
		local ma, mb = a.monitor or nowhere, b.monitor or nowhere
		if ma.x ~= mb.x then
			return ma.x < mb.x
		end
		if ma.y ~= mb.y then
			return ma.y < mb.y
		end
		return a.id < b.id
	end)
	return out
end

-- The row, and the place in it of the focused workspace: none while the focus
-- is on a special workspace.
local function here()
	local win = hl.get_active_window()
	local current = win and win.workspace or hl.get_active_workspace()
	local workspaces = row()
	for i, ws in ipairs(workspaces) do
		if current ~= nil and ws.id == current.id then
			return workspaces, i
		end
	end
	return workspaces, nil
end

-- The id of a new workspace past the end of the row. Hyprland makes it on the focused
-- monitor: the row's last one, or it would land in the middle of the row.
local function new_last(workspaces)
	local top = 0
	for _, ws in ipairs(workspaces) do
		top = math.max(top, ws.id)
	end
	local last = workspaces[#workspaces]
	if last ~= nil and last.monitor ~= nil then
		hl.dispatch(hl.dsp.focus({ monitor = last.monitor.name }))
	end
	return top + 1
end

-- A new id before the row's start, or before id `from`: the workspaces from there
-- move one id up, highest first, as an id in use cannot be taken.
local function new_first(workspaces, from)
	local free = from or workspaces[1].id
	local ids = {}
	for _, ws in ipairs(workspaces) do
		if ws.id >= free then
			table.insert(ids, ws.id)
		end
	end
	table.sort(ids, function(a, b)
		return a > b
	end)
	for _, id in ipairs(ids) do
		hl.dispatch(hl.dsp.workspace.change_id({ workspace = id, id = id + 1 }))
	end
	return free
end

-- A swipe makes a new workspace only past the last; by id (use_r), also before the first: that
-- from a first with windows, as with the keys, a free id before it, none before the next.
local swipes_by_id = false

local function sync_swipe()
	local current = hl.get_active_workspace()
	local workspaces, own, taken = row(), {}, {}
	for _, ws in ipairs(workspaces) do
		taken[ws.id] = true
		if current ~= nil and ws.monitor ~= nil and ws.monitor.name == current.monitor.name then
			table.insert(own, ws)
		end
	end
	local first, second = own[1], own[2]
	local by_id = first ~= nil and first.id == current.id and first.windows > 0
	if by_id then
		local room = false
		for id = 1, first.id - 1 do
			room = room or not taken[id]
		end
		if not room then
			new_first(workspaces, first.id)
			return sync_swipe()
		end
		for id = first.id + 1, (second and second.id or 1) - 1 do
			if not taken[id] then
				hl.dispatch(hl.dsp.workspace.change_id({ workspace = second.id, id = id }))
				break
			end
		end
	end
	if by_id ~= swipes_by_id then
		swipes_by_id = by_id
		hl.config({ gestures = { workspace_swipe_use_r = by_id } })
	end
end

for _, event in ipairs({
	"workspace.active",
	"workspace.removed",
	"workspace.move_to_monitor",
	"monitor.focused",
	"monitor.removed",
	"window.open",
	"window.destroy",
	"window.move_to_workspace",
}) do
	hl.on(event, sync_swipe)
end
sync_swipe()

-- Whether Hyprland's focus and swap find a window on that side: a tiled one past `win`'s
-- edge and level with it. Not from a floating or fullscreen `win`; floating ones never count.
local function anything_beyond(win, dir)
	if win == nil or win.workspace == nil or win.floating or win.fullscreen > 0 then
		return false
	end
	for _, w in ipairs(hl.get_windows({ workspace = win.workspace, mapped = true, floating = false })) do
		local past = dir == "left" and w.at.x + w.size.x <= win.at.x
			or dir == "right" and w.at.x >= win.at.x + win.size.x
		local level = math.min(w.at.y + w.size.y, win.at.y + win.size.y) - math.max(w.at.y, win.at.y)
		if not w.hidden and past and level > 1 then
			return true
		end
	end
	return false
end

-- From a floating window Hyprland only looks among the floating ones: the nearest
-- of any kind on that side, by its middle.
local function nearest_from_floating(win, dir)
	local middle = win.at.x + win.size.x / 2
	local best, best_distance
	for _, w in ipairs(hl.get_windows({ workspace = win.workspace, mapped = true })) do
		local x = w.at.x + w.size.x / 2
		local distance = dir == "left" and middle - x or x - middle
		if not w.hidden and distance > 0 and (best == nil or distance < best_distance) then
			best, best_distance = w, distance
		end
	end
	return best
end

-- The tiled window of `ws` nearest its `side`, the top one of a column: the
-- way in from that side.
local function window_at_side(ws, side)
	local best, best_key
	for _, w in ipairs(hl.get_windows({ workspace = ws, mapped = true, floating = false })) do
		local key = side == "left" and w.at.x or -(w.at.x + w.size.x)
		if
			not w.hidden
			and (best == nil or key < best_key or key == best_key and w.at.y < best.at.y)
		then
			best, best_key = w, key
		end
	end
	return best
end

-- Onto another monitor's workspace the window flies; a workspace that slides in
-- brings it along in place.
local function move(win, id)
	local target = hl.get_workspace(id)
	local slides = target == nil or not target.visible
	if slides then
		hl.dispatch(hl.dsp.window.set_prop({ prop = "no_anim", value = "1", window = win }))
	end
	hl.dispatch(hl.dsp.window.move({ workspace = id, window = win }))
	if slides then
		hl.timer(function()
			hl.dispatch(hl.dsp.window.set_prop({ prop = "no_anim", value = "unset", window = win }))
		end, { timeout = 100, type = "oneshot" })
	end
end

-- Sends `win` to place `n` of the row, or past an end to a new workspace; alone
-- there, it leaves its old one empty, which Hyprland removes: still one new.
local function send(win, workspaces, n)
	local ws = workspaces[n]
	move(win, ws and ws.id or n < 1 and new_first(workspaces) or new_last(workspaces))
end

local M = {}

-- To the window on that side, or on past the edge to the next workspace; past
-- the row's end to a new one, but from an empty one nowhere further.
function M.focus(dir)
	local win = hl.get_active_window()
	if anything_beyond(win, dir) then
		hl.dispatch(hl.dsp.focus({ direction = dir }))
		return
	end
	local beside = win ~= nil and win.floating and win.fullscreen == 0 and nearest_from_floating(win, dir)
	if beside then
		hl.dispatch(hl.dsp.focus({ window = beside }))
		return
	end
	local workspaces, i = here()
	if i == nil then
		return
	end
	local n = i + (dir == "left" and -1 or 1)
	local ws = workspaces[n]
	if ws == nil then
		if workspaces[i].windows > 0 then
			hl.dispatch(hl.dsp.focus({ workspace = n < 1 and new_first(workspaces) or new_last(workspaces) }))
		end
		return
	end
	hl.dispatch(hl.dsp.focus({ workspace = ws.id }))
	-- Coming in from the left, the first window in; from the right, the last.
	local entry = window_at_side(ws, opposite[dir])
	if entry ~= nil then
		hl.dispatch(hl.dsp.focus({ window = entry }))
	end
end

-- Swaps the window with the one on that side, or with none there takes it on
-- to the next workspace of the row.
function M.throw(dir)
	local win = hl.get_active_window()
	if anything_beyond(win, dir) then
		hl.dispatch(hl.dsp.window.swap({ direction = dir }))
		return
	end
	local workspaces, i = here()
	if win == nil or i == nil then
		return
	end
	local n = i + (dir == "left" and -1 or 1)
	-- Dwindle splits the window nearest the cursor, on its side: the cursor waits
	-- in the gap the window came in by.
	local edge = workspaces[n] and window_at_side(workspaces[n], opposite[dir])
	local m = edge and workspaces[n].monitor
	if m ~= nil then
		local last = dir == "left"
		hl.dispatch(hl.dsp.cursor.move({
			x = last and m.x + m.width / m.scale - 1 or m.x,
			y = edge.at.y + edge.size.y / 2 + (last and 1 or -1),
		}))
	end
	send(win, workspaces, n)
end

-- The workspace at place n of the row, or a new one past its end.
function M.focus_nth(n)
	local workspaces = row()
	local ws = workspaces[n]
	hl.dispatch(hl.dsp.focus({ workspace = ws and ws.id or new_last(workspaces) }))
end

function M.send_nth(n)
	local win = hl.get_active_window()
	if win ~= nil then
		send(win, row(), n)
	end
end

return M
