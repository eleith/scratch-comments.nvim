local M = {}

---@param message string
---@param level integer
---@param opts table
local function send(message, level, opts)
  vim.schedule(function()
    vim.notify(message, level, vim.tbl_extend("keep", opts, { title = "scratch-comments" }))
  end)
end

---@param message string
function M.info(message)
  send(message, vim.log.levels.INFO, {})
end

---@param message string
function M.warn(message)
  send(message, vim.log.levels.WARN, { timeout = 10000 })
end

---@param message string
function M.error(message)
  send(message, vim.log.levels.ERROR, { timeout = 10000 })
end

return M
