local M = {}

local group = "ScratchCommentBackdrop"

vim.api.nvim_set_hl(0, group, { bg = "#000000", default = true })

-- Dims the editor behind the comment window. Blending needs true colors, so
-- without them there is nothing to dim with.
---@param lines? integer rows to cover, from the top (default: the editor's)
---@return integer? win
function M.open(lines)
  if not vim.o.termguicolors then
    return nil
  end
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = "wipe"
  local win = vim.api.nvim_open_win(bufnr, false, {
    relative = "editor",
    row = 0,
    col = 0,
    width = vim.o.columns,
    height = lines or vim.o.lines,
    focusable = false,
    style = "minimal",
    -- Below the comment window, which opens at the default 50.
    zindex = 40,
  })
  vim.w[win].scratch_comments_backdrop = true
  -- Past the end of its empty buffer the window draws EndOfBuffer, which
  -- would leave the first row a different shade from the rest.
  vim.wo[win].winhighlight = ("NormalFloat:%s,EndOfBuffer:%s"):format(group, group)
  vim.wo[win].winblend = 60
  return win
end

---@param win? integer
---@param lines? integer
function M.resize(win, lines)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_config(win, {
      relative = "editor",
      row = 0,
      col = 0,
      width = vim.o.columns,
      height = lines or vim.o.lines,
    })
  end
end

---@param win? integer
function M.close(win)
  if win then
    pcall(vim.api.nvim_win_close, win, true)
  end
end

return M
