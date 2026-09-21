local M = {}

local function extension(path)
  return (path or ""):match("%.([^%.]+)$") or ""
end

local function fence_for(text)
  if (text or ""):find("```", 1, true) then
    return "````"
  end
  return "```"
end

local function line_range(comment)
  if comment.start_line == comment.end_line then
    return "line " .. comment.start_line
  end
  return "lines " .. comment.start_line .. "-" .. comment.end_line
end

local function sorted(items)
  table.sort(items, function(a, b)
    local a_path = a.relative_path or a.file_path
    local b_path = b.relative_path or b.file_path
    if a_path == b_path then
      if a.start_line == b.start_line then
        if a.end_line == b.end_line then
          return tostring(a.id or "") < tostring(b.id or "")
        end
        return a.end_line < b.end_line
      end
      return a.start_line < b.start_line
    end
    return a_path < b_path
  end)
  return items
end

---@param items ScratchCommentView[]
---@param orphans ScratchComment[] Comments whose lines were deleted; listed last.
---@return string
function M.render(items, orphans)
  local comments = sorted(vim.deepcopy(items))
  local lines = { "Comments:", "" }

  local current_file = nil
  for _, comment in ipairs(comments) do
    local file = comment.relative_path or comment.file_path
    if file ~= current_file then
      current_file = file
      table.insert(lines, "## " .. file)
      table.insert(lines, "")
    end

    local fence = fence_for(comment.snippet)
    table.insert(lines, "- " .. line_range(comment) .. " (" .. comment.id .. ")")
    table.insert(lines, "")
    table.insert(lines, comment.comment or "")
    table.insert(lines, "")
    table.insert(lines, fence .. extension(file))
    table.insert(lines, comment.snippet or "")
    table.insert(lines, fence)
    table.insert(lines, "")
  end

  if #orphans > 0 then
    table.insert(lines, "## Orphaned")
    table.insert(lines, "")
    table.insert(lines, "The lines these comments were on have been deleted.")
    table.insert(lines, "")
    for _, comment in ipairs(orphans) do
      table.insert(lines, "- " .. comment.relative_path .. " (" .. comment.id .. ")")
      table.insert(lines, "")
      table.insert(lines, comment.comment)
      table.insert(lines, "")
    end
  end

  return table.concat(lines, "\n")
end

return M
