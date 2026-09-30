if vim.g.loaded_scratch_comments then
  return
end
vim.g.loaded_scratch_comments = true

local function scratch()
  return require("scratch_comments")
end

local command = vim.api.nvim_create_user_command

command("Comment", function(ctx)
  require("scratch_comments.actions").comment(ctx.line1, ctx.line2, ctx.range == 2)
end, { range = true, desc = "Comment on the current line or range" })

command("CommentDelete", function()
  scratch().delete()
end, { desc = "Delete the comment in the open card" })

command("CommentList", function(ctx)
  scratch().list(ctx.args ~= "" and ctx.args or nil)
end, { nargs = "?", desc = "Browse comments, or only those matching an argument" })

command("CommentExport", function(ctx)
  scratch().export(ctx.fargs[1], ctx.bang)
end, {
  nargs = "?",
  bang = true,
  complete = function()
    return require("scratch_comments.export").names()
  end,
  desc = "Copy comments to the clipboard; with ! open them in a scratch buffer",
})

command("CommentToggle", function(ctx)
  local choice = ctx.fargs[1]
  if choice ~= nil and choice ~= "on" and choice ~= "off" then
    require("scratch_comments.ui.notify").error("Usage: :CommentToggle [on|off]")
    return
  end
  if choice == nil then
    scratch().toggle()
  else
    scratch().toggle(choice == "on")
  end
end, {
  nargs = "?",
  complete = function()
    return { "on", "off" }
  end,
  desc = "Show or hide the comment signs",
})

command("CommentClear", function()
  scratch().clear()
end, { desc = "Clear all comments" })
