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

local text = "the quick brown fox"
local inputs = {}
---@diagnostic disable-next-line: duplicate-set-field -- test fake
vim.ui.input = function(_, callback)
  callback(table.remove(inputs, 1))
end

vim.cmd.enew()
vim.cmd.file("reflow-fixture.md")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "one", "two", text, "four", "five" })

vim.api.nvim_win_set_cursor(0, { 3, 0 })
inputs = { "a comment on the fox" }
vim.cmd("Comment")

local function only()
  return state.anchored()[1]
end

assert_equal(only().start_line, 3, "comment should anchor to line 3")

vim.api.nvim_buf_set_lines(0, 0, 0, false, { "new a", "new b", "new c" })

assert_equal(only().start_line, 6, "start_line must follow the text when lines are inserted above")
assert_equal(only().end_line, 6, "end_line must follow the text when lines are inserted above")
assert_equal(
  scratch.render():match("%- (line %d+)"),
  "line 6",
  "export must report the current line"
)

vim.api.nvim_buf_set_text(0, 5, 4, 5, 9, { "slow" })
assert_equal(
  only().snippet,
  "the slow brown fox",
  "snippet must be read live, not frozen at creation"
)

vim.api.nvim_buf_set_lines(0, 0, 3, false, {})
assert_equal(only().start_line, 3, "start_line must follow the text when lines above are deleted")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "a", "b", "c", "d", "e" })
state.clear()
inputs = { "a comment on b through d" }
vim.cmd("2,4Comment")
assert_equal(only().start_line, 2, "range start")
assert_equal(only().end_line, 4, "range end")

vim.api.nvim_buf_set_lines(0, 2, 2, false, { "inserted inside the range" })
assert_equal(only().start_line, 2, "range start holds when text is inserted inside")
assert_equal(only().end_line, 5, "range end must grow when text is inserted inside it")

vim.api.nvim_buf_set_lines(0, 4, 5, false, {})
assert_equal(only().end_line, 4, "deleting a range's last line must shrink it")
assert_equal(
  only().snippet,
  "b\ninserted inside the range\nc",
  "the range must not take in the next line"
)

print("reflow: ok")
