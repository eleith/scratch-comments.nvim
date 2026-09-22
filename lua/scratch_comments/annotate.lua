local context = require("scratch_comments.context")
local render = require("scratch_comments.render")
local state = require("scratch_comments.state")
local ui = require("scratch_comments.ui")

local M = {}

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

---@param file_path string
---@param start_line integer
---@param end_line integer
---@return string
local function title(file_path, start_line, end_line)
  local name = vim.fn.fnamemodify(file_path, ":t")
  if start_line == end_line then
    return name .. " [line " .. start_line .. "]"
  end
  return name .. " [lines " .. start_line .. "–" .. end_line .. "]"
end

---@param view ScratchCommentView
---@param on_save? fun(text: string)
local function open_frame(view, on_save)
  ui.open_frame({
    title = title(view.file_path, view.start_line, view.end_line),
    context = vim.split(view.snippet, "\n"),
    filetype = vim.bo[view.bufnr].filetype,
    comment = view.comment,
    on_save = on_save,
  })
end

---@param view ScratchCommentView
local function edit(view)
  open_frame(view, function(text)
    state.update(view.id, { comment = text })
    ui.notify("Updated comment", "info")
  end)
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
  if existing then
    edit(existing)
    return
  end

  local file_path = vim.fn.fnamemodify(name, ":p")
  local relative_path = context.relative_path(context.git_root(file_path), file_path)
  ---@type ScratchComment?
  local added
  ui.open_frame({
    title = title(file_path, start_line, end_line),
    context = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false),
    filetype = vim.bo[bufnr].filetype,
    comment = "",
    on_save = function(text)
      if added then
        state.update(added.id, { comment = text })
        return
      end
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end
      added = state.add({
        bufnr = bufnr,
        comment = text,
        file_path = file_path,
        relative_path = relative_path,
      })
      render.anchor(added, start_line, end_line)
      render.draw_signs(bufnr, state.in_buffer(bufnr))
      ui.notify("Added comment", "info")
    end,
  })
end

---@param view ScratchCommentView
---@return string
local function describe(view)
  local lines = view.start_line == view.end_line and tostring(view.start_line)
    or (view.start_line .. "-" .. view.end_line)
  return "lines " .. lines .. ": " .. ui.summary(view.comment)
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
  render.draw_signs(comment.bufnr, state.in_buffer(comment.bufnr))
  ui.notify("Deleted comment", "info")
end

function M.show_current()
  local views = cursor_comments()
  if #views == 0 then
    ui.notify("No comment at cursor", "info")
    return
  end
  choose(views, function(view)
    open_frame(view)
  end)
end

---@param direction 1|-1
function M.jump(direction)
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local starts = {}
  for _, view in ipairs(state.anchored()) do
    if view.bufnr == bufnr then
      starts[view.start_line] = true
    end
  end
  local lines = vim.tbl_keys(starts)
  if #lines == 0 then
    ui.notify("No comments in this buffer", "info")
    return
  end
  table.sort(lines)

  local target
  if direction == 1 then
    for _, start_line in ipairs(lines) do
      if start_line > line then
        target = start_line
        break
      end
    end
    target = target or lines[1]
  else
    for i = #lines, 1, -1 do
      if lines[i] < line then
        target = lines[i]
        break
      end
    end
    target = target or lines[#lines]
  end

  vim.cmd("normal! m'")
  vim.api.nvim_win_set_cursor(0, { target, 0 })
end

function M.edit_current()
  local views = cursor_comments()
  if #views == 0 then
    ui.notify("No comment at cursor", "info")
    return
  end
  choose(views, edit)
end

function M.delete_current()
  local views = cursor_comments()
  if #views > 0 then
    choose(views, delete)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local orphans = vim.tbl_filter(render.is_orphaned, state.in_buffer(bufnr))
  if #orphans == 0 then
    ui.notify("No comment at cursor", "info")
    return
  end

  vim.ui.select(orphans, {
    prompt = "Delete orphaned comment: ",
    format_item = function(comment)
      return ui.summary(comment.comment)
    end,
  }, function(comment)
    if comment then
      delete(comment)
    end
  end)
end

return M
