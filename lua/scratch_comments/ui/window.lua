local location = require("scratch_comments.location")

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

---@param lines string[]
---@param filetype string
---@return integer bufnr
local function frame_buffer(lines, filetype)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modified = false
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].filetype = filetype
  return bufnr
end

---@class ScratchFrame
---@field title string
---@field context string[]
---@field filetype string
---@field comment string
---@field on_save fun(text: string)
---@field comment_title? string

---@param frame ScratchFrame
---@return integer comment_win
local function open_frame(frame)
  local comment_lines = vim.split(frame.comment, "\n")
  local width = math.min(80, vim.o.columns - 4)
  local context_height = math.min(#frame.context, math.floor(vim.o.lines * 0.4))
  local comment_height = math.min(math.max(#comment_lines, 5), math.floor(vim.o.lines * 0.3))
  -- Each pane has a top and a bottom border line.
  local row = math.floor((vim.o.lines - context_height - comment_height - 4) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local border = (vim.o.winborder == "" or vim.o.winborder == "none") and "rounded" or nil

  local context_buf = frame_buffer(frame.context, frame.filetype)
  vim.bo[context_buf].modifiable = false
  local context_win = vim.api.nvim_open_win(context_buf, false, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = context_height,
    border = border,
    title = " " .. location.fit(frame.title, width - 2) .. " ",
    title_pos = "center",
    style = "minimal",
  })

  local comment_buf = frame_buffer(comment_lines, "markdown")
  local comment_win = vim.api.nvim_open_win(comment_buf, true, {
    relative = "editor",
    row = row + context_height + 2,
    col = col,
    width = width,
    height = comment_height,
    border = border,
    title = " comment ",
    title_pos = "center",
    style = "minimal",
  })
  vim.wo[comment_win].wrap = true
  vim.wo[comment_win].linebreak = true
  for _, win in ipairs({ context_win, comment_win }) do
    vim.wo[win].winhighlight = "NormalFloat:Normal,LineNr:Normal"
    vim.wo[win].statuscolumn = "  "
  end

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(comment_win),
    once = true,
    callback = function()
      pcall(vim.api.nvim_win_close, context_win, true)
      if current and current.comment_win == comment_win then
        current = nil
      end
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(context_win),
    once = true,
    callback = function()
      -- Not forced, so an unsaved comment stays open instead of being lost.
      pcall(vim.api.nvim_win_close, comment_win, false)
    end,
  })

  local function show_mode()
    if vim.api.nvim_win_is_valid(comment_win) then
      local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
      local name = mode_names[mode] or "NORMAL"
      vim.api.nvim_win_set_config(comment_win, {
        title = " " .. (frame.comment_title or "comment") .. " [" .. name .. "] ",
        title_pos = "center",
      })
      vim.cmd.redraw()
    end
  end
  show_mode()
  vim.api.nvim_create_autocmd("ModeChanged", { buffer = comment_buf, callback = show_mode })

  vim.bo[comment_buf].buftype = "acwrite"
  vim.api.nvim_buf_set_name(comment_buf, "scratch-comments://" .. comment_buf)
  if frame.comment == "" then
    vim.cmd.startinsert()
  end
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = comment_buf,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(comment_buf, 0, -1, false)
      local text = vim.trim(table.concat(lines, "\n"))
      if text ~= "" then
        frame.on_save(text)
      end
      vim.bo[comment_buf].modified = false
    end,
  })
  return comment_win
end

---@param frame ScratchFrame
---@param window ScratchCommentWindow
function M.open(frame, window)
  window.comment_win = open_frame(frame)
  current = window
end

---@return ScratchCommentWindow? window the open comment window, if any
function M.current()
  if current and vim.api.nvim_win_is_valid(current.comment_win) then
    return current
  end
end

return M
