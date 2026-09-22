local notify = require("scratch_comments.ui.notify")

local M = {}

---@param text string
---@return string
local function summary(text)
  return vim.split(text, "\n")[1]
end

-- Quickfix rather than a picker: any quickfix front-end (Trouble, Snacks,
-- Telescope, nvim-bqf) can display it.
---@param items ScratchCommentView[]
---@param orphans ScratchComment[]
function M.list(items, orphans)
  if #items + #orphans == 0 then
    notify.info("No comments")
    return
  end

  local entries = vim.tbl_map(function(comment)
    return {
      filename = comment.file_path,
      lnum = comment.start_line,
      end_lnum = comment.end_line,
      text = summary(comment.comment),
    }
  end, items)
  for _, comment in ipairs(orphans) do
    table.insert(
      entries,
      { filename = comment.file_path, text = "[orphaned] " .. summary(comment.comment) }
    )
  end

  vim.fn.setqflist({}, " ", { title = "Comments", items = entries })
  vim.cmd.copen()
end

return M
