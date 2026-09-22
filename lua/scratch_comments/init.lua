local actions = require("scratch_comments.actions")
local comments = require("scratch_comments.comments")
local export = require("scratch_comments.export")
local navigate = require("scratch_comments.navigate")
local notify = require("scratch_comments.ui.notify")
local quickfix = require("scratch_comments.ui.quickfix")
local signs = require("scratch_comments.ui.signs")
local views = require("scratch_comments.model.views")

local M = {}

---@param start_line? integer
---@param end_line? integer
function M.add(start_line, end_line)
  start_line = start_line or vim.api.nvim_win_get_cursor(0)[1]
  actions.comment(start_line, end_line or start_line)
end

M.show = actions.show_current
M.delete = actions.delete_current
M.toggle = actions.toggle
M.clear = actions.clear
M.render = export.render
M.export = export.export

function M.next()
  navigate.jump(1)
end

function M.prev()
  navigate.jump(-1)
end

function M.list()
  quickfix.list(views.anchored(), views.orphans())
end

function M.setup()
  signs.setup()

  vim.api.nvim_create_user_command("Comment", function(ctx)
    actions.comment(ctx.line1, ctx.line2, ctx.range == 2)
  end, { range = true, desc = "Comment on the current line or range" })

  vim.api.nvim_create_user_command(
    "CommentShow",
    M.show,
    { desc = "Show the comments at the cursor" }
  )
  vim.api.nvim_create_user_command(
    "CommentDelete",
    M.delete,
    { desc = "Delete the comment at the cursor" }
  )
  vim.api.nvim_create_user_command("CommentNext", M.next, { desc = "Go to the next comment" })
  vim.api.nvim_create_user_command("CommentPrev", M.prev, { desc = "Go to the previous comment" })
  vim.api.nvim_create_user_command("CommentList", M.list, { desc = "Browse comments" })
  vim.api.nvim_create_user_command("CommentExport", function(ctx)
    M.export(ctx.fargs[1], ctx.bang)
  end, {
    nargs = "?",
    bang = true,
    complete = function()
      return export.names()
    end,
    desc = "Copy comments to the clipboard; with ! open them in a scratch buffer",
  })
  vim.api.nvim_create_user_command("CommentToggle", function(ctx)
    local choice = ctx.fargs[1]
    if choice ~= nil and choice ~= "on" and choice ~= "off" then
      notify.error("Usage: :CommentToggle [on|off]")
      return
    end
    if choice == nil then
      M.toggle()
    else
      M.toggle(choice == "on")
    end
  end, {
    nargs = "?",
    complete = function()
      return { "on", "off" }
    end,
    desc = "Show or hide the comment signs",
  })
  vim.api.nvim_create_user_command("CommentClear", M.clear, { desc = "Clear all comments" })

  local group = vim.api.nvim_create_augroup("scratch_comments", { clear = true })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    callback = function(args)
      comments.redraw(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(args)
      comments.forget_buffer(args.buf)
    end,
  })
end

return M
