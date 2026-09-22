local clipboard = require("scratch_comments.export.clipboard")
local json = require("scratch_comments.export.json")
local markdown = require("scratch_comments.export.markdown")
local notify = require("scratch_comments.ui.notify")
local views = require("scratch_comments.model.views")

local M = {}

local formats = { markdown = markdown.render, json = json.render }

---@return string[]
function M.names()
  return vim.tbl_keys(formats)
end

---@param format? "markdown"|"json"
---@return string
function M.render(format)
  local render_format = formats[format or "markdown"] or error("unknown format: " .. format)
  return render_format(views.anchored(), views.orphans())
end

---@param text string
---@param filetype string
local function open_scratch(text, filetype)
  vim.cmd.new()
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
  vim.bo.filetype = filetype
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(text, "\n"))
end

---@param format? string
---@param in_buffer? boolean
function M.export(format, in_buffer)
  format = format or "markdown"
  local render_format = formats[format]
  if not render_format then
    notify.error("Unknown format: " .. format)
    return
  end

  local anchored, orphans = views.anchored(), views.orphans()
  local count = #anchored + #orphans
  if count == 0 then
    notify.info("No comments to export")
    return
  end

  local text = render_format(anchored, orphans)
  if in_buffer then
    open_scratch(text, format)
    return
  end

  if not clipboard.copy(text) then
    notify.error("Could not copy to the clipboard; no provider configured?")
    return
  end

  notify.info("Copied " .. count .. " comment(s)")
end

return M
