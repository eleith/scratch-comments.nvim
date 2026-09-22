local M = {}

local function run(args)
  local result = vim.system(args, { text = true }):wait()
  if result.code == 0 then
    return vim.trim(result.stdout or "")
  end
  return nil
end

local function dirname(path)
  if path == nil or path == "" then
    return vim.fn.getcwd()
  end
  return vim.fn.fnamemodify(path, ":p:h")
end

---@param path string
---@return string? root
function M.git_root(path)
  return run({ "git", "-C", dirname(path), "rev-parse", "--show-toplevel" })
end

---@param root string?
---@param path string
---@return string path
function M.relative_path(root, path)
  if not root or root == "" then
    return path
  end

  local normalized_root = vim.fn.fnamemodify(root, ":p"):gsub("/$", "")
  local normalized_path = vim.fn.fnamemodify(path, ":p")
  local prefix = normalized_root .. "/"

  if normalized_path:sub(1, #prefix) == prefix then
    return normalized_path:sub(#prefix + 1)
  end

  return path
end

return M
