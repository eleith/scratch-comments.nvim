local frame = require("scratch_comments.ui.frame")

local M = {}

---@type integer[] the panes of the open preview
local current = {}

---@type ScratchFrame? what the open preview shows
local showing

function M.close()
  for _, win in ipairs(current) do
    pcall(vim.api.nvim_win_close, win, true)
  end
  current = {}
  showing = nil
end

-- A card beside whatever you are browsing: no focus, no editing.
---@param spec ScratchFrame
function M.show(spec)
  local browsing = vim.api.nvim_get_current_win()
  M.close()
  spec.enter = false
  -- Fit above the window being browsed, so the card does not cover it, and
  -- dim only that area so the window stays readable.
  local above = vim.fn.win_screenpos(browsing)[1] - 1
  spec.lines = above >= 10 and above or nil
  spec.backdrop = spec.lines ~= nil
  local panes = frame.open(spec)
  vim.bo[panes.comment_buf].modifiable = false
  current = { panes.comment_win, panes.context_win, panes.backdrop_win }
  showing = spec

  -- The window being browsed moves when the editor resizes, so measure again.
  local group = vim.api.nvim_create_augroup("scratch_comments_preview", { clear = true })
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      if not showing then
        return true
      end
      vim.api.nvim_win_call(browsing, function()
        M.show(showing)
      end)
    end,
  })
end

return M
