local actions = require("scratch_comments.actions")
local export = require("scratch_comments.export")
local list = require("scratch_comments.list")

local M = {}

---@param start_line? integer
---@param end_line? integer
function M.add(start_line, end_line)
  start_line = start_line or vim.api.nvim_win_get_cursor(0)[1]
  actions.comment(start_line, end_line or start_line)
end

M.toggle = actions.toggle
M.clear = actions.clear
M.render = export.render
M.export = export.export

M.list = list.open
M.delete = list.delete_open

-- Kept so configs that call it keep working; the commands need no setup.
function M.setup() end

return M
