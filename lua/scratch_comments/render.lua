local M = {}

local namespace = vim.api.nvim_create_namespace("scratch_comments")

local config = {
  sign_text = "C>",
  sign_hl_group = "ScratchCommentSign",
  virtual_text_prefix = " ",
  virtual_text_hl_group = "ScratchCommentVirtual",
  virtual_text_pos = "eol",
  max_comment_length = 80,
  priority = 120,
}

local function short_comment(text)
  local value = (text or ""):gsub("%s+", " ")
  local max_length = config.max_comment_length or 80
  if max_length > 3 and #value > max_length then
    return value:sub(1, max_length - 3) .. "..."
  end
  return value
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
  vim.api.nvim_set_hl(0, "ScratchCommentSign", { link = "DiagnosticInfo", default = true })
  vim.api.nvim_set_hl(0, "ScratchCommentVirtual", { link = "Comment", default = true })
end

function M.show(comment)
  if not comment.bufnr or not vim.api.nvim_buf_is_valid(comment.bufnr) then
    return
  end

  local line_count = vim.api.nvim_buf_line_count(comment.bufnr)
  if line_count < 1 then
    return
  end

  local line = math.max(0, math.min((comment.start_line or 1) - 1, line_count - 1))

  comment.extmark_id = vim.api.nvim_buf_set_extmark(comment.bufnr, namespace, line, 0, {
    sign_text = config.sign_text,
    sign_hl_group = config.sign_hl_group,
    virt_text = {
      {
        (config.virtual_text_prefix or "") .. short_comment(comment.comment),
        config.virtual_text_hl_group,
      },
    },
    virt_text_pos = config.virtual_text_pos,
    priority = config.priority,
  })
end

function M.clear(comment)
  if
    comment
    and comment.extmark_id
    and comment.bufnr
    and vim.api.nvim_buf_is_valid(comment.bufnr)
  then
    pcall(vim.api.nvim_buf_del_extmark, comment.bufnr, namespace, comment.extmark_id)
  end
end

function M.clear_all(items)
  for _, comment in ipairs(items) do
    M.clear(comment)
  end
end

function M.clear_buffer(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  end
end

return M
