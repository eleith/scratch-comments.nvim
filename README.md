# scratch-comments.nvim

![Commenting on this README and exporting the comment as Markdown](assets/demo.gif)

comment on any line(s) in any file, then copy them all out as Markdown (or JSON)
to paste into an LLM or hand to a person.

## why

when reading a file in neovim, sometimes i want to leave comments as i go
without interruption (no second app, no extra buffer). this plugin keeps track
of each comment associated to the right location.

afterwards, i can export all the comments to my clipboard (or a file) and
handoff to an LLM or teammate.

i've found it useful in reviewing plans, code diffs and more. no extra fluff, no
coordination with a custom agent, format, or process.

just text.

## install

With `lazy.nvim`:

```lua
{ "eleith/scratch-comments.nvim" }
```

With `vim.pack`:

```lua
vim.pack.add({ { src = "https://git.eleith.com/eleith/scratch-comments.nvim" } })
```

## use

comment on the current line:

```vim
:Comment
```

comment on a range, or select text and type `:Comment`. select whole lines to
comment on them, or just a word or phrase to comment on only that:

```vim
:12,16Comment
:'<,'>Comment
```

a window opens over the file, with the lines you're commenting on
at the top and your comment below. a new comment opens in insert mode, and the
title shows the mode you're in. write as many lines as you like, then `:wq` to
save. `:q` or `<Esc>` closes it if you haven't changed anything, and `:q!`
throws your changes away. `<C-w>w` moves between the two parts, or scroll them with the
mouse. commenting on an exact range again opens its comment for editing.

commented lines get a mark in the sign column: `│` for one line, and `╭` `│` `╰`
down a range. characterwise selections also highlight the commented text; whole-line
comments only get signs. browse your comments, then copy them all:

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
| `:Comment` | Add or edit a comment in a file; in the built-in comment list, open the cursor row's card |
| `:CommentList [filter]` | Put comments in the quickfix list and open it, fuzzy matching `filter` |
| `:CommentDelete` | Delete the cursor row in the built-in quickfix list, or the open card elsewhere |
| `:CommentExport[!] [format]` | Copy all comments to the clipboard as `markdown` (default) or `json`. `!` opens them in a scratch buffer |
| `:CommentToggle [on\|off]` | Show or hide the comment signs and text highlights |
| `:CommentClear` | Delete every comment |

## mappings

add your own, for example:

```lua
vim.keymap.set("n", "<leader>ca", "<Cmd>Comment<CR>", { desc = "Comment on line" })
vim.keymap.set("x", "<leader>ca", ":Comment<CR>", { desc = "Comment on selection" })
vim.keymap.set("n", "<leader>cl", "<Cmd>CommentList<CR>", { desc = "List comments" })
vim.keymap.set("n", "<leader>cx", "<Cmd>CommentExport<CR>", { desc = "Copy comments" })
```

## browsing

`:CommentList` puts all your comments in the quickfix list. move through them
with `j`/`k` without moving the source cursor or opening a card. `<CR>` jumps
to the source without opening a card. `:Comment` opens the comment under the
quickfix cursor for editing without jumping; its card stays over the file area
so the list remains visible. `:w` saves; `:CommentDelete` deletes the comment
under the quickfix cursor, or the open card when outside the list. `<Esc>`
closes a clean card; unsaved edits need `:w` or `:q!`. an orphan has no line to
jump to, but `:Comment` still opens its card. give `:CommentList` an argument to
fuzzy match text, snippet or path:

```vim
:CommentList typo
```

any quickfix viewer works:

```vim
:copen                       " built in, no plugins
:Trouble qflist toggle       " trouble.nvim
:lua Snacks.picker.qflist()  " snacks.nvim
:Telescope quickfix          " telescope.nvim
```

## retention

comments stay when you close a buffer (`:bd`, `:bw`). open the same source
again and they'll pick up where they left off if the text is still on the same
lines. delete one from the built-in quickfix list with `:CommentDelete`, from
its open card, or by saving its comment empty. `:CommentClear` deletes them all. to keep them after exiting neovim,
export them to a file.

the signs share the sign column with plugins like gitsigns, and can cover their
signs. `:CommentToggle` hides ours when you need to see theirs.

if the lines a comment is on are deleted, it becomes an orphan. orphans are
listed last in `:CommentList` and in an "Orphaned" section of the export. undo
restores them while the buffer is open. delete one from the built-in quickfix
list with `:CommentDelete`, or from its open card.

## colors

`ScratchCommentSign` colors the signs (linked to `Todo` by default).
`ScratchCommentHighlight` colors commented text ranges (also linked to `Todo`
by default). override either group to use your own colors.
`ScratchCommentBackdrop` dims the editor behind an open comment card
(black at 60% blend by default).

set them in your colorscheme's highlight callback to follow light and dark
modes. for example, inside Modus's `on_highlights`:

```lua
hl.ScratchCommentSign = { fg = c.fg_main, bg = c.bg_yellow_intense, bold = true }
hl.ScratchCommentHighlight = { bg = c.bg_yellow_intense }
hl.ScratchCommentBackdrop = { bg = c.bg_dim }
```

for fixed colors, use `vim.api.nvim_set_hl`. to turn off the dim:

```lua
vim.api.nvim_set_hl(0, "ScratchCommentBackdrop", { bg = "NONE" })
```

## lua API

```lua
local scratch = require("scratch_comments")

scratch.add(start_line, end_line)  -- default: the cursor line
scratch.delete()                   -- quickfix cursor row or open card
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

- Neovim 0.12 or newer.
- No plugin dependencies.
- A clipboard provider. in tmux you may need `vim.g.clipboard = "osc52"`.

## development

```
plugin/scratch-comments.lua   the commands
lua/scratch_comments/
  init.lua        the lua API
  actions.lua     add and edit comments, toggle signs, clear
  list.lua        browse, navigate and delete comments
  comments.lua    changes comments and keeps the signs in sync
  location.lua    "line 3", "lines 3–5", "line 3, col 5–12"
  paths.lua       git root and relative paths
  model/          the comments and where they are
  ui/             the comment window, signs, quickfix, notifications
  export/         markdown, json and the clipboard
tests/
  unit/           tests for single modules
  features/       tests that run the commands
```

`mise install` gets the pinned tools. then:

```sh
make check   # lint, format check and tests, like CI
make test    # tests only. the first run clones mini.test into deps/
```

## credit

forked from [annotator.nvim](https://github.com/chpeters/annotator.nvim) by
chpeters.

## license

MIT. See [LICENSE](LICENSE).
