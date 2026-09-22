local json = require("scratch_comments.export.json")
local expect = MiniTest.expect

---@param fields table
---@return ScratchCommentView
local function view(fields)
  return vim.tbl_extend("keep", fields, {
    id = "comment-1",
    bufnr = 1,
    comment = "a comment",
    file_path = "/repo/lua/app.lua",
    relative_path = "lua/app.lua",
    start_line = 3,
    end_line = 4,
    snippet = "a\nb",
  })
end

describe("json", function()
  it("has each comment's file, lines, snippet and text", function()
    local data = vim.json.decode(json.render({ view({}) }, {}))
    expect.equality(data.comments, {
      {
        id = "comment-1",
        file = "/repo/lua/app.lua",
        relative_path = "lua/app.lua",
        start_line = 3,
        end_line = 4,
        snippet = "a\nb",
        comment = "a comment",
      },
    })
  end)

  it("has a span's columns, 1-based and inclusive", function()
    local data = vim.json.decode(json.render({ view({ start_col = 4, end_col = 9 }) }, {}))
    expect.equality(data.comments[1].start_col, 5)
    expect.equality(data.comments[1].end_col, 9)
  end)

  it("has orphans without lines", function()
    local data = vim.json.decode(json.render({}, { view({ id = "comment-9" }) }))
    expect.equality(data.orphaned, {
      {
        id = "comment-9",
        file = "/repo/lua/app.lua",
        relative_path = "lua/app.lua",
        comment = "a comment",
      },
    })
  end)

  it("encodes empty lists as arrays", function()
    local rendered = json.render({}, {})
    expect.no_equality(rendered:find('"comments": []', 1, true), nil)
    expect.no_equality(rendered:find('"orphaned": []', 1, true), nil)
  end)
end)
