# Key Bindings Cheatsheet

## Tmux (prefix: C-a)

### Navigation
| Key       | Action              |
|-----------|---------------------|
| h/j/k/l   | Select pane         |
| space     | Next window         |
| bspace    | Previous window     |
| t / T     | Next / prev window  |
| a         | Last pane           |
| C-o       | Rotate window       |
| q         | Display panes       |

### Splits & Windows
| Key       | Action              |
|-----------|---------------------|
| v         | Vertical split      |
| s         | Horizontal split    |
| c         | New window          |
| + / =     | Horizontal / vertical layout |

### Copy Mode
| Key       | Action              |
|-----------|---------------------|
| [         | Enter copy mode     |
| ]         | Paste buffer        |
| v         | Begin selection     |
| y / Enter | Copy and cancel     |

### Misc
| Key       | Action              |
|-----------|---------------------|
| R         | Reload config       |
| r         | Refresh client      |
| L         | Clear history       |

## Kitty

### Scrollback (ctrl+alt)
| Key           | Action          |
|---------------|-----------------|
| j / k         | Scroll line     |
| d / u         | Scroll page     |
| g / shift+g   | Top / bottom    |

### Windows (ctrl+shift)
| Key           | Action          |
|---------------|-----------------|
| \             | Vertical split  |
| s             | Horizontal split|
| h/j/k/l       | Navigate panes  |
| alt+h/j/k/l   | Resize panes    |

### Tabs (ctrl+shift)
| Key           | Action          |
|---------------|-----------------|
| t             | New tab         |
| 1-5           | Go to tab       |

## Zsh

| Key   | Action                    |
|-------|---------------------------|
| ^D    | Exit shell                |
| ^L    | Clear screen + scrollback |
| ^H    | Delete backward word      |
| ^R    | fzf history search        |
| ~~    | fzf completion trigger    |

## Gitui

| Key   | Action              |
|-------|---------------------|
| h/j/k/l | Navigate          |
| C-b/C-f | Page up/down      |
| g / G | Top / bottom        |
| ?     | Help                |
| 1-5   | Switch tabs         |

## Music (music)

| Command         | Action                      |
|-----------------|-----------------------------|
| music           | fzf-select playlist & play  |
| music \<name\>  | Play playlist by name       |
| music add \<p\> \<url\> | Add track to playlist |
| music import \<p\> \<url\> | Import playlist from URL |
| music rm \<p\>  | Remove tracks from playlist |
| music list      | Show playlists              |
| music pause     | Toggle pause/resume         |
| music next/prev | Skip track                  |
| music stop      | Stop playback               |
| music status    | Show current track          |

## AeroSpace (macOS)

### Focus & Move
| Key             | Action              |
|-----------------|---------------------|
| alt+h/j/k/l     | Focus window        |
| alt+shift+h/j/k/l | Move window       |
| alt+- / alt+=   | Resize shrink/grow  |

### Layout
| Key             | Action              |
|-----------------|---------------------|
| alt+/           | Toggle tiles h/v    |
| alt+,           | Toggle accordion    |

### Workspaces
| Key             | Action              |
|-----------------|---------------------|
| alt+1-9         | Switch workspace    |
| alt+a-z         | Switch workspace    |
| alt+shift+1-9   | Move to workspace   |
| alt+shift+a-z   | Move to workspace   |
| alt+tab         | Last workspace      |
| alt+shift+tab   | Move ws to monitor  |

### Service Mode (alt+shift+;)
| Key             | Action              |
|-----------------|---------------------|
| esc             | Reload config       |
| r               | Reset layout        |
| f               | Toggle float/tile   |
| backspace       | Close other windows |
| alt+shift+h/j/k/l | Join with direction |

## IdeaVim (leader: space)

