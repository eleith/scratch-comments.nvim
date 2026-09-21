local annotate = require("scratch_comments.annotate")
local clipboard = require("scratch_comments.export")
local markdown = require("scratch_comments.markdown")
local render = require("scratch_comments.render")
local state = require("scratch_comments.state")
local ui = require("scratch_comments.ui")

---@class ScratchComment
---@field id string
---@field repo_root? string
---@field file_path string Absolute file path.
---@field relative_path? string Path relative to the Git root when available.
---@field start_line integer 1-based inclusive line number.
---@field end_line integer 1-based inclusive line number.
---@field snippet string Commented text.
---@field comment string
---@field timestamp string UTC timestamp.
---@field bufnr? integer Runtime-only buffer id.
---@field extmark_id? integer Runtime-only extmark id.

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
  ui.list(state.snapshot())
end

---Render pending comments.
---@param format? "markdown"
---@return string
function M.render(format)
  format = format or "markdown"
  if format ~= "markdown" then
    error("unknown format: " .. tostring(format))
  end
  return markdown.render(state.snapshot())
end

---Copy pending comments to the clipboard. Never clears: see :ScratchClear.
function M.export()
  local items = state.snapshot()
  if #items == 0 then
    ui.notify("No comments to export", "info")
    return
  end

  if not clipboard.copy(markdown.render(items)) then
    ui.notify("Could not copy to the clipboard; no provider configured?", "error")
    return
  end

  ui.notify("Copied " .. #items .. " comment(s)", "info")
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
