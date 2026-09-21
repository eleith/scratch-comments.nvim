# scratch-comments.nvim

comment on any line(s) in any file, then copy them all out as Markdown (or JSON)
to paste into an LLM or hand to a person.

## install

With `lazy.nvim`:

```lua
{
  "eleith/scratch-comments.nvim",
  opts = {},
}
```

With `vim.pack`:

```lua
vim.pack.add({ { src = "https://git.eleith.com/eleith/scratch-comments.nvim" } })
require("scratch_comments").setup()
```

## use

Comment on the current line:

```vim
:Comment
```

comment on a range:

```vim
:12,16Comment
```

browse every comment, then copy them all:

```vim
:CommentList
:CommentExport
```

## commands

| Command | Does |
| --- | --- |
| `:Comment` | Comment on the current line or command range |
| `:CommentEdit` | Edit the comment at the cursor |
| `:CommentDelete` | Delete the comment at the cursor |
| `:CommentList` | Put comments in the quickfix list and open it |
| `:CommentExport` | Copy all comments to the clipboard |
| `:CommentClear` | Delete every comment |

## mappings

**This plugin sets no mappings.** Add your own:

```lua
vim.keymap.set("n", "<leader>ca", "<Cmd>Comment<CR>", { desc = "Comment on line" })
vim.keymap.set("x", "<leader>ca", ":Comment<CR>", { desc = "Comment on selection" })
vim.keymap.set("n", "<leader>cl", "<Cmd>CommentList<CR>", { desc = "List comments" })
vim.keymap.set("n", "<leader>cx", "<Cmd>CommentExport<CR>", { desc = "Copy comments" })
```

## browsing

`:CommentList` writes to Neovim's quickfix list and opens it.

```vim
:copen                       " built in, no plugins
:Trouble qflist toggle       " trouble.nvim
:lua Snacks.picker.qflist()  " snacks.nvim
:Telescope quickfix          " telescope.nvim
```

## retention

Comments are lost when you close the buffer (`:bw`) or run `:CommentClear`.

## configuration

Everything is optional.

```lua
require("scratch_comments").setup({
  display = {
    sign_text = "C>",
    sign_hl_group = "ScratchCommentSign",
    virtual_text_prefix = " ",
    virtual_text_hl_group = "ScratchCommentVirtual",
    virtual_text_pos = "eol",
    max_comment_length = 80,
    priority = 120,
  },
})

## lua API

```lua
local scratch = require("scratch_comments")

scratch.setup(opts)
scratch.add()         -- current line
scratch.add_visual()
scratch.edit()
scratch.delete()
scratch.list()
scratch.render()      -- Markdown string for all comments
scratch.export()      -- render + copy to clipboard
scratch.clear()
```

`scratch.render()` returns a string, so you can send comments anywhere:

```lua
vim.fn.writefile(vim.split(scratch.render(), "\n"), "review.md")
```

## requirements

- Neovim 0.10 or newer.
- No plugin dependencies.
- A clipboard provider

## credit

A fork of [annotator.nvim](https://github.com/chpeters/annotator.nvim) by
chpeters, reduced to a single primitive.

## license

MIT. See [LICENSE](LICENSE).
