# Generic development container for the Kimi Code CLI.
# Extend this image with the language runtimes and tools your project needs.

FROM alpine:3.20

ENV PATH=/usr/local/bin:/usr/bin:/bin

# Base tools used by most projects. Add your language toolchain here.
RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    git \
    make \
    nodejs \
    npm \
    shadow \
    su-exec \
    sudo

# Install the Kimi Code CLI globally.
# Override at build time with: --build-arg KIMI_VERSION=x.y.z
ARG KIMI_VERSION=latest
RUN npm install -g @moonshot-ai/kimi-code@${KIMI_VERSION}

# Create the kimi user. UID/GID are matched to the host at container startup
# via entrypoint.sh, so files created in /workspace are owned by the host user.
ARG USER_UID=1000
ARG USER_GID=1000
RUN addgroup -g ${USER_GID} kimi && \
    adduser -u ${USER_UID} -G kimi -s /bin/bash -D kimi && \
    echo "kimi ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/kimi && \
    chmod 0440 /etc/sudoers.d/kimi

WORKDIR /workspace
RUN chown kimi:kimi /workspace

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["kimi"]
