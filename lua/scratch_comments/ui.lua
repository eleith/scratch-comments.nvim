local M = {}

local function level(name)
  return vim.log.levels[(name or "info"):upper()] or vim.log.levels.INFO
end

---@param message string
---@param kind? "info"|"warn"|"error"
function M.notify(message, kind)
  vim.schedule(function()
    local opts = { title = "scratch-comments" }
    if kind == "error" or kind == "warn" then
      opts.timeout = 10000
    end
    vim.notify(message, level(kind), opts)
  end)
end

---@param prompt string
---@param default? string
---@param callback fun(value: string?)
function M.input(prompt, default, callback)
  vim.ui.input({ prompt = prompt, default = default }, function(value)
    callback(value)
  end)
end

-- Quickfix rather than a picker: any quickfix front-end (Trouble, Snacks,
-- Telescope, nvim-bqf) can display it.
---@param items ScratchCommentView[]
---@param orphans ScratchComment[]
function M.list(items, orphans)
  if #items + #orphans == 0 then
    M.notify("No comments", "info")
    return
  end

  local entries = vim.tbl_map(function(comment)
    return {
      filename = comment.file_path,
      lnum = comment.start_line,
      end_lnum = comment.end_line,
      text = comment.comment,
    }
  end, items)
  for _, comment in ipairs(orphans) do
    table.insert(entries, { filename = comment.file_path, text = "[orphaned] " .. comment.comment })
  end

  vim.fn.setqflist({}, " ", { title = "Comments", items = entries })
  vim.cmd.copen()
end

return M
