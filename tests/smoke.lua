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

local function assert_not_contains(haystack, needle, message)
  if haystack:find(needle, 1, true) then
    fail((message or "unexpected text") .. ": " .. needle)
  end
end

local function count()
  return #state.all()
end

local function sign_at(line)
  local namespace = vim.api.nvim_get_namespaces().scratch_comments_signs
  local marks = vim.api.nvim_buf_get_extmarks(
    0,
    namespace,
    { line - 1, 0 },
    { line - 1, -1 },
    { details = true, overlap = true }
  )
  return marks[1] and vim.trim(marks[1][4].sign_text)
end

local inputs = {}
---@diagnostic disable-next-line: duplicate-set-field -- test fake
vim.ui.input = function(_, callback)
  callback(table.remove(inputs, 1))
end

local selections = {}
---@diagnostic disable-next-line: duplicate-set-field -- test fake
vim.ui.select = function(items, _, callback)
  local index = table.remove(selections, 1) or 1
  callback(items[index])
end

local copied
---@diagnostic disable-next-line: duplicate-set-field -- test fake
require("scratch_comments.export").copy = function(text)
  copied = text
  return true
end

vim.cmd.edit("README.md")
vim.api.nvim_win_set_cursor(0, { 1, 0 })

inputs = { "first comment" }
vim.cmd("Comment")
assert_equal(count(), 1, ":Comment should create a comment")
assert_contains(scratch.render(), "## README.md")
assert_contains(scratch.render(), "first comment")
assert_equal(sign_at(1), "│", "a one-line comment gets a single sign")

inputs = { "edited comment" }
vim.cmd("Comment")
assert_equal(count(), 1, "the same anchor should edit, not duplicate")
assert_contains(scratch.render(), "edited comment")
assert_not_contains(scratch.render(), "first comment")

inputs = { "range comment" }
vim.cmd("1,3Comment")
assert_equal(count(), 2, "a different anchor should add a second comment")
assert_contains(scratch.render(), "lines 1-3")

local function float_text()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      return table.concat(
        vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false),
        "\n"
      )
    end
  end
end

vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.cmd("CommentShow")
local shown = float_text() or fail(":CommentShow should open a float")
assert_contains(shown, "edited comment", ":CommentShow should show every comment at the cursor")
assert_contains(shown, "range comment", ":CommentShow should show every comment at the cursor")
assert_contains(shown, "─", ":CommentShow should separate comments with a rule")
vim.cmd("fclose!")

vim.api.nvim_win_set_cursor(0, { 1, 0 })
selections = { 2 }
inputs = { "picked the range" }
vim.cmd("CommentEdit")
assert_equal(count(), 2, ":CommentEdit should not duplicate")
assert_contains(scratch.render(), "picked the range")

vim.cmd("CommentExport")
assert_contains(copied or "", "picked the range", ":CommentExport should copy rendered markdown")
assert_equal(count(), 2, ":CommentExport must not clear comments")

vim.api.nvim_win_set_cursor(0, { 1, 0 })
selections = { 1 }
vim.cmd("CommentDelete")
assert_equal(count(), 1, ":CommentDelete should remove one comment")

vim.cmd("CommentClear")
assert_equal(count(), 0, ":CommentClear should remove every comment")
assert_equal(
  #vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_get_namespaces().scratch_comments, 0, -1, {}),
  0,
  ":CommentClear should remove extmarks"
)

inputs = { "quickfix check" }
vim.cmd("Comment")
vim.cmd("CommentList")
local qf = vim.fn.getqflist({ title = 1, items = 1 })
assert_equal(qf.title, "Comments", ":CommentList should title the quickfix list")
assert_equal(#qf.items, 1, ":CommentList should populate quickfix")
assert_equal(qf.items[1].text, "quickfix check", "quickfix entry should carry the comment text")
vim.cmd("cclose")
vim.cmd("CommentClear")

inputs = { "toggle check" }
vim.cmd("Comment")
vim.cmd("CommentToggle off")
assert_equal(sign_at(1), nil, ":CommentToggle off must hide signs")
vim.cmd("CommentToggle on")
assert_equal(sign_at(1), "│", ":CommentToggle on must show signs")
vim.cmd("CommentToggle")
assert_equal(sign_at(1), nil, ":CommentToggle must hide shown signs")
inputs = { "added while hidden" }
vim.cmd("2Comment")
assert_equal(sign_at(2), nil, "comments added while hidden have no sign")
vim.cmd("CommentToggle")
assert_equal(sign_at(2), "│", ":CommentToggle must show hidden signs")
vim.cmd("CommentClear")
assert_equal(sign_at(1), nil, ":CommentClear must remove signs")

inputs = { "on four lines" }
vim.cmd("2,5Comment")
assert_equal(sign_at(1), nil, "no sign above a range")
assert_equal(sign_at(2), "╭", "a range starts with its first sign")
assert_equal(sign_at(3), "│", "a range's middle lines get the middle sign")
assert_equal(sign_at(4), "│", "a range's middle lines get the middle sign")
assert_equal(sign_at(5), "╰", "a range ends with its last sign")
assert_equal(sign_at(6), nil, "no sign below a range")
vim.cmd("CommentClear")

vim.api.nvim_win_set_cursor(0, { 2, 0 })
inputs = { "on the cursor line" }
scratch.add()
inputs = { "on lines 4-5" }
scratch.add(4, 5)
local ranges = vim.tbl_map(function(comment)
  return comment.start_line .. "-" .. comment.end_line
end, state.anchored())
assert_equal(table.concat(ranges, ","), "2-2,4-5", "scratch.add() defaults to the cursor line")
vim.cmd("CommentClear")

vim.cmd.edit("LICENSE")
inputs = { "license comment" }
vim.cmd("Comment")
vim.cmd("edit!")
assert_equal(#state.anchored(), 1, ":e! must keep the buffer's comments")
vim.cmd("bdelete")
assert_equal(count(), 0, ":bd must drop the buffer's comments")

print("smoke: ok")
