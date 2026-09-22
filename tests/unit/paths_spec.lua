local paths = require("scratch_comments.paths")
local expect = MiniTest.expect

describe("git_root", function()
  it("finds the repository a file is in", function()
    local root = vim.fn.getcwd()
    expect.equality(paths.git_root(root .. "/lua/scratch_comments/paths.lua"), root)
  end)

  it("uses the working directory for a file with no path", function()
    expect.equality(paths.git_root(""), vim.fn.getcwd())
  end)

  it("is nil outside a repository", function()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    expect.equality(paths.git_root(dir .. "/file.txt"), nil)
  end)
end)

describe("relative_path", function()
  it("is the path inside the root", function()
    expect.equality(paths.relative_path("/repo", "/repo/lua/app.lua"), "lua/app.lua")
  end)

  it("accepts a root with a trailing slash", function()
    expect.equality(paths.relative_path("/repo/", "/repo/lua/app.lua"), "lua/app.lua")
  end)

  it("keeps a path outside the root", function()
    expect.equality(paths.relative_path("/repo", "/elsewhere/app.lua"), "/elsewhere/app.lua")
  end)

  it("keeps the path when there is no root", function()
    expect.equality(paths.relative_path(nil, "/elsewhere/app.lua"), "/elsewhere/app.lua")
    expect.equality(paths.relative_path("", "/elsewhere/app.lua"), "/elsewhere/app.lua")
  end)

  it("doesn't mistake a sibling with the same prefix for the root", function()
    expect.equality(paths.relative_path("/repo", "/repo-two/app.lua"), "/repo-two/app.lua")
  end)
end)
