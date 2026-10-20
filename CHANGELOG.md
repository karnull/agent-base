# Changelog

## added/modified:

* fix/compose-image-and-mount: each project builds its own container image, and its .devcontainer folder is read-only inside the container.
* fix/default-branch: AGENTS.md looks up the default branch instead of assuming it is called main.
* fix/changelog-location: AGENTS.md keeps the changelog in the branch's worktree, so it is merged with the pull request.
* fix/absolute-project-paths: projects created with a relative destination get full paths, so the container starts.
* fix/parent-lookup: AGENTS.md finds the upstream of a forked project, so the fork is synced and pull requests go upstream.
* feature/global-claude-md: general behaviour moves to a shared CLAUDE.md, leaving AGENTS.md with only the git and GitHub workflow.
* fix/copier-recopy: projects can be kept up to date with copier update, and folder names with dots or spaces work.
* feature/ask-only-fork: copier copy asks only for the fork and takes the project name and path from the current folder; devenv gains init and update.
* docs/readme: short readme covering setup and usage.
* feature/init-copier-args: devenv init passes anything after the project name to copier, so the fork can be given without the prompt.
* refactor/env-outside-project: each project's compose.yaml, .env and copier answers move to ~/.local/share/devenv/<slug>, a git repository out of reach of the container, while the Dockerfile moves to the project root; projects live in ~/Blackwall, the template is rendered from GitHub, devenv update works on a copy so it never runs git in the project's own repository, and each agent can play a cyberpunk character named by the new character answer. New containers' com.docker.compose.project.working_dir label points at ~/.local/share/devenv/<slug> rather than the project, which Uplink reads.
* refactor/shard: each project's soul, preferences and Dockerfile live in .shard, which the agent reads at the start of every session and devenv update carries across; the Personality section is gone from AGENTS.md, the character answer names the remote connection instead, and the container's hostname is the project slug. Uplink must read the Dockerfile from .shard/Dockerfile.
* fix/container-identity: containers are named after the project's slug, without the -devcontainer suffix, and commits made in one are signed by its character as <character-slug>@kargent.local.
* chore/security-changes: containers run with no capabilities, each keeps its own Claude folder while the shared CLAUDE.md, settings and skills are read-only managed settings, an optional claude.env shares one token, the image builds from .shard alone, and memory and processes are capped.
* feature/shared-host-config: every container shares the host's ~/.local/blackice/claude, so one login covers them all and remote-control works; the shared token file is gone, the read-only managed settings in ~/.local/blackice/claude-managed are seeded to ignore hooks and MCP servers from anywhere else, compose files move to ~/.local/blackice/devenv, gh and git authenticate with a GH_TOKEN kept in ~/.local/blackice/gh.env rather than a shared gh folder, every container reads ~/.local/blackice/configs/vim as its vimrc, images are built with the uid and gid in each project's .env, projects live under /home/kaerosol, and every agent signs its commits as <name>@kaerosol.bot.
* feature/ci: pull requests are checked with shellcheck and hadolint, the base and project images are built, and the template is rendered and its compose file validated, all with pinned tools; devenv claude-remote starts its sessions in auto permission mode.

## removed

* fix/gitconfig-mount: the host's ~/.gitconfig is no longer mounted into containers, so projects without a character sign their commits as agent <agent@kargent.local> instead of the host user.
