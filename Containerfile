FROM ubuntu:latest

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Add amd64 architecture
RUN dpkg --add-architecture amd64

# Set up repositories for both arm64 and amd64
RUN echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports noble main restricted universe multiverse\n\
deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports noble-updates main restricted universe multiverse\n\
deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports noble-backports main restricted universe multiverse\n\
deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports noble-security main restricted universe multiverse\n\
deb [arch=amd64] http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse\n\
deb [arch=amd64] http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse\n\
deb [arch=amd64] http://archive.ubuntu.com/ubuntu noble-backports main restricted universe multiverse\n\
deb [arch=amd64] http://security.ubuntu.com/ubuntu noble-security main restricted universe multiverse" > /etc/apt/sources.list

RUN rm /etc/apt/sources.list.d/ubuntu.sources

# Update and install essential build tools and kernel headers
RUN apt-get update && apt-get install -y \
    build-essential \
    clang-19 \
    libelf-dev \
    pkg-config \
    git \
    vim \
    curl \
    kmod \
    r-base \
    openssh-server \
    mosh \
    tmux \
    jq \
    sudo \
    && rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/clang-19 /usr/bin/clang

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Set up user and group (fixed values for yonch user)
ARG UNAME=yonch
ARG UID=501
ARG GNAME=staff
ARG GID=20

RUN set -x; \
    # These commands are allowed to fail (it happens for root, for example).
    # The result will be checked in the next RUN.
    userdel -r `getent passwd ${UID} | cut -d : -f 1` > /dev/null 2>&1; \
    groupdel -f `getent group ${GID} | cut -d : -f 1` > /dev/null 2>&1; \
    groupadd -g ${GID} ${GNAME}; \
    useradd -u $UID -g $GID -G sudo -ms /bin/bash ${UNAME}; \
    mkdir -p /home/${UNAME}; \
    chown -R ${UNAME}:${GNAME} /home/${UNAME}; \
    echo "${UNAME} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

RUN set -ex; \
    mkdir -p /var/run/sshd; \
    mkdir -p /home/${UNAME}/.ssh; \
    chown ${UNAME}:${GNAME} /home/${UNAME}/.ssh; \
    chmod 700 /home/${UNAME}/.ssh

USER ${UNAME}:${GNAME}
WORKDIR /home/yonch

RUN set -ex; \
    ln -sf /workspace/.ccache /home/${UNAME}/.ccache; \
    ln -sf /workspace/.aws /home/${UNAME}/.aws; \
    ln -sf /workspace/.claude /home/${UNAME}/.claude; \
    mkdir -p /home/${UNAME}/.config; \
    ln -sf /workspace/.config/gh /home/${UNAME}/.config/gh

# Verification
RUN set -ex; \
    id | grep "uid=${UID}(${UNAME}) gid=${GID}(${GNAME})"; \
    sudo ls; \
    pwd | grep "^/home/yonch"

EXPOSE 22

CMD ["/bin/bash", "-c", "sudo /usr/sbin/sshd && exec bash"]