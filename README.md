# repo-merge.sh

A simple script to **merge one Git repository into another** by placing its contents into a subdirectory while **preserving the entire commit history**.

This is useful when consolidating multiple Git projects into a single repository, creating a monorepo, or just archiving your personal contributions across various projects.


## Why?

Over time, I've accumulated many Git repositories across different projects and contexts. Some are personal experiments, others are contributions to various initiatives, and some are just old projects I want to keep around for reference.

The problem is that these repositories end up scattered across different locations - some on my local machine, some in cloud folders, some on different Git hosting services. They're not organized, not searchable, and over time I even forget what projects I worked on.

What I really want is to pull all those repositories into a single, well-organized Git repo. One folder per project, with all the commit history preserved. That way I can keep everything tidy in a single private repository that's easy to browse, search, and reference.

Thanks to services like GitHub, it's easy to store and secure private repositories. With this script, I can now consolidate everything cleanly and push it to a single private repo. For me, this is much better than having a scattered pile of backups floating around.

Here’s how I typically use it:

```bash
mkdir -p ~/acme

for repo in ~/work/*; do
  ./repo-merge.sh -s "$repo" -t ~/acme
done
```
The result is a single repository named acme, where each imported project has its own subdirectory and its full history.


## Features

- Merges any Git repo into another
- Preserves the complete commit history
- Automatically detects the default branch (e.g. `main`, `master`)
- Minimal and portable (pure Bash)

## Requirements

- [git-filter-repo](https://github.com/newren/git-filter-repo) must be installed and available in your `$PATH`

```bash
# macOS
brew install git-filter-repo

# Manual (any OS)
curl -o /usr/local/bin/git-filter-repo https://raw.githubusercontent.com/newren/git-filter-repo/main/git-filter-repo
chmod +x /usr/local/bin/git-filter-repo
```

## Usage

To merge one repository into another and place its contents in a subdirectory:

```sh
./repo-merge.sh --source <source_repo_path> --target <target_repo_path> [--dir <subdirectory>] [--verbose]
```

## Pushing very large merged repositories

After merging many repositories into one target repository, the first push to GitHub can become too large for a single pack upload. A typical failure looks like this:

```text
remote: fatal: pack exceeds maximum allowed size (2.00 GiB)
error: remote unpack failed: index-pack failed
```

In that case, it can help to advance the remote branch in small chunks instead of pushing `HEAD` in one go. This is most meaningful after a large repo consolidation where the local branch is ahead of `origin/main` by many merge commits and `origin/main` is an ancestor of local `HEAD`.

Use `--first-parent` for this workflow. A plain `git rev-list origin/main..HEAD` also lists commits from merged side histories, and those commits are not necessarily valid fast-forward targets for `main`.

```zsh
git fetch origin +refs/heads/main:refs/remotes/origin/main

branch=main
chunk_size=1

if ! git merge-base --is-ancestor "origin/${branch}" HEAD; then
  echo "origin/${branch} is not an ancestor of local HEAD."
  echo "Refusing to push chunks because this would not be a fast-forward."
  exit 1
fi

git rev-list --first-parent --reverse "origin/${branch}..HEAD" |
  awk -v n="$chunk_size" 'NR % n == 0 { print } END { if (NR % n != 0) print }' |
  while read sha; do
    [ -n "$sha" ] || continue
    subject=$(git show -s --format=%s "$sha")
    echo "Pushing ${branch} up to ${sha} - ${subject}"
    git push origin "${sha}:refs/heads/${branch}" || exit 1
  done
```

`chunk_size=1` is intentionally conservative: it pushes one first-parent commit at a time. For repositories produced by this merge script, those first-parent commits are usually the merge commits that added each imported repository. If your pushes are comfortably below GitHub's pack limit, you can increase `chunk_size` to push multiple first-parent commits per upload.

This does not fix a single file or single commit that exceeds GitHub's hard limits. If GitHub rejects an individual chunk because of oversized files, remove those files from history or move them to Git LFS before pushing.
