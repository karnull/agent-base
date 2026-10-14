# agent-base

A Copier template that gives each project its own Claude Code container, a clone
of your fork in `main/`, and an `AGENTS.md` covering the git and GitHub workflow.

## Setup

Once per machine, from this repository:

```bash
cp CLAUDE.md ~/.claude/CLAUDE.md
docker build -t agent-base:latest --build-arg UID="$(id -u)" --build-arg GID="$(id -g)" .
ln -s "$PWD/devenv.sh" ~/.local/bin/devenv
```

## Usage

```bash
cd ~/Projects
devenv init TokyoBurnNvim       # asks for the fork's URL
cd TokyoBurnNvim && devenv up && devenv claude-remote
```

Anything after the name is passed to `copier copy`, so the fork can be given up
front instead of at the prompt:

```bash
devenv init repo --data fork_url=user/agent-repo
```

To pick up template changes, run `devenv update` anywhere in the project and
commit the result. Commit any changes to this repository first; `devenv` refuses
to run against a template with uncommitted changes.
