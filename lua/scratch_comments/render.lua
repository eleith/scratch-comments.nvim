local M = {}

local namespace = vim.api.nvim_create_namespace("scratch_comments")
local sign_namespace = vim.api.nvim_create_namespace("scratch_comments_signs")
local group = "ScratchCommentSign"
local signs = { single = "│", first = "╭", middle = "│", last = "╰" }
local visible = true

function M.setup()
  vim.api.nvim_set_hl(0, group, { link = "DiagnosticInfo", default = true })
end

---@return boolean
function M.is_visible()
  return visible
end

---@param on boolean
function M.set_visible(on)
  visible = on
end

---@param comment ScratchComment
---@param start_line integer
---@param end_line integer
function M.anchor(comment, start_line, end_line)
  comment.extmark_id = vim.api.nvim_buf_set_extmark(comment.bufnr, namespace, start_line - 1, 0, {
    -- Ending at the start of the next line includes the line breaks, so
    -- rewriting a line's text keeps the mark and only deleting the lines
    -- invalidates it.
    end_row = end_line,
    end_col = 0,
    invalidate = true,
  })
end

---@param comment ScratchComment
---@return integer? row
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

---@param comment ScratchComment
---@return integer? start_line
---@return integer? end_line
function M.range(comment)
  local row, details = get_mark(comment)
  if not row or not details or details.invalid then
    return nil, nil
  end
  -- end_row is the line after the range: as a 0-based row it is the range's
  -- last line numbered from 1.
  return row + 1, details.end_row
end

---@param comment ScratchComment
---@return boolean
function M.is_orphaned(comment)
  local _, details = get_mark(comment)
  return details ~= nil and details.invalid == true
end

---@param bufnr integer
---@param text string
---@param start_line integer
---@param end_line? integer
local function sign(bufnr, text, start_line, end_line)
  vim.api.nvim_buf_set_extmark(bufnr, sign_namespace, start_line - 1, 0, {
    end_row = (end_line or start_line) - 1,
    sign_text = text,
    sign_hl_group = group,
  })
end

-- Signs are drawn from the anchors rather than stored on them: a mark shows
-- its sign on every row it touches, and an anchor also touches the line after
-- its range.
---@param bufnr integer
---@param comments ScratchComment[]
function M.draw_signs(bufnr, comments)
  vim.api.nvim_buf_clear_namespace(bufnr, sign_namespace, 0, -1)
  if not visible then
    return
  end
  for _, comment in ipairs(comments) do
    local start_line, end_line = M.range(comment)
    if start_line and end_line then
      if start_line == end_line then
        sign(bufnr, signs.single, start_line)
      else
        sign(bufnr, signs.first, start_line)
        if end_line - start_line > 1 then
          sign(bufnr, signs.middle, start_line + 1, end_line - 1)
        end
        sign(bufnr, signs.last, end_line)
      end
    end
  end
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
    vim.api.nvim_buf_clear_namespace(bufnr, sign_namespace, 0, -1)
  end
end

return M
