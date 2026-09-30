local actions = require("scratch_comments.actions")
local card = require("scratch_comments.ui.card")
local comments = require("scratch_comments.comments")
local store = require("scratch_comments.model.store")
local preview = require("scratch_comments.ui.preview")
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
  if
    comment.state == "inactive"
    or (
      comment.state == nil
      and #vim.tbl_filter(function(c)
        return c.id == id
      end, views.orphans()) > 0
    )
  then
    notify.warn("This comment no longer has a location")
    return
  end
  local ok = pcall(function()
    vim.cmd(index .. "cc")
  end)
  if not ok then
    notify.warn("Could not open the comment source")
    return
  end
  local bufnr, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  if vim.api.nvim_buf_get_name(bufnr) ~= comment.source_name then
    return
  end
  local function position()
    if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= bufnr then
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
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = bufnr,
    once = true,
    callback = function()
      if pending_jump[bufnr] == position then
        pending_jump[bufnr] = nil
      end
    end,
  })
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
local function refresh(id, index, expected_id)
  local qf = vim.fn.getqflist({ id = 0, winid = 0 })
  if qf.id ~= expected_id or qf.winid == 0 then
    return
  end
  local anchored, orphans = filtered(active_filter)
  local items = quickfix.items(anchored, orphans)
  vim.fn.setqflist({}, "r", { title = "Comments", items = items })
  if #items == 0 then
    preview.close()
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

local function edit_selected()
  local index, id = selected()
  if not index or not id or not by_id(id) then
    notify.warn("This comment is gone")
    return
  end
  local expected_id = list_id
  actions.show_by_id(id, function()
    vim.schedule(function()
      local qf = vim.fn.getqflist({ id = 0, winid = 0 })
      if qf.id == expected_id and qf.winid ~= 0 and vim.api.nvim_win_is_valid(qf.winid) then
        vim.api.nvim_set_current_win(qf.winid)
      end
    end)
  end, function()
    refresh(id, index, expected_id)
  end)
end

local function delete_selected()
  local index, id = selected()
  if not index then
    notify.warn("Not a Scratch Comments list")
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
  comments.delete(comment)
  local anchored, orphans = filtered(active_filter)
  if M.open(active_filter) then
    vim.api.nvim_win_set_cursor(0, { math.min(index, #anchored + #orphans), 0 })
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = 0 })
  end
end

-- Every comment in the quickfix list, with the one under the cursor shown
-- in a card above it.
---@param filter? string only comments matching this
function M.open(filter)
  if not window.close() then
    notify.warn("Save or discard the comment first")
    return
  end
  active_filter = filter
  local anchored, orphans = filtered(filter)
  if #anchored + #orphans == 0 then
    if list_id and vim.fn.getqflist({ id = 0 }).id == list_id then
      preview.close()
      vim.fn.setqflist({}, "r", { items = {} })
      vim.cmd.cclose()
    end
    list_id, list_bufnr = nil, nil
    notify.info("No comments")
    return false
  end
  list_id = quickfix.list(anchored, orphans, function(index)
    local qf = vim.fn.getqflist({ items = 1 })
    local data = index and qf.items[index] and qf.items[index].user_data
    local id = data and data.scratch_comments_id
    local entry = id
      and vim.iter(views.anchored()):find(function(view)
        return view.id == id
      end)
    if entry then
      preview.show(card.of(entry))
    else
      local orphan = id
        and vim.iter(views.orphans()):find(function(comment)
          return comment.id == id
        end)
      if orphan then
        preview.show(card.of_orphan(orphan))
      else
        preview.close()
      end
    end
  end)
  if not list_id then
    return
  end
  list_bufnr = vim.api.nvim_get_current_buf()
  vim.keymap.set("n", "<CR>", jump, { buffer = list_bufnr, desc = "Jump to comment" })
  vim.keymap.set("n", "d", delete_selected, { buffer = list_bufnr, desc = "Delete comment" })
  vim.keymap.set("n", "e", edit_selected, { buffer = list_bufnr, desc = "Edit comment" })
  return true
end

return M
