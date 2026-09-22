local location = require("scratch_comments.location")
local views = require("scratch_comments.model.views")

local M = {}

---@param view ScratchCommentView
---@return ScratchFrame
function M.of(view)
  local in_file = views.in_buffer(view.bufnr)
  return {
    title = location.title(view.file_path, view),
    context = vim.split(view.snippet, "\n"),
    filetype = vim.bo[view.bufnr].filetype,
    comment = view.comment,
    comment_title = ("comment (%d of %d)"):format(views.index_of(in_file, view.id) or 0, #in_file),
  }
end

---@param comment ScratchComment
---@return ScratchFrame
function M.of_orphan(comment)
  return {
    title = comment.relative_path .. " [orphaned]",
    context = { "The lines this comment was on are gone." },
    filetype = "",
    comment = comment.comment,
  }
end

return M
