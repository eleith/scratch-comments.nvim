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

---Browse comments by populating the quickfix list.
---
---Quickfix is Neovim's interop format for "a list of places in files". Writing
---to it means vanilla `:copen` works, and every quickfix front-end the user has
---installed -- trouble.nvim, nvim-bqf, Snacks.picker.qflist, :Telescope
---quickfix -- displays it without this plugin knowing they exist.
---@param items ScratchCommentView[]
function M.list(items)
  if #items == 0 then
    M.notify("No comments", "info")
    return
  end

  vim.fn.setqflist({}, " ", {
    title = "Comments",
    items = vim.tbl_map(function(comment)
      return {
        filename = comment.file_path,
        lnum = comment.start_line,
        end_lnum = comment.end_line,
        text = comment.comment,
      }
    end, items),
  })
  vim.cmd.copen()
end

return M
