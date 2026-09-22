local actions = require("scratch_comments.actions")
local export = require("scratch_comments.export")
local list = require("scratch_comments.list")
local navigate = require("scratch_comments.navigate")

local M = {}

---@param start_line? integer
---@param end_line? integer
function M.add(start_line, end_line)
  start_line = start_line or vim.api.nvim_win_get_cursor(0)[1]
  actions.comment(start_line, end_line or start_line)
end

M.show = actions.show_current
M.delete = actions.delete_current
M.toggle = actions.toggle
M.clear = actions.clear
M.render = export.render
M.export = export.export

function M.next()
  navigate.jump(1)
end

function M.prev()
  navigate.jump(-1)
end

M.list = list.open

-- Kept so configs that call it keep working; the commands need no setup.
function M.setup() end

return M
