local render = require("scratch_comments.render")
local store = require("scratch_comments.model.store")

local M = {}

---@class ScratchCommentView : ScratchComment
---@field start_line integer 1-based, inclusive.
---@field end_line integer 1-based, inclusive.
---@field start_col? integer 0-based byte, for a character span.
---@field end_col? integer 0-based byte, exclusive.
---@field snippet string

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
  for _, comment in ipairs(store.all()) do
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
  return vim.tbl_filter(render.is_orphaned, store.all())
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

return M
