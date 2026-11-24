# Development container for the Kimi Code CLI.
#
# The base image is configurable so a project can bring its own toolchain
# (e.g. php:8.3-cli for composer/phpstan/phpunit) and have Kimi Code
# installed on top of it.  Supported base images are Alpine (apk) and
# Debian/Ubuntu (apt-get) derivatives.
#
# Override at build time with: --build-arg BASE_IMAGE=php:8.3-cli

ARG BASE_IMAGE=alpine:3.22
FROM ${BASE_IMAGE}

# Some base images set a non-root USER; everything below needs root.
USER root

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Node.js version installed on apt-based images (Kimi Code requires
# node >= 22.19 and Debian/Ubuntu packages are older).  Alpine provides a
# recent enough Node.js via apk.
ARG NODE_VERSION=22.19.0

# Base tools used by most projects, plus Node.js for the Kimi CLI.
RUN set -eux; \
    if command -v apk >/dev/null 2>&1; then \
        apk add --no-cache \
            bash \
            ca-certificates \
            curl \
            git \
            make \
            nodejs \
            npm \
            shadow \
            shellcheck \
            su-exec \
            sudo \
            python3 \
        ; \
    elif command -v apt-get >/dev/null 2>&1; then \
        apt-get update; \
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            bash \
            ca-certificates \
            curl \
            git \
            gosu \
            make \
            passwd \
            sudo \
        ; \
        rm -rf /var/lib/apt/lists/*; \
        arch="$(uname -m)"; \
        case "$arch" in \
            x86_64) node_arch=x64 ;; \
            aarch64) node_arch=arm64 ;; \
            *) echo "Unsupported architecture for Node.js: $arch" >&2; exit 1 ;; \
        esac; \
        curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.gz" \
            | tar -xz -C /usr/local --strip-components=1; \
    else \
        echo "Unsupported base image: neither apk nor apt-get found" >&2; \
        exit 1; \
    fi

# Install the Kimi Code CLI globally.
# Override at build time with: --build-arg KIMI_VERSION=x.y.z
ARG KIMI_VERSION=latest
RUN npm install -g @moonshot-ai/kimi-code@${KIMI_VERSION}

# Create the kimi user. UID/GID are matched to the host at container startup
# via entrypoint.sh, so files created in /workspace are owned by the host user.
ARG USER_UID=1000
ARG USER_GID=1000
RUN set -eux; \
    # Free the UID/GID if the base image already assigned them to another
    # account (e.g. a "node" user), so kimi can take their place.
    existing_user="$(getent passwd "${USER_UID}" | cut -d: -f1 || true)"; \
    if [ -n "$existing_user" ] && [ "$existing_user" != "kimi" ]; then \
        if command -v apk >/dev/null 2>&1; then \
            deluser "$existing_user"; \
        else \
            userdel "$existing_user"; \
        fi; \
    fi; \
    existing_group="$(getent group "${USER_GID}" | cut -d: -f1 || true)"; \
    if [ -n "$existing_group" ] && [ "$existing_group" != "kimi" ]; then \
        if command -v apk >/dev/null 2>&1; then \
            delgroup "$existing_group"; \
        else \
            groupdel "$existing_group"; \
        fi; \
    fi; \
    if command -v apk >/dev/null 2>&1; then \
        addgroup -g "${USER_GID}" kimi; \
        adduser -u "${USER_UID}" -G kimi -s /bin/bash -D kimi; \
    else \
        groupadd -g "${USER_GID}" kimi; \
        useradd -u "${USER_UID}" -g kimi -s /bin/bash -m kimi; \
    fi; \
    echo "kimi ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/kimi; \
    chmod 0440 /etc/sudoers.d/kimi

WORKDIR /workspace
RUN chown kimi:kimi /workspace

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["kimi"]
