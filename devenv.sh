#!/usr/bin/env bash

# Wrapper around docker commands to standardise devcontainer development

ACTION=$1
[ $# -gt 0 ] && shift

# rendered from github, never a local copy, so only pushed template changes reach a project
TEMPLATE=${DEVENV_TEMPLATE:-gh:karnull/agent-base}
PROJECTS_DIR=${DEVENV_PROJECTS:-$HOME/Blackwall}
ENVS_DIR=${DEVENV_HOME:-$HOME/.local/share/devenv}

# a container can write the project's repositories, so their config must not run anything here
untrusted_git() {
    GIT_CONFIG_NOSYSTEM=1 git -c core.fsmonitor=false -c core.hooksPath=/dev/null "$@"
}

# cd to project root if inside git repo
if untrusted_git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    cd "$(untrusted_git rev-parse --show-toplevel)" || exit 1
fi

#-------------------------------------------------------------------------------
# default behaviour (no args)

if [ -z "$ACTION" ]; then
    lazydocker
    exit 0
fi

show_help() {
cat <<'EOF'
Usage: devenv [action] [args...]

Actions:
  init <NAME> [ARGS...] create project NAME in ~/Blackwall from the template,
                        passing ARGS to copier copy
  update [ARGS...]      apply template changes to this project and its container
                        definition, passing ARGS to copier update
  up                    start devcontainer (creates it if missing)
  down                  stop devcontainer
  restart               restart devcontainer
  delete                remove devcontainer
  logs                  follow devcontainer output
  exec <CMD>            run CMD in devcontainer
  claude-remote         run claude code with remote connection, named after the
                        character when there is one
  connect               open shell in devcontainer
  list                  list docker containers

Default:
  <no action>           open lazydocker

Notes:
  - works from anywhere inside a project, so worktrees beside main/ share the
    one container
  - each project's compose.yaml, .env and copier answers live in
    ~/.local/share/devenv/<slug>, part of a git repository no container can
    change; the Dockerfile stays in the project's .shard folder
  - DEVENV_PROJECTS, DEVENV_HOME and DEVENV_TEMPLATE override the projects
    folder, the compose files folder and the template
EOF
}

error() {
    echo -e "\033[31mError: $*\033[0m" >&2
    exit 1
}

#-------------------------------------------------------------------------------
# helper functions

slugify() {
    echo "$1" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9_-]\{1,\}/-/g; s/^-*//; s/-*$//'
}

# the folder directly inside PROJECTS_DIR that holds the current directory
find_project_root() {
    local projects here rest
    projects=$(cd "$PROJECTS_DIR" 2>/dev/null && pwd -P) || return 1
    here=$(pwd -P)
    case "$here/" in
        "$projects"/?*/*) ;;
        *) return 1 ;;
    esac
    rest=${here#"$projects"/}
    echo "$PROJECTS_DIR/${rest%%/*}"
}

# sets PROJECT_DIR, ENV_DIR and COMPOSE_ARGS for the project holding the current directory
require_env() {
    PROJECT_DIR=$(find_project_root) \
        || error "$PWD is not inside a project in $PROJECTS_DIR"
    ENV_DIR="$ENVS_DIR/$(slugify "${PROJECT_DIR##*/}")"
    [ -f "$ENV_DIR/compose.yaml" ] || error "no container definition in $ENV_DIR"
    COMPOSE_ARGS=(--project-directory "$ENV_DIR" -f "$ENV_DIR/compose.yaml")
}

compose() {
    # values left in the shell would override the ones in the env's .env
    env -u PROJECT_ROOT -u PROJECT_SLUG -u CHARACTER -u CHARACTER_SLUG docker compose "${COMPOSE_ARGS[@]}" "$@"
}

get_container_name() {
    local name
    name=$(compose config 2>/dev/null \
        | sed -n 's/^[[:space:]]*container_name:[[:space:]]*//p' \
        | head -n 1 | tr -d "\"'[:space:]")
    echo "${name:-$(slugify "${PROJECT_DIR##*/}")}"
}

get_character() {
    sed -n 's/^CHARACTER=//p' "$ENV_DIR/.env" | head -n 1
}

# these decide what the host runs, so they never stay where a container can write
HOST_FILES=(compose.yaml .env .copier-answers.yml)

move_host_files() {
    local from=$1 file
    mkdir -p "$ENV_DIR" || return 1
    for file in "${HOST_FILES[@]}"; do
        mv -f "$from/$file" "$ENV_DIR/$file" || return 1
    done
}

# copier update runs git in its destination, so it gets a fresh repository rather than the project's own
stage_project() {
    local work=$1 file
    for file in "$PROJECT_DIR"/* "$PROJECT_DIR"/.[!.]*; do
        case ${file##*/} in compose.yaml|.env|.copier-answers.yml) continue ;; esac
        [ -f "$file" ] && cp -P "$file" "$work/"
    done
    if [ -e "$PROJECT_DIR/.shard" ] || [ -L "$PROJECT_DIR/.shard" ]; then
        cp -RP "$PROJECT_DIR/.shard" "$work/" || return 1
    fi
    # cp -P copies a symlink as a link, including one swapped in after the -f test
    [ -z "$(find "$work" ! -type f ! -type d)" ] \
        || { echo "$PROJECT_DIR has a symlinked or special file" >&2; return 1; }
    for file in "${HOST_FILES[@]}"; do
        cp "$ENV_DIR/$file" "$work/" || return 1
    done
    git -C "$work" init -q && git -C "$work" add -A -f \
        && git -C "$work" -c user.name=devenv -c user.email=devenv@localhost \
            -c commit.gpgsign=false commit -q -m "before update"
}

