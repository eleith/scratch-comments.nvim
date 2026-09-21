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

local function assert_contains(haystack, needle, message)
  if not haystack:find(needle, 1, true) then
    fail((message or "missing text") .. ": " .. needle)
  end
end

local inputs = {}
---@diagnostic disable-next-line: duplicate-set-field -- test fake
vim.ui.input = function(_, callback)
  callback(table.remove(inputs, 1))
end

local offered = {}
---@diagnostic disable-next-line: duplicate-set-field -- test fake
vim.ui.select = function(items, _, callback)
  offered = items
  callback(items[1])
end

-- Headless edits share one undo block unless it is broken explicitly.
local function undo_break()
  vim.o.undolevels = vim.o.undolevels
end

vim.cmd.enew()
vim.cmd.file("orphans-fixture.md")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "one", "two", "the quick fox", "four", "five" })

vim.api.nvim_win_set_cursor(0, { 3, 0 })
inputs = { "a comment on the fox" }
vim.cmd("Comment")

vim.cmd("normal! ccthe slow fox")
assert_equal(#state.anchored(), 1, "rewriting a line must keep its comment anchored")
assert_equal(#state.orphans(), 0, "rewriting a line must not orphan its comment")

undo_break()
vim.cmd("3d")
assert_equal(#state.anchored(), 0, "a comment whose lines are deleted is not anchored")
assert_equal(#state.orphans(), 1, "a comment whose lines are deleted is orphaned")

local markdown = scratch.render()
assert_contains(markdown, "## Orphaned", "export must list orphans in their own section")
assert_contains(markdown, "a comment on the fox", "export must keep the orphan's text")

vim.cmd("CommentList")
local entries = vim.fn.getqflist()
assert_equal(#entries, 1, "the list must include the orphan")
assert_contains(entries[1].text, "[orphaned]", "the list must mark the orphan")
vim.cmd("cclose")

undo_break()
vim.cmd("silent undo")
assert_equal(#state.orphans(), 0, "undo must re-anchor the orphan")
assert_equal(state.anchored()[1].start_line, 3, "undo must restore the comment's line")

undo_break()
vim.cmd("3d")
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.cmd("CommentDelete")
assert_equal(#offered, 1, ":CommentDelete must offer the orphan when no comment is at the cursor")
assert_equal(#state.orphans(), 0, ":CommentDelete must delete the chosen orphan")

state.clear()
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "a", "b", "c", "d", "e" })
inputs = { "a comment on b through d" }
vim.cmd("2,4Comment")
undo_break()
vim.cmd("3d")
assert_equal(#state.orphans(), 0, "deleting part of a range must not orphan the comment")
assert_equal(state.anchored()[1].end_line, 3, "deleting part of a range shrinks it")

print("orphans: ok")
