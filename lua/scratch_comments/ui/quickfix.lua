local notify = require("scratch_comments.ui.notify")

local M = {}

---@param text string
---@return string
local function summary(text)
  return vim.split(text, "\n")[1]
end

-- Quickfix rather than a picker: any quickfix front-end (Trouble, Snacks,
-- Telescope, nvim-bqf) can display it.
-- Reports the entry the cursor is on, and nil once the list is gone.
---@param on_entry? fun(index: integer?)
local function follow(on_entry)
  if not on_entry then
    return
  end
  local group = vim.api.nvim_create_augroup("scratch_comments_quickfix", { clear = true })
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_create_autocmd({ "CursorMoved", "BufEnter" }, {
    group = group,
    buffer = bufnr,
    callback = function()
      on_entry(vim.api.nvim_win_get_cursor(0)[1])
    end,
  })
  for _, event in ipairs({ "BufLeave", "BufWipeout" }) do
    vim.api.nvim_create_autocmd(event, {
      group = group,
      buffer = bufnr,
      callback = function()
        on_entry(nil)
      end,
    })
  end
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = tostring(vim.api.nvim_get_current_win()),
    once = true,
    callback = function()
      on_entry(nil)
    end,
  })
  on_entry(vim.api.nvim_win_get_cursor(0)[1])
end

---@param views ScratchCommentView[]
---@param orphans ScratchComment[]
---@param on_entry? fun(index: integer?) called with the entry the cursor is on
function M.list(views, orphans, on_entry)
  if #views + #orphans == 0 then
    notify.info("No comments")
    return
  end

  local entries = vim.tbl_map(function(comment)
    return {
      filename = comment.file_path,
      lnum = comment.start_line,
      end_lnum = comment.end_line,
      col = comment.start_col and comment.start_col + 1,
      end_col = comment.end_col and comment.end_col + 1,
      text = summary(comment.comment),
    }
  end, views)
  for _, comment in ipairs(orphans) do
    table.insert(
      entries,
      { filename = comment.file_path, text = "[orphaned] " .. summary(comment.comment) }
    )
  end

  vim.fn.setqflist({}, " ", { title = "Comments", items = entries })
  vim.cmd.copen()
  follow(on_entry)
end

return M
