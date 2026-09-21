local scratch = require("scratch_comments")

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

local function write(comment)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(comment, "\n"))
  vim.cmd("wq")
end

local copied
---@diagnostic disable-next-line: duplicate-set-field -- test fake
require("scratch_comments.export").copy = function(text)
  copied = text
  return true
end

vim.cmd.enew()
vim.cmd.file("export-fixture.lua")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local a = 1", "local b = 2", "local c = 3" })
local source = vim.api.nvim_get_current_buf()

vim.cmd("3Comment")
write("on c")
vim.cmd("1Comment")
write("on a")

local data = vim.json.decode(scratch.render("json"))
assert_equal(#data.comments, 2, "json must list every comment")
assert_equal(data.comments[1].comment, "on a", "comments must be ordered by position")
assert_equal(data.comments[1].start_line, 1, "json must carry the line range")
assert_equal(data.comments[1].snippet, "local a = 1", "json must carry the commented text")
assert_equal(#data.orphaned, 0, "json must always carry the orphaned list")
assert_contains(scratch.render("json"), '"orphaned": []', "an empty list must encode as an array")

vim.cmd("CommentExport json")
assert_equal(
  vim.json.decode(copied).comments[2].comment,
  "on c",
  ":CommentExport json must copy json"
)

copied = nil
vim.cmd("CommentExport bogus")
assert_equal(copied, nil, ":CommentExport must not copy an unknown format")

vim.cmd("CommentExport!")
assert_equal(vim.bo.buftype, "nofile", ":CommentExport! must open a scratch buffer")
assert_equal(vim.bo.filetype, "markdown", ":CommentExport! must default to markdown")
assert_contains(
  table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"),
  "on a",
  ":CommentExport! must fill the scratch buffer"
)
vim.cmd("close")

vim.cmd("CommentExport! json")
assert_equal(vim.bo.filetype, "json", ":CommentExport! json must open json")
vim.cmd("close")

assert_equal(
  vim.api.nvim_get_current_buf(),
  source,
  "closing the scratch window returns to the file"
)

print("export: ok")
