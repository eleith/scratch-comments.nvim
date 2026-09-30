local frame = require("scratch_comments.ui.frame")
local backdrop = require("scratch_comments.ui.backdrop")

local M = {}

---@type ScratchFramePanes? the panes of the open preview
local current

---@type ScratchFrame? what the open preview shows
local showing

---@type string? ID displayed in the passive card
local showing_id

function M.close()
  local panes = current
  current, showing, showing_id = nil, nil, nil
  pcall(vim.api.nvim_del_augroup_by_name, "scratch_comments_preview")
  if panes then
    pcall(vim.api.nvim_win_close, panes.comment_win, true)
    pcall(vim.api.nvim_win_close, panes.context_win, true)
    backdrop.close(panes.backdrop_win)
  end
end

---@return boolean
function M.is_open()
  return current ~= nil and vim.api.nvim_win_is_valid(current.comment_win)
end

---@return string?
function M.current_id()
  return M.is_open() and showing_id or nil
end

-- Transfer the visible card to the editor; BufLeave must no longer dismiss it.
---@return ScratchFramePanes?
function M.take()
  local panes = current
  if panes and showing then
    panes.lines = showing.lines
    panes.backdrop = showing.backdrop
  end
  current, showing, showing_id = nil, nil, nil
  pcall(vim.api.nvim_del_augroup_by_name, "scratch_comments_preview")
  if panes and vim.api.nvim_win_is_valid(panes.comment_win) then
    return panes
  end
end

-- A card beside whatever you are browsing: no focus, no editing.
---@param spec ScratchFrame
---@param id? string displayed comment ID
function M.show(spec, id)
  local browsing = vim.api.nvim_get_current_win()
  spec.enter = false
  -- Fit above the window being browsed, so the card does not cover it, and
  -- dim only that area so the window stays readable.
  local above = vim.fn.win_screenpos(browsing)[1] - 1
  spec.lines = above >= 10 and above or nil
  spec.backdrop = spec.lines ~= nil
  if current and M.is_open() then
    current.update(spec)
  else
    M.close()
    current = frame.open(spec)
    vim.bo[current.comment_buf].modifiable = false
  end
  showing, showing_id = spec, id

  -- The window being browsed moves when the editor resizes, so measure again.
  local group = vim.api.nvim_create_augroup("scratch_comments_preview", { clear = true })
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      if not showing then
        return true
      end
      vim.api.nvim_win_call(browsing, function()
        M.show(showing, showing_id)
      end)
    end,
  })
end

return M