unstage_project() {
    local work=$1 file
    move_host_files "$work" || return 1
    for file in "$work"/* "$work"/.[!.]*; do
        [ -f "$file" ] || continue
        cmp -s "$file" "$PROJECT_DIR/${file##*/}" && continue
        # -T replaces whatever is there, never writing through a symlink planted in its place
        mv -fT "$file" "$PROJECT_DIR/${file##*/}" || return 1
    done
    replace_shard "$work"
}

# swapped whole by rename, so nothing is written through a symlink planted inside the project's copy
replace_shard() {
    local work=$1
    [ -d "$work/.shard" ] || return 0
    if [ -e "$PROJECT_DIR/.shard" ] || [ -L "$PROJECT_DIR/.shard" ]; then
        mv -T "$PROJECT_DIR/.shard" "$work/.shard.old" || return 1
    fi
    mv -T "$work/.shard" "$PROJECT_DIR/.shard"
}

# every container definition lives in one repository, created on first use
ensure_envs_repo() {
    [ -d "$ENVS_DIR/.git" ] && return 0
    mkdir -p "$ENVS_DIR" && git -C "$ENVS_DIR" init -q
}

commit_env() {
    git -C "$ENVS_DIR" add -- "$ENV_DIR" \
        && git -C "$ENVS_DIR" commit -q -m "$1" -- "$ENV_DIR"
}

#-------------------------------------------------------------------------------
# actions

case "$ACTION" in
    init)
        [ -z "$1" ] && error "no project name provided"
        name=$1
        shift
        slug=$(slugify "$name")
        [ -n "$slug" ] || error "$name has no letters or digits to name the container after"
        PROJECT_DIR="$PROJECTS_DIR/$name"
        ENV_DIR="$ENVS_DIR/$slug"
        [ -e "$PROJECT_DIR" ] && error "$PROJECT_DIR already exists"
        [ -e "$ENV_DIR" ] && error "$ENV_DIR already exists"
        ensure_envs_repo || error "could not create a git repository in $ENVS_DIR"

        # anything after the name goes to copier, e.g. --data fork_url=owner/repo
        copier copy --trust --data projects_dir="$PROJECTS_DIR" --data project_name="$name" \
            --data project_slug="$slug" "$@" "$TEMPLATE" "$PROJECT_DIR" \
            || error "copier copy failed for $PROJECT_DIR"
        move_host_files "$PROJECT_DIR" \
            || error "could not move ${HOST_FILES[*]} from $PROJECT_DIR to $ENV_DIR"
        commit_env "$slug: compose file and environment for $PROJECT_DIR" \
            || error "could not commit $ENV_DIR in $ENVS_DIR"
        echo "Start the container with: cd $PROJECT_DIR && devenv up"
        exit
        ;;

    update|u)
        require_env
        # beside ENV_DIR rather than in /tmp, so files move back into the project by rename
        work=$(mktemp -d "$ENVS_DIR/.update.XXXXXX") || exit 1
        trap 'rm -rf "$work"' EXIT
        stage_project "$work" || error "could not copy $PROJECT_DIR to update it"
        copier update --trust --defaults "$@" "$work" \
            || error "copier update failed for $PROJECT_DIR"
        unstage_project "$work" || error "could not move the update into $PROJECT_DIR and $ENV_DIR"
        echo "Review the changes with git diff in $PROJECT_DIR and $ENVS_DIR, then commit them."
        exit
        ;;

    start|up)
        require_env
        compose up -d
        exit
        ;;

    stop|down)
        require_env
        compose stop
        exit
        ;;

    restart|r)
        require_env
        compose restart
        exit
        ;;

    delete|rm)
        require_env
        compose down
        exit
        ;;

    logs)
        require_env
        compose logs -f "$@"
        exit
        ;;

    claude-remote|cr)
        require_env
        container=$(get_container_name)
        character=$(get_character)
        docker exec -w "$PWD" "$container" claude remote-control --name "${character:-$container}"
        exit
        ;;

    exec|e)
        [ -z "$1" ] && error "no command provided"
        require_env
        # host and container paths are identical, so the current directory exists in both
        docker exec -w "$PWD" "$(get_container_name)" sh -c "$*"
        exit
        ;;

    connect|c)
        require_env
        docker exec -ti -w "$PWD" "$(get_container_name)" bash
        exit
        ;;

    list|l|ls)
        docker container list --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
        exit
        ;;

    --help|-h|help|h)
        show_help
        exit 0
        ;;

    *)
        error "unknown action: $ACTION (see devenv help)"
        ;;
esac
