local clipboard = require("scratch_comments.export.clipboard")
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
  it("copies markdown by default, keeping the comments", function()
    vim.cmd("CommentExport")
    expect.no_equality(copied:find("## export-fixture.lua", 1, true), nil)
    expect.no_equality(copied:find("on a", 1, true), nil)
    expect.equality(#vim.json.decode(scratch.render("json")).comments, 2)
  end)

  it("copies json", function()
    vim.cmd("CommentExport json")
    expect.equality(vim.json.decode(copied).comments[2].comment, "on c")
  end)

  it("says so when the clipboard can't be written", function()
    ---@diagnostic disable-next-line: duplicate-set-field -- test fake
    clipboard.copy = function()
      return false
    end
    vim.cmd("CommentExport")
    expect.equality(
      helpers.notified()[#helpers.notified()],
      "Could not copy to the clipboard; no provider configured?"
    )
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

describe(":CommentList", function()
  it("fills a titled quickfix list with one entry per comment", function()
    vim.cmd("CommentList")
    local qf = vim.fn.getqflist({ title = 1, items = 1 })
    expect.equality(qf.title, "Comments")
    expect.equality(#qf.items, 2)
    expect.equality(qf.items[1].text, "on a")
    vim.cmd("cclose")
  end)
end)

describe("markdown", function()
  it("names a range's lines", function()
    vim.cmd("1,2Comment")
    helpers.write("on a and b")
    expect.no_equality(scratch.render():find("lines 1–2", 1, true), nil)
  end)
end)

describe("the card beside the list", function()
  ---@return string
  local function card()
    local panes = vim.tbl_filter(function(win)
      return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "markdown"
    end, helpers.floats())
    return panes[1] and helpers.text(vim.api.nvim_win_get_buf(panes[1])) or ""
  end

  ---@param line integer
  local function move_to(line)
    vim.api.nvim_win_set_cursor(0, { line, 0 })
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = vim.api.nvim_get_current_buf() })
  end

  it("shows the comment the cursor is on, and follows it", function()
    vim.cmd("CommentList")
    expect.equality(card(), "on a")
    move_to(2)
    expect.equality(card(), "on c")
    move_to(1)
    expect.equality(card(), "on a")
  end)

  it("keeps the focus in the list", function()
    vim.cmd("CommentList")
    expect.equality(vim.bo.buftype, "quickfix")
  end)

  it("goes away with the list", function()
    vim.cmd("CommentList")
    vim.api.nvim_exec_autocmds("BufLeave", { buffer = vim.api.nvim_get_current_buf() })
    expect.equality(#helpers.every_float(), 0)
  end)
end)

describe("comments in several files", function()
  before_each(function()
    helpers.buffer("a-first.md", { "a" })
    vim.cmd("Comment")
    helpers.write("in a-first")
  end)

  it("are listed by file, then line", function()
    vim.cmd("CommentList")
    local files = vim.tbl_map(function(item)
      return vim.fn.fnamemodify(vim.fn.bufname(item.bufnr), ":t")
    end, vim.fn.getqflist())
    expect.equality(table.concat(files, ","), "a-first.md,export-fixture.lua,export-fixture.lua")
    vim.cmd("cclose")
  end)

  it("are exported by file, then line", function()
    local markdown = scratch.render()
    expect.equality(
      markdown:find("## a-first.md", 1, true) < markdown:find("## export-fixture.lua", 1, true),
      true
    )
  end)
end)

describe("a snippet containing a code fence", function()
  it("is fenced with four backticks", function()
    helpers.buffer("fence.md", { "```lua", "x = 1", "```" })
    vim.cmd("1,3Comment")
    helpers.write("on a fence")
    expect.no_equality(scratch.render():find("````md\n```lua", 1, true), nil)
  end)
end)
