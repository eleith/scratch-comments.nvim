local helpers = require("helpers")
local expect = MiniTest.expect

local file_win

local function cursor_line()
  return vim.api.nvim_win_get_cursor(file_win)[1]
end

---@param command string
---@return string lines the cursor visited, four steps
local function walk(command)
  local lines = {}
  for _ = 1, 4 do
    vim.cmd(command)
    table.insert(lines, cursor_line())
  end
  return table.concat(lines, ",")
end

before_each(function()
  helpers.reset()
  helpers.buffer("notes.md", { "1", "2", "3", "4", "5", "6", "7", "8" })
  file_win = vim.api.nvim_get_current_win()
  vim.cmd("2Comment")
  helpers.write("on two")
  vim.cmd("4,5Comment")
  helpers.write("on four and five")
  vim.cmd("4Comment")
  helpers.write("also on four")
  vim.cmd("7Comment")
  helpers.write("on seven")
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
end)

describe("without a comment open", function()
  it(":CommentNext visits each start line once, then wraps", function()
    expect.equality(walk("CommentNext"), "2,4,7,2")
  end)

  it(":CommentPrev goes back, then wraps", function()
    expect.equality(walk("CommentPrev"), "7,4,2,7")
  end)

  it("jumps can be undone with <C-o>", function()
    vim.cmd("CommentNext")
    vim.cmd([[execute "normal! \<C-o>"]])
    expect.equality(cursor_line(), 1)
  end)

  it("only moves the cursor", function()
    vim.cmd("CommentNext")
    expect.equality(#helpers.floats(), 0)
  end)
end)

describe("with a comment open", function()
  before_each(function()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.cmd("CommentShow")
  end)

  it("counts the file's comments", function()
    expect.equality(helpers.title(0), " comment (1 of 4) [NORMAL] ")
  end)

  it(":CommentNext shows each comment in turn, then wraps, the cursor following", function()
    local shown, lines = {}, {}
    for _ = 1, 4 do
      vim.cmd("CommentNext")
      table.insert(shown, helpers.text())
      table.insert(lines, cursor_line())
    end
    expect.equality(table.concat(shown, ","), "also on four,on four and five,on seven,on two")
    expect.equality(table.concat(lines, ","), "4,4,7,2")
    expect.equality(#helpers.floats(), 2)
    expect.equality(helpers.title(0), " comment (1 of 4) [NORMAL] ")
  end)

  it(":CommentPrev goes back", function()
    vim.cmd("CommentPrev")
    expect.equality(helpers.text(), "on seven")
  end)

  it("won't move while the comment has unsaved changes", function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved" })
    vim.cmd("CommentNext")
    expect.equality(helpers.text(), "unsaved")
  end)
end)

describe("from a new comment", function()
  it("moves to the next comment after its line", function()
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    vim.cmd("Comment")
    vim.cmd("stopinsert")
    vim.cmd("CommentNext")
    expect.equality(helpers.text(), "also on four")
  end)
end)
