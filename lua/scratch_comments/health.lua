local M = {}

function M.check()
  vim.health.start("scratch-comments")

  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim version is supported")
  else
    vim.health.warn("Neovim 0.10 or newer is required")
  end

  if vim.fn.has("clipboard") == 1 or vim.g.clipboard ~= nil then
    vim.health.ok("Clipboard provider is available for :CommentExport")
  else
    vim.health.warn(
      "No clipboard provider found. Install wl-clipboard, xclip or xsel, "
        .. "or set vim.g.clipboard = 'osc52'"
    )
  end
end

return M
