local M = {}

---@type string[]
M.notifications = {}

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

---@param bufnr? integer
---@return string
function M.text(bufnr)
  return table.concat(vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false), "\n")
end

-- Every spec starts from one empty window with no comments.
function M.reset()
  for _, win in ipairs(M.floats()) do
    vim.api.nvim_win_close(win, true)
  end
  vim.cmd("silent! only!")
  require("scratch_comments").clear()
  vim.cmd("silent! %bwipeout!")
  M.notifications = {}
end

return M
