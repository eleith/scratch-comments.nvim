local backdrop = require("scratch_comments.ui.backdrop")
local location = require("scratch_comments.location")
local notify = require("scratch_comments.ui.notify")

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
---@field comment_name? string name shown for the editable comment buffer
---@field on_save? fun(text: string): boolean|string? false keeps the text unsaved; "deleted" closes the editor
---@field comment_title? string
---@field on_close? fun()

---@class ScratchFramePanes
---@field context_win integer
---@field context_buf integer
---@field comment_win integer
---@field comment_buf integer
---@field backdrop_win? integer
---@field update fun(spec: ScratchFrame, preserve_comment?: boolean)

-- Two stacked floats, centered: the commented lines above, the comment below.
---@param frame ScratchFrame
---@param parent integer editing window to cover, not the quickfix list
---@return ScratchFramePanes
function M.open(frame, parent)
  ---@return { width: integer, col: integer, row: integer, context: integer, comment: integer, compact: boolean }
  local function layout()
    local lines = vim.api.nvim_win_get_height(parent)
    local columns = vim.api.nvim_win_get_width(parent)
    local compact = lines < 6
    local width = math.max(1, math.min(80, columns - (compact and 0 or 4)))
    if compact then
      -- Two bordered panes cannot fit. The comment covers the context pane,
      -- which stays open so edits and normal resizing keep the same buffers.
      return {
        width = width,
        col = math.floor((columns - width) / 2),
        row = 0,
        context = 1,
        comment = lines,
        compact = true,
      }
    end
    local available = lines - 4
    local context = math.max(1, math.min(#frame.context, math.floor(lines * 0.4), available - 1))
    local comment = math.max(
      1,
      math.min(
        math.max(#vim.split(frame.comment, "\n"), 5),
        math.floor(lines * 0.3),
        available - context
      )
    )
    return {
      width = width,
      col = math.floor((columns - width) / 2),
      -- Each pane has a top and a bottom border line.
      row = math.floor((lines - context - comment - 4) / 2),
      context = context,
      comment = comment,
      compact = false,
    }
  end

  local border = (vim.o.winborder == "" or vim.o.winborder == "none") and "rounded"
    or vim.o.winborder
  ---@param place table
  ---@return vim.api.keyset.win_config context
  ---@return vim.api.keyset.win_config comment
  local function placement(place)
    local narrow = place.width < 4
    return {
      relative = "win",
      win = parent,
      row = place.row,
      col = place.col,
      width = place.width,
      height = place.compact and place.comment or place.context,
      title = (place.compact or narrow) and ""
        or " " .. location.fit(frame.title, place.width - 2) .. " ",
      title_pos = "center",
      border = place.compact and "none" or border,
      zindex = 45,
    }, {
      relative = "win",
      win = parent,
      row = place.compact and place.row or place.row + place.context + 2,
      col = place.col,
      width = place.width,
      height = place.comment,
      border = place.compact and "none" or border,
      zindex = 50,
    }
  end

  local dim = backdrop.open(parent)
  local context_place, comment_place = placement(layout())
  local context_buf = frame_buffer(frame.context, frame.filetype)
  vim.bo[context_buf].modifiable = false
  local context_win = vim.api.nvim_open_win(
    context_buf,
    false,
    vim.tbl_extend("error", context_place, { style = "minimal" })
  )

  local comment_buf = frame_buffer(vim.split(frame.comment, "\n"), "markdown")
  if frame.comment_name then
    vim.api.nvim_buf_set_name(
      comment_buf,
      "scratch-comments://" .. comment_buf .. "/" .. frame.comment_name
    )
  end
  local comment_win = vim.api.nvim_open_win(
    comment_buf,
    true,
    vim.tbl_extend(
      "error",
      comment_place,
      { style = "minimal", title = " comment ", title_pos = "center" }
    )
  )
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

  local group = vim.api.nvim_create_augroup("scratch_comments_frame_" .. comment_win, {})
  local tab = vim.api.nvim_win_get_tabpage(parent)
  local function watch_parent()
    vim.api.nvim_create_autocmd("WinClosed", {
      group = group,
      pattern = tostring(parent),
      once = true,
      callback = function()
        vim.schedule(function()
          if
            not (
              vim.api.nvim_tabpage_is_valid(tab)
              and vim.api.nvim_win_is_valid(comment_win)
              and vim.api.nvim_win_is_valid(context_win)
            )
          then
            return
          end
          local file_win, other_win, qf_win
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
            if vim.api.nvim_win_get_config(win).relative == "" then
              local kind = vim.bo[vim.api.nvim_win_get_buf(win)].buftype
              if kind == "" then
                file_win = file_win or win
              elseif kind == "quickfix" then
                qf_win = win
              else
                other_win = other_win or win
              end
            end
          end
          local replacement = file_win or other_win
          if not replacement and qf_win then
            if not vim.bo[comment_buf].modified then
              vim.api.nvim_win_close(comment_win, true)
              return
            end
            -- Preserve unsaved text even if the editor cannot make a split.
            local ok, created = pcall(vim.api.nvim_win_call, qf_win, function()
              vim.cmd("aboveleft new")
              return vim.api.nvim_get_current_win()
            end)
            if not ok then
              notify.warn("No room for an editing window; save or discard the open card")
            end
            replacement = ok and created or qf_win
          end
          if replacement then
            parent = replacement
            backdrop.resize(dim, parent)
            local context_next, comment_next = placement(layout())
            vim.api.nvim_win_set_config(context_win, context_next)
            vim.api.nvim_win_set_config(comment_win, comment_next)
            watch_parent()
          end
        end)
      end,
    })
  end
  watch_parent()
  vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, {
    group = group,
    callback = function()
      if
        not (vim.api.nvim_win_is_valid(context_win) and vim.api.nvim_win_is_valid(comment_win))
      then
        backdrop.close(dim)
        pcall(vim.api.nvim_del_augroup_by_id, group)
        return
      end
      if not vim.api.nvim_win_is_valid(parent) then
        return
      end
      backdrop.resize(dim, parent)
      local context_resized, comment_resized = placement(layout())
      vim.api.nvim_win_set_config(context_win, context_resized)
      vim.api.nvim_win_set_config(comment_win, comment_resized)
    end,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(comment_win),
    once = true,
    callback = function()
      pcall(vim.api.nvim_win_close, context_win, true)
      backdrop.close(dim)
      pcall(vim.api.nvim_del_augroup_by_id, group)
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

  local panes = {
    context_win = context_win,
    context_buf = context_buf,
    comment_win = comment_win,
    comment_buf = comment_buf,
    backdrop_win = dim,
  }
  -- A parked comment can become orphaned when its source finishes loading.
  -- Update the context without discarding any edits to the comment.
  function panes.update(spec, preserve_comment)
    frame = spec
    if preserve_comment then
      spec.comment = table.concat(vim.api.nvim_buf_get_lines(comment_buf, 0, -1, false), "\n")
    end
    vim.bo[context_buf].modifiable = true
    vim.api.nvim_buf_set_lines(context_buf, 0, -1, false, spec.context)
    vim.bo[context_buf].modifiable = false
    vim.bo[context_buf].modified = false
    vim.bo[context_buf].filetype = spec.filetype
    if not preserve_comment then
      vim.bo[comment_buf].modifiable = true
      vim.api.nvim_buf_set_lines(comment_buf, 0, -1, false, vim.split(spec.comment, "\n"))
      vim.bo[comment_buf].modified = false
      vim.bo[comment_buf].modifiable = false
    end
    backdrop.resize(dim, parent)
    local context_next, comment_next = placement(layout())
    vim.api.nvim_win_set_config(context_win, context_next)
    vim.api.nvim_win_set_config(comment_win, comment_next)
  end
  return panes
end

return M
