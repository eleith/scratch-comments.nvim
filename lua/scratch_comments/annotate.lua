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

---@return ScratchCommentView[]
local function cursor_comments()
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  return state.find_all(function(comment)
    return comment.bufnr == bufnr and comment.start_line <= line and line <= comment.end_line
  end)
end

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
    render.place(comment, view.start_line, view.end_line)
    ui.notify("Updated comment", "info")
  end
end

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

    -- vim.ui.input may be asynchronous; the buffer can be gone by now.
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

---@param view ScratchCommentView
---@return string
local function describe(view)
  local lines = view.start_line == view.end_line and tostring(view.start_line)
    or (view.start_line .. "-" .. view.end_line)
  return "lines " .. lines .. ": " .. view.comment
end

---@param views ScratchCommentView[]
---@param callback fun(view: ScratchCommentView)
local function choose(views, callback)
  if #views == 1 then
    callback(views[1])
    return
  end
  vim.ui.select(views, { prompt = "Comment: ", format_item = describe }, function(view)
    if view then
      callback(view)
    end
  end)
end

---@param comment ScratchComment
local function delete(comment)
  render.clear_all(state.remove_ids({ comment.id }))
  ui.notify("Deleted comment", "info")
end

function M.edit_current()
  local views = cursor_comments()
  if #views == 0 then
    ui.notify("No comment at cursor", "info")
    return
  end
  choose(views, function(view)
    prompt(view, function(text)
      update_text(view, text)
    end)
  end)
end

function M.delete_current()
  local views = cursor_comments()
  if #views > 0 then
    choose(views, delete)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local orphans = vim.tbl_filter(function(comment)
    return comment.bufnr == bufnr
  end, state.orphans())
  if #orphans == 0 then
    ui.notify("No comment at cursor", "info")
    return
  end

  vim.ui.select(orphans, {
    prompt = "Delete orphaned comment: ",
    format_item = function(comment)
      return comment.comment
    end,
  }, function(comment)
    if comment then
      delete(comment)
    end
  end)
end

return M
