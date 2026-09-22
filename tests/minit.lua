vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(assert(vim.env.MINI_TEST, "MINI_TEST is not set; run make test"))
vim.opt.swapfile = false
vim.opt.showmode = false
package.path = vim.fn.getcwd() .. "/tests/?.lua;" .. package.path

require("scratch_comments").setup()
require("mini.test").setup({
  collect = {
    find_files = function()
      return vim.fn.globpath("tests", "**/*_spec.lua", true, true)
    end,
  },
})
