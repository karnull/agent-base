# agent-base

A Copier template that gives each project its own Claude Code container, a clone
of your fork in `main/`, and an `AGENTS.md` covering the git and GitHub workflow.

## Setup

Once per machine, from this repository:

```bash
mkdir -p ~/.local/blackice/claude-managed ~/.local/blackice/configs
touch ~/.local/blackice/configs/vim
cp CLAUDE.md ~/.local/blackice/claude-managed/CLAUDE.md
docker build -t agent-base:latest --build-arg UID="$(id -u)" --build-arg GID="$(id -g)" .
ln -s "$PWD/devenv.sh" ~/.local/bin/devenv
```

`devenv` runs from this clone rather than from GitHub, so pull it to pick up
changes to `devenv.sh`.

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
commits as `Alt Cunningham <alt-cunningham@kaerosol.bot>`. Without a character,
commits are signed `agent <agent@kaerosol.bot>`. Your own `~/.gitconfig` is
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
~/.local/blackice/devenv/<slug>/   compose.yaml, .env and the copier answers, host only
~/.local/blackice/gh.env           GH_TOKEN=..., read by every container, chmod 600
~/.local/blackice/configs/vim      a file, mounted read-only into every container as ~/.vimrc
```

`devenv init` renders the whole template into `~/Blackwall/<name>`, then moves
`compose.yaml`, `.env` and `.copier-answers.yml` out to
`~/.local/blackice/devenv/<slug>` and commits them
there. That folder is one git repository for every project, created by the first
`devenv init`. Nothing running in a container can change the compose file, so
it cannot change what the host runs. `.env` holds the project's absolute path,
so the compose file works from where it now lives.

The `Dockerfile` stays in the project, at `.shard/Dockerfile`. Add packages there.
The image is built from `.shard` alone, so anything else the build needs goes in
that folder too.

`gh` and `git` authenticate with the `GH_TOKEN` in `~/.local/blackice/gh.env`.
It is never committed with the rest of a project's files, but any process in any
container can read it, so use a fine-grained token limited to the agent's own
repositories. Without the file, `gh` is logged out and pushes fail.

## Claude's files

```
~/.local/blackice/claude/                 shared by every container: login, sessions, memory
~/.local/blackice/claude-managed/         read-only in every container, at /etc/claude-code
  CLAUDE.md
  managed-settings.json
```

Every container mounts `~/.local/blackice/claude` as its Claude folder, so logging
in once, inside any container, covers them all, remote-control included.

The cost is that any agent can read and rewrite every other project's sessions,
memory and history, along with the shared login. The managed settings limit what
it can do with that. They take precedence over everything else and cannot be
changed from inside a container. `devenv` creates `managed-settings.json` on
first use with:

```json
{
  "allowManagedHooksOnly": true,
  "allowManagedMcpServersOnly": true
}
```

so hooks and MCP servers written into the shared folder by one agent never run
in the others. Hooks you do want go in `managed-settings.json` itself, and MCP
servers you do want are listed under `allowedMcpServers` there. A `CLAUDE.md` or
skill planted in the shared folder still reaches every container and can steer
its agent, including into running a script, so treat what is in there as
untrusted.

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
review and commit the result in both the project folder and `~/.local/blackice/devenv`.
Copier works on a copy of the project's files with a fresh git repository, so
nothing in the project's own `.git` runs on the host, and the results are moved
back. A symlinked file at the project's root stops the update. Anything after
`update` is passed to copier.
