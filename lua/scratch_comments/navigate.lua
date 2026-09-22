local annotate = require("scratch_comments.annotate")
local notify = require("scratch_comments.ui.notify")
local views = require("scratch_comments.model.views")
local window = require("scratch_comments.ui.window")

local M = {}

---@param current ScratchCommentWindow
---@param direction 1|-1
local function cycle(current, direction)
  if vim.bo[vim.api.nvim_win_get_buf(current.comment_win)].modified then
    notify.warn("Save or discard the comment first")
    return
  end
  local in_file = views.in_buffer(current.bufnr)
  if #in_file == 0 then
    return
  end

  local index = views.index_of(in_file, current.id)
  local target
  if index then
    target = in_file[(index - 1 + direction) % #in_file + 1]
  elseif direction == 1 then
    target = vim.iter(in_file):find(function(view)
      return view.start_line > current.line
    end) or in_file[1]
  else
    target = vim.iter(in_file):rev():find(function(view)
      return view.start_line < current.line
    end) or in_file[#in_file]
  end

  vim.api.nvim_win_close(current.comment_win, true)
  if vim.api.nvim_win_is_valid(current.source_win) then
    vim.api.nvim_win_call(current.source_win, function()
      vim.cmd("normal! m'")
      vim.api.nvim_win_set_cursor(0, { target.start_line, target.start_col or 0 })
    end)
  end
  annotate.show(target, current.source_win)
end

---@param direction 1|-1
local function move_cursor(direction)
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local starts = {}
  for _, view in ipairs(views.in_buffer(bufnr)) do
    starts[view.start_line] = true
  end
  local lines = vim.tbl_keys(starts)
  if #lines == 0 then
    notify.info("No comments in this buffer")
    return
  end
  table.sort(lines)

  local target
  if direction == 1 then
    for _, start_line in ipairs(lines) do
      if start_line > line then
        target = start_line
        break
      end
    end
    target = target or lines[1]
  else
    for i = #lines, 1, -1 do
      if lines[i] < line then
        target = lines[i]
        break
      end
    end
    target = target or lines[#lines]
  end

  vim.cmd("normal! m'")
  vim.api.nvim_win_set_cursor(0, { target, 0 })
end

---@param direction 1|-1
function M.jump(direction)
  local current = window.current()
  if current then
    cycle(current, direction)
  else
    move_cursor(direction)
  end
end

return M
