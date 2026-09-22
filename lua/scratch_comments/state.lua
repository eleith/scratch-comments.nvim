local render = require("scratch_comments.render")

local M = {}

---@class ScratchComment
---@field id string
---@field bufnr integer
---@field extmark_id? integer
---@field comment string
---@field file_path string
---@field relative_path string
---@field charwise? boolean

---@class ScratchCommentView : ScratchComment
---@field start_line integer 1-based, inclusive.
---@field end_line integer 1-based, inclusive.
---@field start_col? integer 0-based byte, for a character span.
---@field end_col? integer 0-based byte, exclusive.
---@field snippet string

---@type ScratchComment[]
local items = {}
local next_id = 1

---@param a ScratchCommentView
---@param b ScratchCommentView
local function by_position(a, b)
  if a.relative_path ~= b.relative_path then
    return a.relative_path < b.relative_path
  end
  if a.start_line ~= b.start_line then
    return a.start_line < b.start_line
  end
  if a.end_line ~= b.end_line then
    return a.end_line < b.end_line
  end
  return a.id < b.id
end

---@param fields { bufnr: integer, comment: string, file_path: string, relative_path: string, charwise?: boolean }
---@return ScratchComment
function M.add(fields)
  local comment = {
    id = "comment-" .. next_id,
    bufnr = fields.bufnr,
    comment = fields.comment,
    file_path = fields.file_path,
    relative_path = fields.relative_path,
    charwise = fields.charwise,
  }
  next_id = next_id + 1
  table.insert(items, comment)
  return comment
end

---@param bufnr integer
---@param start_line integer
---@param end_line integer
---@param start_col? integer
---@param end_col? integer
---@return string[]
function M.text(bufnr, start_line, end_line, start_col, end_col)
  if start_col and end_col then
    return vim.api.nvim_buf_get_text(bufnr, start_line - 1, start_col, end_line - 1, end_col, {})
  end
  return vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
end

---@return ScratchCommentView[]
function M.anchored()
  local views = {}
  for _, comment in ipairs(items) do
    local start_line, end_line, start_col, end_col = render.range(comment)
    if start_line and end_line then
      local view = vim.deepcopy(comment) --[[@as ScratchCommentView]]
      view.start_line, view.end_line = start_line, end_line
      view.start_col, view.end_col = start_col, end_col
      view.snippet =
        table.concat(M.text(comment.bufnr, start_line, end_line, start_col, end_col), "\n")
      table.insert(views, view)
    end
  end
  table.sort(views, by_position)
  return views
end

---@return ScratchComment[]
function M.orphans()
  return vim.tbl_filter(render.is_orphaned, items)
end

---@param predicate fun(comment: ScratchCommentView): boolean
---@return ScratchCommentView[]
function M.find_all(predicate)
  return vim.tbl_filter(predicate, M.anchored())
end

---@param predicate fun(comment: ScratchCommentView): boolean
---@return ScratchCommentView?
function M.find(predicate)
  return M.find_all(predicate)[1]
end

---@param id string
---@param fields table
---@return ScratchComment?
function M.update(id, fields)
  for _, comment in ipairs(items) do
    if comment.id == id then
      for key, value in pairs(fields) do
        comment[key] = value
      end
      return comment
    end
  end
  return nil
end

---@return ScratchComment[]
function M.all()
  return items
end

---@param bufnr integer
---@return ScratchComment[]
function M.in_buffer(bufnr)
  return vim.tbl_filter(function(comment)
    return comment.bufnr == bufnr
  end, items)
end

function M.clear()
  items = {}
end

---@param ids string[]
---@return ScratchComment[] removed
function M.remove_ids(ids)
  local idset = {}
  for _, id in ipairs(ids) do
    idset[id] = true
  end

  local kept = {}
  local removed = {}
  for _, comment in ipairs(items) do
    if idset[comment.id] then
      table.insert(removed, comment)
    else
      table.insert(kept, comment)
    end
  end

  items = kept
  return removed
end

---@param bufnr integer
---@return ScratchComment[] removed
function M.remove_buffer(bufnr)
  local kept = {}
  local removed = {}
  for _, comment in ipairs(items) do
    if comment.bufnr == bufnr then
      table.insert(removed, comment)
    else
      table.insert(kept, comment)
    end
  end
  items = kept
  return removed
end

return M
