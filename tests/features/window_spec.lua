local helpers = require("helpers")
local expect = MiniTest.expect

local source

before_each(function()
  helpers.reset()
  source = helpers.buffer("notes.md", { "one", "two", "three", "four" })
  vim.cmd("1,3Comment")
  helpers.write("on one to three")
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.cmd("CommentShow")
end)

describe("the comment window", function()
  it("shows the commented lines above the comment", function()
    local lines_win, comment_win = helpers.panes()
    expect.equality(#helpers.floats(), 2)
    expect.equality(helpers.text(vim.api.nvim_win_get_buf(comment_win)), "on one to three")
    expect.equality(helpers.text(vim.api.nvim_win_get_buf(lines_win)), "one\ntwo\nthree")
    expect.equality(helpers.text(source), "one\ntwo\nthree\nfour")
  end)

  it("titles the lines pane with the file and lines", function()
    expect.equality(helpers.title((helpers.panes())), " notes.md [lines 1–3] ")
  end)

  it("titles the comment pane with the count and mode", function()
    local _, comment_win = helpers.panes()
    expect.equality(helpers.title(comment_win), " comment (1 of 1) [NORMAL] ")
  end)

  it("shows the mode as it changes", function()
    local titles = {}
    vim.api.nvim_create_autocmd("ModeChanged", {
      buffer = 0,
      callback = function()
        table.insert(titles, helpers.title(0))
      end,
    })
    vim.cmd("normal! ihello")
    expect.equality(
      table.concat(titles, ","),
      " comment (1 of 1) [INSERT] , comment (1 of 1) [NORMAL] "
    )
  end)

  it("can edit the comment, but not the lines", function()
    local lines_win = helpers.panes()
    expect.equality(vim.bo.modifiable, true)
    expect.equality(vim.bo[vim.api.nvim_win_get_buf(lines_win)].modifiable, false)
  end)

  it("uses the editor background, padding included", function()
    expect.equality(vim.wo[(helpers.panes())].winhighlight, "NormalFloat:Normal,LineNr:Normal")
  end)

  it("closes both panes when one closes", function()
    vim.cmd("close")
    expect.equality(#helpers.floats(), 0)
  end)
end)
