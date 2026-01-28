FROM node:18-slim

# Install required packages
USER root
RUN apt-get update && \
    apt-get install -y sudo gosu curl git && \
    rm -rf /var/lib/apt/lists/*

# Install GitHub Copilot CLI using npm (with SSL check disabled if needed)
RUN npm config set strict-ssl false && \
    npm install -g @github/copilot && \
    npm config set strict-ssl true

# Create a script to setup the user dynamically
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["copilot", "yolo"]
