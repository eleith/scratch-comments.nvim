local helpers = require("helpers")
local expect = MiniTest.expect

before_each(function()
  helpers.reset()
end)

describe(":checkhealth scratch_comments", function()
  it("reports the Neovim version and the clipboard", function()
    vim.cmd("silent checkhealth scratch_comments")
    local report = helpers.text()
    expect.no_equality(report:find("Neovim version is supported", 1, true), nil)
    expect.no_equality(report:find("lipboard", 1, true), nil)
  end)
end)
