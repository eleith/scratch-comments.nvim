local card = require("scratch_comments.ui.card")
local preview = require("scratch_comments.ui.preview")
local quickfix = require("scratch_comments.ui.quickfix")
local views = require("scratch_comments.model.views")

local M = {}

-- Every comment in the quickfix list, with the one under the cursor shown
-- in a card above it.
function M.open()
  local anchored, orphans = views.anchored(), views.orphans()
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
