function vibe() {
  local branch="$1"
  local repo_root subdir worktree_path

  # Step 1: Capture paths
  repo_root=$(git rev-parse --show-toplevel) || return 1
  subdir="${PWD#$repo_root/}"  # remove repo root prefix from $PWD
  worktree_path="$repo_root/../$(basename "$repo_root")-$branch"

  # Step 2: Create worktree from root
  cd "$repo_root" || return 1
  git worktree add "$worktree_path" -b "$branch" || return 1

  # Step 3: Move to equivalent subdir and run claude
  cd "$worktree_path/$subdir" 2>/dev/null || cd "$worktree_path" || return 1
  claude
}

function unvibe() {
  local delete_branch=false

  # Parse flags
  if [[ "$1" == "-d" ]]; then
    delete_branch=true
  fi

  local branch main_repo_root worktree_root subdir worktree_path

  # Get current branch
  branch=$(git branch --show-current)
  if [[ -z "$branch" ]]; then
    echo "You're not on a branch. Are you in a detached HEAD or bare repo?"
    return 1
  fi

  # Get the main repo root even from inside a worktree
  main_repo_root=$(git rev-parse --git-common-dir | xargs dirname)
  main_repo_root=$(cd "$main_repo_root" && pwd) || return 1

  # Get the current worktree root and relative subdir
  worktree_root=$(git rev-parse --show-toplevel)
  subdir="${PWD#$worktree_root/}"

  # Construct the worktree path
  worktree_path="$main_repo_root/../$(basename "$main_repo_root")-$branch"
  worktree_path=$(cd "$worktree_path" 2>/dev/null && pwd) || {
    echo "Worktree '$worktree_path' does not exist."
    return 1
  }

  # Move out of the worktree to avoid shell weirdness
  cd "$main_repo_root" || cd ~ || return 1

  # Remove the worktree
  git worktree remove --force "$worktree_path" || return 1

  # Optionally delete the branch
  if $delete_branch; then
    git -C "$main_repo_root" branch -D "$branch" || echo "Branch '$branch' could not be deleted."
    echo "Removed worktree and deleted branch '$branch'."
  else
    echo "Removed worktree for branch '$branch'. Branch was not deleted."
  fi

  # Return to equivalent subdir in main repo, if it exists
  if [[ -n "$subdir" && -d "$main_repo_root/$subdir" ]]; then
    cd "$main_repo_root/$subdir" || cd "$main_repo_root"
  else
    cd "$main_repo_root"
  fi
}