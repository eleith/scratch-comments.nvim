local helpers = require("helpers")
local scratch = require("scratch_comments")
local views = require("scratch_comments.model.views")
local expect = MiniTest.expect

---@param keys string a visual selection, such as "viw"
local function select(keys)
  vim.cmd("normal! " .. keys .. "\27")
end

local function lines_title()
  return helpers.title((helpers.panes()))
end

before_each(function()
  helpers.reset()
  helpers.buffer("spans.md", { "the quick brown fox", "café → bar", "one two", "three four" })
end)

describe("a charwise selection", function()
  before_each(function()
    vim.api.nvim_win_set_cursor(0, { 1, 4 })
    select("viw")
    vim.cmd("'<,'>Comment")
  end)

  it("names its columns in the title", function()
    expect.equality(lines_title(), " spans.md [line 1, col 5–9] ")
  end)

  it("makes a span over exactly the selected text", function()
    helpers.write("on quick")
    local quick = views.anchored()[1]
    expect.equality(quick.snippet, "quick")
    expect.equality(quick.start_col, 4)
    expect.equality(quick.end_col, 9)
  end)

  it("is separate from a comment on the whole line", function()
    helpers.write("on quick")
    vim.cmd("Comment")
    helpers.write("on the line")
    vim.cmd("1Comment")
    expect.equality(helpers.text(), "on the line")
    vim.cmd("quit")
    expect.equality(#views.anchored(), 2)
  end)
end)

describe("a span", function()
  local quick

  before_each(function()
    vim.api.nvim_win_set_cursor(0, { 1, 4 })
    select("viw")
    vim.cmd("'<,'>Comment")
    helpers.write("on quick")
    quick = views.anchored()[1]
  end)

  local function current()
    return vim.tbl_filter(function(view)
      return view.id == quick.id
    end, views.anchored())[1]
  end

  it("follows its text", function()
    vim.api.nvim_buf_set_text(0, 0, 4, 0, 4, { "very " })
    expect.equality(current().snippet, "quick")
  end)

  it("is orphaned when its text is replaced, and restored by undo", function()
    helpers.undo_break()
    vim.api.nvim_buf_set_text(0, 0, 4, 0, 9, { "slow" })
    expect.equality(current(), nil)
    expect.equality(#views.orphans(), 1)
    helpers.undo_break()
    vim.cmd("silent undo")
    expect.equality(current().snippet, "quick")
  end)

  it("exports 1-based columns to json, ending on the last byte", function()
    local exported = vim.json.decode(scratch.render("json")).comments[1]
    expect.equality(exported.start_col, 5)
    expect.equality(exported.end_col, 9)
  end)
end)

describe("a selection", function()
  it("keeps a multibyte character whole", function()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    select("v3l")
    vim.cmd("'<,'>Comment")
    helpers.write("on café")
    expect.equality(views.anchored()[1].snippet, "café")
  end)

  it("to $ ends at the end of the line", function()
    vim.api.nvim_win_set_cursor(0, { 3, 4 })
    select("v$")
    vim.cmd("'<,'>Comment")
    helpers.write("to the end")
    expect.equality(views.anchored()[1].snippet, "two")
  end)

  it("can cross lines, titled with line:col", function()
    vim.api.nvim_win_set_cursor(0, { 3, 4 })
    select("vj")
    vim.cmd("'<,'>Comment")
    expect.equality(lines_title(), " spans.md [lines 3:5–4:5] ")
    helpers.write("across lines")
    expect.equality(views.anchored()[1].snippet, "two\nthree")
  end)

  it("that is linewise makes a line comment", function()
    vim.api.nvim_win_set_cursor(0, { 3, 4 })
    select("V")
    vim.cmd("'<,'>Comment")
    expect.equality(lines_title(), " spans.md [line 3] ")
    helpers.write("whole line")
    expect.equality(views.anchored()[1].start_col, nil)
    expect.equality(views.anchored()[1].snippet, "one two")
  end)
end)

describe("a long title", function()
  local columns

  before_each(function()
    columns = vim.o.columns
    vim.cmd.file(("a-very-long-name"):rep(6) .. ".md")
    vim.api.nvim_win_set_cursor(0, { 1, 4 })
    select("viw")
    vim.o.columns = 60
    vim.cmd("'<,'>Comment")
  end)

  after_each(function()
    vim.o.columns = columns
  end)

  it("fits the window, cut from the left with an ellipsis, keeping the range", function()
    local title = lines_title()
    expect.equality(vim.api.nvim_strwidth(title), 56)
    expect.equality(title:sub(1, 4), " …")
    expect.equality(vim.endswith(title, "name.md [line 1, col 5–9] "), true)
  end)
end)
