FROM jenkins/jenkins:lts

USER root

# Base tools required by this repo's Jenkinsfile / deploy.sh:
#   - python3, pip,
#     python3-venv       : Install dependencies / Test stages (python3 -m venv, pytest)
#   - curl               : Verify Deployment stage's health check
#   - openssh-client      : scp/ssh to EC2 (also brought in by the SSH Agent plugin, but
#                           installing it here means it's always present regardless of
#                           plugin version)
#   - awscli              : aws ecr get-login-password (Push to ECR stage runs this
#                           directly on the Jenkins agent, not just inside deploy.sh)
#   - ca-certificates, gnupg : needed to add Docker's apt repo below
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        gnupg \
        python3 \
        python3-venv \
        python3-pip \
        curl \
        openssh-client \
        awscli && \
    rm -rf /var/lib/apt/lists/*

# Docker CLI + buildx, from Docker's own official apt repo.
# Debian's own docker.io package has proven unreliable across base image variants
# (installed cleanly but produced no /usr/bin/docker binary in testing) — Docker's
# official repo is the standard, dependable source and also ships docker-buildx-plugin,
# so no separate binary download is needed for that either. We only need the CLI here,
# not the daemon (dockerd) — the container talks to the host's Docker daemon via the
# mounted /var/run/docker.sock.
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        docker-ce-cli \
        docker-buildx-plugin && \
    rm -rf /var/lib/apt/lists/*

# Let the jenkins user run docker (the socket is mounted from the host at runtime)
RUN groupadd -f docker && usermod -aG docker jenkins

USER jenkins