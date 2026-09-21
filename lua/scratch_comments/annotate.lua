local context = require("scratch_comments.context")
local render = require("scratch_comments.render")
local state = require("scratch_comments.state")
local ui = require("scratch_comments.ui")

local M = {}

local function validate_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    ui.notify("Target buffer is no longer available", "warn")
    return nil
  end

  local file_path = vim.api.nvim_buf_get_name(bufnr)
  if file_path == "" then
    ui.notify("Save the buffer before commenting on it", "warn")
    return nil
  end
  return vim.fn.fnamemodify(file_path, ":p")
end

local function selected_lines(bufnr, start_line, end_line)
  return table.concat(vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false), "\n")
end

local function same_path(left, right)
  return vim.fn.fnamemodify(left or "", ":p") == vim.fn.fnamemodify(right or "", ":p")
end

local function clamp_range(bufnr, start_line, end_line)
  local line_count = math.max(1, vim.api.nvim_buf_line_count(bufnr))

  start_line = math.max(1, math.min(start_line, line_count))
  end_line = math.max(1, math.min(end_line, line_count))

  return math.min(start_line, end_line), math.max(start_line, end_line)
end

local function range_from_ctx(ctx)
  if ctx and ctx.range and ctx.range > 0 then
    return ctx.line1, ctx.line2
  end
  local line = vim.api.nvim_win_get_cursor(0)[1]
  return line, line
end

local function visual_range()
  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")

  if start_line == 0 or end_line == 0 then
    start_line = vim.fn.getpos("'<")[2]
    end_line = vim.fn.getpos("'>")[2]
  end

  return start_line, end_line
end

local function target_for_range(start_line, end_line)
  if not start_line or not end_line or start_line < 1 or end_line < 1 then
    ui.notify("Could not determine the comment range", "warn")
    return nil
  end

  local bufnr = vim.api.nvim_get_current_buf()
  if not validate_buffer(bufnr) then
    return nil
  end

  local target = { bufnr = bufnr }
  target.start_line, target.end_line =
    clamp_range(bufnr, math.min(start_line, end_line), math.max(start_line, end_line))
  target.file_path = vim.api.nvim_buf_get_name(bufnr)
  target.snippet = selected_lines(bufnr, target.start_line, target.end_line)

  return target
end

local function build_comment(target, text)
  local file_path = validate_buffer(target.bufnr)
  if not file_path then
    return nil
  end

  local start_line, end_line = clamp_range(target.bufnr, target.start_line, target.end_line)
  local repo_root = context.git_root(file_path)

  return {
    bufnr = target.bufnr,
    repo_root = repo_root,
    file_path = file_path,
    relative_path = context.relative_path(repo_root, file_path),
    start_line = start_line,
    end_line = end_line,
    snippet = selected_lines(target.bufnr, start_line, end_line),
    comment = text,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }
end

---An anchor is a file plus a line range. Comments are keyed by anchor: the same
---anchor edits, a different anchor (including one that overlaps or nests) adds.
local function find_anchor(file_path, start_line, end_line)
  return state.find(function(comment)
    return same_path(comment.file_path, file_path)
      and comment.start_line == start_line
      and comment.end_line == end_line
  end)
end

local function find_covering(file_path, line)
  return state.find_all(function(comment)
    return same_path(comment.file_path, file_path)
      and comment.start_line <= line
      and comment.end_line >= line
  end)
end

local function save(target, text, existing)
  local comment = build_comment(target, text)
  if not comment then
    return
  end

  if existing then
    comment.id = existing.id
    render.clear(existing)
    comment = state.update(existing.id, comment)
    if comment then
      render.show(comment)
      ui.notify("Updated comment", "info")
    end
    return comment
  end

  comment = state.add(comment)
  render.show(comment)
  ui.notify("Added comment", "info")
  return comment
end

local function prompt(target, existing)
  ui.input("Comment: ", existing and existing.comment or nil, function(text)
    if not text or text:gsub("%s+", "") == "" then
      return
    end
    save(target, text, existing)
  end)
end

---Add a comment on a line range, or edit the comment already on that exact anchor.
function M.range(start_line, end_line)
  local target = target_for_range(start_line, end_line)
  if not target then
    return
  end

  prompt(target, find_anchor(target.file_path, target.start_line, target.end_line))
end

---@param ctx? vim.api.keyset.create_user_command.command_args
function M.command(ctx)
  M.range(range_from_ctx(ctx))
end

function M.visual_selection()
  M.range(visual_range())
end

---Resolve the comment to act on at the cursor, disambiguating when several
---anchors cover the same line.
local function at_cursor(callback)
  local bufnr = vim.api.nvim_get_current_buf()
  local file_path = validate_buffer(bufnr)
  if not file_path then
    return
  end

  local covering = find_covering(file_path, vim.api.nvim_win_get_cursor(0)[1])
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
  at_cursor(function(existing)
    local target = target_for_range(existing.start_line, existing.end_line)
    if target then
      prompt(target, existing)
    end
  end)
end

function M.delete_current()
  at_cursor(function(existing)
    render.clear_all(state.remove_ids({ existing.id }))
    ui.notify("Deleted comment", "info")
  end)
end

return M
