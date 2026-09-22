local context = require("scratch_comments.context")
local render = require("scratch_comments.render")
local state = require("scratch_comments.state")
local ui = require("scratch_comments.ui")

local M = {}

---@param bufnr integer
---@param start_line integer
---@param end_line integer
---@param start_col? integer
---@param end_col? integer
---@return ScratchCommentView?
local function find_anchor(bufnr, start_line, end_line, start_col, end_col)
  return state.find(function(comment)
    return comment.bufnr == bufnr
      and comment.start_line == start_line
      and comment.end_line == end_line
      and comment.start_col == start_col
      and comment.end_col == end_col
  end)
end

---@param start_line integer
---@param end_line integer
---@return integer? start_col
---@return integer? end_col
local function selected_columns(start_line, end_line)
  local from, to = vim.fn.getpos("'<"), vim.fn.getpos("'>")
  if vim.fn.visualmode() ~= "v" or from[2] ~= start_line or to[2] ~= end_line then
    return nil, nil
  end
  local last_line = vim.fn.getline(end_line)
  local last = math.min(to[3], #last_line)
  local end_col = last == 0 and 0 or last + vim.str_utf_end(last_line, last)
  return from[3] - 1, end_col
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
---@param start_col? integer
---@param end_col? integer
---@return string
local function title(file_path, start_line, end_line, start_col, end_col)
  local name = vim.fn.fnamemodify(file_path, ":t")
  if start_col and end_col then
    local first, last = start_col + 1, end_col
    if start_line ~= end_line then
      return ("%s [lines %d:%d–%d:%d]"):format(name, start_line, first, end_line, last)
    end
    if first == last then
      return ("%s [line %d, col %d]"):format(name, start_line, first)
    end
    return ("%s [line %d, col %d–%d]"):format(name, start_line, first, last)
  end
  if start_line == end_line then
    return name .. " [line " .. start_line .. "]"
  end
  return name .. " [lines " .. start_line .. "–" .. end_line .. "]"
end

---@param view ScratchCommentView
---@param fields table on_save, on_close or comment_title for ui.open_frame
---@return integer comment_win
local function open_frame(view, fields)
  return ui.open_frame(vim.tbl_extend("error", {
    title = title(view.file_path, view.start_line, view.end_line, view.start_col, view.end_col),
    context = vim.split(view.snippet, "\n"),
    filetype = vim.bo[view.bufnr].filetype,
    comment = view.comment,
  }, fields))
end

---@class ScratchPreview
---@field id string
---@field bufnr integer
---@field source_win integer
---@field comment_win integer

---@type ScratchPreview?
local preview

---@param bufnr integer
---@return ScratchCommentView[]
local function file_views(bufnr)
  return vim.tbl_filter(function(view)
    return view.bufnr == bufnr
  end, state.anchored())
end

---@param views ScratchCommentView[]
---@param id string
---@return integer?
local function index_of(views, id)
  for i, view in ipairs(views) do
    if view.id == id then
      return i
    end
  end
end

---@param view ScratchCommentView
---@param source_win integer
local function show(view, source_win)
  local views = file_views(view.bufnr)
  local comment_win
  comment_win = open_frame(view, {
    comment_title = ("comment (%d of %d)"):format(index_of(views, view.id) or 0, #views),
    on_close = function()
      if preview and preview.comment_win == comment_win then
        preview = nil
      end
    end,
  })
  preview = { id = view.id, bufnr = view.bufnr, source_win = source_win, comment_win = comment_win }
end

---@param current ScratchPreview
---@param direction 1|-1
local function cycle_preview(current, direction)
  local views = file_views(current.bufnr)
  if #views == 0 then
    return
  end

  local index = index_of(views, current.id)
  local target
  if index then
    target = views[(index - 1 + direction) % #views + 1]
  else
    target = direction == 1 and views[1] or views[#views]
  end

  vim.api.nvim_win_close(current.comment_win, true)
  if vim.api.nvim_win_is_valid(current.source_win) then
    vim.api.nvim_win_call(current.source_win, function()
      vim.cmd("normal! m'")
      vim.api.nvim_win_set_cursor(0, { target.start_line, target.start_col or 0 })
    end)
  end
  show(target, current.source_win)
end

---@param view ScratchCommentView
local function edit(view)
  open_frame(view, {
    on_save = function(text)
      state.update(view.id, { comment = text })
      ui.notify("Updated comment", "info")
    end,
  })
end

---@param start_line integer
---@param end_line integer
---@param use_selection? boolean
function M.range(start_line, end_line, use_selection)
  local bufnr = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    ui.notify("Save the buffer before commenting on it", "warn")
    return
  end
  start_line, end_line = math.min(start_line, end_line), math.max(start_line, end_line)
  local start_col, end_col
  if use_selection then
    start_col, end_col = selected_columns(start_line, end_line)
  end

  local existing = find_anchor(bufnr, start_line, end_line, start_col, end_col)
  if existing then
    edit(existing)
    return
  end

  local file_path = vim.fn.fnamemodify(name, ":p")
  local relative_path = context.relative_path(context.git_root(file_path), file_path)
  ---@type ScratchComment?
  local added
  ui.open_frame({
    title = title(file_path, start_line, end_line, start_col, end_col),
    context = state.text(bufnr, start_line, end_line, start_col, end_col),
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
        charwise = start_col ~= nil,
      })
      render.anchor(added, start_line, end_line, start_col, end_col)
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
  local source_win = vim.api.nvim_get_current_win()
  choose(views, function(view)
    show(view, source_win)
  end)
end

---@param direction 1|-1
function M.jump(direction)
  if preview and vim.api.nvim_win_is_valid(preview.comment_win) then
    cycle_preview(preview, direction)
    return
  end

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