### General
| Key         | Action              |
|-------------|---------------------|
| Q           | Format (gq)         |
| Y           | Yank to end of line |
| M           | Split line at cursor|
| s / ss      | Replace with register|
| C-s         | Substitute (:%s/)   |
| C-/         | Comment line        |
| \           | Window prefix (C-w) |
| H / L       | Prev / next tab     |
| A-j / A-k   | Move line down / up |
| < / > (vis) | Indent and reselect |
| n / N       | Search + recenter   |
| \<leader\>p (vis) | Paste (no yank)|
| A-n         | Select next occurrence|
| A-x         | Unselect occurrence |
| A-S-n       | Select all occurrences|
| A-Up / A-Down | Expand / shrink selection |

### LSP / Navigation
| Key         | Action              |
|-------------|---------------------|
| gd          | Go to declaration   |
| gY          | Go to type decl     |
| K           | Quick docs          |
| \<leader\>la | Code action        |
| \<leader\>lr | Find usages        |
| \<leader\>li | Implementation     |
| \<leader\>lR | Rename             |
| \<leader\>ls | Signature help     |
| \<leader\>lh | Type hierarchy     |
| \<leader\>lc | Call hierarchy     |
| \<leader\>lu | Show usages (popup)|

### Diagnostics
| Key         | Action              |
|-------------|---------------------|
| [d / ]d     | Prev / next error   |
| \<leader\>dd | Show diagnostic    |
| \<leader\>da | All diagnostics    |

### Find / Search
| Key         | Action              |
|-------------|---------------------|
| \<leader\>ff | Files              |
| \<leader\>fg | Grep (find in path)|
| \<leader\>fr | Recent files       |
| \<leader\>fb | Buffers (switcher) |
| \<leader\>fm | Bookmarks          |
| \<leader\>fk | Actions (keymaps)  |
| \<leader\>fo | Symbols            |
| \<leader\>fc | Classes            |
| \<leader\>th | Toggle highlight   |

### Git (hunk)
| Key         | Action              |
|-------------|---------------------|
| [c / ]c     | Prev / next change  |
| \<leader\>gb | Blame (annotate)   |
| \<leader\>gd | Diff vs index      |
| \<leader\>gD | Diff vs parent     |
| \<leader\>gp | Preview hunk       |
| \<leader\>gr | Reset hunk         |

### Git
| Key         | Action              |
|-------------|---------------------|
| \<leader\>Gs | Status (commit)   |
| \<leader\>Gl | Log                |
| \<leader\>Gh | File history       |
| \<leader\>Go | Open in browser    |
| \<leader\>Gu | Revert file        |

### Debug
| Key         | Action              |
|-------------|---------------------|
| F5          | Resume              |
| F8          | Step over           |
| F9          | Step into           |
| F10         | Step out            |
| \<leader\>b | Toggle breakpoint   |
| \<leader\>B | Edit breakpoint     |

### Run
| Key         | Action              |
|-------------|---------------------|
| \<leader\>rr | Run                |
| \<leader\>rd | Debug              |
| \<leader\>rc | Run context        |
| \<leader\>rs | Stop               |
| \<leader\>rt | Rerun tests        |
| \<leader\>rT | Go to test         |

### Code / Refactor
| Key         | Action              |
|-------------|---------------------|
| \<leader\>cr | Refactor menu      |
| \<leader\>cR | Rename file        |
| \<leader\>cg | Generate           |
| \<leader\>cm | Extract method     |
| \<leader\>cv | Extract variable   |
| \<leader\>ci | Inline             |
| \<leader\>cs | Change signature   |
| \<leader\>co | Optimize imports   |
| \<leader\>cf | Reformat code      |

### Toggles
| Key         | Action              |
|-------------|---------------------|
| \<leader\>tw | Wrap               |
| \<leader\>tn | Relative numbers   |

### View / UI
| Key         | Action              |
|-------------|---------------------|
| \<leader\>]  | Outline (structure)|
| \<leader\>x  | Terminal           |
| \<leader\>z  | Focus fold         |
| \<leader\>\<leader\>z | Zen mode |
| \<leader\>w  | Close buffer       |
| \<leader\>W  | Close other tabs   |
| \<leader\>Q  | Quit all           |
| \<leader\>e  | Reveal in project  |

### Navigation
| Key         | Action              |
|-------------|---------------------|
| [m / ]m     | Prev / next method  |
