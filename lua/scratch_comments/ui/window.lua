local frame = require("scratch_comments.ui.frame")
local notify = require("scratch_comments.ui.notify")
local preview = require("scratch_comments.ui.preview")

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
---@field update? fun(spec: ScratchFrame)

---@type ScratchCommentWindow?
local current

---@param spec ScratchFrame
---@param record ScratchCommentWindow
---@param panes? ScratchFramePanes existing preview panes to focus in place
function M.open(spec, record, panes)
  local promoted = panes ~= nil
  if not panes then
    preview.close()
  end
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
  if panes then
    spec.lines = panes.lines
    spec.backdrop = panes.backdrop
    panes.update(spec)
  else
    panes = frame.open(spec)
  end
  local comment_win, comment_buf = panes.comment_win, panes.comment_buf
  if promoted then
    vim.api.nvim_buf_set_name(
      comment_buf,
      "scratch-comments://" .. comment_buf .. "/" .. spec.comment_name
    )
    vim.bo[comment_buf].modifiable = true
    vim.api.nvim_set_current_win(comment_win)
  end
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
  record.update = function(next_spec)
    next_spec.on_close = spec.on_close
    next_spec.on_save = spec.on_save
    next_spec.lines = spec.lines
    next_spec.backdrop = spec.backdrop
    panes.update(next_spec, true)
    spec = next_spec
    show_mode()
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
  -- Only a user closing the card should return to its list.
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
