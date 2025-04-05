FROM rust:latest AS build

RUN cargo install lcov2xml
RUN whereis lcov2xml


################################################################################################################################################################
FROM alpine:latest AS build2

WORKDIR /tmp
RUN apk add curl xz
RUN mkdir -p /tmp/node && \
  curl -L "https://nodejs.org/dist/v22.14.0/node-v22.14.0-linux-x64.tar.xz" -o node.tar.xz && \
  tar -C /tmp/node --strip-components=1 -xf node.tar.xz

RUN mkdir -p /tmp/go && \
  curl -L "https://go.dev/dl/go1.24.2.linux-amd64.tar.gz" -o go.tar.gz && \
  tar -C /tmp/go --strip-components=1 -xf go.tar.gz

RUN curl -sfL https://github.com/devcontainers-contrib/nanolayer/releases/download/v0.5.6/nanolayer-x86_64-unknown-linux-gnu.tgz | tar fxvz - -C / 

################################################################################################################################################################
FROM mcr.microsoft.com/devcontainers/python:1-3.12-bullseye AS build3

# Upgrade to latest libraries
RUN apt-get update && apt-get upgrade -y

RUN apt-get update && apt-get install -y \
  acl \
  libacl1-dev \
  attr \
  libattr1-dev \
  libcap2-bin \
  libcap-dev \
  liburing-dev \
  libonig-dev \
  make \
  g++

###
WORKDIR /tmp

# CLI tools bfs
RUN mkdir bfs
WORKDIR /tmp/bfs
RUN curl -L "https://github.com/tavianator/bfs/releases/download/4.0.4/bfs-4.0.4.tar.gz" -o bfs.tar.gz
RUN tar xf bfs.tar.gz
RUN ./configure --enable-release
RUN make

###
WORKDIR /tmp

################################################################################################################################################################
FROM ubuntu:24.04

COPY --from=build --chown=root:root /usr/local/cargo/bin/lcov2xml /usr/local/bin/lcov2xml
COPY --from=build --chown=root:root /usr/local/cargo/bin/cobertura_split /usr/local/bin/cobertura_split
COPY --from=build2 --chown=root:root /tmp/node /opt/node
COPY --from=build2 --chown=root:root /tmp/go /go
COPY --from=build2 --chown=root:root /nanolayer /nanolayer
COPY --from=build3 --chown=root:root /tmp/bfs/bin/bfs /usr/local/bin/bfs

RUN ln -s /opt/node/bin/node /usr/local/bin/node && \
    ln -s /opt/node/bin/npm  /usr/local/bin/npm  && \
    ln -s /opt/node/bin/npx  /usr/local/bin/npx 

RUN npm install -g yarn

RUN /nanolayer install apt-get zip,make,ca-certificates,git,zsh,python3.12,sudo,wget,curl
RUN /nanolayer install gh-release 'junegunn/fzf' 'fzf'
RUN /nanolayer install gh-release --asset-regex '.tar.gz$' 'eza-community/eza' 'eza'
RUN /nanolayer install gh-release 'ajeetdsouza/zoxide' 'zoxide'
RUN /nanolayer install gh-release 'astral-sh/uv' 'uv'
RUN /nanolayer install gh-release 'sharkdp/bat' 'bat'
RUN /nanolayer install gh-release 'Wilfred/difftastic' 'difft'

WORKDIR /tmp

# Pre-commit
RUN uv pip install --break-system-packages --system pre-commit

COPY --chown=vscode:vscode zshrc /home/vscode/.zshrc

RUN userdel ubuntu && useradd -m -d /home/vscode -U -u 1000 -s /bin/zsh vscode && chown vscode:vscode -R /home/vscode
RUN echo "vscode ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/vscode

WORKDIR /home/vscode
USER vscode
ENV LC_ALL=C
ENV GIT_EDITOR="code --wait"
ENV EDITOR="code --wait"

RUN git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git .oh-my-zsh
RUN /go/bin/go install github.com/spf13/cobra-cli@latest
