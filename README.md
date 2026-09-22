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

comment on the current line:

```vim
:Comment
```

comment on a range, or select lines and type `:Comment`:

```vim
:12,16Comment
:'<,'>Comment
```

a window opens in the middle of the screen, with the lines you're commenting on
at the top and your comment below. write as many lines as you like, then `:wq`
to save, or `:q!` to cancel. `esc` closes it when there's nothing unsaved.
`<C-w>w` moves between the two parts, or scroll them with the mouse.

commented lines get a mark in the sign column: `│` for one line, and `╭` `│` `╰`
down a range. read a comment on the cursor line, in the same window:

```vim
:CommentShow
```

browse every comment, then copy them all:

```vim
:CommentList
:CommentExport         " markdown, to the clipboard
:CommentExport json    " json, to the clipboard
```

add `!` to open the export in a scratch buffer instead. from there you can save
it, pipe it to a command, or edit it:

```vim
:CommentExport!        " then :w review.md, :w !some-cmd, :%!jq ., ...
:CommentExport! json
```

## commands

| Command | Does |
| --- | --- |
| `:Comment` | Comment on the current line or command range |
| `:CommentShow` | Show the comment at the cursor, with the lines it's on |
| `:CommentEdit` | Edit the comment at the cursor |
| `:CommentDelete` | Delete the comment at the cursor, or pick an orphaned one |
| `:CommentList` | Put comments in the quickfix list and open it |
| `:CommentExport[!] [format]` | Copy all comments to the clipboard as `markdown` (default) or `json`. `!` opens them in a scratch buffer |
| `:CommentToggle [on\|off]` | Show or hide the comment signs |
| `:CommentClear` | Delete every comment |

## mappings

add your own, for example:

```lua
vim.keymap.set("n", "<leader>ca", "<Cmd>Comment<CR>", { desc = "Comment on line" })
vim.keymap.set("x", "<leader>ca", ":Comment<CR>", { desc = "Comment on selection" })
vim.keymap.set("n", "<leader>cs", "<Cmd>CommentShow<CR>", { desc = "Show comments" })
vim.keymap.set("n", "<leader>cl", "<Cmd>CommentList<CR>", { desc = "List comments" })
vim.keymap.set("n", "<leader>cx", "<Cmd>CommentExport<CR>", { desc = "Copy comments" })
```

## browsing

`:CommentList` puts your comments in the quickfix list, so any quickfix viewer
works:

```vim
:copen                       " built in, no plugins
:Trouble qflist toggle       " trouble.nvim
:lua Snacks.picker.qflist()  " snacks.nvim
:Telescope quickfix          " telescope.nvim
```

## retention

comments go away when you close the buffer (`:bd`, `:bw`) or run
`:CommentClear`. to keep them, export them to a file.

the signs share the sign column with plugins like gitsigns, and can cover their
signs. `:CommentToggle` hides ours when you need to see theirs.

if you delete all the lines a comment is on, the comment becomes an orphan.
orphans are listed last in `:CommentList` and in an "Orphaned" section of the
export, and undo restores them. to delete one, run `:CommentDelete` on a line
with no comment.

## configuration

the signs use the `ScratchCommentSign` highlight, which links to `Todo`.
to change it:

```lua
vim.api.nvim_set_hl(0, "ScratchCommentSign", { fg = "#2fafff", bg = "#004065" })
```

## lua API

```lua
local scratch = require("scratch_comments")

scratch.setup()
scratch.add(start_line, end_line)  -- default: the cursor line
scratch.show()
scratch.edit()
scratch.delete()
scratch.list()
scratch.render(format)             -- "markdown" (default) or "json"
scratch.export(format, in_buffer)  -- copy, or open in a scratch buffer
scratch.toggle(on)                 -- true, false, or nil to toggle
scratch.clear()
```

`scratch.render()` returns the export as a string. to write it to a file:

```lua
vim.fn.writefile(vim.split(scratch.render(), "\n"), "review.md")
```

## requirements

- Neovim 0.10 or newer.
- No plugin dependencies.
- A clipboard provider. in tmux you may need `vim.g.clipboard = "osc52"`.

## credit

forked from [annotator.nvim](https://github.com/chpeters/annotator.nvim) by
chpeters.

## license

MIT. See [LICENSE](LICENSE).
