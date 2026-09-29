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
  -- cursor. Wait for its content change, then use the reattached location.
  local done = false
  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function()
      if done then
        return true
      end
      vim.schedule(function()
        if not done and position() then
          done = true
        end
      end)
    end,
  })
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
  local anchored, orphans = views.anchored(), views.orphans()
  if active_filter and active_filter ~= "" then
    anchored, orphans = matching(anchored, active_filter), matching(orphans, active_filter)
  end
  if #anchored + #orphans == 0 then
    preview.close()
    vim.fn.setqflist({}, "r", { items = {} })
    vim.cmd.cclose()
    notify.info("No comments left in the list")
    return
  end
  M.open(active_filter)
  vim.api.nvim_win_set_cursor(0, { math.min(index, #anchored + #orphans), 0 })
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = 0 })
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
  local anchored, orphans = views.anchored(), views.orphans()
  if filter and filter ~= "" then
    anchored, orphans = matching(anchored, filter), matching(orphans, filter)
  end
  local listed = {}
  for _, entry in ipairs(anchored) do
    listed[entry.id] = entry
  end
  for _, entry in ipairs(orphans) do
    listed[entry.id] = entry
  end
  list_id = quickfix.list(anchored, orphans, function(index)
    local qf = vim.fn.getqflist({ items = 1 })
    local data = index and qf.items[index] and qf.items[index].user_data
    local entry = data and listed[data.scratch_comments_id]
    if not entry then
      preview.close()
    elseif entry.start_line then
      preview.show(card.of(entry))
    else
      preview.show(card.of_orphan(entry))
    end
  end)
  if not list_id then
    return
  end
  list_bufnr = vim.api.nvim_get_current_buf()
  vim.keymap.set("n", "<CR>", jump, { buffer = list_bufnr, desc = "Jump to comment" })
  vim.keymap.set("n", "d", delete_selected, { buffer = list_bufnr, desc = "Delete comment" })
end

return M
