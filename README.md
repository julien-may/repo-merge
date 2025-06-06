# repo-merge.sh

A simple script to **merge one Git repository into another** by placing its contents into a subdirectory while **preserving the entire commit history**.

This is useful when consolidating multiple Git projects into a single repository, creating a monorepo, or just archiving your personal contributions across various projects.


## Why?

Whenever I leave a company or wrap up a long-term collaboration, I want to keep a clean record of the projects I contributed to. Not to publish them (most of the work is internal and confidential), but simply to have them archived for myself. For learning, future reference, or just to remember what I worked on.

At most companies, I end up working across dozens of different projects, each with its own Git repository. And when it's time to move on, I often copy those repos into a folder. Sometimes that's on a hard drive, sometimes in a cloud folder. Then I forget about them. They are not organized, not searchable, and over time I even forget what I contributed to.

What I really want is to pull all those repositories into a single Git repo. One folder per project, with all the commit history preserved. That way I can name the repository after the company, keep it private, and still have a tidy, complete archive of everything I worked on during that time.

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
