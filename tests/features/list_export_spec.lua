local clipboard = require("scratch_comments.export")
local helpers = require("helpers")
local scratch = require("scratch_comments")
local expect = MiniTest.expect

local copy = clipboard.copy
local copied
local source

before_each(function()
  helpers.reset()
  copied = nil
  ---@diagnostic disable-next-line: duplicate-set-field -- test fake
  clipboard.copy = function(text)
    copied = text
    return true
  end
  source = helpers.buffer("export-fixture.lua", { "local a = 1", "local b = 2", "local c = 3" })
  vim.cmd("3Comment")
  helpers.write("on c")
  vim.cmd("1Comment")
  helpers.write("on a")
end)

after_each(function()
  clipboard.copy = copy
end)

describe("json", function()
  it("lists every comment in position order, with its lines and text", function()
    local data = vim.json.decode(scratch.render("json"))
    expect.equality(#data.comments, 2)
    expect.equality(data.comments[1].comment, "on a")
    expect.equality(data.comments[1].start_line, 1)
    expect.equality(data.comments[1].snippet, "local a = 1")
  end)

  it("always has an orphaned list, encoded as an array", function()
    expect.equality(#vim.json.decode(scratch.render("json")).orphaned, 0)
    expect.no_equality(scratch.render("json"):find('"orphaned": []', 1, true), nil)
  end)
end)

describe(":CommentExport", function()
  it("copies json", function()
    vim.cmd("CommentExport json")
    expect.equality(vim.json.decode(copied).comments[2].comment, "on c")
  end)

  it("copies nothing for an unknown format", function()
    vim.cmd("CommentExport bogus")
    expect.equality(copied, nil)
  end)
end)

describe(":CommentExport!", function()
  it("opens markdown in a scratch buffer by default", function()
    vim.cmd("CommentExport!")
    expect.equality(vim.bo.buftype, "nofile")
    expect.equality(vim.bo.filetype, "markdown")
    expect.no_equality(helpers.text():find("on a", 1, true), nil)
  end)

  it("opens json when asked", function()
    vim.cmd("CommentExport! json")
    expect.equality(vim.bo.filetype, "json")
  end)

  it("returns to the file when the scratch window closes", function()
    vim.cmd("CommentExport!")
    vim.cmd("close")
    expect.equality(vim.api.nvim_get_current_buf(), source)
  end)
end)
