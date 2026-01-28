FROM ghcr.io/github/copilot-cli:latest

# Install sudo, gosu and other useful packages
USER root
RUN apt-get update && \
    apt-get install -y sudo gosu && \
    rm -rf /var/lib/apt/lists/*

# Create a script to setup the user dynamically
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["copilot", "--yolo"]
