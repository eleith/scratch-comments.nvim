local store = require("scratch_comments.model.store")
local expect = MiniTest.expect

---@param bufnr integer
---@param text string
local function add(bufnr, text)
  return store.add({ bufnr = bufnr, comment = text, file_path = "/f", relative_path = "f" })
end

before_each(function()
  store.clear()
end)

describe("store", function()
  it("adds comments with unique ids, in order", function()
    local first, second = add(1, "first"), add(1, "second")
    expect.no_equality(first.id, second.id)
    expect.equality(store.all(), { first, second })
  end)

  it("updates a comment's fields by id", function()
    local comment = add(1, "before")
    expect.equality(store.update(comment.id, { comment = "after" }), comment)
    expect.equality(comment.comment, "after")
  end)

  it("updates nothing for an unknown id", function()
    add(1, "kept")
    expect.equality(store.update("comment-none", { comment = "after" }), nil)
    expect.equality(store.all()[1].comment, "kept")
  end)

  it("finds the comments in a buffer", function()
    local in_one = add(1, "in one")
    add(2, "in two")
    expect.equality(store.in_buffer(1), { in_one })
  end)

  it("removes what matches and returns it, keeping the rest in order", function()
    local a, b, c = add(1, "a"), add(2, "b"), add(1, "c")
    local removed = store.remove(function(comment)
      return comment.bufnr == 1
    end)
    expect.equality(removed, { a, c })
    expect.equality(store.all(), { b })
  end)

  it("clears everything", function()
    add(1, "a")
    store.clear()
    expect.equality(store.all(), {})
  end)
end)
