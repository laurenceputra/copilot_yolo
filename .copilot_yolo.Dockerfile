ARG BASE_IMAGE=node:20-slim
FROM ${BASE_IMAGE}
ARG COPILOT_VERSION=latest
ARG COPILOT_YOLO_VERSION=unknown

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gosu \
    passwd \
    sudo \
  && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    gh \
  && rm -rf /var/lib/apt/lists/*

# Install GitHub Copilot CLI (provides the `copilot` binary).
RUN npm install -g @github/copilot@${COPILOT_VERSION}

# Make a writable home for arbitrary UID/GID at runtime.
RUN mkdir -p /home/copilot/.config/github-copilot \
  && chmod -R 0777 /home/copilot

# Runtime entrypoint to create a matching user, enable sudo, and cleanup perms.
COPY .copilot_yolo_entrypoint.sh /usr/local/bin/copilot-entrypoint
RUN chmod +x /usr/local/bin/copilot-entrypoint

# Record the installed GitHub Copilot CLI version for update checks.
RUN node -e "process.stdout.write(require('/usr/local/lib/node_modules/@github/copilot/package.json').version)" \
  > /opt/copilot-version
RUN printf '%s' "${COPILOT_YOLO_VERSION}" > /opt/copilot-yolo-version

ENV HOME=/home/copilot
WORKDIR /workspace
ENTRYPOINT ["copilot-entrypoint"]
