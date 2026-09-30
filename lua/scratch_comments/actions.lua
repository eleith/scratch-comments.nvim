local comments = require("scratch_comments.comments")
local location = require("scratch_comments.location")
local paths = require("scratch_comments.paths")
local store = require("scratch_comments.model.store")
local views = require("scratch_comments.model.views")
local notify = require("scratch_comments.ui.notify")
local card = require("scratch_comments.ui.card")
local signs = require("scratch_comments.ui.signs")
local window = require("scratch_comments.ui.window")

local M = {}

---@param bufnr integer
---@param start_line integer
---@param end_line integer
---@param start_col? integer
---@param end_col? integer
---@return ScratchCommentView?
local function find_anchor(bufnr, start_line, end_line, start_col, end_col)
  return vim.iter(views.in_buffer(bufnr)):find(function(view)
    return view.start_line == start_line
      and view.end_line == end_line
      and view.start_col == start_col
      and view.end_col == end_col
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

---@param id string
---@param text string
---@return boolean|string? "deleted" when saving removes the comment
local function save_existing(id, text)
  local comment = vim.iter(store.all()):find(function(candidate)
    return candidate.id == id
  end)
  if not comment then
    notify.warn("This comment is gone; nothing was saved")
    return false
  end
  if text == "" then
    comments.delete(comment)
    notify.info("Deleted comment")
    return "deleted"
  end
  comments.edit(id, text)
  notify.info("Updated comment")
end

---@param view ScratchComment|ScratchCommentView
---@param source_win integer
---@param on_close? fun()
---@param on_saved? fun()
function M.show(view, source_win, on_close, on_saved)
  local frame
  if view.start_line then
    frame = card.of(view --[[@as ScratchCommentView]])
  else
    frame = card.of_orphan(view)
  end
  frame.on_save = function(text)
    return save_existing(view.id, text)
  end
  window.open(frame, {
    id = view.id,
    bufnr = view.bufnr,
    source_name = view.source_name,
    line = view.start_line or view.last_location.start_line,
    source_win = source_win,
    on_close = on_close,
    on_saved = on_saved,
  })
end

-- Opens an editor for a comment that does not exist yet; it is created when
-- the window is first saved.
---@param bufnr integer
---@param file_path string
---@param where ScratchLocation
local function edit_new(bufnr, file_path, where)
  local relative_path = paths.is_uri(file_path) and file_path
    or paths.relative_path(paths.git_root(file_path), file_path)
  ---@type ScratchComment?
  local added
  ---@type ScratchCommentWindow
  local record =
    { bufnr = bufnr, line = where.start_line, source_win = vim.api.nvim_get_current_win() }
  window.open({
    title = location.title(file_path, where),
    context = views.text(bufnr, where.start_line, where.end_line, where.start_col, where.end_col),
    filetype = vim.bo[bufnr].filetype,
    comment = "",
    on_save = function(text)
      if added then
        return save_existing(added.id, text)
      end
      if text == "" or not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end
      added = comments.add({
        bufnr = bufnr,
        comment = text,
        file_path = file_path,
        source_name = file_path,
        relative_path = relative_path,
      }, where)
      record.id = added.id
      notify.info("Added comment")
    end,
  }, record)
end

---@param start_line integer
---@param end_line integer
---@param use_selection? boolean
function M.comment(start_line, end_line, use_selection)
  local bufnr = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    notify.warn("Save the buffer before commenting on it")
    return
  end

  ---@type ScratchLocation
  local where = {
    start_line = math.min(start_line, end_line),
    end_line = math.max(start_line, end_line),
  }
  if use_selection then
    where.start_col, where.end_col = selected_columns(where.start_line, where.end_line)
  end

  local existing =
    find_anchor(bufnr, where.start_line, where.end_line, where.start_col, where.end_col)
  if existing then
    M.show(existing, vim.api.nvim_get_current_win())
    return
  end

  edit_new(bufnr, paths.is_uri(name) and name or vim.fn.fnamemodify(name, ":p"), where)
end

---@param on? boolean
function M.toggle(on)
  if on == nil then
    on = not signs.is_visible()
  end
  comments.show_signs(on)
end

function M.clear()
  comments.clear()
  notify.info("Cleared comments")
end

return M
