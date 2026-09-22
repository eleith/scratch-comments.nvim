local scratch = require("scratch_comments")
local state = require("scratch_comments.state")

local function fail(message)
  error(message, 2)
end

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    fail(
      (message or "values differ")
        .. ": expected "
        .. vim.inspect(expected)
        .. ", got "
        .. vim.inspect(actual)
    )
  end
end

local function write(comment)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(comment, "\n"))
  vim.cmd("wq")
end

-- Headless edits share one undo block unless it is broken explicitly.
local function undo_break()
  vim.o.undolevels = vim.o.undolevels
end

local function select(keys)
  vim.cmd("normal! " .. keys .. "\27")
end

local function views()
  return state.anchored()
end

local function lines_pane_title()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local config = vim.api.nvim_win_get_config(win)
    if config.relative ~= "" and win ~= vim.api.nvim_get_current_win() then
      return config.title[1][1]
    end
  end
end

vim.cmd.enew()
vim.cmd.file("spans-fixture.md")
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "the quick brown fox",
  "café → bar",
  "one two",
  "three four",
})

vim.api.nvim_win_set_cursor(0, { 1, 4 })
select("viw")
vim.cmd("'<,'>Comment")
assert_equal(
  lines_pane_title(),
  " spans-fixture.md [line 1, col 5–9] ",
  "the title names the columns"
)
write("on quick")
local quick = views()[1]
assert_equal(quick.snippet, "quick", "a selected word is the snippet")
assert_equal(quick.start_col, 4, "the span starts at the word")
assert_equal(quick.end_col, 9, "the span ends after the word")

vim.cmd("Comment")
write("on the line")
vim.cmd("1Comment")
assert_equal(#vim.api.nvim_list_wins(), 3, ":1Comment on the same line edits the line comment")
vim.cmd("q")
assert_equal(#views(), 2, "a line comment and a word comment are separate")
local line = vim.tbl_filter(function(view)
  return view.start_col == nil
end, views())[1]
assert_equal(line.snippet, "the quick brown fox", ":Comment without a selection covers the line")

vim.api.nvim_buf_set_text(0, 0, 4, 0, 4, { "very " })
local function quick_view()
  return vim.tbl_filter(function(view)
    return view.id == quick.id
  end, views())[1]
end
assert_equal(quick_view().snippet, "quick", "the span follows its text")

undo_break()
vim.api.nvim_buf_set_text(0, 0, 9, 0, 14, { "slow" })
assert_equal(quick_view(), nil, "replacing the word orphans its comment")
assert_equal(#state.orphans(), 1, "only the word comment is orphaned")
undo_break()
vim.cmd("silent undo")
assert_equal(quick_view().snippet, "quick", "undo restores the span")

local data = vim.json.decode(scratch.render("json"))
local exported = vim.tbl_filter(function(comment)
  return comment.id == quick.id
end, data.comments)[1]
assert_equal(exported.start_col, 10, "json columns are 1-based")
assert_equal(exported.end_col, 14, "json end column is the last byte")
vim.cmd("CommentClear")

vim.api.nvim_win_set_cursor(0, { 2, 0 })
select("v3l")
vim.cmd("'<,'>Comment")
write("on café")
assert_equal(views()[1].snippet, "café", "a multibyte character stays whole")
vim.cmd("CommentClear")

vim.api.nvim_win_set_cursor(0, { 3, 4 })
select("v$")
vim.cmd("'<,'>Comment")
write("to the end")
assert_equal(views()[1].snippet, "two", "a selection to $ ends at the line's end")
vim.cmd("CommentClear")

vim.api.nvim_win_set_cursor(0, { 3, 4 })
select("vj")
vim.cmd("'<,'>Comment")
assert_equal(
  lines_pane_title(),
  " spans-fixture.md [lines 3:5–4:5] ",
  "a span across lines uses line:col"
)
write("across lines")
assert_equal(views()[1].snippet, "two\nthree", "a selection can cross lines")
vim.cmd("CommentClear")

vim.api.nvim_win_set_cursor(0, { 3, 4 })
select("V")
vim.cmd("'<,'>Comment")
assert_equal(lines_pane_title(), " spans-fixture.md [line 3] ", "a line comment has no columns")
write("whole line")
assert_equal(views()[1].start_col, nil, "a linewise selection makes a line comment")
assert_equal(views()[1].snippet, "one two", "a linewise selection covers the line")

vim.cmd("CommentClear")

vim.cmd.file(("a-very-long-name"):rep(6) .. ".md")
vim.api.nvim_win_set_cursor(0, { 1, 4 })
select("viw")
vim.o.columns = 60
vim.cmd("'<,'>Comment")
local long_title = lines_pane_title()
assert_equal(vim.fn.strdisplaywidth(long_title), 56, "a long title fits the window")
assert_equal(long_title:sub(1, 4), " …", "a long title starts with an ellipsis")
assert_equal(
  vim.endswith(long_title, "name.md [line 1, col 5–9] "),
  true,
  "a long title keeps the range"
)
vim.cmd("q!")

print("spans: ok")
