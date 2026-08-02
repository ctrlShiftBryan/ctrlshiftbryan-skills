---
name: worktrees
description: Bryan's git worktree workflow (his gw, gwct, gwb, gwl zsh aliases). Use whenever the task involves git worktrees in any way - creating a worktree, starting a new branch to work in parallel, checking out an existing or remote branch into a worktree, getting back to the main repo from a worktree, listing worktrees, or cleaning up merged worktrees and their branches. Trigger even on casual phrasing like "new worktree for X", "work on X in a worktree", "spin up a branch for this", or "clean up my worktrees".
---

# Bryan's worktree workflow

Bryan manages worktrees with zsh functions in `~/.zsh/aliases.sh`: `gwct` (create), `gw` (checkout), `gwb` (back to main repo), `gwl` (interactive list; pressing `c` cleans merged worktrees). These are interactive shell functions — they `cd`, prompt for confirmation, and `gwl` is a Node TUI — so do not invoke them yourself. Run the equivalent git commands below, which reproduce exactly what the functions do. When telling Bryan what to type himself, use the alias names.

## Layout convention (the core rule)

For a repo at `/path/to/<repo>`, every worktree lives in a sibling directory:

```
/path/to/<repo>-worktrees/<branch-name>
```

One directory per branch, named exactly after the branch (a branch like `feature/scoring` creates a nested dir — that's expected). Never put worktrees inside the repo, in `/tmp`, or anywhere else; the sibling `-worktrees` folder is what all of Bryan's tooling expects.

## Ground rules

- Create worktrees from the **main repo** while it is on `main`/`master`. If you're currently inside a worktree, resolve the main repo path first — the first entry of `git worktree list` is always the main working tree:
  ```
  git worktree list --porcelain | head -1 | sed 's/^worktree //'
  ```
- If a worktree directory for that branch already exists, don't create anything — just use/report the existing one.
- Leave the main repo checked out on `main` — worktrees exist precisely so main never has to switch branches.

## Create a new branch + worktree (`gwct <branch>`)

From the main repo root, on main:

```
mkdir -p ../<repo>-worktrees
git worktree add ../<repo>-worktrees/<branch> -b <branch>
```

Error if the branch already exists (then it's a `gw` case instead).

## Check out an existing branch into a worktree (`gw <branch>`)

- Local branch exists: `git worktree add ../<repo>-worktrees/<branch> <branch>`
- Not local: `git fetch origin`, and if it exists on the remote, create a tracking branch:
  ```
  git worktree add --track -b <branch> ../<repo>-worktrees/<branch> origin/<branch>
  ```
- Exists neither place: stop and say so — don't silently invent a new branch (that's what `gwct` is for).

## Back to the main repo (`gwb`)

`cd` to the main working tree path (first entry of `git worktree list`, as above).

## List and clean up (`gwl`, then `c` / `gwc`)

List with `git worktree list`. "Clean up" means, for each worktree whose branch is **merged**:

```
git worktree remove <path>     # refuses if dirty — never --force without asking Bryan
git branch -d <branch>         # fall back to -D only when the merge was a squash-merge
```

How to decide a branch is merged, in order of preference:
1. `gh pr list --head <branch> --state all --json state --jq '.[0].state'` → `MERGED` (this is what Bryan's tooling checks; handles squash merges)
2. If `gh` is unavailable or there's no PR: `git branch --merged main` from the main repo.

Skip (and tell Bryan about) any worktree with uncommitted changes or an unmerged branch — cleanup is only for finished work. Run cleanup from the main repo, never from inside the worktree being removed.
