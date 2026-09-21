local M = {}

local namespace = vim.api.nvim_create_namespace("scratch_comments")

local config = {
  sign_text = "C>",
  sign_hl_group = "ScratchCommentSign",
  virtual_text_prefix = " ",
  virtual_text_hl_group = "ScratchCommentVirtual",
  virtual_text_pos = "eol",
  max_comment_length = 80,
  priority = 120,
}

local function short_comment(text)
  local value = (text or ""):gsub("%s+", " ")
  local max_length = config.max_comment_length or 80
  if max_length > 3 and #value > max_length then
    return value:sub(1, max_length - 3) .. "..."
  end
  return value
end

---@param opts? ScratchDisplayConfig
function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
  vim.api.nvim_set_hl(0, "ScratchCommentSign", { link = "DiagnosticInfo", default = true })
  vim.api.nvim_set_hl(0, "ScratchCommentVirtual", { link = "Comment", default = true })
end

---Anchor a comment to a line range, or move its existing mark there. The mark
---spans the whole range, so Neovim moves it with edits above and grows or
---shrinks it with edits inside.
---
---It ends at the start of the line after the range, so it includes the line
---breaks: rewriting a line's text keeps the comment, and only deleting the
---lines themselves orphans it (`invalidate` hides the mark, undo restores it).
---@param comment ScratchComment
---@param start_line integer 1-based, inclusive.
---@param end_line integer 1-based, inclusive.
function M.place(comment, start_line, end_line)
  comment.extmark_id = vim.api.nvim_buf_set_extmark(comment.bufnr, namespace, start_line - 1, 0, {
    id = comment.extmark_id,
    end_row = end_line,
    end_col = 0,
    invalidate = true,
    sign_text = config.sign_text,
    sign_hl_group = config.sign_hl_group,
    virt_text = {
      {
        (config.virtual_text_prefix or "") .. short_comment(comment.comment),
        config.virtual_text_hl_group,
      },
    },
    virt_text_pos = config.virtual_text_pos,
    priority = config.priority,
  })
end

---@param comment ScratchComment
---@return integer? row 0-based start row; nil when the mark is gone.
---@return vim.api.keyset.extmark_details? details
local function get_mark(comment)
  if not comment.extmark_id or not vim.api.nvim_buf_is_valid(comment.bufnr) then
    return nil, nil
  end
  local mark = vim.api.nvim_buf_get_extmark_by_id(
    comment.bufnr,
    namespace,
    comment.extmark_id,
    { details = true }
  )
  return mark[1], mark[3]
end

---The lines a comment covers now.
---@param comment ScratchComment
---@return integer? start_line 1-based, inclusive; nil when orphaned or the mark is gone.
---@return integer? end_line 1-based, inclusive.
function M.range(comment)
  local row, details = get_mark(comment)
  if not row or not details or details.invalid then
    return nil, nil
  end
  -- The mark ends at the start of the line after the range.
  return row + 1, details.end_row
end

---Whether every line a comment covered has been deleted.
---@param comment ScratchComment
---@return boolean
function M.is_orphaned(comment)
  local _, details = get_mark(comment)
  return details ~= nil and details.invalid == true
end

---@param comment ScratchComment
function M.clear(comment)
  if
    comment
    and comment.extmark_id
    and comment.bufnr
    and vim.api.nvim_buf_is_valid(comment.bufnr)
  then
    pcall(vim.api.nvim_buf_del_extmark, comment.bufnr, namespace, comment.extmark_id)
  end
end

---@param items ScratchComment[]
function M.clear_all(items)
  for _, comment in ipairs(items) do
    M.clear(comment)
  end
end

---@param bufnr integer
function M.clear_buffer(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  end
end

return M
