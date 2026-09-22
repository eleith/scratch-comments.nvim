local frame = require("scratch_comments.ui.frame")
local notify = require("scratch_comments.ui.notify")

local M = {}

local mode_names = {
  n = "NORMAL",
  i = "INSERT",
  v = "VISUAL",
  V = "VISUAL",
  ["\22"] = "VISUAL",
  c = "COMMAND",
  R = "REPLACE",
}

---@class ScratchCommentWindow
---@field id? string unset until a new comment is saved
---@field bufnr integer
---@field line integer
---@field source_win integer
---@field comment_win? integer

---@type ScratchCommentWindow?
local current

---@param spec ScratchFrame
---@param window ScratchCommentWindow
function M.open(spec, window)
  spec.on_close = function()
    if current and current.comment_win == window.comment_win then
      current = nil
    end
  end
  local panes = frame.open(spec)
  local comment_win, comment_buf = panes.comment_win, panes.comment_buf
  window.comment_win = comment_win
  current = window

  local function show_mode()
    if vim.api.nvim_win_is_valid(comment_win) then
      local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
      local name = mode_names[mode] or "NORMAL"
      vim.api.nvim_win_set_config(comment_win, {
        title = " " .. (spec.comment_title or "comment") .. " [" .. name .. "] ",
        title_pos = "center",
      })
      vim.cmd.redraw()
    end
  end
  show_mode()
  vim.api.nvim_create_autocmd("ModeChanged", { buffer = comment_buf, callback = show_mode })

  for _, buf in ipairs({ comment_buf, panes.context_buf }) do
    vim.keymap.set("n", "<Esc>", function()
      if vim.bo[comment_buf].modified then
        notify.warn("Save with :w, or discard with :q!")
        return
      end
      pcall(vim.api.nvim_win_close, comment_win, true)
    end, { buffer = buf, desc = "Close the comment window" })
  end

  vim.bo[comment_buf].buftype = "acwrite"
  vim.api.nvim_buf_set_name(comment_buf, "scratch-comments://" .. comment_buf)
  if spec.comment == "" then
    vim.cmd.startinsert()
  end
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = comment_buf,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(comment_buf, 0, -1, false)
      local text = vim.trim(table.concat(lines, "\n"))
      if text ~= "" and spec.on_save then
        spec.on_save(text)
      end
      vim.bo[comment_buf].modified = false
    end,
  })
end

---@return ScratchCommentWindow? window the open comment window, if any
function M.current()
  if current and vim.api.nvim_win_is_valid(current.comment_win) then
    return current
  end
end

return M
