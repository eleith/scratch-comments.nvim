local anchors = require("scratch_comments.model.anchors")

local M = {}

local namespace = vim.api.nvim_create_namespace("scratch_comments_signs")
local group = "ScratchCommentSign"
local signs = { single = "│", first = "╭", middle = "│", last = "╰" }
local visible = true

vim.api.nvim_set_hl(0, group, { link = "Todo", default = true })

---@return boolean
function M.is_visible()
  return visible
end

---@param on boolean
function M.set_visible(on)
  visible = on
end

---@param bufnr integer
---@param text string
---@param start_line integer
---@param end_line? integer
local function sign(bufnr, text, start_line, end_line)
  vim.api.nvim_buf_set_extmark(bufnr, namespace, start_line - 1, 0, {
    end_row = (end_line or start_line) - 1,
    sign_text = text,
    sign_hl_group = group,
  })
end

-- Signs are drawn from the anchors rather than stored on them: a mark shows
-- its sign on every row it touches, and an anchor also touches the line after
-- its range.
---@param bufnr integer
---@param comments ScratchComment[]
function M.draw(bufnr, comments)
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  if not visible then
    return
  end
  for _, comment in ipairs(comments) do
    local start_line, end_line = anchors.range(comment)
    if start_line and end_line then
      if start_line == end_line then
        sign(bufnr, signs.single, start_line)
      else
        sign(bufnr, signs.first, start_line)
        if end_line - start_line > 1 then
          sign(bufnr, signs.middle, start_line + 1, end_line - 1)
        end
        sign(bufnr, signs.last, end_line)
      end
    end
  end
end

---@param bufnr integer
function M.clear_buffer(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  end
end

return M
