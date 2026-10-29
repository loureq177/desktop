-- The workspaces are one row across the monitors: SUPER + 1..9 count along it, H / L
-- go past a workspace's last window, SHIFT takes the window along.

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

-- The id of a new workspace past the end of the row.
local function new_last(workspaces)
	local top = 0
	for _, ws in ipairs(workspaces) do
		top = math.max(top, ws.id)
	end
	return top + 1
end

-- A new id before the row's start: every workspace moves one id up, highest
-- first, as an id in use cannot be taken.
local function new_first(workspaces)
	local free = workspaces[1].id
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

-- Whether `win`'s workspace has a window to the `dir` side (focus wraps at the edge).
local function anything_beyond(win, dir)
	if win == nil or win.workspace == nil then
		return false
	end
	for _, w in ipairs(hl.get_windows({ workspace = win.workspace, mapped = true })) do
		if
			not w.hidden
			and (dir == "left" and w.at.x < win.at.x or dir == "right" and w.at.x > win.at.x)
		then
			return true
		end
	end
	return false
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

-- Sends `win` to place `n` of the row, or past an end to a new workspace (not
-- when it is alone at that end).
local function send(win, workspaces, n)
	local ws = workspaces[n]
	if ws == nil then
		local edge = workspaces[n < 1 and 1 or #workspaces]
		if edge ~= nil and edge.id == win.workspace.id and win.workspace.windows <= 1 then
			return
		end
	end
	move(win, ws and ws.id or n < 1 and new_first(workspaces) or new_last(workspaces))
end

local M = {}

-- To the window on that side, or on past the edge to the next workspace.
function M.focus(dir)
	if anything_beyond(hl.get_active_window(), dir) then
		hl.dispatch(hl.dsp.focus({ direction = dir }))
		return
	end
	local workspaces, i = here()
	local ws = i and workspaces[i + (dir == "left" and -1 or 1)]
	if ws == nil then
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
