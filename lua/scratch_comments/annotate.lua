local comments = require("scratch_comments.comments")
local location = require("scratch_comments.location")
local paths = require("scratch_comments.paths")
local views = require("scratch_comments.model.views")
local notify = require("scratch_comments.ui.notify")
local ui = require("scratch_comments.ui")
local window = require("scratch_comments.ui.window")

local M = {}

---@param bufnr integer
---@param start_line integer
---@param end_line integer
---@param start_col? integer
---@param end_col? integer
---@return ScratchCommentView?
local function find_anchor(bufnr, start_line, end_line, start_col, end_col)
  return views.find(function(comment)
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
  return views.find_all(function(comment)
    return comment.bufnr == bufnr and comment.start_line <= line and line <= comment.end_line
  end)
end

---@param view ScratchCommentView
---@param source_win integer
function M.show(view, source_win)
  local in_file = views.in_buffer(view.bufnr)
  window.open({
    title = location.title(view.file_path, view),
    context = vim.split(view.snippet, "\n"),
    filetype = vim.bo[view.bufnr].filetype,
    comment = view.comment,
    comment_title = ("comment (%d of %d)"):format(views.index_of(in_file, view.id) or 0, #in_file),
    on_save = function(text)
      comments.edit(view.id, text)
      notify.info("Updated comment")
    end,
  }, { id = view.id, bufnr = view.bufnr, line = view.start_line, source_win = source_win })
end

---@param start_line integer
---@param end_line integer
---@param use_selection? boolean
function M.range(start_line, end_line, use_selection)
  local bufnr = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    notify.warn("Save the buffer before commenting on it")
    return
  end
  start_line, end_line = math.min(start_line, end_line), math.max(start_line, end_line)
  local start_col, end_col
  if use_selection then
    start_col, end_col = selected_columns(start_line, end_line)
  end

  local existing = find_anchor(bufnr, start_line, end_line, start_col, end_col)
  if existing then
    M.show(existing, vim.api.nvim_get_current_win())
    return
  end

  local file_path = vim.fn.fnamemodify(name, ":p")
  local relative_path = paths.relative_path(paths.git_root(file_path), file_path)
  ---@type ScratchComment?
  local added
  ---@type ScratchCommentWindow
  local record = { bufnr = bufnr, line = start_line, source_win = vim.api.nvim_get_current_win() }
  window.open({
    title = location.title(file_path, {
      start_line = start_line,
      end_line = end_line,
      start_col = start_col,
      end_col = end_col,
    }),
    context = views.text(bufnr, start_line, end_line, start_col, end_col),
    filetype = vim.bo[bufnr].filetype,
    comment = "",
    on_save = function(text)
      if added then
        comments.edit(added.id, text)
        return
      end
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end
      added = comments.add({
        bufnr = bufnr,
        comment = text,
        file_path = file_path,
        relative_path = relative_path,
      }, {
        start_line = start_line,
        end_line = end_line,
        start_col = start_col,
        end_col = end_col,
      })
      record.id = added.id
      notify.info("Added comment")
    end,
  }, record)
end

---@param view ScratchCommentView
---@return string
local function describe(view)
  local lines = view.start_line == view.end_line and tostring(view.start_line)
    or (view.start_line .. "-" .. view.end_line)
  return "lines " .. lines .. ": " .. ui.summary(view.comment)
end

---@param candidates ScratchCommentView[]
---@param callback fun(view: ScratchCommentView)
local function choose(candidates, callback)
  if #candidates == 1 then
    callback(candidates[1])
    return
  end
  vim.ui.select(candidates, { prompt = "Comment: ", format_item = describe }, function(view)
    if view then
      callback(view)
    end
  end)
end

---@param comment ScratchComment
local function delete(comment)
  comments.delete(comment)
  notify.info("Deleted comment")
end

function M.show_current()
  local at_cursor = cursor_comments()
  if #at_cursor == 0 then
    notify.info("No comment at cursor")
    return
  end
  local source_win = vim.api.nvim_get_current_win()
  choose(at_cursor, function(view)
    M.show(view, source_win)
  end)
end

function M.delete_current()
  local at_cursor = cursor_comments()
  if #at_cursor > 0 then
    choose(at_cursor, delete)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local orphans = vim.tbl_filter(function(comment)
    return comment.bufnr == bufnr
  end, views.orphans())
  if #orphans == 0 then
    notify.info("No comment at cursor")
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
