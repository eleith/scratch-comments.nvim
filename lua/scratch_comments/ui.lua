local M = {}

local function level(name)
  return vim.log.levels[(name or "info"):upper()] or vim.log.levels.INFO
end

---@param message string
---@param kind? "info"|"warn"|"error"
function M.notify(message, kind)
  vim.schedule(function()
    local opts = { title = "scratch-comments" }
    if kind == "error" or kind == "warn" then
      opts.timeout = 10000
    end
    vim.notify(message, level(kind), opts)
  end)
end

---@param text string
---@return string
function M.summary(text)
  return vim.split(text, "\n")[1]
end

---@param lines string[]
---@param filetype string
---@return integer bufnr
local function frame_buffer(lines, filetype)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modified = false
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].filetype = filetype
  return bufnr
end

---@class ScratchFrame
---@field title string
---@field context string[]
---@field filetype string
---@field comment string
---@field on_save? fun(text: string)

---@param frame ScratchFrame
function M.open_frame(frame)
  local comment_lines = vim.split(frame.comment, "\n")
  local width = math.min(80, vim.o.columns - 4)
  local context_height = math.min(#frame.context, math.floor(vim.o.lines * 0.4))
  local comment_height = math.min(math.max(#comment_lines, 5), math.floor(vim.o.lines * 0.3))
  -- Each pane has a top and a bottom border line.
  local row = math.floor((vim.o.lines - context_height - comment_height - 4) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local border = vim.o.winborder == "" and "rounded" or nil

  local context_buf = frame_buffer(frame.context, frame.filetype)
  vim.bo[context_buf].modifiable = false
  local context_win = vim.api.nvim_open_win(context_buf, false, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = context_height,
    border = border,
    title = " " .. frame.title .. " ",
    title_pos = "center",
    style = "minimal",
  })

  local comment_buf = frame_buffer(comment_lines, "markdown")
  local comment_win = vim.api.nvim_open_win(comment_buf, true, {
    relative = "editor",
    row = row + context_height + 2,
    col = col,
    width = width,
    height = comment_height,
    border = border,
    title = " comment ",
    title_pos = "center",
    footer = frame.on_save and " :wq save · :q! cancel " or nil,
    footer_pos = frame.on_save and "center" or nil,
    style = "minimal",
  })
  vim.wo[comment_win].wrap = true
  vim.wo[comment_win].linebreak = true
  for _, win in ipairs({ context_win, comment_win }) do
    vim.wo[win].winhighlight = "NormalFloat:Normal"
  end

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(comment_win),
    once = true,
    callback = function()
      pcall(vim.api.nvim_win_close, context_win, true)
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(context_win),
    once = true,
    callback = function()
      -- Not forced, so an unsaved comment stays open instead of being lost.
      pcall(vim.api.nvim_win_close, comment_win, false)
    end,
  })
  for _, buf in ipairs({ context_buf, comment_buf }) do
    vim.keymap.set("n", "<Esc>", "<Cmd>quit<CR>", { buffer = buf, desc = "Close" })
  end

  if not frame.on_save then
    vim.bo[comment_buf].modifiable = false
    return
  end

  vim.bo[comment_buf].buftype = "acwrite"
  vim.api.nvim_buf_set_name(comment_buf, "scratch-comments://" .. comment_buf)
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = comment_buf,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(comment_buf, 0, -1, false)
      local text = vim.trim(table.concat(lines, "\n"))
      if text ~= "" then
        frame.on_save(text)
      end
      vim.bo[comment_buf].modified = false
    end,
  })
  if frame.comment == "" then
    vim.cmd.startinsert()
  end
end

---@param text string
---@param filetype string
function M.open_scratch(text, filetype)
  vim.cmd.new()
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
  vim.bo.filetype = filetype
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(text, "\n"))
end

-- Quickfix rather than a picker: any quickfix front-end (Trouble, Snacks,
-- Telescope, nvim-bqf) can display it.
---@param items ScratchCommentView[]
---@param orphans ScratchComment[]
function M.list(items, orphans)
  if #items + #orphans == 0 then
    M.notify("No comments", "info")
    return
  end

  local entries = vim.tbl_map(function(comment)
    return {
      filename = comment.file_path,
      lnum = comment.start_line,
      end_lnum = comment.end_line,
      text = M.summary(comment.comment),
    }
  end, items)
  for _, comment in ipairs(orphans) do
    table.insert(
      entries,
      { filename = comment.file_path, text = "[orphaned] " .. M.summary(comment.comment) }
    )
  end

  vim.fn.setqflist({}, " ", { title = "Comments", items = entries })
  vim.cmd.copen()
end

return M
