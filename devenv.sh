#!/usr/bin/env bash

# Wrapper around docker commands to standardise devcontainer development

ACTION=$1
[ $# -gt 0 ] && shift

# the copier template is the repository this script lives in, found through any symlink
TEMPLATE_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

# cd to project root if inside git repo; init works in the current folder instead
if [ "$ACTION" != init ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    cd "$(git rev-parse --show-toplevel)" || exit 1
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
  init <NAME>     create project NAME in the current folder from the template
  up              start devcontainer (creates it if missing)
  down            stop devcontainer
  restart         restart devcontainer
  delete          remove devcontainer
  logs            follow devcontainer output
  exec <CMD>      run CMD in devcontainer
  claude-remote   run claude code with remote connection
  connect         open shell in devcontainer
  list            list docker containers

Default:
  <no action>     open lazydocker

Notes:
  - runs from git repo root if present
  - .devcontainer/compose.yaml is searched for upwards, so worktrees
    beside main/ share the one container
EOF
}

error() {
    echo -e "\033[31mError: $*\033[0m" >&2
    exit 1
}

#-------------------------------------------------------------------------------
# helper functions

# the compose file sits beside main/ and the worktrees, not inside the repo
find_compose_file() {
    local dir="$PWD"
    while [ -n "$dir" ]; do
        if [ -f "$dir/.devcontainer/compose.yaml" ]; then
            echo "$dir/.devcontainer/compose.yaml"
            return 0
        fi
        dir="${dir%/*}"
    done
    return 1
}

require_compose_file() {
    COMPOSE_FILE=$(find_compose_file) \
        || error "no .devcontainer/compose.yaml in $PWD or any parent"
}

compose() {
    docker compose -f "$COMPOSE_FILE" "$@"
}

get_container_name() {
    local compose_file name
    if compose_file=$(find_compose_file); then
        # compose config fills in the names from .devcontainer/.env
        name=$(docker compose -f "$compose_file" config 2>/dev/null \
            | sed -n 's/^[[:space:]]*container_name:[[:space:]]*//p' \
            | head -n 1 | tr -d "\"'[:space:]")
    fi
    echo "${name:-${PWD##*/}-devcontainer}"
}

# copier mishandles a template with uncommitted changes and deletes generated files
require_clean_template() {
    [ -z "$(git -C "$TEMPLATE_DIR" status --porcelain)" ] \
        || error "the template at $TEMPLATE_DIR has uncommitted changes; commit or stash them first"
}

#-------------------------------------------------------------------------------
# actions

case "$ACTION" in
    init)
        [ -z "$1" ] && error "no project name provided"
        [ -e "$1" ] && error "$1 already exists"
        require_clean_template
        mkdir "$1" && cd "$1" || exit 1
        # HEAD rather than the newest tag, so the template matches this checkout
        copier copy --trust --vcs-ref HEAD "$TEMPLATE_DIR" .
        exit
        ;;

    start|up)
        require_compose_file
        compose up -d
        exit
        ;;

    stop|down)
        require_compose_file
        compose stop
        exit
        ;;

    restart|r)
        require_compose_file
        compose restart
        exit
        ;;

    delete|rm)
        require_compose_file
        compose down
        exit
        ;;

    logs)
        require_compose_file
        compose logs -f "$@"
        exit
        ;;
	
	claude-remote|cr)
		container=$(get_container_name)
		docker exec -w "$PWD" "$container" claude remote-control --name "$container"
		exit
		;;

    exec|e)
        [ -z "$1" ] && error "no command provided"
        # host and container paths are identical, so the current directory exists in both
        docker exec -w "$PWD" "$(get_container_name)" sh -c "$*"
        exit
        ;;

    connect|c)
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
