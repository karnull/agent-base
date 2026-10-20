# base image for every project agent: alpine + vim, git, gh, claude-code

#---------------------------------------------------------------------------------------------------

ARG ALPINE_VERSION=3.24
FROM alpine:${ALPINE_VERSION}

ARG USERNAME=dev
ARG UID=1000
ARG GID=1000

# each project is bind mounted at the SAME absolute path it has on the host, and nothing
# else is mounted, so a container sees its own project and an otherwise empty parent.
ARG WORKSPACE_ROOT=/home/kaerosol/Blackwall

ARG TZ=Australia/Melbourne

RUN apk upgrade --no-cache \
    && apk add --no-cache \
        bash \
        ca-certificates \
        curl \
        git \
        github-cli \
        less \
        libgcc \
        libstdc++ \
        ripgrep \
        tree-sitter-cli \
        tzdata \
        vim

#---------------------------------------------------------------------------------------------------

# checksum of the apk signing key, published in the apk tab of
# https://code.claude.com/docs/en/setup under "Install with Linux package managers".
ARG CLAUDE_CODE_KEY_SHA256=395759c1f7449ef4cdef305a42e820f3c766d6090d142634ebdb049f113168b6
ARG CLAUDE_CODE_CHANNEL=stable

# anthropic's signed apk repository: pin the key, then let apk check the packages
RUN wget -q -O /etc/apk/keys/claude-code.rsa.pub \
        https://downloads.claude.ai/keys/claude-code.rsa.pub \
    && if ! echo "${CLAUDE_CODE_KEY_SHA256}  /etc/apk/keys/claude-code.rsa.pub" \
            | sha256sum -c - ; then \
           echo "the signing key does not match CLAUDE_CODE_KEY_SHA256: re-check the" >&2; \
           echo "hash in the apk tab of https://code.claude.com/docs/en/setup before" >&2; \
           echo "trusting this key, it may have been rotated." >&2; \
           exit 1; \
       fi \
    && echo "https://downloads.claude.ai/claude-code/apk/${CLAUDE_CODE_CHANNEL}" \
        >> /etc/apk/repositories \
    && apk add --no-cache claude-code

# macos hands out gids that alpine already assigns (20 is staff on the host, dialout here),
# so join the group that owns the gid instead of failing to create a second one
RUN group="$(awk -F: -v gid="${GID}" '$3 == gid { print $1 }' /etc/group)" \
    && if [ -z "$group" ]; then \
           addgroup -g "${GID}" "${USERNAME}"; \
           group="${USERNAME}"; \
       fi \
    && adduser -D -u "${UID}" -G "$group" -s /bin/bash "${USERNAME}"

#---------------------------------------------------------------------------------------------------

# push and pull over https using the gh login mounted from the host: gh hands its token
# to git on demand, so no ssh key is mounted and `gh pr create` uses the same credential.
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
