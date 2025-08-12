# syntax=docker/dockerfile:1
###############################################################################
# Builder: Install pinned Ollama release
###############################################################################
FROM ubuntu:22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

# minimal build deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates python3 python3-pip git wget && \
    rm -rf /var/lib/apt/lists/*

# pin Ollama version (supports --host)
ARG OLLAMA_VERSION="v0.1.32"
RUN curl -L "https://github.com/ollama/ollama/releases/download/${OLLAMA_VERSION}/ollama-linux-amd64" -o /usr/local/bin/ollama \
 && chmod +x /usr/local/bin/ollama


# copy binary out
RUN mkdir -p /ollama_bin && cp /usr/local/bin/ollama /ollama_bin

###############################################################################
# Final image: runtime with non-root user
###############################################################################
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# runtime deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates python3 python3-pip wget jq && \
    rm -rf /var/lib/apt/lists/*

# copy ollama binary from builder
COPY --from=builder /ollama_bin/ollama /usr/local/bin/ollama
RUN chmod +x /usr/local/bin/ollama

# create non-root user and model directory
RUN useradd -m -s /bin/bash ollama \
 && mkdir -p /home/ollama/.ollama/models \
 && chown -R ollama:ollama /home/ollama

# install huggingface client globally
RUN pip3 install --no-cache-dir huggingface_hub

# copy helper scripts
COPY start.sh /usr/local/bin/start.sh
COPY download_model.py /usr/local/bin/download_model.py
RUN chmod +x /usr/local/bin/start.sh /usr/local/bin/download_model.py \
 && chown ollama:ollama /usr/local/bin/start.sh /usr/local/bin/download_model.py

USER ollama
WORKDIR /home/ollama
ENV HOME=/home/ollama

# expose Ollama default port
EXPOSE 11434

# healthcheck: /api/version
HEALTHCHECK --interval=20s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -fsS http://localhost:11434/api/version || exit 1

# entrypoint
ENTRYPOINT ["/usr/local/bin/start.sh"]