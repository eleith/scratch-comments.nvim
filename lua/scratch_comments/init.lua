local annotate = require("scratch_comments.annotate")
local clipboard = require("scratch_comments.export")
local json = require("scratch_comments.json")
local markdown = require("scratch_comments.markdown")
local render = require("scratch_comments.render")
local state = require("scratch_comments.state")
local ui = require("scratch_comments.ui")

local M = {}

local formats = { markdown = markdown.render, json = json.render }

---@param start_line? integer
---@param end_line? integer
function M.add(start_line, end_line)
  start_line = start_line or vim.api.nvim_win_get_cursor(0)[1]
  annotate.range(start_line, end_line or start_line)
end

function M.show()
  annotate.show_current()
end

function M.next()
  annotate.jump(1)
end

function M.prev()
  annotate.jump(-1)
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

---@return integer[]
local function commented_buffers()
  local buffers = {}
  for _, comment in ipairs(state.all()) do
    buffers[comment.bufnr] = true
  end
  return vim.tbl_keys(buffers)
end

---@param bufnr integer
local function redraw(bufnr)
  render.draw_signs(bufnr, state.in_buffer(bufnr))
end

---@param on? boolean
function M.toggle(on)
  if on == nil then
    on = not render.is_visible()
  end
  render.set_visible(on)
  for _, bufnr in ipairs(commented_buffers()) do
    redraw(bufnr)
  end
end

function M.clear()
  for _, bufnr in ipairs(commented_buffers()) do
    render.clear_buffer(bufnr)
  end
  state.clear()
  ui.notify("Cleared comments", "info")
end

function M.setup()
  render.setup()

  vim.api.nvim_create_user_command("Comment", function(ctx)
    annotate.range(ctx.line1, ctx.line2, ctx.range == 2)
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
      return vim.tbl_keys(formats)
    end,
    desc = "Copy comments to the clipboard; with ! open them in a scratch buffer",
  })
  vim.api.nvim_create_user_command("CommentToggle", function(ctx)
    local choice = ctx.fargs[1]
    if choice ~= nil and choice ~= "on" and choice ~= "off" then
      ui.notify("Usage: :CommentToggle [on|off]", "error")
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
      redraw(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(args)
      render.clear_buffer(args.buf)
      state.remove_buffer(args.buf)
    end,
  })
end

return M
