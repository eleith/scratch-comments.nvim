local clipboard = require("scratch_comments.export.clipboard")
local helpers = require("helpers")
local scratch = require("scratch_comments")
local store = require("scratch_comments.model.store")
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

describe("the comment list manager", function()
  it("edits a comment in the same card, then refreshes the list", function()
    vim.cmd("CommentList")
    local id = vim.fn.getqflist()[1].user_data.scratch_comments_id
    vim.cmd.Comment()
    expect.equality(helpers.text(), "on a")
    expect.equality(vim.bo.modifiable, true)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "revised" })
    vim.cmd.write()
    expect.equality(vim.fn.getqflist()[1].text, "revised")
    vim.cmd.quit()
    vim.wait(0)
    expect.equality(vim.bo.buftype, "quickfix")
    expect.equality(vim.fn.getqflist()[1].text, "revised")
    expect.equality(vim.fn.getqflist()[1].user_data.scratch_comments_id, id)
    vim.cmd.cclose()
  end)

  it("doesn't reopen a list the user closed while editing", function()
    vim.cmd.CommentList()
    vim.cmd.Comment()
    vim.cmd.cclose()
    vim.cmd.quit()
    vim.wait(0)
    expect.equality(vim.fn.getqflist({ winid = 0 }).winid, 0)
  end)

  it("leaves the source cursor alone while browsing", function()
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    local source_win = vim.api.nvim_get_current_win()
    vim.cmd.CommentList()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = 0 })
    expect.equality(vim.api.nvim_win_get_cursor(source_win)[1], 1)
    vim.cmd("normal \r")
    expect.equality(vim.api.nvim_win_get_cursor(source_win)[1], 3)
    expect.equality(#helpers.every_float(), 0)
  end)

  it("doesn't return an orphan editor to another plugin's quickfix list", function()
    vim.cmd("1d")
    helpers.text_changed()
    local file_win = vim.api.nvim_get_current_win()
    vim.cmd.CommentList()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.cmd.Comment()
    vim.fn.setqflist({}, " ", { items = { { filename = "other.lua", lnum = 1, text = "other" } } })
    vim.cmd.quit()
    vim.api.nvim_set_current_win(file_win)
    vim.wait(0)
    expect.equality(vim.api.nvim_get_current_win(), file_win)
  end)

  it("keeps focus on an export replacing a manager-opened card", function()
    vim.cmd.CommentList()
    vim.cmd.Comment()
    vim.cmd("CommentExport!")
    vim.wait(0)
    expect.equality(vim.bo.buftype, "nofile")
    expect.equality(vim.bo.filetype, "markdown")
    vim.cmd.cclose()
  end)

  it("edits a comment whose source was wiped", function()
    vim.cmd("bwipeout! " .. source)
    vim.cmd.CommentList()
    vim.cmd.Comment()
    expect.equality(helpers.text(), "on a")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "revised parked" })
    vim.cmd("wq")
    vim.wait(0)
    expect.equality(vim.fn.getqflist()[1].text, "revised parked")
    expect.equality(store.all()[2].state, "parked")
    vim.cmd.cclose()
  end)

  it("does not guess a jump for an orphan; :Comment opens its card", function()
    vim.cmd("1d")
    helpers.text_changed()
    vim.cmd.CommentList()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = 0 })
    local qf_win = vim.api.nvim_get_current_win()
    vim.cmd("normal \r")
    expect.equality(vim.api.nvim_get_current_win(), qf_win)
    expect.equality(#helpers.every_float(), 0)
    expect.equality(
      helpers.notified()[#helpers.notified()],
      "This comment has no source location; use :Comment to edit it"
    )
    vim.cmd.Comment()
    expect.equality(helpers.text(), "on a")
    local dim = vim.iter(helpers.every_float()):find(function(win)
      return vim.w[win].scratch_comments_backdrop
    end)
    local parent = assert(vim.api.nvim_win_get_config(dim).win)
    expect.equality(vim.api.nvim_win_get_buf(parent), source)
    expect.no_equality(parent, qf_win)
    vim.cmd.quit()
    vim.wait(0)
    expect.equality(vim.api.nvim_get_current_win(), qf_win)
    expect.equality(vim.bo.buftype, "quickfix")
  end)

  it("places an orphan card over a file, not an export scratch split", function()
    vim.cmd("1d")
    helpers.text_changed()
    vim.cmd("CommentExport!")
    expect.equality(vim.bo.buftype, "nofile")
    vim.cmd.CommentList()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.cmd.Comment()
    local dim = vim.iter(helpers.every_float()):find(function(win)
      return vim.w[win].scratch_comments_backdrop
    end)
    local parent = assert(vim.api.nvim_win_get_config(dim).win)
    expect.equality(vim.api.nvim_win_get_buf(parent), source)
  end)

  it("makes a file area if only quickfix remains for an orphan", function()
    vim.cmd("1d")
    helpers.text_changed()
    vim.cmd.CommentList()
    local qf_win = vim.api.nvim_get_current_win()
    local file_win = vim.fn.bufwinid(vim.api.nvim_buf_get_name(source))
    vim.api.nvim_win_close(file_win, true)
    vim.api.nvim_win_set_cursor(qf_win, { 2, 0 })
    vim.cmd.Comment()
    local dim = vim.iter(helpers.every_float()):find(function(win)
      return vim.w[win].scratch_comments_backdrop
    end)
    local parent = assert(vim.api.nvim_win_get_config(dim).win)
    expect.no_equality(parent, qf_win)
    expect.equality(vim.api.nvim_win_is_valid(qf_win), true)
    vim.cmd.quit()
    vim.wait(0)
    expect.equality(vim.api.nvim_get_current_win(), qf_win)
  end)

  it("keeps quickfix usable if there is no room to open an orphan card", function()
    vim.cmd("1d")
    helpers.text_changed()
    vim.cmd.CommentList()
    local qf_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_close(vim.fn.bufwinid(vim.api.nvim_buf_get_name(source)), true)
    local min_height, preferred = vim.o.winminheight, vim.o.winheight
    local ok = pcall(function()
      vim.o.winheight = 12
      vim.o.winminheight = 12
      vim.api.nvim_win_set_cursor(qf_win, { 2, 0 })
      vim.cmd.Comment()
    end)
    vim.o.winminheight = min_height
    vim.o.winheight = preferred
    expect.equality(ok, true)
    expect.equality(vim.api.nvim_get_current_win(), qf_win)
    expect.equality(#helpers.floats(), 0)
    expect.equality(
      helpers.notified()[#helpers.notified()],
      "Make room for an editing window to open this comment"
    )
  end)

  it("deletes an orphan by saving its card empty", function()
    vim.api.nvim_set_current_buf(source)
    vim.cmd("1d")
    helpers.text_changed()
    vim.cmd.CommentList()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = 0 })
    vim.cmd.Comment()
    expect.equality(helpers.text(), "on a")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
    vim.cmd.write()
    vim.wait(0)
    expect.equality(#store.all(), 1)
    expect.equality(vim.bo.buftype, "quickfix")
    expect.equality(#vim.fn.getqflist(), 1)
    vim.cmd.cclose()
  end)

  it("deletes the opened comment and keeps the filtered list", function()
    vim.cmd("CommentList export-fixture")
    local removed = vim.fn.getqflist()[1].user_data.scratch_comments_id
    vim.cmd.Comment()
    vim.cmd.CommentDelete()
    expect.equality(#store.all(), 1)
    expect.no_equality(store.all()[1].id, removed)
    expect.equality(#vim.fn.getqflist(), 1)
    vim.cmd.cclose()
  end)

  it("lists and exports comments after their source was wiped", function()
    vim.cmd("bwipeout! " .. source)
    local data = vim.json.decode(scratch.render("json"))
    expect.equality(#data.comments, 2)
    expect.equality(data.comments[1].snippet, "local a = 1")
    vim.cmd.CommentList()
    expect.equality(#vim.fn.getqflist(), 2)
    vim.cmd.cclose()
  end)

  it("deletes a parked comment after opening its card", function()
    vim.cmd("bwipeout! " .. source)
    expect.equality(#store.all(), 2)
    vim.cmd.CommentList()
    vim.cmd.Comment()
    vim.cmd.CommentDelete()
    expect.equality(#store.all(), 1)
    expect.equality(store.all()[1].comment, "on c")
    vim.cmd.cclose()
  end)

  it("deletes a filtered orphan directly from quickfix", function()
    vim.cmd("1d")
    helpers.text_changed()
    vim.cmd("CommentList 1")
    local qf_win = vim.api.nvim_get_current_win()
    expect.equality(#vim.fn.getqflist(), 1)
    expect.equality(
      vim.fn.getqflist()[1].user_data.scratch_comments_id,
      vim.iter(store.all()):find(function(comment)
        return comment.comment == "on a"
      end).id
    )
    vim.cmd.CommentDelete()
    expect.equality(#store.all(), 1)
    expect.equality(store.all()[1].comment, "on c")
    expect.equality(vim.api.nvim_win_is_valid(qf_win), false)
  end)

  it("deletes an inactive comment from the list", function()
    vim.cmd.cclose()
    vim.api.nvim_set_current_buf(source)
    vim.cmd("1d")
    helpers.text_changed()
    vim.cmd.CommentList()
    local qf = vim.fn.getqflist()
    local index = vim.iter(qf):enumerate():find(function(_, item)
      return item.text:find("[orphaned]", 1, true) ~= nil
    end)
    vim.api.nvim_win_set_cursor(0, { index, 0 })
    vim.cmd.CommentDelete()
    expect.equality(#store.all(), 1)
    expect.equality(store.all()[1].comment, "on c")
    vim.cmd.cclose()
  end)

  it("does not open a card from another plugin's quickfix list", function()
    vim.cmd.CommentList()
    vim.fn.setqflist({}, " ", { items = { { filename = "other.lua", lnum = 1, text = "other" } } })
    vim.cmd.Comment()
    expect.equality(#helpers.every_float(), 0)
    expect.equality(helpers.notified()[#helpers.notified()], "Not a Scratch Comments list")
    vim.cmd.cclose()
  end)

  it("does not open a card for a stale quickfix row", function()
    vim.cmd.CommentList()
    local items = vim.fn.getqflist()
    items[1].user_data = {}
    vim.fn.setqflist({}, "r", { items = items })
    vim.cmd.Comment()
    expect.equality(#helpers.every_float(), 0)
    expect.equality(helpers.notified()[#helpers.notified()], "This comment is gone")
    vim.cmd.cclose()
  end)

  it("does not delete another plugin's quickfix entry", function()
    vim.cmd.CommentList()
    vim.fn.setqflist({}, " ", { items = { { filename = "other.lua", lnum = 1, text = "other" } } })
    vim.cmd.CommentDelete()
    expect.equality(#store.all(), 2)
    vim.cmd.cclose()
  end)

  it("jumps to a parked URI after a delayed read", function()
    local url = "review-test:///comments.lua"
    local pending
    vim.api.nvim_create_autocmd("BufReadCmd", {
      pattern = "review-test:///*",
      once = true,
      callback = function(args)
        pending = args.buf
      end,
    })
    vim.cmd("enew!")
    vim.api.nvim_buf_set_name(0, url)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first", "second" })
    vim.bo.bufhidden = "wipe"
    vim.cmd("2Comment")
    helpers.write("URI comment")
    local id = store.all()[#store.all()].id
    vim.cmd("enew!")
    vim.cmd.CommentList()
    local index
    for i, item in ipairs(vim.fn.getqflist()) do
      if item.user_data.scratch_comments_id == id then
        index = i
      end
    end
    vim.api.nvim_win_set_cursor(0, { index, 0 })
    vim.cmd("normal \r")
    local source_win = vim.fn.bufwinid(url)
    expect.equality(vim.api.nvim_win_get_buf(source_win), pending)
    expect.equality(store.all()[#store.all()].state, "parked")
    vim.api.nvim_buf_set_lines(pending, 0, -1, false, { "first", "second" })
    vim.wait(0)
    expect.equality(store.all()[#store.all()].state, nil)
    expect.equality(vim.api.nvim_win_get_cursor(source_win)[1], 2)
    vim.cmd.quit()
    vim.wait(0)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.api.nvim_buf_set_lines(pending, 0, 1, false, { "updated" })
    vim.wait(0)
    expect.equality(vim.api.nvim_win_get_cursor(0)[1], 1)
  end)

  local function jump_to_pending_source(url)
    local pending
    vim.api.nvim_create_autocmd("BufReadCmd", {
      pattern = "review-test:///*",
      once = true,
      callback = function(args)
        pending = args.buf
      end,
    })
    vim.cmd("enew!")
    vim.api.nvim_buf_set_name(0, url)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first", "second" })
    vim.bo.bufhidden = "wipe"
    vim.cmd("2Comment")
    helpers.write("async orphan")
    vim.cmd("enew!")
    vim.cmd.CommentList()
    local qf_win = vim.api.nvim_get_current_win()
    local id = store.all()[#store.all()].id
    local index = vim.iter(vim.fn.getqflist()):enumerate():find(function(_, item)
      return item.user_data.scratch_comments_id == id
    end)
    vim.api.nvim_win_set_cursor(qf_win, { index, 0 })
    vim.cmd("normal \r")
    return pending, qf_win
  end

  it("does not return to a closed list when a delayed read invalidates a location", function()
    local pending, qf_win = jump_to_pending_source("review-test:///closed-list.lua")
    local source_win = vim.api.nvim_get_current_win()
    vim.cmd.cclose()
    vim.api.nvim_buf_set_lines(pending, 0, -1, false, { "first", "changed" })
    vim.api.nvim_exec_autocmds("BufReadPost", { buffer = pending })
    vim.wait(0)
    expect.equality(store.all()[#store.all()].state, "inactive")
    expect.equality(vim.api.nvim_win_is_valid(qf_win), false)
    expect.equality(vim.api.nvim_get_current_win(), source_win)
  end)

  it(
    "does not enter a replacement quickfix list when a delayed read invalidates a location",
    function()
      local pending, qf_win = jump_to_pending_source("review-test:///replaced-list.lua")
      local source_win = vim.api.nvim_get_current_win()
      vim.fn.setqflist(
        {},
        " ",
        { items = { { filename = "other.lua", lnum = 1, text = "other" } } }
      )
      vim.api.nvim_buf_set_lines(pending, 0, -1, false, { "first", "changed" })
      vim.api.nvim_exec_autocmds("BufReadPost", { buffer = pending })
      vim.wait(0)
      expect.equality(store.all()[#store.all()].state, "inactive")
      expect.equality(vim.api.nvim_get_current_win(), source_win)
      expect.equality(vim.api.nvim_win_is_valid(qf_win), true)
      expect.equality(vim.fn.getqflist()[1].text, "other")
    end
  )

  it("doesn't move the source cursor after leaving an asynchronous jump", function()
    local url = "review-test:///late-cursor.lua"
    local pending
    vim.api.nvim_create_autocmd("BufReadCmd", {
      pattern = "review-test:///*",
      once = true,
      callback = function(args)
        pending = args.buf
      end,
    })
    vim.cmd.enew()
    vim.api.nvim_buf_set_name(0, url)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first", "second" })
    vim.bo.bufhidden = "wipe"
    vim.cmd("2Comment")
    helpers.write("late")
    vim.cmd("enew!")
    vim.cmd.CommentList()
    local qf_win = vim.api.nvim_get_current_win()
    local index = vim.iter(vim.fn.getqflist()):enumerate():find(function(_, item)
      return item.user_data.scratch_comments_id == store.all()[#store.all()].id
    end)
    vim.api.nvim_win_set_cursor(0, { index, 0 })
    vim.cmd("normal \r")
    local editor_win = vim.api.nvim_get_current_win()
    local source_win = vim.fn.bufwinid(url)
    vim.api.nvim_win_set_cursor(source_win, { 1, 0 })
    vim.api.nvim_set_current_win(qf_win)
    vim.api.nvim_set_current_win(editor_win)
    vim.api.nvim_buf_set_lines(pending, 0, -1, false, { "first", "second" })
    vim.wait(0)
    expect.equality(vim.api.nvim_win_get_cursor(source_win)[1], 1)
  end)

  it("does not navigate to stale source lines after a mismatched reload", function()
    vim.cmd.edit("tests/fixtures/lifecycle.txt")
    vim.api.nvim_buf_set_lines(0, 0, 1, false, { "unsaved source" })
    vim.cmd.Comment()
    helpers.write("comment on unsaved source")
    local wanted = store.all()[#store.all()].id
    vim.cmd("bdelete!")
    vim.cmd.CommentList()
    local qf_win = vim.api.nvim_get_current_win()
    local index = vim.iter(vim.fn.getqflist()):enumerate():find(function(_, item)
      return item.user_data.scratch_comments_id == wanted
    end)
    vim.api.nvim_win_set_cursor(0, { index, 0 })
    vim.cmd("normal \r")
    vim.wait(0)
    expect.equality(vim.api.nvim_get_current_win(), qf_win)
    expect.equality(#helpers.every_float(), 0)
    expect.equality(vim.fn.getqflist()[index].text:find("[orphaned]", 1, true), 1)
    vim.cmd.Comment()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved edit" })
    vim.wait(0)
    expect.equality(store.all()[#store.all()].state, "inactive")
    local context_win = helpers.panes()
    expect.equality(
      helpers.text(vim.api.nvim_win_get_buf(context_win)),
      "The lines this comment was on are gone."
    )
    expect.equality(helpers.text(), "unsaved edit")
    expect.equality(vim.bo.modified, true)
    vim.cmd("q!")
    vim.wait(0)
    expect.equality(vim.api.nvim_get_current_win(), qf_win)
  end)

  it("jumps to a parked file and restores its comment", function()
    vim.cmd("edit! tests/fixtures/lifecycle.txt")
    vim.cmd.Comment()
    helpers.write("in a real file")
    local wanted = store.all()[#store.all()].id
    vim.cmd("bdelete")
    vim.cmd.CommentList()
    local index
    for i, item in ipairs(vim.fn.getqflist()) do
      if item.user_data.scratch_comments_id == wanted then
        index = i
      end
    end
    vim.api.nvim_win_set_cursor(0, { index, 0 })
    vim.cmd("normal \r")
    vim.wait(0)
    expect.equality(vim.api.nvim_buf_get_name(0), store.all()[#store.all()].source_name)
    expect.equality(#helpers.every_float(), 0)
    expect.equality(store.all()[#store.all()].state, nil)
  end)
end)

describe("markdown", function()
  it("names a range's lines", function()
    vim.cmd("1,2Comment")
    helpers.write("on a and b")
    expect.no_equality(scratch.render():find("lines 1–2", 1, true), nil)
  end)
end)

describe(":CommentList with a filter", function()
  ---@return string[]
  local function listed()
    return vim.tbl_map(function(item)
      return item.text
    end, vim.fn.getqflist())
  end

  it("keeps only the comments that match", function()
    vim.cmd("CommentList 3")
    expect.equality(listed(), { "on c" })
    vim.cmd("cclose")
  end)

  it("matches the snippet and the path too", function()
    vim.cmd("CommentList local")
    expect.equality(#listed(), 2)
    vim.cmd("cclose")
    vim.cmd("CommentList fixture")
    expect.equality(#listed(), 2)
    vim.cmd("cclose")
  end)

  it("matches loosely, like a fuzzy finder", function()
    vim.cmd("CommentList lc3")
    expect.equality(listed(), { "on c" })
    vim.cmd("cclose")
  end)

  it("keeps the list in file and line order", function()
    helpers.buffer("a-first.md", { "alpha" })
    vim.cmd("Comment")
    helpers.write("also mentions local")
    vim.cmd("CommentList local")
    expect.equality(listed(), { "also mentions local", "on a", "on c" })
    vim.cmd("cclose")
  end)

  it("says so when nothing matches", function()
    vim.cmd("CommentList zzz")
    expect.equality(helpers.notified()[#helpers.notified()], "No comments")
  end)
end)

describe("one card at a time", function()
  it(":CommentList closes an open comment window without opening another", function()
    vim.cmd.CommentList()
    vim.cmd.Comment()
    expect.equality(#helpers.floats(), 2)
    vim.cmd("CommentList")
    expect.equality(#helpers.floats(), 0)
    expect.equality(vim.bo.buftype, "quickfix")
  end)

  it(":CommentList keeps an unsaved comment, and says so", function()
    vim.cmd.CommentList()
    vim.cmd.Comment()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved" })
    vim.cmd("CommentList")
    expect.equality(helpers.text(), "unsaved")
    expect.equality(helpers.notified()[#helpers.notified()], "Save or discard the comment first")
  end)

  it(":Comment keeps unsaved edits when selecting another row", function()
    vim.cmd.CommentList()
    local qf_win = vim.api.nvim_get_current_win()
    vim.cmd.Comment()
    local card_win = vim.api.nvim_get_current_win()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved" })
    vim.api.nvim_set_current_win(qf_win)
    vim.api.nvim_win_set_cursor(qf_win, { 2, 0 })
    vim.cmd.Comment()
    expect.equality(#helpers.floats(), 2)
    expect.equality(helpers.notified()[#helpers.notified()], "Save or discard the comment first")
    expect.equality(helpers.text(vim.api.nvim_win_get_buf(card_win)), "unsaved")
    vim.api.nvim_set_current_win(card_win)
    vim.cmd("q!")
  end)

  it(":CommentExport! closes the comment window first", function()
    vim.cmd.CommentList()
    vim.cmd.Comment()
    vim.cmd("CommentExport!")
    expect.equality(#helpers.every_float(), 0)
    expect.equality(vim.bo.buftype, "nofile")
  end)

  it("opens a new comment even with the list visible", function()
    vim.cmd("CommentList")
    vim.cmd("wincmd k")
    vim.cmd("2Comment")
    expect.equality(#helpers.floats(), 2)
    helpers.write("on b")
    expect.equality(#vim.fn.getqflist(), 3)
    expect.equality(vim.fn.getqflist()[2].text, "on b")
  end)
end)

describe("quickfix navigation", function()
  it("moves through entries without opening a card or moving the source cursor", function()
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    local source_win = vim.api.nvim_get_current_win()
    vim.cmd.CommentList()
    vim.cmd("normal j")
    expect.equality(vim.api.nvim_win_get_cursor(0)[1], 2)
    expect.equality(vim.fn.getqflist({ idx = 0 }).idx, 1)
    expect.equality(vim.api.nvim_win_get_cursor(source_win)[1], 1)
    expect.equality(#helpers.every_float(), 0)
  end)

  it("jumps on <CR> without opening a card", function()
    vim.cmd.CommentList()
    vim.cmd("normal j")
    vim.cmd("normal \r")
    expect.equality(vim.api.nvim_get_current_buf(), source)
    expect.equality(vim.api.nvim_win_get_cursor(0)[1], 3)
    expect.equality(#helpers.every_float(), 0)
  end)

  it("keeps the selected quickfix row when saving a card opened from source", function()
    vim.cmd.CommentList()
    local qf_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_cursor(qf_win, { 2, 0 })
    vim.cmd("wincmd k")
    vim.cmd.Comment()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "revised from source" })
    vim.cmd.write()
    expect.equality(vim.api.nvim_win_get_cursor(qf_win)[1], 2)
    expect.equality(vim.fn.getqflist()[1].text, "revised from source")
  end)

  it("refreshes the list when editing from the source after a jump", function()
    vim.cmd.CommentList()
    vim.cmd("normal \r")
    expect.equality(#helpers.every_float(), 0)
    vim.cmd.Comment()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "revised from source" })
    vim.cmd.write()
    expect.equality(vim.fn.getqflist()[1].text, "revised from source")
    vim.cmd.quit()
  end)

  it(":Comment edits the cursor row without moving the source cursor", function()
    local source_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_cursor(source_win, { 1, 0 })
    vim.cmd.CommentList()
    vim.cmd("normal j")
    vim.cmd.Comment()
    expect.equality(helpers.text(), "on c")
    expect.equality(vim.api.nvim_win_get_cursor(source_win)[1], 1)
    local dim = vim.iter(helpers.every_float()):find(function(win)
      return vim.w[win].scratch_comments_backdrop
    end)
    local config = vim.api.nvim_win_get_config(dim)
    expect.equality(config.relative, "win")
    expect.equality(config.win, source_win)
    expect.equality(config.height, vim.api.nvim_win_get_height(source_win))
    local qf_win = vim.fn.getqflist({ winid = 0 }).winid
    expect.equality(
      vim.fn.win_screenpos(source_win)[1] + config.height <= vim.fn.win_screenpos(qf_win)[1],
      true
    )
    vim.cmd.quit()
    vim.wait(0)
    expect.equality(vim.api.nvim_get_current_win(), qf_win)
    expect.equality(vim.api.nvim_win_get_cursor(source_win)[1], 1)
  end)

  it("does not jump away from unsaved card edits", function()
    local source_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_cursor(source_win, { 1, 0 })
    vim.cmd.CommentList()
    local qf_win = vim.api.nvim_get_current_win()
    vim.cmd.Comment()
    local card_win = vim.api.nvim_get_current_win()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved" })
    vim.api.nvim_set_current_win(qf_win)
    vim.api.nvim_win_set_cursor(qf_win, { 2, 0 })
    vim.cmd("normal \r")
    expect.equality(vim.api.nvim_get_current_win(), qf_win)
    expect.equality(vim.api.nvim_win_get_cursor(source_win)[1], 1)
    expect.equality(helpers.text(vim.api.nvim_win_get_buf(card_win)), "unsaved")
    expect.equality(helpers.notified()[#helpers.notified()], "Save or discard the comment first")
    vim.api.nvim_set_current_win(card_win)
    vim.cmd("q!")
  end)

  it("keeps another editing split visible behind the card", function()
    vim.cmd.vsplit()
    vim.cmd.CommentList()
    vim.cmd.Comment()
    local dim = vim.iter(helpers.every_float()):find(function(win)
      return vim.w[win].scratch_comments_backdrop
    end)
    local config = vim.api.nvim_win_get_config(dim)
    expect.equality(config.relative, "win")
    expect.equality(config.width < vim.o.columns, true)
    expect.equality(vim.api.nvim_win_get_buf(config.win), source)
  end)

  it("has nothing to dismiss on <Esc> before opening a card", function()
    vim.cmd.CommentList()
    vim.cmd([[execute "normal \<Esc>"]])
    expect.equality(vim.bo.buftype, "quickfix")
    expect.equality(#helpers.every_float(), 0)
  end)

  it("closes a clean editor on <Esc> from the list, but preserves unsaved edits", function()
    vim.cmd.CommentList()
    local qf_win = vim.api.nvim_get_current_win()
    vim.cmd.Comment()
    local comment_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_current_win(qf_win)
    vim.api.nvim_buf_set_lines(comment_buf, 0, -1, false, { "unsaved" })
    vim.cmd([[execute "normal \<Esc>"]])
    expect.equality(#helpers.floats(), 2)
    expect.equality(helpers.notified()[#helpers.notified()], "Save with :w, or discard with :q!")
    vim.bo[comment_buf].modified = false
    vim.cmd([[execute "normal \<Esc>"]])
    expect.equality(#helpers.every_float(), 0)
    expect.equality(vim.bo.buftype, "quickfix")
  end)

  it("does not leave any card behind when the list closes", function()
    vim.cmd.CommentList()
    vim.cmd.cclose()
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
