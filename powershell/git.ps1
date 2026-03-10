# Git aliases (mirrors oh-my-zsh git plugin)
function _git_current_branch { git rev-parse --abbrev-ref HEAD }
function _git_main_branch { (git symbolic-ref refs/remotes/origin/HEAD --short) -replace '^origin/', '' }

# Status
function gst  { git status @args }
function gss  { git status --short @args }
function gsb  { git status --short --branch @args }

# Add
function ga   { git add @args }
function gaa  { git add --all @args }
function gapa { git add --patch @args }
function gau  { git add --update @args }

# Commit
function gc    { git commit --verbose @args }
function gca   { git commit --verbose --all @args }
function gcA   { git commit --verbose --amend @args }
function gcaA  { git commit --verbose --all --amend @args }
function gcaN  { git commit --verbose --all --no-edit --amend @args }
function gcmsg { git commit --message @args }
function gcam  { git commit --all --message @args }
function gcf   { git config --list @args }

# Diff
function gd    { git diff @args }
function gds   { git diff --staged @args }
function gdca  { git diff --cached @args }
function gdcw  { git diff --cached --word-diff @args }
function gdw   { git diff --word-diff @args }
function gdup  { git diff '@{upstream}' @args }
function gdt   { git diff-tree --no-commit-id --name-only -r @args }

# Checkout
function gco  { git checkout @args }
function gcb  { git checkout -b @args }
function gcm  { git checkout (_git_main_branch) @args }

# Switch
function gsw  { git switch @args }
function gswc { git switch --create @args }
function gswm { git switch (_git_main_branch) @args }

# Fetch
function gf   { git fetch @args }
function gfa  { git fetch --all --tags --prune --jobs=10 @args }
function gfo  { git fetch origin @args }

# Pull
function gl    { git pull @args }
function gpr   { git pull --rebase @args }
function gpra  { git pull --rebase --autostash @args }
function gprav { git pull --rebase --autostash -v @args }
function gprom { git pull --rebase origin main @args }
function glum  { git pull upstream main @args }

# Push
function gp    { git push @args }
function gpf   { git push --force-with-lease --force-if-includes @args }
function gpF   { git push --force @args }
function gpsup { git push --set-upstream origin (_git_current_branch) @args }
function gpv   { git push --verbose @args }
function gpod  { git push origin --delete @args }

# Log
function glog  { git log --oneline --decorate --graph @args }
function gloga { git log --oneline --decorate --graph --all @args }
function glo   { git log --oneline --decorate @args }
function glol  { git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' @args }
function glola { git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --all @args }
function glg   { git log --stat @args }
function glgp  { git log --stat --patch @args }

# Rebase
function grb   { git rebase @args }
function grba  { git rebase --abort @args }
function grbc  { git rebase --continue @args }
function grbi  { git rebase --interactive @args }
function grbo  { git rebase --onto @args }
function grbs  { git rebase --skip @args }
function grbm  { git rebase (git symbolic-ref refs/remotes/origin/HEAD --short) @args }
function grbom { git rebase origin/main @args }

# Stash
function gsta  { git stash push @args }
function gstp  { git stash pop @args }
function gstl  { git stash list @args }
function gstaa { git stash apply @args }
function gstd  { git stash drop @args }
function gstc  { git stash clear @args }
function gsts  { git stash show --patch @args }

# Merge
function gm    { git merge @args }
function gma   { git merge --abort @args }
function gmc   { git merge --continue @args }
function gms   { git merge --squash @args }
function gmff  { git merge --ff-only @args }
function gmom  { git merge origin/main @args }

# Cherry-pick
function gcp   { git cherry-pick @args }
function gcpa  { git cherry-pick --abort @args }
function gcpc  { git cherry-pick --continue @args }

# Branch
function gb    { git branch @args }
function gba   { git branch --all @args }
function gbd   { git branch --delete @args }
function gbD   { git branch --delete --force @args }
function gbr   { git branch --remote @args }
function gbm   { git branch --move @args }
function gbnm  { git branch --no-merged @args }

# Reset & Restore
function grh   { git reset @args }
function grhh  { git reset --hard @args }
function grhs  { git reset --soft @args }
function grs   { git restore @args }
function grst  { git restore --staged @args }

# Remote
function gr    { git remote @args }
function grv   { git remote --verbose @args }
function gra   { git remote add @args }
function grrm  { git remote remove @args }
function grmv  { git remote rename @args }
function grset { git remote set-url @args }
function grup  { git remote update @args }

# Revert
function grev  { git revert @args }
function greva { git revert --abort @args }
function grevc { git revert --continue @args }

# Remove
function grm   { git rm @args }
function grmc  { git rm --cached @args }

# Show
function gsh   { git show @args }
function gcount { git shortlog --summary --numbered @args }

# Tag
function gta  { git tag --annotate @args }
function gts  { git tag --sign @args }
function gtv  { git tag --sort=-v:refname @args }

# Worktree
function gwt   { git worktree @args }
function gwta  { git worktree add @args }
function gwtls { git worktree list @args }
function gwtrm { git worktree remove @args }

# Blame & Clean
function gbl    { git blame -w @args }
function gclean { git clean --interactive -d @args }

# Repo root
function grt { Set-Location (git rev-parse --show-toplevel) }
