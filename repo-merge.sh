#!/bin/bash

# Color definitions
COLOR_PATH="\033[1;97m"     # bold white
COLOR_SUCCESS="\033[0;32m"  # green
COLOR_VERBOSE="\033[2m"     # dim gray
COLOR_ERROR="\033[0;31m"    # red
COLOR_RESET="\033[0m"

# Conditional verbose logger
vlog() {
  if $verbose; then
    echo -e "${COLOR_VERBOSE}$1${COLOR_RESET}"
  fi
}

# Check exit status of the last command and exit if failed
check_step() {
  if [ $1 -ne 0 ]; then
    fail
  fi
}

fail() {
  echo -e "${COLOR_ERROR}failed!${COLOR_RESET}"
  exit 1
}

merge() {
  local source_repo_path=$1
  local target_repo_path=$2
  local target_subdir=$3
  local verbose=$4

  if [ ! -d "$source_repo_path/.git" ]; then
    echo "Error: $source_repo_path does not exist or is not a Git repository"
    return 1
  fi
  if [ ! -d "$target_repo_path/.git" ]; then
    echo "Error: $target_repo_path does not exist or is not a Git repository"
    return 1
  fi

  if [ -z "$target_subdir" ]; then
    target_subdir=$(basename "$source_repo_path")
  fi

  local source_display="$source_repo_path"
  local target_display="${target_repo_path}/${target_subdir}"
  local echo_flag="-e"

  $verbose || echo_flag="-en"
  echo $echo_flag "Merging ${COLOR_PATH}${source_display}${COLOR_RESET} into ${COLOR_PATH}${target_display}${COLOR_RESET}... "

  local default_branch=$(cd "$source_repo_path" && git remote show origin 2>/dev/null | grep 'HEAD branch' | grep -v '(unknown)' | cut -d':' -f2 | tr -d ' ')
  if [ -z "$default_branch" ]; then
    # Fallback to try receiving the default branch by looking at the HEAD file
    default_branch=$(cd "$source_repo_path" && cat .git/HEAD | cut -d'/' -f3)

    if [ -z "$default_branch" ]; then
      vlog "Error: Could not detect default branch of $source_repo_path"
      fail
    fi
  fi

  vlog "Detected default branch: $default_branch"

  local temp_dir=$(mktemp -d -t migrate-"${target_subdir}"-XXXXXX)
  vlog "Cloning $source_repo_path into $temp_dir on branch '$default_branch'..."
  git clone --no-local --branch "$default_branch" --single-branch "$source_repo_path" "$temp_dir" >/dev/null 2>&1
  check_step $?

  vlog "Rewriting history into subdirectory '$target_subdir'..."
  (cd "$temp_dir" && git filter-repo --to-subdirectory-filter "$target_subdir" >/dev/null 2>&1)
  check_step $?

  local remote_name="temp-remote-$target_subdir"
  vlog "Adding temporary remote..."
  (cd "$target_repo_path" && git remote add "$remote_name" "$temp_dir")
  check_step $?

  vlog "Fetching branch '$default_branch'..."
  (cd "$target_repo_path" && git fetch "$remote_name" >/dev/null 2>&1)
  check_step $?

  vlog "Merging '$default_branch' into $target_subdir..."
  (cd "$target_repo_path" && git merge "$remote_name/$default_branch" --allow-unrelated-histories -m "Merge $target_subdir from $source_repo_path" >/dev/null 2>&1)
  check_step $?

  vlog "Cleaning up..."
  (cd "$target_repo_path" && git remote remove "$remote_name")
  rm -rf "$temp_dir"

  echo -e "${COLOR_SUCCESS}done!${COLOR_RESET}"
}

print_help() {
  echo "Usage:"
  echo "  repo-merge.sh --source <source_repo> --target <target_repo> [--dir <subdirectory>] [--verbose]"
  echo
  echo "Options:"
  echo "  -s, --source    Path to the source Git repository to import"
  echo "  -t, --target    Path to the target repo"
  echo "  -d, --dir       (Optional) Target subdirectory name inside the repo (defaults to repo name)"
  echo "  -v, --verbose   Enable detailed output (faint gray logs)"
  echo "  -h, --help      Show this help message"
  echo
  echo "Example:"
  echo "  ./repo-merge.sh --source ~/src/work/actions --target ~/src/ricardo --dir actions --verbose"
}

main() {
  source_repo_path=""
  target_repo_path=""
  target_subdir=""
  verbose=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      -s | --source)
        source_repo_path="$2"
        shift 2
        ;;
      -t | --target)
        target_repo_path="$2"
        shift 2
        ;;
      -d | --dir)
        target_subdir="$2"
        shift 2
        ;;
      -v | --verbose)
        verbose=true
        shift
        ;;
      -h | --help)
        print_help
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        echo "Use --help to show usage."
        exit 1
        ;;
    esac
  done

  if [ -z "$source_repo_path" ] || [ -z "$target_repo_path" ]; then
    echo "Usage: repo-merge --source <source_repo> --target <target_repo> [--dir <subdirectory>] [--verbose]"
    return 1
  fi

  if ! command -v git-filter-repo >/dev/null 2>&1; then
    echo "Error: 'git filter-repo' is not installed or not in your PATH."
    echo
    echo "To install it:"
    echo "    On macOS (Homebrew):     brew install git-filter-repo"
    echo "    On any OS (manual):      https://github.com/newren/git-filter-repo"
    echo
    echo "Note: It is not included by default with Git and must be installed separately."
    return 1
  fi

  merge "$source_repo_path" "$target_repo_path" "$target_subdir" $verbose
}

main "$@"
