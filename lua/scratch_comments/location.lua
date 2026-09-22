local M = {}

---@class ScratchLocation
---@field start_line integer 1-based, inclusive.
---@field end_line integer 1-based, inclusive.
---@field start_col? integer 0-based byte, for a character span.
---@field end_col? integer 0-based byte, exclusive.

---@param location ScratchLocation
---@return string
function M.describe(location)
  local start_line, end_line = location.start_line, location.end_line
  if location.start_col and location.end_col then
    local first, last = location.start_col + 1, location.end_col
    if start_line ~= end_line then
      return ("lines %d:%d–%d:%d"):format(start_line, first, end_line, last)
    end
    if first == last then
      return ("line %d, col %d"):format(start_line, first)
    end
    return ("line %d, col %d–%d"):format(start_line, first, last)
  end
  if start_line == end_line then
    return "line " .. start_line
  end
  return "lines " .. start_line .. "–" .. end_line
end

---@param file_path string
---@param location ScratchLocation
---@return string
function M.title(file_path, location)
  return vim.fn.fnamemodify(file_path, ":t") .. " [" .. M.describe(location) .. "]"
end

-- Cuts from the left so the line range and the file extension stay visible.
---@param text string
---@param width integer
---@return string
function M.fit(text, width)
  local start = 0
  while vim.api.nvim_strwidth(vim.fn.strcharpart(text, start)) > width do
    start = start + 1
  end
  return start == 0 and text or "…" .. vim.fn.strcharpart(text, start + 1)
end

return M
