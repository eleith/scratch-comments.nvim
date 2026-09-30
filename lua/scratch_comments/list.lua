local actions = require("scratch_comments.actions")
local card = require("scratch_comments.ui.card")
local comments = require("scratch_comments.comments")
local store = require("scratch_comments.model.store")
local notify = require("scratch_comments.ui.notify")
local quickfix = require("scratch_comments.ui.quickfix")
local window = require("scratch_comments.ui.window")
local views = require("scratch_comments.model.views")

local M = {}

local list_id
local list_bufnr
local active_filter
local pending_jump = {}
local listening = {}
local refresh

---@param comment ScratchComment|ScratchCommentView
---@return string
local function haystack(comment)
  return table.concat({ comment.relative_path, comment.comment, comment.snippet or "" }, " ")
end

-- Keeps the comments that fuzzy match, in the order they were listed.
---@generic T: ScratchComment
---@param entries T[]
---@param filter string
---@return T[]
local function matching(entries, filter)
  local candidates = {}
  for index, comment in ipairs(entries) do
    table.insert(candidates, { index = index, text = haystack(comment) })
  end
  local kept = {}
  for _, candidate in ipairs(vim.fn.matchfuzzy(candidates, filter, { key = "text" })) do
    kept[candidate.index] = true
  end

  local matched = {}
  for index, comment in ipairs(entries) do
    if kept[index] then
      table.insert(matched, comment)
    end
  end
  return matched
end

---@param filter? string
---@return ScratchCommentView[], ScratchComment[]
local function filtered(filter)
  local anchored, orphans = views.anchored(), views.orphans()
  if filter and filter ~= "" then
    anchored, orphans = matching(anchored, filter), matching(orphans, filter)
  end
  return anchored, orphans
end

---@param id string
---@return ScratchComment?
local function by_id(id)
  return vim.iter(store.all()):find(function(comment)
    return comment.id == id
  end)
end

---@return integer?, string?
local function selected()
  if vim.api.nvim_get_current_buf() ~= list_bufnr then
    return nil
  end
  local qf = vim.fn.getqflist({ id = 0, items = 1 })
  if qf.id ~= list_id then
    return nil
  end
  local index = vim.api.nvim_win_get_cursor(0)[1]
  local data = qf.items[index] and qf.items[index].user_data
  return index, data and data.scratch_comments_id
end

local function jump()
  -- Only the most recent manager jump may move the cursor after a delayed read.
  for bufnr in pairs(pending_jump) do
    pending_jump[bufnr] = nil
  end
  local index, id = selected()
  if not index then
    -- Another plugin replaced our quickfix list; leave its normal navigation usable.
    vim.cmd.cc(vim.api.nvim_win_get_cursor(0)[1])
    return
  end
  if not id then
    notify.warn("This comment is gone")
    return
  end
  local comment = by_id(id)
  if not comment then
    notify.warn("This comment is gone")
    return
  end
  if not window.close() then
    notify.warn("Save or discard the comment first")
    return
  end
  local qf_win = vim.api.nvim_get_current_win()
  local entry = vim.iter(views.anchored()):find(function(view)
    return view.id == id
  end) or vim.iter(views.orphans()):find(function(view)
    return view.id == id
  end)
  if not entry then
    notify.warn("This comment is gone")
    return
  end
  local owner = qf_win
  local bufnr, win
  if entry.start_line then
    local ok = pcall(function()
      vim.cmd(index .. "cc")
    end)
    if ok and vim.api.nvim_buf_get_name(0) == comment.source_name then
      bufnr, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
      owner = win
    else
      notify.warn("Could not open the comment source")
    end
  end
  local expected_id = list_id
  if bufnr then
    -- A completed read may invalidate a parked anchor while :cc opens it.
    local resolved = vim.iter(views.orphans()):find(function(orphan)
      return orphan.id == id
    end)
    if resolved then
      entry = resolved
      bufnr, win, owner = nil, nil, qf_win
      vim.api.nvim_set_current_win(qf_win)
    end
  end
  actions.show(entry, owner, function()
    vim.schedule(function()
      if owner == qf_win and vim.fn.getqflist({ id = 0 }).id ~= expected_id then
        return
      end
      if vim.api.nvim_win_is_valid(owner) then
        vim.api.nvim_set_current_win(owner)
      end
    end)
  end, function()
    refresh(id, index, expected_id)
  end)
  if not bufnr or not win then
    return
  end
  local function position()
    if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= bufnr then
      return true
    end
    local active = window.current()
    if
      vim.api.nvim_get_current_win() ~= win
      and not (
        active
        and active.id == id
        and active.source_win == win
        and vim.api.nvim_get_current_win() == active.comment_win
      )
    then
      return true
    end
    local current = by_id(id)
    if not current then
      return true
    end
    local view = vim.iter(views.in_buffer(bufnr)):find(function(v)
      return v.id == id
    end)
    if view then
      vim.api.nvim_win_set_cursor(win, { view.start_line, view.start_col or 0 })
      return true
    end
    if current.state == "inactive" then
      local open = window.current()
      if open and open.id == id and open.update then
        open.update(card.of_orphan(current))
        open.source_win, owner = qf_win, qf_win
        refresh(id, index, expected_id)
      end
      notify.warn("This comment no longer has a location")
      return true
    end
    return false
  end
  if position() then
    return
  end
  -- An async BufReadCmd may fill the buffer after :cc has already moved the
  -- cursor. Keep one listener per buffer even if the user jumps repeatedly.
  pending_jump[bufnr] = position
  local open = window.current()
  if open then
    vim.api.nvim_create_autocmd("BufLeave", {
      buffer = vim.api.nvim_win_get_buf(open.comment_win),
      once = true,
      callback = function()
        if pending_jump[bufnr] == position then
          pending_jump[bufnr] = nil
        end
      end,
    })
  end
  -- BufReadPost reattachment runs on the next scheduled turn. Recheck after
  -- it, even if the file was fully populated before our on_lines listener.
  vim.schedule(function()
    if pending_jump[bufnr] == position and position() then
      pending_jump[bufnr] = nil
    end
  end)
  if listening[bufnr] then
    return
  end
  listening[bufnr] = vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function()
      local current = pending_jump[bufnr]
      if not current then
        listening[bufnr] = nil
        return true
      end
      vim.schedule(function()
        if pending_jump[bufnr] == current and current() then
          pending_jump[bufnr] = nil
        end
      end)
    end,
    on_detach = function()
      pending_jump[bufnr] = nil
      listening[bufnr] = nil
    end,
  })
