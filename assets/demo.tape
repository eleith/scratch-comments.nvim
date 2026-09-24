Output assets/demo.gif
Require nvim
Require ttyd
Require ffmpeg

Set FontFamily "JetBrainsMono Nerd Font Mono"
Set FontSize 23
Set Width 1440
Set Height 900
Set Padding 0
Set TypingSpeed 45ms

# Start with an empty terminal; this README is opened but never modified.
Sleep 1s
Type@45ms "nvim -n README.md"
Enter
Hide
Sleep 1s
Type ":set laststatus=0"
Enter
Type "gg"
Ctrl+L
Show
Sleep 1s

Down@420ms 9
Sleep 1s
Type "V"
Down@550ms 2
Sleep 1.5s
Type@70ms ":"
Type@70ms "Comment"
Enter
Sleep 1.5s
Type@65ms "rephrase this"
Sleep 150ms
Type@50ms " to avoid"
Sleep 120ms
Type@75ms " first person"
Sleep 1.5s
Escape
Type@70ms ":wq"
Enter
Sleep 3.5s

Type@70ms ":CommentExport"
Enter
Sleep 2s
Type@70ms ":edit note.md"
Enter
Hide
Type ":silent %delete _"
Enter
Show
Sleep 1s
Type '"+p'
Sleep 1s
Type "gg"
Ctrl+L
Sleep 5s
