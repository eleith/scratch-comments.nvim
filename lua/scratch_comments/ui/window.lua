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
---@field bufnr? integer
---@field source_name? string
---@field line integer
---@field source_win integer
---@field comment_win? integer
---@field on_close? fun()
---@field on_saved? fun()

---@type ScratchCommentWindow?
local current

-- A quickfix row with no source location still edits in the file area, while
-- closing its card returns focus to the list.
---@param record ScratchCommentWindow
---@return integer?
local function editing_window(record)
  local source = record.source_win
  if
    vim.api.nvim_win_is_valid(source)
    and vim.bo[vim.api.nvim_win_get_buf(source)].buftype ~= "quickfix"
  then
    return source
  end
  local file_win, other_win
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      local bufnr = vim.api.nvim_win_get_buf(win)
      if record.source_name and vim.api.nvim_buf_get_name(bufnr) == record.source_name then
        return win
      end
      if vim.bo[bufnr].buftype == "" then
        file_win = file_win or win
      elseif vim.bo[bufnr].buftype ~= "quickfix" then
        other_win = other_win or win
      end
    end
  end
  if file_win or other_win then
    return file_win or other_win
  end
  -- Quickfix cannot provide a source area on its own. Make one if there is
  -- room; otherwise keep the list usable rather than drawing over it.
  if not pcall(function()
    vim.cmd("aboveleft new")
  end) then
    notify.warn("Make room for an editing window to open this comment")
    return nil
  end
  return vim.api.nvim_get_current_win()
end

---@param spec ScratchFrame
---@param record ScratchCommentWindow
function M.open(spec, record)
  spec.on_close = function()
    if current and current.comment_win == record.comment_win then
      current = nil
    end
    if record.on_close then
      record.on_close()
    end
  end
  local source_buffer_name = record.source_name
    or (record.bufnr and vim.api.nvim_buf_get_name(record.bufnr))
    or "comment"
  local source_name = vim.fn.fnamemodify(source_buffer_name, ":t")
  spec.comment_name = source_name .. ":" .. record.line .. " [comment]"
  local parent = editing_window(record)
  if not parent then
    return
  end
  local panes = frame.open(spec, parent)
  local comment_win, comment_buf = panes.comment_win, panes.comment_buf
  record.comment_win = comment_win
  current = record

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
  if spec.comment == "" then
    vim.cmd.startinsert()
  end
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = comment_buf,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(comment_buf, 0, -1, false)
      local text = vim.trim(table.concat(lines, "\n"))
      local result = spec.on_save and spec.on_save(text)
      if result == false then
        return
      end
      vim.bo[comment_buf].modified = false
      if record.on_saved then
        record.on_saved()
      end
      if result == "deleted" then
        vim.schedule(function()
          if vim.api.nvim_win_is_valid(comment_win) then
            vim.api.nvim_win_close(comment_win, true)
          end
        end)
      end
    end,
  })
end

-- Closes the open comment window, unless it has unsaved changes.
---@return boolean closed
function M.close()
  local open = M.current()
  if not open then
    return true
  end
  if vim.bo[vim.api.nvim_win_get_buf(open.comment_win)].modified then
    return false
  end
  -- A command replacing the card (e.g. :CommentExport!) owns the next focus.
  -- Only a user closing the card should return to its source or list.
  open.on_close = nil
  pcall(vim.api.nvim_win_close, open.comment_win, true)
  return true
end

---@return ScratchCommentWindow? window the open comment window, if any
function M.current()
  if current and vim.api.nvim_win_is_valid(current.comment_win) then
    return current
  end
end

return M