end

-- Update the manager behind an open editor, without taking focus or opening
-- a list that the user already closed. Replace items in the same quickfix ID.
---@param id string
---@param index integer
---@param expected_id integer
refresh = function(id, index, expected_id)
  local qf = vim.fn.getqflist({ id = 0, winid = 0 })
  if qf.id ~= expected_id or qf.winid == 0 then
    return
  end
  local anchored, orphans = filtered(active_filter)
  local items = quickfix.items(anchored, orphans)
  vim.fn.setqflist({}, "r", { title = "Comments", items = items })
  if #items == 0 then
    vim.api.nvim_win_call(qf.winid, function()
      vim.cmd.cclose()
    end)
    list_id, list_bufnr = nil, nil
    return
  end
  local row = math.min(index, #items)
  for i, item in ipairs(items) do
    if item.user_data.scratch_comments_id == id then
      row = i
      break
    end
  end
  vim.api.nvim_win_set_cursor(qf.winid, { row, 0 })
end

-- Delete only the comment displayed in an open editor, never one inferred
-- from the cursor in a file or the selected quickfix row.
function M.delete_open()
  local open = window.current()
  local index = selected()
  local id = open and open.id
  if not id then
    notify.warn("No comment card open")
    return
  end
  if open and vim.bo[vim.api.nvim_win_get_buf(open.comment_win)].modified then
    notify.warn("Save or discard the comment first")
    return
  end
  local comment = by_id(id)
  if not comment then
    notify.warn("This comment is gone")
    return
  end
  comments.delete(comment)
  notify.info("Deleted comment")
  if index then
    refresh(id, index, list_id)
  elseif open and open.on_saved then
    open.on_saved()
  end
  if open then
    if index then
      -- Deleting from the list leaves focus there, even if its card was focused.
      window.close()
    else
      vim.api.nvim_win_close(open.comment_win, true)
    end
  end
end

local function escape()
  if window.current() and not window.close() then
    notify.warn("Save with :w, or discard with :q!")
  end
end

-- Open the quickfix list without moving the source cursor or showing a card.
---@param filter? string only comments matching this
function M.open(filter)
  if not window.close() then
    notify.warn("Save or discard the comment first")
    return
  end
  for bufnr in pairs(pending_jump) do
    pending_jump[bufnr] = nil
  end
  active_filter = filter
  local anchored, orphans = filtered(filter)
  if #anchored + #orphans == 0 then
    if list_id and vim.fn.getqflist({ id = 0 }).id == list_id then
      vim.fn.setqflist({}, "r", { items = {} })
      vim.cmd.cclose()
    end
    list_id, list_bufnr = nil, nil
    notify.info("No comments")
    return false
  end
  list_id = quickfix.list(anchored, orphans)
  if not list_id then
    return
  end
  list_bufnr = vim.api.nvim_get_current_buf()
  vim.keymap.set("n", "<CR>", jump, { buffer = list_bufnr, desc = "Jump and edit comment" })
  vim.keymap.set("n", "<Esc>", escape, { buffer = list_bufnr, desc = "Dismiss comment card" })
  return true
end

return M
