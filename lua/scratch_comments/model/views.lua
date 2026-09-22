local anchors = require("scratch_comments.model.anchors")
local store = require("scratch_comments.model.store")

local M = {}

---@class ScratchCommentView : ScratchComment, ScratchLocation
---@field snippet string

---@param id string
---@return integer
local function number(id)
  return assert(tonumber(id:match("%d+$")))
end

-- Orders views by file, then lines, then the order they were added.
---@param a ScratchCommentView
---@param b ScratchCommentView
---@return boolean
function M.by_position(a, b)
  if a.relative_path ~= b.relative_path then
    return a.relative_path < b.relative_path
  end
  if a.start_line ~= b.start_line then
    return a.start_line < b.start_line
  end
  if a.end_line ~= b.end_line then
    return a.end_line < b.end_line
  end
  return number(a.id) < number(b.id)
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
    local start_line, end_line, start_col, end_col = anchors.range(comment)
    if start_line and end_line then
      local view = vim.deepcopy(comment) --[[@as ScratchCommentView]]
      view.start_line, view.end_line = start_line, end_line
      view.start_col, view.end_col = start_col, end_col
      view.snippet =
        table.concat(M.text(comment.bufnr, start_line, end_line, start_col, end_col), "\n")
      table.insert(views, view)
    end
  end
  table.sort(views, M.by_position)
  return views
end

---@param bufnr integer
---@return ScratchCommentView[]
function M.in_buffer(bufnr)
  return vim.tbl_filter(function(view)
    return view.bufnr == bufnr
  end, M.anchored())
end

---@param list ScratchCommentView[]
---@param id? string
---@return integer?
function M.index_of(list, id)
  for i, view in ipairs(list) do
    if view.id == id then
      return i
    end
  end
end

---@return ScratchComment[]
function M.orphans()
  return vim.tbl_filter(anchors.is_orphaned, store.all())
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
