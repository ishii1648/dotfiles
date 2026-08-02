FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends \
    fish neovim jq python3 python3-yaml git ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats-core \
    && /tmp/bats-core/install.sh /usr/local \
    && rm -rf /tmp/bats-core
RUN useradd -m testuser
COPY --chown=testuser:testuser . /home/testuser/dotfiles
USER testuser
WORKDIR /home/testuser/dotfiles
ENV PATH=/home/testuser/.local/bin:$PATH
RUN bash scripts/setup.sh --non-interactive --profile linux
RUN bash scripts/setup.sh --dry-run --profile linux
RUN bats tests/
