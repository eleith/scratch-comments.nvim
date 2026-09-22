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

command("CommentShow", function()
  scratch().show()
end, { desc = "Show the comments at the cursor" })

command("CommentDelete", function()
  scratch().delete()
end, { desc = "Delete the comment at the cursor" })

command("CommentNext", function()
  scratch().next()
end, { desc = "Go to the next comment" })

command("CommentPrev", function()
  scratch().prev()
end, { desc = "Go to the previous comment" })

command("CommentList", function()
  scratch().list()
end, { desc = "Browse comments" })

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
