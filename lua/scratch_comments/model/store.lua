local M = {}

---@class ScratchComment
---@field id string
---@field bufnr? integer
---@field extmark_id? integer
---@field source_name string
---@field last_location ScratchLocation
---@field snippet string
---@field state? "parked"|"inactive" nil while attached
---@field comment string
---@field file_path string
---@field relative_path string
---@field charwise? boolean

---@type ScratchComment[]
local comments = {}
local next_id = 1

---@param fields { bufnr: integer, comment: string, file_path: string, relative_path: string, source_name?: string, last_location?: ScratchLocation, snippet?: string, charwise?: boolean }
---@return ScratchComment
function M.add(fields)
  local comment = {
    id = "comment-" .. next_id,
    bufnr = fields.bufnr,
    source_name = fields.source_name or fields.file_path,
    last_location = fields.last_location or { start_line = 1, end_line = 1 },
    snippet = fields.snippet or "",
    comment = fields.comment,
    file_path = fields.file_path,
    relative_path = fields.relative_path,
    charwise = fields.charwise,
  }
  next_id = next_id + 1
  table.insert(comments, comment)
  return comment
end

---@param id string
---@param fields table
---@return ScratchComment?
function M.update(id, fields)
  for _, comment in ipairs(comments) do
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
  return comments
end

---@param bufnr integer
---@return ScratchComment[]
function M.in_buffer(bufnr)
  return vim.tbl_filter(function(comment)
    return comment.bufnr == bufnr
  end, comments)
end

---@param predicate fun(comment: ScratchComment): boolean
---@return ScratchComment[] removed
function M.remove(predicate)
  local kept, removed = {}, {}
  for _, comment in ipairs(comments) do
    table.insert(predicate(comment) and removed or kept, comment)
  end
  comments = kept
  return removed
end

function M.clear()
  comments = {}
end

return M
