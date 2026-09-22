local M = {}

local namespace = vim.api.nvim_create_namespace("scratch_comments")

---@param comment ScratchComment
---@param start_line integer
---@param end_line integer
---@param start_col? integer
---@param end_col? integer
function M.anchor(comment, start_line, end_line, start_col, end_col)
  local opts = { invalidate = true }
  if start_col then
    opts.end_row, opts.end_col = end_line - 1, end_col
  else
    -- Ending at the start of the next line includes the line breaks, so
    -- rewriting a line's text keeps the mark and only deleting the lines
    -- invalidates it.
    opts.end_row, opts.end_col = end_line, 0
  end
  comment.extmark_id =
    vim.api.nvim_buf_set_extmark(comment.bufnr, namespace, start_line - 1, start_col or 0, opts)
end

---@param comment ScratchComment
---@return integer? row
---@return integer? col
---@return vim.api.keyset.extmark_details? details
local function get_mark(comment)
  if not comment.extmark_id or not vim.api.nvim_buf_is_valid(comment.bufnr) then
    return nil, nil, nil
  end
  local mark = vim.api.nvim_buf_get_extmark_by_id(
    comment.bufnr,
    namespace,
    comment.extmark_id,
    { details = true }
  )
  return mark[1], mark[2], mark[3]
end

---@param comment ScratchComment
---@return integer? start_line
---@return integer? end_line
---@return integer? start_col
---@return integer? end_col
function M.range(comment)
  local row, col, details = get_mark(comment)
  if not row or not details or details.invalid then
    return nil, nil, nil, nil
  end
  if comment.charwise then
    return row + 1, details.end_row + 1, col, details.end_col
  end
  -- end_row is the line after the range: as a 0-based row it is the range's
  -- last line numbered from 1.
  return row + 1, details.end_row
end

---@param comment ScratchComment
---@return boolean
function M.is_orphaned(comment)
  local _, _, details = get_mark(comment)
  return details ~= nil and details.invalid == true
end

---@param comment ScratchComment
local function clear(comment)
  if
    comment
    and comment.extmark_id
    and comment.bufnr
    and vim.api.nvim_buf_is_valid(comment.bufnr)
  then
    pcall(vim.api.nvim_buf_del_extmark, comment.bufnr, namespace, comment.extmark_id)
  end
end

---@param comments ScratchComment[]
function M.clear_all(comments)
  for _, comment in ipairs(comments) do
    clear(comment)
  end
end

---@param bufnr integer
function M.clear_buffer(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  end
end

return M
