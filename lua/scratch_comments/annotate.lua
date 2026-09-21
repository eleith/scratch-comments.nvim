local context = require("scratch_comments.context")
local render = require("scratch_comments.render")
local state = require("scratch_comments.state")
local ui = require("scratch_comments.ui")

local M = {}

---@param ctx? vim.api.keyset.create_user_command.command_args
---@return integer start_line, integer end_line
local function range_from_ctx(ctx)
  if ctx and ctx.range and ctx.range > 0 then
    return ctx.line1, ctx.line2
  end
  local line = vim.api.nvim_win_get_cursor(0)[1]
  return line, line
end

---@return integer start_line, integer end_line
local function visual_range()
  return vim.fn.line("v"), vim.fn.line(".")
end

---Comments are keyed by anchor: commenting on the same lines again edits that
---comment; any other range, including one that overlaps or nests, adds one.
---@param bufnr integer
---@param start_line integer
---@param end_line integer
---@return ScratchCommentView?
local function find_anchor(bufnr, start_line, end_line)
  return state.find(function(comment)
    return comment.bufnr == bufnr
      and comment.start_line == start_line
      and comment.end_line == end_line
  end)
end

---@param bufnr integer
---@param line integer
---@return ScratchCommentView[]
local function find_covering(bufnr, line)
  return state.find_all(function(comment)
    return comment.bufnr == bufnr and comment.start_line <= line and line <= comment.end_line
  end)
end

---Ask for comment text, prefilled when editing. Blank input cancels.
---@param existing? ScratchCommentView
---@param on_text fun(text: string)
local function prompt(existing, on_text)
  ui.input("Comment: ", existing and existing.comment, function(text)
    if text and vim.trim(text) ~= "" then
      on_text(text)
    end
  end)
end

---@param view ScratchCommentView
---@param text string
local function update_text(view, text)
  local comment = state.update(view.id, { comment = text })
  if comment then
    -- Re-place at the current range so the displayed text is refreshed.
    render.place(comment, view.start_line, view.end_line)
    ui.notify("Updated comment", "info")
  end
end

---Add a comment on a line range, or edit the comment already on that exact anchor.
---@param start_line integer
---@param end_line integer
function M.range(start_line, end_line)
  local bufnr = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    ui.notify("Save the buffer before commenting on it", "warn")
    return
  end
  start_line, end_line = math.min(start_line, end_line), math.max(start_line, end_line)

  local existing = find_anchor(bufnr, start_line, end_line)
  prompt(existing, function(text)
    if existing then
      update_text(existing, text)
      return
    end

    -- The prompt can be asynchronous; the buffer may be gone by now.
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    local file_path = vim.fn.fnamemodify(name, ":p")
    local comment = state.add({
      bufnr = bufnr,
      comment = text,
      file_path = file_path,
      relative_path = context.relative_path(context.git_root(file_path), file_path),
    })
    render.place(comment, start_line, end_line)
    ui.notify("Added comment", "info")
  end)
end

---@param ctx? vim.api.keyset.create_user_command.command_args
function M.command(ctx)
  M.range(range_from_ctx(ctx))
end

function M.visual_selection()
  M.range(visual_range())
end

---Resolve the comment to act on at the cursor, asking when several anchors
---cover the cursor line.
---@param callback fun(view: ScratchCommentView)
local function at_cursor(callback)
  local covering = find_covering(vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0)[1])
  if #covering == 0 then
    ui.notify("No comment at cursor", "info")
    return
  end

  if #covering == 1 then
    callback(covering[1])
    return
  end

  vim.ui.select(covering, {
    prompt = "Comment: ",
    format_item = function(comment)
      local range = comment.start_line == comment.end_line and tostring(comment.start_line)
        or (comment.start_line .. "-" .. comment.end_line)
      return "lines " .. range .. ": " .. comment.comment
    end,
  }, function(comment)
    if comment then
      callback(comment)
    end
  end)
end

function M.edit_current()
  at_cursor(function(view)
    prompt(view, function(text)
      update_text(view, text)
    end)
  end)
end

function M.delete_current()
  at_cursor(function(view)
    render.clear_all(state.remove_ids({ view.id }))
    ui.notify("Deleted comment", "info")
  end)
end

return M
