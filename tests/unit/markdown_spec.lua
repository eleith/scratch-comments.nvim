local markdown = require("scratch_comments.export.markdown")
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
    end_line = 3,
    snippet = "local x = 1",
  })
end

---@param lines string[]
---@return string
local function text(lines)
  return table.concat(lines, "\n")
end

describe("markdown", function()
  it("groups comments by file, each with its lines, text and snippet", function()
    local rendered = markdown.render({
      view({ id = "comment-1", start_line = 3, end_line = 3 }),
      view({ id = "comment-2", start_line = 5, end_line = 6, snippet = "a\nb", comment = "two" }),
      view({ id = "comment-3", relative_path = "README.md", comment = "in the readme" }),
    }, {})
    expect.equality(
      rendered,
      text({
        "Comments:",
        "",
        "## lua/app.lua",
        "",
        "- line 3 (comment-1)",
        "",
        "a comment",
        "",
        "```lua",
        "local x = 1",
        "```",
        "",
        "- lines 5–6 (comment-2)",
        "",
        "two",
        "",
        "```lua",
        "a",
        "b",
        "```",
        "",
        "## README.md",
        "",
        "- line 3 (comment-3)",
        "",
        "in the readme",
        "",
        "```md",
        "local x = 1",
        "```",
        "",
      })
    )
  end)

  it("names a span's columns", function()
    local rendered = markdown.render({ view({ start_col = 6, end_col = 11 }) }, {})
    expect.no_equality(rendered:find("- line 3, col 7–11 (comment-1)", 1, true), nil)
  end)

  it("fences a snippet that contains a fence with four backticks", function()
    local rendered = markdown.render({ view({ snippet = "```\ncode\n```" }) }, {})
    expect.no_equality(rendered:find("````lua\n```\ncode\n```\n````", 1, true), nil)
  end)

  it("lists orphans in their own section", function()
    local orphan = view({ id = "comment-9", comment = "lost" })
    expect.equality(
      markdown.render({}, { orphan }),
      text({
        "Comments:",
        "",
        "## Orphaned",
        "",
        "The lines these comments were on have been deleted.",
        "",
        "- lua/app.lua (comment-9)",
        "",
        "lost",
        "",
      })
    )
  end)
end)
