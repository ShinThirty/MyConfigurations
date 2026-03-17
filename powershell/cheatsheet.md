# Key Bindings Cheatsheet (Windows)

## Windows Terminal

### Scrollback (ctrl+alt)
| Key           | Action          |
|---------------|-----------------|
| j / k         | Scroll line     |
| d / u         | Scroll page     |
| g / shift+g   | Top / bottom    |

### Panes (ctrl+shift)
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

### Clipboard
| Key           | Action          |
|---------------|-----------------|
| ctrl+c        | Copy            |
| ctrl+v        | Paste           |

## PowerShell

### PSReadLine
| Key       | Action                    |
|-----------|---------------------------|
| Ctrl+D    | Delete char               |
| Ctrl+T    | fzf file search           |
| Ctrl+R    | fzf history search        |

### Directory History (Alt+Arrow)
| Key       | Action                    |
|-----------|---------------------------|
| Alt+Left  | Back to previous dir      |
| Alt+Right | Forward to next dir       |
| Alt+Up    | Parent directory          |
| Alt+Down  | First subdirectory        |

### Aliases
| Alias | Command                   |
|-------|---------------------------|
| g     | git                       |
| l     | ls                        |
| df    | duf                       |
| batp  | bat --style=plain         |
| fzp   | fzf with bat preview      |
| keys  | View this cheatsheet      |
| y     | yazi (with cwd tracking)  |

## Git Aliases

### Status & Add
| Alias | Command                   |
|-------|---------------------------|
| gst   | git status                |
| gss   | git status --short        |
| ga    | git add                   |
| gaa   | git add --all             |
| gapa  | git add --patch           |

### Commit
| Alias | Command                   |
|-------|---------------------------|
| gc    | git commit --verbose      |
| gca   | git commit --verbose --all|
| gcA   | git commit --amend        |
| gcaA  | git commit --all --amend  |
| gcaN  | git commit --all --no-edit --amend |
| gcmsg | git commit --message      |
| gcam  | git commit --all --message|

### Diff
| Alias | Command                   |
|-------|---------------------------|
| gd    | git diff                  |
| gds   | git diff --staged         |
| gdca  | git diff --cached         |
| gdw   | git diff --word-diff      |

### Branch & Switch
| Alias | Command                   |
|-------|---------------------------|
| gb    | git branch                |
| gba   | git branch --all          |
| gbd   | git branch --delete       |
| gbD   | git branch --delete --force|
| gsw   | git switch                |
| gswc  | git switch --create       |
| gswm  | git switch main           |
| gco   | git checkout              |
| gcb   | git checkout -b           |
| gcm   | git checkout main         |

### Fetch, Pull & Push
| Alias | Command                   |
|-------|---------------------------|
| gf    | git fetch                 |
| gfa   | git fetch --all --prune   |
| gl    | git pull                  |
| gpr   | git pull --rebase         |
| gpra  | git pull --rebase --autostash |
| gprom | git pull --rebase origin main |
| gp    | git push                  |
| gpf   | git push --force-with-lease |
| gpF   | git push --force          |
| gpsup | git push --set-upstream origin (branch) |

### Log
| Alias | Command                   |
|-------|---------------------------|
| glog  | git log --oneline --graph |
| gloga | git log --oneline --graph --all |
| glol  | git log --graph (pretty)  |
| glola | git log --graph --all (pretty) |
| glg   | git log --stat            |

### Rebase
| Alias | Command                   |
|-------|---------------------------|
| grb   | git rebase                |
| grba  | git rebase --abort        |
| grbc  | git rebase --continue     |
| grbi  | git rebase --interactive  |
| grbm  | git rebase main           |

### Stash
| Alias | Command                   |
|-------|---------------------------|
| gsta  | git stash push            |
| gstp  | git stash pop             |
| gstl  | git stash list            |
| gstaa | git stash apply           |
| gstd  | git stash drop            |
| gsts  | git stash show --patch    |

### Merge & Cherry-pick
| Alias | Command                   |
|-------|---------------------------|
| gm    | git merge                 |
| gmff  | git merge --ff-only       |
| gmom  | git merge origin/main     |
| gcp   | git cherry-pick           |
| gcpc  | git cherry-pick --continue|

### Reset & Restore
| Alias | Command                   |
|-------|---------------------------|
| grh   | git reset                 |
| grhh  | git reset --hard          |
| grhs  | git reset --soft          |
| grs   | git restore               |
| grst  | git restore --staged      |

### Misc
| Alias | Command                   |
|-------|---------------------------|
| gr    | git remote                |
| grv   | git remote --verbose      |
| gsh   | git show                  |
| gbl   | git blame -w              |
| grt   | cd to repo root           |
| gta   | git tag --annotate        |

## Gitui

| Key   | Action              |
|-------|---------------------|
| h/j/k/l | Navigate          |
| C-b/C-f | Page up/down      |
| g / G | Top / bottom        |
| ?     | Help                |
| 1-5   | Switch tabs         |
