local render = require("scratch_comments.render")

local M = {}

---@class ScratchComment
---@field id string
---@field bufnr integer
---@field extmark_id? integer Set once the comment is anchored.
---@field comment string
---@field file_path string Absolute path.
---@field relative_path string Relative to the Git root, or absolute outside a repository.
---@field timestamp string UTC time the comment was made.

---A comment with its anchor read from the buffer as it is now.
---@class ScratchCommentView : ScratchComment
---@field start_line integer 1-based, inclusive.
---@field end_line integer 1-based, inclusive.
---@field snippet string The commented lines.

---@type ScratchComment[]
local items = {}
local next_id = 1

---@param a ScratchCommentView
---@param b ScratchCommentView
local function compare_position(a, b)
  if a.start_line ~= b.start_line then
    return a.start_line < b.start_line
  end
  if a.end_line ~= b.end_line then
    return a.end_line < b.end_line
  end
  return a.id < b.id
end

---@param fields { bufnr: integer, comment: string, file_path: string, relative_path: string }
---@return ScratchComment
function M.add(fields)
  local comment = {
    id = "comment-" .. next_id,
    bufnr = fields.bufnr,
    comment = fields.comment,
    file_path = fields.file_path,
    relative_path = fields.relative_path,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }
  next_id = next_id + 1
  table.insert(items, comment)
  return comment
end

---Every anchored comment with its line range and text read from the buffer
---now, so positions follow edits. Orphans are not included: see M.orphans.
---@return ScratchCommentView[]
function M.snapshot()
  local views = {}
  for _, comment in ipairs(items) do
    local start_line, end_line = render.range(comment)
    -- No range: the comment is orphaned, or its buffer was unloaded.
    if start_line and end_line then
      local view = vim.deepcopy(comment) --[[@as ScratchCommentView]]
      view.start_line = start_line
      view.end_line = end_line
      view.snippet = table.concat(
        vim.api.nvim_buf_get_lines(comment.bufnr, start_line - 1, end_line, false),
        "\n"
      )
      table.insert(views, view)
    end
  end
  return views
end

---Comments whose lines have all been deleted. They are kept, not dropped:
---undo restores them, and exports list them separately.
---@return ScratchComment[]
function M.orphans()
  return vim.tbl_filter(render.is_orphaned, items)
end

---@param predicate fun(comment: ScratchCommentView): boolean
---@return ScratchCommentView[] matches Ordered by position.
function M.find_all(predicate)
  local matches = vim.tbl_filter(predicate, M.snapshot())
  table.sort(matches, compare_position)
  return matches
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
