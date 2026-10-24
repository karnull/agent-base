# base image for every project agent: debian + vim, git, gh, claude-code

#---------------------------------------------------------------------------------------------------

FROM debian:trixie-slim@sha256:62bd423aeee912639ca8ee681c2b762cb3e25137e0a92b20be455898a9f034ad

# every RUN below fails on the first failing command of a pipe, not just the last
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# a user name, not a secret
# hadolint ignore=DL3064
ARG USERNAME=dev
ARG UID=1000
ARG GID=1000

# each project is bind mounted at the SAME absolute path it has on the host, and nothing
# else is mounted, so a container sees its own project and an otherwise empty parent.
ARG WORKSPACE_ROOT=/home/kaerosol/Blackwall

ARG TZ=Australia/Melbourne
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        gh \
        git \
        less \
        ripgrep \
        tree-sitter-cli \
        tzdata \
        vim \
    && rm -rf /var/lib/apt/lists/*

#---------------------------------------------------------------------------------------------------

# checksum of the signing key, not a version: claude-code itself follows the channel.
# the key's fingerprint is published at https://code.claude.com/docs/en/setup as
# 31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE.
ARG CLAUDE_CODE_KEY_SHA256=bd70a5e4a268002704024ceba7f8446024114e94f3f0bdd11c23a9e592be81c6
ARG CLAUDE_CODE_CHANNEL=stable

# claude code has no debian package, so it comes from anthropic's signed apt repository
RUN install -d -m 0755 /etc/apt/keyrings \
    && curl -fsSL -o /etc/apt/keyrings/claude-code.asc https://downloads.claude.ai/keys/claude-code.asc \
    && if ! echo "${CLAUDE_CODE_KEY_SHA256}  /etc/apt/keyrings/claude-code.asc" | sha256sum -c - ; then \
           echo "the signing key does not match CLAUDE_CODE_KEY_SHA256: check its fingerprint against" >&2; \
           echo "https://code.claude.com/docs/en/setup before trusting it, it may have been rotated." >&2; \
           exit 1; \
       fi \
    && echo "deb [signed-by=/etc/apt/keyrings/claude-code.asc] https://downloads.claude.ai/claude-code/apt/${CLAUDE_CODE_CHANNEL} ${CLAUDE_CODE_CHANNEL} main" \
        > /etc/apt/sources.list.d/claude-code.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends claude-code \
    && rm -rf /var/lib/apt/lists/*

# macos hands out gids that debian already assigns (20 is staff on the host, dialout here),
# so join the group that owns the gid instead of failing to create a second one
RUN group="$(getent group "${GID}" | cut -d: -f1 || true)" \
    && if [ -z "$group" ]; then \
           groupadd -g "${GID}" "${USERNAME}"; \
           group="${USERNAME}"; \
       fi \
    && useradd -l -m -u "${UID}" -g "$group" -s /bin/bash "${USERNAME}"

#---------------------------------------------------------------------------------------------------

# push and pull over https using GH_TOKEN from the host: gh hands it to git on demand,
# so no ssh key is mounted and `gh pr create` uses the same credential.
RUN git config --system credential."https://github.com".helper '!gh auth git-credential'


#---------------------------------------------------------------------------------------------------

RUN mkdir -p "/home/${USERNAME}/.config/gh" "/home/${USERNAME}/.claude" "${WORKSPACE_ROOT}" \
    && chown -R "${UID}:${GID}" "/home/${USERNAME}" "${WORKSPACE_ROOT}"

USER ${USERNAME}
ENV USER=${USERNAME}
ENV HOME=/home/${USERNAME}
ENV XDG_CONFIG_HOME=/home/${USERNAME}/.config
ENV SHELL=/bin/bash
ENV PATH=/home/${USERNAME}/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV TZ=${TZ}

#---------------------------------------------------------------------------------------------------

ENV EDITOR=vim
ENV VISUAL=vim

ENV CLAUDE_CONFIG_DIR=/home/${USERNAME}/.claude

ENV USE_BUILTIN_RIPGREP=0
ENV DISABLE_AUTOUPDATER=1

WORKDIR ${WORKSPACE_ROOT}
CMD ["bash"]
