local M = {}

---@param items ScratchCommentView[]
---@param orphans ScratchComment[]
---@return string
function M.render(items, orphans)
  local comments = vim.tbl_map(function(comment)
    return {
      id = comment.id,
      file = comment.file_path,
      relative_path = comment.relative_path,
      start_line = comment.start_line,
      end_line = comment.end_line,
      snippet = comment.snippet,
      comment = comment.comment,
    }
  end, items)

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
