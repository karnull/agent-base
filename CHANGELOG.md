# Changelog

## added/modified:

* fix/compose-image-and-mount: each project builds its own container image, and its .devcontainer folder is read-only inside the container.
* fix/default-branch: AGENTS.md looks up the default branch instead of assuming it is called main.
* fix/changelog-location: AGENTS.md keeps the changelog in the branch's worktree, so it is merged with the pull request.
* fix/absolute-project-paths: projects created with a relative destination get full paths, so the container starts.
* fix/parent-lookup: AGENTS.md finds the upstream of a forked project, so the fork is synced and pull requests go upstream.
* feature/global-claude-md: general behaviour moves to a shared CLAUDE.md, leaving AGENTS.md with only the git and GitHub workflow.
* fix/copier-recopy: projects can be kept up to date with copier update, and folder names with dots or spaces work.
