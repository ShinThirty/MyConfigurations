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
| v             | Vertical split  |
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

### Navigation
| Key         | Action              |
|-------------|---------------------|
| gd          | Go to declaration   |
| gi          | Go to implementation|
| gr          | Find usages         |
| K           | Quick docs          |
| [d / ]d     | Prev / next error   |

### Search
| Key         | Action              |
|-------------|---------------------|
| \<leader\>f | Go to file          |
| \<leader\>g | Find in path        |
| \<leader\>o | File structure      |
| \<leader\>s | Select in tree      |

### Debug
| Key         | Action              |
|-------------|---------------------|
| \<leader\>d | Debug               |
| \<leader\>b | Toggle breakpoint   |
| \<leader\>c | Stop                |

### Git
| Key         | Action              |
|-------------|---------------------|
| \<leader\>a | Annotate            |
| \<leader\>hr| Rollback lines      |
| [c / ]c     | Prev / next change  |
