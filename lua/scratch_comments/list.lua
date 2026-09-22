local card = require("scratch_comments.ui.card")
local preview = require("scratch_comments.ui.preview")
local notify = require("scratch_comments.ui.notify")
local quickfix = require("scratch_comments.ui.quickfix")
local window = require("scratch_comments.ui.window")
local views = require("scratch_comments.model.views")

local M = {}

---@param comment ScratchComment|ScratchCommentView
---@return string
local function haystack(comment)
  return table.concat({ comment.relative_path, comment.comment, comment.snippet or "" }, " ")
end

-- Keeps the comments that fuzzy match, in the order they were listed.
---@generic T: ScratchComment
---@param comments T[]
---@param filter string
---@return T[]
local function matching(comments, filter)
  local candidates = {}
  for index, comment in ipairs(comments) do
    table.insert(candidates, { index = index, text = haystack(comment) })
  end
  local kept = {}
  for _, candidate in ipairs(vim.fn.matchfuzzy(candidates, filter, { key = "text" })) do
    kept[candidate.index] = true
  end

  local matched = {}
  for index, comment in ipairs(comments) do
    if kept[index] then
      table.insert(matched, comment)
    end
  end
  return matched
end

-- Every comment in the quickfix list, with the one under the cursor shown
-- in a card above it.
---@param filter? string only comments matching this
function M.open(filter)
  if not window.close() then
    notify.warn("Save or discard the comment first")
    return
  end
  local anchored, orphans = views.anchored(), views.orphans()
  if filter and filter ~= "" then
    anchored, orphans = matching(anchored, filter), matching(orphans, filter)
  end
  local listed = vim.list_extend(vim.list_slice(anchored), orphans)
  quickfix.list(anchored, orphans, function(index)
    local entry = index and listed[index]
    if not entry then
      preview.close()
    elseif entry.snippet then
      preview.show(card.of(entry))
    else
      preview.show(card.of_orphan(entry))
    end
  end)
end

return M
