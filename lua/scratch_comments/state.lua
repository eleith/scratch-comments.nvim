local M = {}

local items = {}
local next_id = 1

local function compare_position(a, b)
  if (a.start_line or 0) ~= (b.start_line or 0) then
    return (a.start_line or 0) < (b.start_line or 0)
  end
  if (a.end_line or 0) ~= (b.end_line or 0) then
    return (a.end_line or 0) < (b.end_line or 0)
  end
  return tostring(a.id or "") < tostring(b.id or "")
end

---@param comment ScratchComment
---@return ScratchComment
function M.add(comment)
  comment.id = comment.id or ("comment-" .. tostring(next_id))
  next_id = next_id + 1
  table.insert(items, comment)
  return comment
end

---@param predicate fun(comment: ScratchComment): boolean
---@return ScratchComment|nil
function M.find(predicate)
  local matches = M.find_all(predicate)
  return matches[1]
end

---@param predicate fun(comment: ScratchComment): boolean
---@return ScratchComment[]
function M.find_all(predicate)
  local matches = {}
  for _, comment in ipairs(items) do
    if predicate(comment) then
      table.insert(matches, comment)
    end
  end

  table.sort(matches, compare_position)
  return matches
end

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

function M.all()
  return items
end

function M.snapshot()
  return vim.deepcopy(items)
end

function M.clear()
  items = {}
end

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
