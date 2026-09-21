vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.swapfile = false

require("scratch_comments").setup()
