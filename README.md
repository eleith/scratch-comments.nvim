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

commented lines are highlighted. read the comments on the cursor line:

```vim
:CommentShow
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
| `:CommentShow` | Show the comments at the cursor in a float |
| `:CommentEdit` | Edit the comment at the cursor |
| `:CommentDelete` | Delete the comment at the cursor, or pick an orphaned one |
| `:CommentList` | Put comments in the quickfix list and open it |
| `:CommentExport` | Copy all comments to the clipboard |
| `:CommentClear` | Delete every comment |

## mappings

**This plugin sets no mappings.** Add your own:

```lua
vim.keymap.set("n", "<leader>ca", "<Cmd>Comment<CR>", { desc = "Comment on line" })
vim.keymap.set("x", "<leader>ca", ":Comment<CR>", { desc = "Comment on selection" })
vim.keymap.set("n", "<leader>cs", "<Cmd>CommentShow<CR>", { desc = "Show comments" })
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

deleting every line a comment covers orphans it. an orphan is hidden but kept:
`:CommentList` shows it last, `:CommentExport` puts it in an "Orphaned" section,
and undo brings it back. `:CommentDelete` on a line with no comment offers the
buffer's orphans to delete.

## configuration

there are no options. commented lines use the `ScratchCommentRange` highlight,
linked to `Visual`. restyle it:

```lua
vim.api.nvim_set_hl(0, "ScratchCommentRange", { bg = "#3b3520" })
```

## lua API

```lua
local scratch = require("scratch_comments")

scratch.setup()
scratch.add()         -- current line
scratch.add_visual()
scratch.show()
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
