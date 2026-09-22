local expect = MiniTest.expect

---@param lua string run in a fresh Neovim with only this plugin
---@return string output
local function fresh(lua)
  local result = vim
    .system({
      vim.v.progpath,
      "--headless",
      "--clean",
      "--cmd",
      "set runtimepath^=" .. vim.fn.getcwd(),
      "-c",
      "lua " .. lua,
      "-c",
      "qa!",
    }, { text = true })
    :wait()
  return result.stdout
end

describe("the plugin", function()
  it("defines its commands without setup()", function()
    expect.equality(fresh("io.write(vim.fn.exists(':CommentShow'))"), "2")
  end)

  it("loads nothing until a command runs", function()
    local loaded = "io.write(tostring(package.loaded['scratch_comments.actions'] ~= nil))"
    expect.equality(fresh(loaded), "false")
    expect.equality(fresh("vim.cmd('CommentList') " .. loaded), "true")
  end)

  it("still accepts setup()", function()
    expect.equality(fresh("require('scratch_comments').setup() io.write('ok')"), "ok")
  end)
end)
