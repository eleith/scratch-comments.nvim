local M = {}

---@param text string
---@return boolean
function M.copy(text)
  local ok = pcall(vim.fn.setreg, "+", text)
  if not ok then
    return false
  end

  -- setreg never errors when no provider is configured, so confirm the
  -- register actually holds what we put in it.
  local ok_read, stored = pcall(vim.fn.getreg, "+")
  return ok_read and stored == text
end

return M
