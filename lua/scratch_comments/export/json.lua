local M = {}

---@param views ScratchCommentView[]
---@param orphans ScratchComment[]
---@return string
function M.render(views, orphans)
  local comments = vim.tbl_map(function(comment)
    return {
      id = comment.id,
      file = comment.file_path,
      relative_path = comment.relative_path,
      start_line = comment.start_line,
      end_line = comment.end_line,
      start_col = comment.start_col and comment.start_col + 1,
      end_col = comment.end_col,
      snippet = comment.snippet,
      comment = comment.comment,
    }
  end, views)

  local orphaned = vim.tbl_map(function(comment)
    return {
      id = comment.id,
      file = comment.file_path,
      relative_path = comment.relative_path,
      comment = comment.comment,
    }
  end, orphans)

  return vim.json.encode({ comments = comments, orphaned = orphaned }, { indent = "  " })
end

return M
