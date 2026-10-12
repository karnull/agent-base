# Changelog

## added/modified:

* fix/compose-image-and-mount: each project builds its own container image, and its .devcontainer folder is read-only inside the container.
* fix/default-branch: AGENTS.md looks up the default branch instead of assuming it is called main.
* fix/changelog-location: AGENTS.md keeps the changelog in the branch's worktree, so it is merged with the pull request.
