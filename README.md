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
devenv init TokyoBurnNvim       # asks for the fork's URL
cd ~/Blackwall/TokyoBurnNvim && devenv up && devenv claude-remote
```

Anything after the name is passed to `copier copy`, so the fork can be given up
front instead of at the prompt:

```bash
devenv init repo --data fork_url=user/agent-repo
```

Every `devenv` command works from anywhere inside a project folder.

## Characters

Each project's agent can play a character from cyberpunk, given as the
`character` answer. It adds a Personality section to the project's `AGENTS.md`:
the agent takes on the character's voice when talking to you, while commits, pull
requests, code and docs stay plain. Only a short name is accepted.

```bash
devenv init repo --data fork_url=user/agent-repo --data "character=Molly Millions"
devenv update --data "character=Molly Millions"     # for an existing project
```

The answer is kept in the copier answers file beside the compose file, where
agents cannot write.

## Where things live

```
~/Blackwall/<name>/                the project and its Dockerfile, mounted into its container
~/.local/share/devenv/<slug>/      compose.yaml, .env and the copier answers, host only
```

`devenv init` renders the whole template into `~/Blackwall/<name>`, then moves
`compose.yaml`, `.env` and `.copier-answers.yml` out to
`~/.local/share/devenv/<slug>` and commits them
there. That folder is one git repository for every project, created by the first
`devenv init`. Nothing running in a container can change the compose file, so
it cannot change what the host runs. `.env` holds the project's absolute path,
so the compose file works from where it now lives.

The `Dockerfile` stays at the project's root. Add packages there.

## Template changes

Projects are rendered from `gh:karnull/agent-base`, never from a local copy, so
only pushed changes reach a project. Copier picks the newest tag when there is
one, so tag a release to hand it out.

To try a template branch before it is merged, point `devenv` at the fork and the
branch:

```bash
DEVENV_TEMPLATE=gh:karshPrime/agent-base devenv init repo --vcs-ref <branch>
```

To pick up template changes, run `devenv update` anywhere in the project, then
review and commit the result in both the project folder and `~/.local/share/devenv`.
Copier works on a copy of the project's files with a fresh git repository, so
nothing in the project's own `.git` runs on the host, and the results are moved
back. A symlinked file at the project's root stops the update. Anything after
`update` is passed to copier.
