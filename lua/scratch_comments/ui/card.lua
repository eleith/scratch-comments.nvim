local location = require("scratch_comments.location")
local views = require("scratch_comments.model.views")

local M = {}

---@param view ScratchCommentView
---@return ScratchFrame
function M.of(view)
  local in_file = vim.tbl_filter(function(candidate)
    return candidate.source_name == view.source_name
  end, views.anchored())
  return {
    title = location.title(view.file_path, view),
    context = vim.split(view.snippet, "\n"),
    filetype = view.bufnr and vim.api.nvim_buf_is_valid(view.bufnr) and vim.bo[view.bufnr].filetype
      or "",
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
