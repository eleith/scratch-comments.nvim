local frame = require("scratch_comments.ui.frame")

local M = {}

---@type integer[] the panes of the open preview
local current = {}

function M.close()
  for _, win in ipairs(current) do
    pcall(vim.api.nvim_win_close, win, true)
  end
  current = {}
end

-- A card beside whatever you are browsing: no focus, no editing, no backdrop.
---@param spec ScratchFrame
function M.show(spec)
  M.close()
  spec.enter = false
  -- Fit above the window being browsed, so the card does not cover it, and
  -- dim only that area so the window stays readable.
  local above = vim.fn.win_screenpos(0)[1] - 1
  spec.lines = above >= 10 and above or nil
  spec.backdrop = spec.lines ~= nil
  local panes = frame.open(spec)
  vim.bo[panes.comment_buf].modifiable = false
  current = { panes.comment_win, panes.context_win, panes.backdrop_win }
end

return M
