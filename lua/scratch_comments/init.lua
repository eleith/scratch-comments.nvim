local annotate = require("scratch_comments.annotate")
local clipboard = require("scratch_comments.export")
local markdown = require("scratch_comments.markdown")
local render = require("scratch_comments.render")
local state = require("scratch_comments.state")
local ui = require("scratch_comments.ui")

---@class ScratchDisplayConfig
---@field sign_text? string
---@field sign_hl_group? string
---@field virtual_text_prefix? string
---@field virtual_text_hl_group? string
---@field virtual_text_pos? string
---@field max_comment_length? integer
---@field priority? integer

---@class ScratchConfig
---@field display? ScratchDisplayConfig

local M = {}

---@param ctx? vim.api.keyset.create_user_command.command_args
function M.add(ctx)
  annotate.command(ctx)
end

function M.add_visual()
  annotate.visual_selection()
end

function M.edit()
  annotate.edit_current()
end

function M.delete()
  annotate.delete_current()
end

function M.list()
  ui.list(state.anchored(), state.orphans())
end

---@param format? "markdown"
---@return string
function M.render(format)
  format = format or "markdown"
  if format ~= "markdown" then
    error("unknown format: " .. tostring(format))
  end
  return markdown.render(state.anchored(), state.orphans())
end

function M.export()
  local items, orphans = state.anchored(), state.orphans()
  local count = #items + #orphans
  if count == 0 then
    ui.notify("No comments to export", "info")
    return
  end

  if not clipboard.copy(markdown.render(items, orphans)) then
    ui.notify("Could not copy to the clipboard; no provider configured?", "error")
    return
  end

  ui.notify("Copied " .. count .. " comment(s)", "info")
end

function M.clear()
  render.clear_all(state.all())
  state.clear()
  ui.notify("Cleared comments", "info")
end

---@param opts? ScratchConfig
function M.setup(opts)
  opts = opts or {}
  render.setup(opts.display)

  vim.api.nvim_create_user_command("Comment", function(ctx)
    M.add(ctx)
  end, { range = true, desc = "Comment on the current line or range" })

  vim.api.nvim_create_user_command(
    "CommentEdit",
    M.edit,
    { desc = "Edit the comment at the cursor" }
  )
  vim.api.nvim_create_user_command(
    "CommentDelete",
    M.delete,
    { desc = "Delete the comment at the cursor" }
  )
  vim.api.nvim_create_user_command("CommentList", M.list, { desc = "Browse comments" })
  vim.api.nvim_create_user_command(
    "CommentExport",
    M.export,
    { desc = "Copy comments to the clipboard" }
  )
  vim.api.nvim_create_user_command("CommentClear", M.clear, { desc = "Clear all comments" })

  local group = vim.api.nvim_create_augroup("scratch_comments", { clear = true })

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(args)
      render.clear_buffer(args.buf)
      state.remove_buffer(args.buf)
    end,
  })
end

return M
