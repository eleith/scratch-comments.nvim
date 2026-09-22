local location = require("scratch_comments.location")
local expect = MiniTest.expect

describe("describe", function()
  it("names a line", function()
    expect.equality(location.describe({ start_line = 3, end_line = 3 }), "line 3")
  end)

  it("names a range of lines with an en dash", function()
    expect.equality(location.describe({ start_line = 3, end_line = 5 }), "lines 3–5")
  end)

  it("names a span's columns, 1-based and inclusive", function()
    local span = { start_line = 3, end_line = 3, start_col = 4, end_col = 12 }
    expect.equality(location.describe(span), "line 3, col 5–12")
  end)

  it("names a one-column span by its column", function()
    local span = { start_line = 3, end_line = 3, start_col = 4, end_col = 5 }
    expect.equality(location.describe(span), "line 3, col 5")
  end)

  it("names a span across lines by line:col", function()
    local span = { start_line = 3, end_line = 5, start_col = 4, end_col = 4 }
    expect.equality(location.describe(span), "lines 3:5–5:4")
  end)
end)

describe("title", function()
  it("is the file's name and its location", function()
    local title = location.title("/repo/lua/app.lua", { start_line = 3, end_line = 5 })
    expect.equality(title, "app.lua [lines 3–5]")
  end)
end)

describe("fit", function()
  it("leaves text that fits alone", function()
    expect.equality(location.fit("app.lua [line 3]", 16), "app.lua [line 3]")
  end)

  it("cuts from the left with an ellipsis, to exactly the width", function()
    expect.equality(location.fit("long-name.lua [line 3]", 12), "…ua [line 3]")
  end)

  it("counts wide characters by their width", function()
    local fitted = location.fit("日本語の名前.md [line 3]", 15)
    expect.equality(vim.startswith(fitted, "…"), true)
    expect.equality(vim.api.nvim_strwidth(fitted) <= 15, true)
    expect.equality(vim.endswith(fitted, ".md [line 3]"), true)
  end)
end)
