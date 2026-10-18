# agent-base

A Copier template that gives each project its own Claude Code container, a clone
of your fork in `main/`, and an `AGENTS.md` covering the git and GitHub workflow.

## Setup

Once per machine, from this repository:

```bash
mkdir -p ~/.local/share/blackwall/claude/managed ~/.local/share/blackwall/claude/skills
cp CLAUDE.md ~/.local/share/blackwall/claude/managed/CLAUDE.md
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

## The shard

Each project has a `.shard/` folder that the agent reads at the start of every
session:

```
.shard/soul.md          the agent's soul, written by you
.shard/preferences.md   your preferences, added to as they come up
.shard/Dockerfile       what the container image is built from
```

The `character` answer names the remote connection that `devenv claude-remote`
opens, such as `Alt Cunningham`; without one the connection takes the container's
name. Only a short name is accepted.

The character also signs every commit made in the container. `Alt Cunningham`
commits as `Alt Cunningham <alt-cunningham@kargent.local>`. Without a character,
commits are signed `agent <agent@kargent.local>`. Your own `~/.gitconfig` is
never mounted, so its identity and settings stay on the host.

```bash
devenv init repo --data fork_url=user/agent-repo --data "character=Alt Cunningham"
devenv update --data "character=Alt Cunningham"     # for an existing project
```

The answer is kept in the copier answers file and `.env` beside the compose file,
where agents cannot write. Inside, the container's hostname is the project's slug.

## Where things live

```
~/Blackwall/<name>/                the project and its .shard, mounted into its container
~/.local/share/devenv/<slug>/      compose.yaml, .env and the copier answers, host only
```

`devenv init` renders the whole template into `~/Blackwall/<name>`, then moves
`compose.yaml`, `.env` and `.copier-answers.yml` out to
`~/.local/share/devenv/<slug>` and commits them
there. That folder is one git repository for every project, created by the first
`devenv init`. Nothing running in a container can change the compose file, so
it cannot change what the host runs. `.env` holds the project's absolute path,
so the compose file works from where it now lives.

The `Dockerfile` stays in the project, at `.shard/Dockerfile`. Add packages there.
The image is built from `.shard` alone, so anything else the build needs goes in
that folder too.

## Claude's files

```
~/.local/share/blackwall/
  claude.env                     optional, CLAUDE_CODE_OAUTH_TOKEN=..., chmod 600
  claude/managed/                read-only in every container, at /etc/claude-code
    CLAUDE.md
    managed-settings.json        settings and hooks every agent gets
  claude/skills/                 read-only in every container
  cages/<slug>/claude/           one per project: sessions, memory, history, login
```

Each container has its own Claude folder, so one agent cannot read or rewrite
another's sessions or memory. The shared `CLAUDE.md` and settings are Claude
Code's managed settings, which take precedence over everything else and cannot
be changed from inside a container. Each container still has its own
`settings.json`, which only affects that container.

`devenv init` and `devenv up` create these folders. `devenv delete` leaves the
project's Claude folder alone, so sessions survive the container being
recreated; remove it by hand once the project is gone.

Without `claude.env`, log in once inside each container. If you keep a token
there instead, it is shared by every container and readable by any process in
them.

Each container is limited to 8 GB of memory and 1024 processes.

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
