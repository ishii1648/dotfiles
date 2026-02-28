FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends \
    fish tmux neovim jq python3 python3-yaml git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m testuser
COPY --chown=testuser:testuser . /home/testuser/dotfiles
USER testuser
WORKDIR /home/testuser/dotfiles
RUN bash scripts/setup.sh --profile linux
RUN bash scripts/setup.sh --dry-run --profile linux
