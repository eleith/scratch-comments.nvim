std = "luajit"
cache = false

-- Neovim's global. Snacks is never required, only referenced defensively.
read_globals = { "vim" }

ignore = {
  "212", -- unused argument
}

files["tests/"] = {
  -- tests monkeypatch vim.ui.* and module functions
  globals = { "vim" },
}
