local backdrop = require("scratch_comments.ui.backdrop")
local location = require("scratch_comments.location")

local M = {}

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
---@field on_save fun(text: string)
---@field comment_title? string
---@field on_close? fun()

-- Two stacked floats, centered: the commented lines above, the comment below.
---@param frame ScratchFrame
---@return integer context_win
---@return integer comment_win
---@return integer comment_buf
---@return integer context_buf
function M.open(frame)
  local comment_lines = vim.split(frame.comment, "\n")
  local wanted_context = #frame.context
  local wanted_comment = math.max(#comment_lines, 5)

  ---@return { width: integer, col: integer, row: integer, context: integer, comment: integer }
  local function layout()
    local width = math.min(80, vim.o.columns - 4)
    local context = math.min(wanted_context, math.floor(vim.o.lines * 0.4))
    local comment = math.min(wanted_comment, math.floor(vim.o.lines * 0.3))
    return {
      width = width,
      col = math.floor((vim.o.columns - width) / 2),
      -- Each pane has a top and a bottom border line.
      row = math.floor((vim.o.lines - context - comment - 4) / 2),
      context = context,
      comment = comment,
    }
  end

  local dim = backdrop.open()
  local place = layout()
  local border = (vim.o.winborder == "" or vim.o.winborder == "none") and "rounded" or nil

  local context_buf = frame_buffer(frame.context, frame.filetype)
  vim.bo[context_buf].modifiable = false
  local context_win = vim.api.nvim_open_win(context_buf, false, {
    relative = "editor",
    row = place.row,
    col = place.col,
    width = place.width,
    height = place.context,
    border = border,
    title = " " .. location.fit(frame.title, place.width - 2) .. " ",
    title_pos = "center",
    style = "minimal",
  })

  local comment_buf = frame_buffer(comment_lines, "markdown")
  local comment_win = vim.api.nvim_open_win(comment_buf, true, {
    relative = "editor",
    row = place.row + place.context + 2,
    col = place.col,
    width = place.width,
    height = place.comment,
    border = border,
    title = " comment ",
    title_pos = "center",
    style = "minimal",
  })
  vim.wo[comment_win].wrap = true
  vim.wo[comment_win].linebreak = true
  for _, win in ipairs({ context_win, comment_win }) do
    -- The padding column draws in one of these, depending on the window's
    -- options, so all of them follow the window's background.
    vim.wo[win].winhighlight = table.concat({
      "NormalFloat:Normal",
      "LineNr:Normal",
      "LineNrAbove:Normal",
      "LineNrBelow:Normal",
      "CursorLineNr:Normal",
      "SignColumn:Normal",
      "FoldColumn:Normal",
    }, ",")
    vim.wo[win].statuscolumn = "  "
  end

  vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
      if not vim.api.nvim_win_is_valid(comment_win) then
        return true
      end
      local resized = layout()
      backdrop.resize(dim)
      vim.api.nvim_win_set_config(context_win, {
        relative = "editor",
        row = resized.row,
        col = resized.col,
        width = resized.width,
        height = resized.context,
        title = " " .. location.fit(frame.title, resized.width - 2) .. " ",
        title_pos = "center",
      })
      vim.api.nvim_win_set_config(comment_win, {
        relative = "editor",
        row = resized.row + resized.context + 2,
        col = resized.col,
        width = resized.width,
        height = resized.comment,
      })
    end,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(comment_win),
    once = true,
    callback = function()
      pcall(vim.api.nvim_win_close, context_win, true)
      backdrop.close(dim)
      if frame.on_close then
        frame.on_close()
      end
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

  return context_win, comment_win, comment_buf, context_buf
end

return M
