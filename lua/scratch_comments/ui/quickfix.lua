local notify = require("scratch_comments.ui.notify")

local M = {}

---@param text string
---@return string
local function summary(text)
  return vim.split(text, "\n")[1]
end

-- Quickfix rather than a picker: any quickfix front-end (Trouble, Snacks,
-- Telescope, nvim-bqf) can display the entries.
---@param views ScratchCommentView[]
---@param orphans ScratchComment[]
---@return table[]
function M.items(views, orphans)
  local entries = vim.tbl_map(function(comment)
    return {
      filename = comment.source_name,
      user_data = { scratch_comments_id = comment.id },
      lnum = comment.start_line,
      end_lnum = comment.end_line,
      col = comment.start_col and comment.start_col + 1,
      end_col = comment.end_col and comment.end_col + 1,
      text = summary(comment.comment),
    }
  end, views)
  for _, comment in ipairs(orphans) do
    table.insert(entries, {
      filename = comment.source_name,
      user_data = { scratch_comments_id = comment.id },
      text = "[orphaned] " .. summary(comment.comment),
    })
  end

  return entries
end

---@param views ScratchCommentView[]
---@param orphans ScratchComment[]
function M.list(views, orphans)
  if #views + #orphans == 0 then
    notify.info("No comments")
    return
  end

  vim.fn.setqflist({}, " ", { title = "Comments", items = M.items(views, orphans) })
  vim.cmd.copen()
  return vim.fn.getqflist({ id = 0 }).id
end

return M
