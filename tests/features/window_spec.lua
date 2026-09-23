local helpers = require("helpers")
local expect = MiniTest.expect

local size
local source

before_each(function()
  helpers.reset()
  size = { vim.o.columns, vim.o.lines }
  source = helpers.buffer("notes.md", { "one", "two", "three", "four" })
  vim.cmd("1,3Comment")
  helpers.write("on one to three")
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.cmd("CommentShow")
end)

after_each(function()
  vim.o.columns, vim.o.lines = size[1], size[2]
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

  it("names an existing comment after its source file and line", function()
    local bufnr = vim.api.nvim_get_current_buf()
    expect.equality(
      vim.api.nvim_buf_get_name(bufnr),
      "scratch-comments://" .. bufnr .. "/notes.md:1 [comment]"
    )
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
    local lines_win, comment_win = helpers.panes()
    for _, win in ipairs({ lines_win, comment_win }) do
      local groups = vim.split(vim.wo[win].winhighlight, ",")
      expect.equality(groups[1], "NormalFloat:Normal")
      for _, group in ipairs(groups) do
        expect.equality(vim.endswith(group, ":Normal"), true)
      end
      expect.equality(#groups, 7)
    end
  end)

  it("follows the editor's size", function()
    vim.o.columns, vim.o.lines = 60, 20
    vim.api.nvim_exec_autocmds("VimResized", {})
    local lines_win, comment_win = helpers.panes()
    for _, win in ipairs({ lines_win, comment_win }) do
      local config = vim.api.nvim_win_get_config(win)
      expect.equality(config.width, 56)
      expect.equality(config.col, 2)
    end
    local top = vim.api.nvim_win_get_config(lines_win)
    local bottom = vim.api.nvim_win_get_config(comment_win)
    expect.equality(bottom.row, top.row + top.height + 2)
    expect.equality(top.height <= math.floor(20 * 0.4), true)
    expect.equality(helpers.title(lines_win), " notes.md [lines 1–3] ")
  end)

  it("closes on <Esc> in normal mode", function()
    vim.cmd([[execute "normal \<Esc>"]])
    expect.equality(#helpers.floats(), 0)
  end)

  it("stays open on <Esc> with unsaved changes", function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved" })
    vim.cmd([[execute "normal \<Esc>"]])
    expect.equality(#helpers.floats(), 2)
    expect.equality(helpers.notified()[#helpers.notified()], "Save with :w, or discard with :q!")
  end)

  it("closes on <Esc> from the lines pane too", function()
    vim.cmd("wincmd w")
    vim.cmd([[execute "normal \<Esc>"]])
    expect.equality(#helpers.floats(), 0)
  end)

  it("dims the editor behind it, and stops when it closes", function()
    local dim = vim.tbl_filter(function(win)
      return vim.w[win].scratch_comments_backdrop
    end, helpers.every_float())
    expect.equality(#dim, 1)
    local config = vim.api.nvim_win_get_config(dim[1])
    expect.equality({ config.width, config.height }, { vim.o.columns, vim.o.lines })
    expect.equality(config.zindex < vim.api.nvim_win_get_config(0).zindex, true)
    expect.equality(vim.wo[dim[1]].winblend, 60)
    vim.cmd("quit")
    expect.equality(#helpers.every_float(), 0)
  end)

  it("takes its resize handler with it when it closes", function()
    local function handlers()
      return #vim.api.nvim_get_autocmds({ event = "VimResized" })
    end
    vim.cmd("quit")
    local baseline = handlers()
    vim.cmd("CommentShow")
    expect.equality(handlers() > baseline, true)
    vim.cmd("quit")
    expect.equality(handlers(), baseline)
  end)

  it("closes both panes when one closes", function()
    vim.cmd("close")
    expect.equality(#helpers.floats(), 0)
  end)
end)

describe("the border", function()
  local winborder

  before_each(function()
    winborder = vim.o.winborder
    vim.cmd("quit")
  end)

  after_each(function()
    vim.o.winborder = winborder
  end)

  it("is rounded when 'winborder' is not set", function()
    vim.o.winborder = ""
    vim.cmd("CommentShow")
    expect.equality(vim.api.nvim_win_get_config(0).border[1], "╭")
  end)

  it("follows 'winborder' when it is set", function()
    vim.o.winborder = "single"
    vim.cmd("CommentShow")
    expect.equality(vim.api.nvim_win_get_config(0).border[1], "┌")
  end)
end)
