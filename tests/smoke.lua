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

local function write(comment)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(comment, "\n"))
  vim.cmd("wq")
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

vim.cmd("Comment")
write("first comment")
assert_equal(count(), 1, ":Comment should create a comment")
assert_contains(scratch.render(), "## README.md")
assert_contains(scratch.render(), "first comment")
assert_equal(sign_at(1), "│", "a one-line comment gets a single sign")

vim.cmd("Comment")
write("edited comment")
assert_equal(count(), 1, "the same anchor should edit, not duplicate")
assert_contains(scratch.render(), "edited comment")
assert_not_contains(scratch.render(), "first comment")

vim.cmd("1,3Comment")
write("range comment")
assert_equal(count(), 2, "a different anchor should add a second comment")
assert_contains(scratch.render(), "lines 1-3")

local function floats()
  return vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_config(win).relative ~= ""
  end, vim.api.nvim_list_wins())
end

local function text_of(win)
  return table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false), "\n")
end

local source = vim.api.nvim_get_current_buf()
vim.api.nvim_win_set_cursor(0, { 1, 0 })
selections = { 2 }
vim.cmd("CommentShow")
local comment_win = vim.api.nvim_get_current_win()
local context_win = vim.tbl_filter(function(win)
  return win ~= comment_win
end, floats())[1]
assert_equal(#floats(), 2, ":CommentShow opens the commented lines and the comment")
assert_equal(text_of(comment_win), "range comment", ":CommentShow shows the picked comment")
assert_equal(
  text_of(context_win),
  table.concat(vim.api.nvim_buf_get_lines(source, 0, 3, false), "\n"),
  ":CommentShow shows the commented lines"
)
assert_contains(
  vim.api.nvim_win_get_config(context_win).title[1][1],
  "README.md [lines 1–3]",
  "the frame is titled with the commented lines"
)
assert_equal(vim.bo.modifiable, false, ":CommentShow is read-only")
assert_equal(
  vim.bo[vim.api.nvim_win_get_buf(context_win)].modifiable,
  false,
  "the lines pane is read-only"
)
assert_equal(
  vim.wo[context_win].winhighlight,
  "NormalFloat:Normal",
  "the panes use the editor background"
)
vim.cmd("close")
assert_equal(#floats(), 0, "closing one pane closes the frame")

selections = { 2 }
vim.cmd("CommentShow")
vim.cmd("quit")
assert_equal(#floats(), 0, ":q closes the show window")

vim.api.nvim_win_set_cursor(0, { 1, 0 })
selections = { 2 }
vim.cmd("CommentEdit")
write("picked the range")
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

vim.cmd("Comment")
write("quickfix check")
vim.cmd("CommentList")
local qf = vim.fn.getqflist({ title = 1, items = 1 })
assert_equal(qf.title, "Comments", ":CommentList should title the quickfix list")
assert_equal(#qf.items, 1, ":CommentList should populate quickfix")
assert_equal(qf.items[1].text, "quickfix check", "quickfix entry should carry the comment text")
vim.cmd("cclose")
vim.cmd("CommentClear")

vim.api.nvim_win_set_cursor(0, { 2, 0 })
vim.cmd("Comment")
local function title()
  return vim.api.nvim_win_get_config(0).title[1][1]
end
local titles = {}
vim.api.nvim_create_autocmd("ModeChanged", {
  buffer = 0,
  callback = function()
    table.insert(titles, title())
  end,
})
vim.cmd("normal! ihello")
assert_equal(
  table.concat(titles, ","),
  " comment [INSERT] , comment [NORMAL] ",
  "the title shows the current mode"
)
vim.cmd("q!")
assert_equal(count(), 0, "cancelling with :q! adds nothing")
assert_equal(#floats(), 0, "cancelling closes the frame")

vim.cmd("Comment")
vim.cmd("quit")
assert_equal(#floats(), 0, ":q closes an untouched editor")

vim.cmd("Comment")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved" })
pcall(vim.cmd.quit)
assert_equal(#floats(), 2, ":q keeps an editor with unsaved text")
vim.cmd("wincmd w")
pcall(vim.cmd.quit)
assert_equal(#floats(), 1, "closing the lines pane keeps an unsaved comment open")
vim.api.nvim_set_current_win(floats()[1])
vim.cmd("q!")
assert_equal(#floats(), 0, ":q! discards the unsaved comment")
assert_equal(count(), 0, "a discarded comment is not saved")

vim.cmd("Comment")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first line", "second line" })
vim.cmd("w")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first line", "second line, revised" })
vim.cmd("wq")
assert_equal(count(), 1, "saving twice keeps one comment")
assert_equal(state.all()[1].comment, "first line\nsecond line, revised", "comments can span lines")
vim.cmd("CommentClear")

vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.cmd("Comment")
write("toggle check")
vim.cmd("CommentToggle off")
assert_equal(sign_at(1), nil, ":CommentToggle off must hide signs")
vim.cmd("CommentToggle on")
assert_equal(sign_at(1), "│", ":CommentToggle on must show signs")
vim.cmd("CommentToggle")
assert_equal(sign_at(1), nil, ":CommentToggle must hide shown signs")
vim.cmd("2Comment")
write("added while hidden")
assert_equal(sign_at(2), nil, "comments added while hidden have no sign")
vim.cmd("CommentToggle")
assert_equal(sign_at(2), "│", ":CommentToggle must show hidden signs")
vim.cmd("CommentClear")
assert_equal(sign_at(1), nil, ":CommentClear must remove signs")

vim.cmd("2,5Comment")
write("on four lines")
assert_equal(sign_at(1), nil, "no sign above a range")
assert_equal(sign_at(2), "╭", "a range starts with its first sign")
assert_equal(sign_at(3), "│", "a range's middle lines get the middle sign")
assert_equal(sign_at(4), "│", "a range's middle lines get the middle sign")
assert_equal(sign_at(5), "╰", "a range ends with its last sign")
assert_equal(sign_at(6), nil, "no sign below a range")
vim.cmd("CommentClear")

vim.api.nvim_win_set_cursor(0, { 2, 0 })
scratch.add()
write("on the cursor line")
scratch.add(4, 5)
write("on lines 4-5")
local ranges = vim.tbl_map(function(comment)
  return comment.start_line .. "-" .. comment.end_line
end, state.anchored())
assert_equal(table.concat(ranges, ","), "2-2,4-5", "scratch.add() defaults to the cursor line")
vim.cmd("CommentClear")

vim.cmd("2Comment")
write("on two")
vim.cmd("4,5Comment")
write("on four and five")
vim.cmd("4Comment")
write("also on four")
vim.cmd("7Comment")
write("on seven")

local function cursor_line()
  return vim.api.nvim_win_get_cursor(0)[1]
end
local function walk(command)
  local lines = {}
  for _ = 1, 4 do
    vim.cmd(command)
    table.insert(lines, cursor_line())
  end
  return table.concat(lines, ",")
end

vim.api.nvim_win_set_cursor(0, { 1, 0 })
assert_equal(walk("CommentNext"), "2,4,7,2", ":CommentNext visits each start once, then wraps")
assert_equal(walk("CommentPrev"), "7,4,2,7", ":CommentPrev goes back, then wraps")

vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.cmd("CommentNext")
vim.cmd([[execute "normal! \<C-o>"]])
assert_equal(cursor_line(), 1, "<C-o> returns from a comment jump")

local file_win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_cursor(0, { 2, 0 })
vim.cmd("CommentShow")
local function comment_title()
  return vim.api.nvim_win_get_config(0).title[1][1]
end
assert_equal(comment_title(), " comment (1 of 4) ", "the preview counts the file's comments")
local previewed = {}
local file_lines = {}
for _ = 1, 4 do
  vim.cmd("CommentNext")
  table.insert(previewed, text_of(vim.api.nvim_get_current_win()))
  table.insert(file_lines, vim.api.nvim_win_get_cursor(file_win)[1])
end
assert_equal(
  table.concat(previewed, ","),
  "also on four,on four and five,on seven,on two",
  ":CommentNext in a preview shows each comment in turn, then wraps"
)
assert_equal(table.concat(file_lines, ","), "4,4,7,2", "the cursor in the file follows the preview")
assert_equal(#floats(), 2, "cycling keeps one preview open")
assert_equal(comment_title(), " comment (1 of 4) ", "the count follows the preview")
vim.cmd("CommentPrev")
assert_equal(
  text_of(vim.api.nvim_get_current_win()),
  "on seven",
  ":CommentPrev goes back in a preview"
)
vim.cmd("quit")
assert_equal(#floats(), 0, "closing the preview")
vim.api.nvim_set_current_win(file_win)
vim.cmd("CommentNext")
assert_equal(#floats(), 0, "without a preview, :CommentNext only moves the cursor")
vim.cmd("CommentClear")

vim.cmd.edit("LICENSE")
vim.cmd("Comment")
write("license comment")
vim.cmd("edit!")
assert_equal(#state.anchored(), 1, ":e! must keep the buffer's comments")
vim.cmd("bdelete")
assert_equal(count(), 0, ":bd must drop the buffer's comments")

print("smoke: ok")
