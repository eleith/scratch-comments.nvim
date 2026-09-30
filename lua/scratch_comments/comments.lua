local anchors = require("scratch_comments.model.anchors")
local paths = require("scratch_comments.paths")
local signs = require("scratch_comments.ui.signs")
local store = require("scratch_comments.model.store")
local views = require("scratch_comments.model.views")

local M = {}

local group = vim.api.nvim_create_augroup("scratch_comments", { clear = true })
local watched = {}

---@param bufnr integer
function M.redraw(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
    signs.draw(bufnr, store.in_buffer(bufnr))
  end
end

---@return integer[]
local function commented_buffers()
  local seen = {}
  for _, comment in ipairs(store.all()) do
    if comment.bufnr then
      seen[comment.bufnr] = true
    end
  end
  return vim.tbl_keys(seen)
end

---@param fields { bufnr: integer, comment: string, file_path: string, source_name?: string, relative_path: string }
---@param location ScratchLocation
---@return ScratchComment
function M.add(fields, location)
  local comment = store.add({
    bufnr = fields.bufnr,
    comment = fields.comment,
    file_path = fields.file_path,
    relative_path = fields.relative_path,
    source_name = fields.source_name,
    last_location = vim.deepcopy(location),
    snippet = table.concat(
      views.text(
        fields.bufnr,
        location.start_line,
        location.end_line,
        location.start_col,
        location.end_col
      ),
      "\n"
    ),
    charwise = location.start_col ~= nil,
  })
  anchors.anchor(
    comment,
    location.start_line,
    location.end_line,
    location.start_col,
    location.end_col
  )
  M.redraw(fields.bufnr)
  return comment
end

---@param id string
---@param text string
---@return boolean edited false when the comment is gone
function M.edit(id, text)
  return store.update(id, { comment = text }) ~= nil
end

---@param comment ScratchComment
function M.delete(comment)
  anchors.clear_all(store.remove(function(candidate)
    return candidate.id == comment.id
  end))
  if comment.bufnr then
    M.redraw(comment.bufnr)
  end
end

function M.clear()
  for _, bufnr in ipairs(commented_buffers()) do
    anchors.clear_buffer(bufnr)
    signs.clear_buffer(bufnr)
  end
  store.clear()
end

-- Remember the latest live range for parking, or for a URI provider that
-- replaces an already-attached line without changing its contents.
---@param comment ScratchComment
---@param bufnr integer
---@return boolean
local function snapshot(comment, bufnr)
  local start_line, end_line, start_col, end_col = anchors.range(comment)
  if not start_line then
    return false
  end
  end_line = assert(end_line)
  comment.last_location = {
    start_line = start_line,
    end_line = end_line,
    start_col = start_col,
    end_col = end_col,
  }
  comment.snippet = table.concat(views.text(bufnr, start_line, end_line, start_col, end_col), "\n")
  return true
end

-- Snapshot while extmarks and text still exist. BufUnload, BufDelete and
-- BufWipeout can all fire for the same buffer; only the first does work.
---@param bufnr integer
function M.park_buffer(bufnr)
  for _, comment in ipairs(store.in_buffer(bufnr)) do
    if snapshot(comment, bufnr) then
      comment.state = "parked"
    else
      comment.state = "inactive"
    end
    anchors.clear_all({ comment })
    comment.bufnr, comment.extmark_id = nil, nil
  end
end

-- An active source may reopen under a different bufnr. Its old line number is
-- only trusted when the saved text still occupies that exact range.
---@param bufnr integer
---@param definitive? boolean true after a completed ordinary file read
function M.attach_buffer(bufnr, definitive)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end
  local name = vim.api.nvim_buf_get_name(bufnr)
  local is_uri = paths.is_uri(name)
  -- BufReadCmd providers can return from the command before asynchronously
  -- supplying any text. The initial empty line is not a completed read.
  if is_uri then
    local first = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
    if first == "" and vim.api.nvim_buf_line_count(bufnr) == 1 then
      return
    end
  end
  local changed = false
  for _, comment in ipairs(store.all()) do
    local where = comment.last_location
    local matches = false
    if
      (comment.source_name == name or comment.bufnr == bufnr)
      and where.end_line <= vim.api.nvim_buf_line_count(bufnr)
    then
      local ok, text =
        pcall(views.text, bufnr, where.start_line, where.end_line, where.start_col, where.end_col)
      matches = ok and table.concat(text, "\n") == comment.snippet
    end
    -- A provider may replace an already-matching line without changing its
    -- text. Reanchor that exact range; a changed or deleted line is an orphan.
    if is_uri and comment.bufnr == bufnr and anchors.is_orphaned(comment) then
      if matches then
        anchors.clear_all({ comment })
        anchors.anchor(comment, where.start_line, where.end_line, where.start_col, where.end_col)
      end
      changed = true
    end
    if comment.source_name == name and comment.state == "parked" then
      if matches then
        comment.bufnr = bufnr
        anchors.anchor(comment, where.start_line, where.end_line, where.start_col, where.end_col)
        comment.state = nil
        changed = true
      elseif definitive then
        comment.state = "inactive"
        changed = true
      end
    end
  end
  if changed then
    M.redraw(bufnr)
    require("scratch_comments.list").source_updated(bufnr)
  end
end

---@param on boolean
function M.show_signs(on)
  signs.set_visible(on)
  for _, bufnr in ipairs(commented_buffers()) do
    M.redraw(bufnr)
  end
end

vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
  group = group,
  callback = function(args)
    M.redraw(args.buf)
  end,
})

vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete", "BufWipeout" }, {
  group = group,
  callback = function(args)
    M.park_buffer(args.buf)
  end,
})

-- A read has completed for normal files. BufReadCmd sources may instead fill
-- the buffer later; watch their text changes without depending on the provider.
vim.api.nvim_create_autocmd("BufReadPost", {
  group = group,
  callback = function(args)
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(args.buf) then
        M.attach_buffer(args.buf, true)
      end
    end)
  end,
})

vim.api.nvim_create_autocmd("BufEnter", {
  group = group,
  callback = function(args)
    local bufnr = args.buf
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      local has_parked = vim.iter(store.all()):any(function(comment)
        return comment.source_name == name and comment.state == "parked"
      end)
      if not has_parked then
        return
      end
      if not watched[bufnr] then
        watched[bufnr] = vim.api.nvim_buf_attach(bufnr, false, {
          on_lines = function(_, _, _, first, last, new_last)
            -- The next provider change can invalidate the mark before a
            -- scheduled snapshot runs. Track line shifts above it immediately.
            for _, comment in ipairs(store.in_buffer(bufnr)) do
              local where = comment.last_location
              if first <= where.start_line - 1 and last <= where.start_line - 1 then
                local delta = new_last - last
                where.start_line = where.start_line + delta
                where.end_line = where.end_line + delta
              end
            end
            vim.schedule(function()
              if vim.api.nvim_buf_is_valid(bufnr) then
                for _, comment in ipairs(store.in_buffer(bufnr)) do
                  snapshot(comment, bufnr)
                end
                M.attach_buffer(bufnr)
              end
            end)
            if
              not paths.is_uri(name)
              and not vim.iter(store.all()):any(function(comment)
                return comment.source_name == name and comment.state == "parked"
              end)
            then
              return true
            end
          end,
          on_detach = function()
            watched[bufnr] = nil
          end,
        })
      end
      -- A previously loaded file can be reentered without a read event. For
      -- URI buffers an initial empty pane may still be waiting for BufReadCmd.
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)
      if not paths.is_uri(name) or lines[1] ~= "" then
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(bufnr) then
            M.attach_buffer(bufnr)
          end
        end)
      end
    end
  end,
})

return M
