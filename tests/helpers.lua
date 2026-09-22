local M = {}

---@type string[]
M.notifications = {}

-- Notifications are scheduled; this runs them before reading the list.
---@return string[]
function M.notified()
  vim.wait(0)
  return M.notifications
end

---@diagnostic disable-next-line: duplicate-set-field -- record instead of printing
vim.notify = function(message)
  table.insert(M.notifications, message)
end

-- A named buffer holding lines, not backed by a file on disk.
---@param name string
---@param lines string[]
---@return integer bufnr
function M.buffer(name, lines)
  vim.cmd.enew()
  vim.cmd.file(name)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  return vim.api.nvim_get_current_buf()
end

-- Types a comment into the open comment window and saves it.
---@param text string
function M.write(text)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(text, "\n"))
  vim.cmd("wq")
end

---@return integer[]
function M.floats()
  return vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_config(win).relative ~= ""
  end, vim.api.nvim_list_wins())
end

-- The two panes of the open comment window, from inside the comment pane.
---@return integer lines_win
---@return integer comment_win
function M.panes()
  local comment_win = vim.api.nvim_get_current_win()
  local lines_win = vim.tbl_filter(function(win)
    return win ~= comment_win
  end, M.floats())[1]
  return lines_win, comment_win
end

---@param win integer
---@return string
function M.title(win)
  return vim.api.nvim_win_get_config(win).title[1][1]
end

---@param bufnr? integer
---@return string
function M.text(bufnr)
  return table.concat(vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false), "\n")
end

---@param line integer
---@return string? sign
function M.sign_at(line)
  local namespace = vim.api.nvim_get_namespaces().scratch_comments_signs
  local marks = vim.api.nvim_buf_get_extmarks(
    0,
    namespace,
    { line - 1, 0 },
    { line - 1, -1 },
    { details = true, overlap = true }
  )
  return marks[1] and vim.trim(marks[1][4].sign_text)
end

local select = vim.ui.select

---@type any[] the items the last vim.ui.select offered
M.offered = {}

---@type string[] how the last vim.ui.select showed its items
M.labels = {}

-- Answers each vim.ui.select with the next index given, then with 1. An index
-- past the items (such as 0) cancels.
---@param ... integer
function M.pick(...)
  local choices = { ... }
  ---@diagnostic disable-next-line: duplicate-set-field -- test fake
  vim.ui.select = function(items, opts, callback)
    M.offered = items
    M.labels = vim.tbl_map(opts.format_item or tostring, items)
    callback(items[table.remove(choices, 1) or 1])
  end
end

-- Headless edits share one undo block unless it is broken explicitly.
function M.undo_break()
  vim.o.undolevels = vim.o.undolevels
end

-- Neovim fires TextChanged from its main loop, which a spec never returns to.
function M.text_changed()
  vim.api.nvim_exec_autocmds("TextChanged", { buffer = 0 })
end

-- Every spec starts from one empty window with no comments.
function M.reset()
  for _, win in ipairs(M.floats()) do
    -- Closing one pane of a comment window closes the other.
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.cmd("silent! only!")
  require("scratch_comments").clear()
  require("scratch_comments").toggle(true)
  vim.cmd("silent! %bwipeout!")
  vim.ui.select = select
  M.offered = {}
  M.labels = {}
  vim.wait(0)
  M.notifications = {}
end

return M
