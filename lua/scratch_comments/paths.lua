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

local function parent(path)
  local parent_dir = vim.fn.fnamemodify(path, ":h")
  if parent_dir == path then
    return nil
  end
  return parent_dir
end

local function find_git_root(path)
  local dir = dirname(path)
  while true do
    if (vim.uv or vim.loop).fs_stat(dir .. "/.git") then
      return dir
    end
    local parent_dir = parent(dir)
    if parent_dir == nil then
      return nil
    end
    dir = parent_dir
  end
end

---@param path string
---@return string? root
function M.git_root(path)
  return run({ "git", "-C", dirname(path), "rev-parse", "--show-toplevel" }) or find_git_root(path)
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
