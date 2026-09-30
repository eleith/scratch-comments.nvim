local actions = require("scratch_comments.actions")
local comments = require("scratch_comments.comments")
local store = require("scratch_comments.model.store")
local notify = require("scratch_comments.ui.notify")
local quickfix = require("scratch_comments.ui.quickfix")
local window = require("scratch_comments.ui.window")
local views = require("scratch_comments.model.views")

local M = {}

local list_id
local list_bufnr
local list_win
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

---@param expected_id integer?
---@return integer?
local function manager_window(expected_id)
  if
    not expected_id
    or vim.fn.getqflist({ id = 0 }).id ~= expected_id
    or not list_win
    or not vim.api.nvim_win_is_valid(list_win)
    or vim.api.nvim_win_get_buf(list_win) ~= list_bufnr
  then
    return nil
  end
  return list_win
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
  local entry = vim.iter(views.anchored()):find(function(view)
    return view.id == id
  end)
  if not entry then
    notify.warn("This comment has no source location; use :Comment to edit it")
    return
  end
  if not window.close() then
    notify.warn("Save or discard the comment first")
    return
  end
  local qf_win = vim.api.nvim_get_current_win()
  local ok = pcall(function()
    vim.cmd(index .. "cc")
  end)
  if not ok or vim.api.nvim_buf_get_name(0) ~= comment.source_name then
    notify.warn("Could not open the comment source")
    return
  end
  local bufnr, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  local expected_id = list_id
  local function return_to_manager()
    if vim.api.nvim_win_is_valid(qf_win) and vim.fn.getqflist({ id = 0 }).id == expected_id then
      vim.api.nvim_set_current_win(qf_win)
      refresh(id, index, expected_id)
    end
  end
  -- Loading a parked source can reveal that its saved location is gone.
  if vim.iter(views.orphans()):find(function(orphan)
    return orphan.id == id
  end) then
    return_to_manager()
    notify.warn("This comment no longer has a location; use :Comment to edit it")
    return
  end
  local function position()
    if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= bufnr then
      return true
    end
    if vim.api.nvim_get_current_win() ~= win then
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
      return_to_manager()
      notify.warn("This comment no longer has a location; use :Comment to edit it")
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
  -- A delayed read must not reposition a source the user has left and
  -- returned to in the meantime.
  vim.api.nvim_create_autocmd("WinLeave", {
    once = true,
    callback = function()
      if pending_jump[bufnr] == position then
        pending_jump[bufnr] = nil
      end
    end,
  })
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
  local qf_win = manager_window(expected_id)
  if not qf_win then
    return
  end
  local anchored, orphans = filtered(active_filter)
  local items = quickfix.items(anchored, orphans)
  vim.fn.setqflist({}, "r", { title = "Comments", items = items })
  if #items == 0 then
    vim.api.nvim_win_call(qf_win, function()
      vim.cmd.cclose()
    end)
    list_id, list_bufnr, list_win = nil, nil, nil
    return
  end
  local row = math.min(index, #items)
  for i, item in ipairs(items) do
    if item.user_data.scratch_comments_id == id then
      row = i
      break
    end
  end
  vim.api.nvim_win_set_cursor(qf_win, { row, 0 })
end

-- A card opened from a source window may also change a visible manager list.
---@param id? string
function M.refresh_comment(id)
  local qf_win = manager_window(list_id)
  if not qf_win then
    return
  end
  local row = vim.api.nvim_win_get_cursor(qf_win)[1]
  local item = vim.fn.getqflist({ items = 1 }).items[row]
  local selected_id = item and item.user_data and item.user_data.scratch_comments_id
  refresh(selected_id or id or "", row, list_id)
end

-- Recheck a pending navigation after reattachment, which can happen after
-- the last on_lines notification from an asynchronous source.
---@param bufnr integer
function M.source_updated(bufnr)
  M.refresh_comment()
  local position = pending_jump[bufnr]
  if position then
    vim.schedule(function()
      if pending_jump[bufnr] == position and position() then
        pending_jump[bufnr] = nil
      end
    end)
  end
end

-- Open the card for the cursor row without jumping to its source.
---@return boolean handled true if this is our quickfix list
function M.edit_selected()
  local index, id = selected()
  if not index then
    return false
  end
  if not id or not by_id(id) then
    notify.warn("This comment is gone")
    return true
  end
  local entry = vim.iter(views.anchored()):find(function(view)
    return view.id == id
  end) or vim.iter(views.orphans()):find(function(view)
    return view.id == id
  end)
  if not entry then
    notify.warn("This comment is gone")
    return true
  end
  if not window.close() then
    notify.warn("Save or discard the comment first")
    return true
  end
  local qf_win = vim.api.nvim_get_current_win()
  local tab = vim.api.nvim_get_current_tabpage()
  local expected_id = list_id
  local parent_win
  actions.show(entry, qf_win, function()
    vim.schedule(function()
      local focused = vim.api.nvim_get_current_win()
      if
        vim.api.nvim_get_current_tabpage() == tab
        and (focused == parent_win or focused == qf_win)
        and manager_window(expected_id) == qf_win
      then
        vim.api.nvim_set_current_win(qf_win)
      end
    end)
  end, function()
    refresh(id, index, expected_id)
  end)
  local open = window.current()
  if open and open.id == id then
    parent_win = vim.api.nvim_win_get_config(open.comment_win).win
  end
  return true
end

-- From our quickfix list, use the cursor row (not the last-jumped quickfix
-- index). Elsewhere, an open card identifies the comment to delete.
function M.delete_selected()
  local open = window.current()
  local index, selected_id = selected()
  if vim.bo.buftype == "quickfix" and not index then
    notify.warn("Not a Scratch Comments list")
    return
  end
  local id
  if index then
    id = selected_id
  else
    id = open and open.id
  end
  if not id then
    notify.warn(index and "This comment is gone" or "No comment card open")
    return
  end
  if open and open.id == id and vim.bo[vim.api.nvim_win_get_buf(open.comment_win)].modified then
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
  if open and open.id == id then
    if index then
      -- A command run from the list should leave focus there.
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
    local qf_win = manager_window(list_id)
    if qf_win then
      vim.fn.setqflist({}, "r", { items = {} })
      vim.api.nvim_win_call(qf_win, function()
        vim.cmd.cclose()
      end)
    end
    list_id, list_bufnr, list_win = nil, nil, nil
    notify.info("No comments")
    return false
  end
  list_id = quickfix.list(anchored, orphans)
  if not list_id then
    return
  end
  list_bufnr = vim.api.nvim_get_current_buf()
  list_win = vim.api.nvim_get_current_win()
  vim.keymap.set("n", "<CR>", jump, { buffer = list_bufnr, desc = "Jump to comment source" })
  vim.keymap.set("n", "<Esc>", escape, { buffer = list_bufnr, desc = "Dismiss comment card" })
  return true
end

return M
