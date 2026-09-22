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

---@param views ScratchCommentView[]
---@param orphans ScratchComment[]
---@return string
function M.render(views, orphans)
  local lines = { "Comments:", "" }

  local current_file = nil
  for _, comment in ipairs(views) do
    local file = comment.relative_path
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
