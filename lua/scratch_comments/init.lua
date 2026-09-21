local annotate = require("scratch_comments.annotate")
local clipboard = require("scratch_comments.export")
local json = require("scratch_comments.json")
local markdown = require("scratch_comments.markdown")
local render = require("scratch_comments.render")
local state = require("scratch_comments.state")
local ui = require("scratch_comments.ui")

local M = {}

local formats = { markdown = markdown.render, json = json.render }

---@param ctx? vim.api.keyset.create_user_command.command_args
function M.add(ctx)
  annotate.command(ctx)
end

function M.add_visual()
  annotate.visual_selection()
end

function M.show()
  annotate.show_current()
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

---@param format? "markdown"|"json"
---@return string
function M.render(format)
  local render_format = formats[format or "markdown"] or error("unknown format: " .. format)
  return render_format(state.anchored(), state.orphans())
end

---@param format? string
---@param in_buffer? boolean
function M.export(format, in_buffer)
  format = format or "markdown"
  local render_format = formats[format]
  if not render_format then
    ui.notify("Unknown format: " .. format, "error")
    return
  end

  local items, orphans = state.anchored(), state.orphans()
  local count = #items + #orphans
  if count == 0 then
    ui.notify("No comments to export", "info")
    return
  end

  local text = render_format(items, orphans)
  if in_buffer then
    ui.open_scratch(text, format)
    return
  end

  if not clipboard.copy(text) then
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

function M.setup()
  render.setup()

  vim.api.nvim_create_user_command("Comment", function(ctx)
    M.add(ctx)
  end, { range = true, desc = "Comment on the current line or range" })

  vim.api.nvim_create_user_command(
    "CommentShow",
    M.show,
    { desc = "Show the comments at the cursor" }
  )
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
  vim.api.nvim_create_user_command("CommentExport", function(ctx)
    M.export(ctx.fargs[1], ctx.bang)
  end, {
    nargs = "?",
    bang = true,
    complete = function()
      return vim.tbl_keys(formats)
    end,
    desc = "Copy comments to the clipboard; with ! open them in a scratch buffer",
  })
  vim.api.nvim_create_user_command("CommentClear", M.clear, { desc = "Clear all comments" })

  local group = vim.api.nvim_create_augroup("scratch_comments", { clear = true })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(args)
      render.clear_buffer(args.buf)
      state.remove_buffer(args.buf)
    end,
  })
end

return M
