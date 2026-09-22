local views = require("scratch_comments.model.views")
local expect = MiniTest.expect

---@param id string
---@param relative_path? string
---@param start_line? integer
local function view(id, relative_path, start_line)
  return {
    id = id,
    relative_path = relative_path or "f",
    start_line = start_line or 1,
    end_line = 1,
  }
end

---@param list table[]
---@return string
local function ids(list)
  table.sort(list, views.by_position)
  return table.concat(
    vim.tbl_map(function(v)
      return v.id
    end, list),
    ","
  )
end

describe("by_position", function()
  it("orders by file, then line", function()
    expect.equality(
      ids({ view("comment-1", "b"), view("comment-2", "a", 2), view("comment-3", "a", 1) }),
      "comment-3,comment-2,comment-1"
    )
  end)

  it("orders comments on the same lines by when they were added", function()
    expect.equality(ids({ view("comment-10"), view("comment-2") }), "comment-2,comment-10")
  end)
end)
