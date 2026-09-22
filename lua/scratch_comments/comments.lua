local anchors = require("scratch_comments.model.anchors")
local signs = require("scratch_comments.ui.signs")
local store = require("scratch_comments.model.store")

local M = {}

---@param bufnr integer
function M.redraw(bufnr)
  signs.draw(bufnr, store.in_buffer(bufnr))
end

---@return integer[]
local function commented_buffers()
  local seen = {}
  for _, comment in ipairs(store.all()) do
    seen[comment.bufnr] = true
  end
  return vim.tbl_keys(seen)
end

---@param fields { bufnr: integer, comment: string, file_path: string, relative_path: string }
---@param location ScratchLocation
---@return ScratchComment
function M.add(fields, location)
  local comment = store.add({
    bufnr = fields.bufnr,
    comment = fields.comment,
    file_path = fields.file_path,
    relative_path = fields.relative_path,
    charwise = location.start_col ~= nil,
  })
  anchors.anchor(
    comment,
    location.start_line,
    location.end_line,
    location.start_col,
    location.end_col
  )
  M.redraw(comment.bufnr)
  return comment
end

---@param id string
---@param text string
function M.edit(id, text)
  store.update(id, { comment = text })
end

---@param comment ScratchComment
function M.delete(comment)
  anchors.clear_all(store.remove(function(candidate)
    return candidate.id == comment.id
  end))
  M.redraw(comment.bufnr)
end

function M.clear()
  for _, bufnr in ipairs(commented_buffers()) do
    anchors.clear_buffer(bufnr)
    signs.clear_buffer(bufnr)
  end
  store.clear()
end

---@param bufnr integer
function M.forget_buffer(bufnr)
  anchors.clear_buffer(bufnr)
  signs.clear_buffer(bufnr)
  store.remove(function(comment)
    return comment.bufnr == bufnr
  end)
end

---@param on boolean
function M.show_signs(on)
  signs.set_visible(on)
  for _, bufnr in ipairs(commented_buffers()) do
    M.redraw(bufnr)
  end
end

return M
