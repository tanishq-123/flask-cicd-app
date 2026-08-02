FROM jenkins/jenkins:lts

USER root

# Tools required by this repo's Jenkinsfile / deploy.sh:
#   - docker.io          : docker build / push (needs the host's docker.sock mounted in)
#   - python3, pip,
#     python3-venv       : Install dependencies / Test stages (python3 -m venv, pytest)
#   - curl               : Verify Deployment stage's health check
#   - openssh-client      : scp/ssh to EC2 (also brought in by the SSH Agent plugin, but
#                           installing it here means it's always present regardless of
#                           plugin version)
#   - awscli              : aws ecr get-login-password (Push to ECR stage runs this
#                           directly on the Jenkins agent, not just inside deploy.sh)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        docker.io \
        python3 \
        python3-venv \
        python3-pip \
        curl \
        openssh-client \
        awscli && \
    rm -rf /var/lib/apt/lists/*

# docker buildx (see Build stage — target EC2 is x86_64, images must be built for
# linux/amd64 regardless of the Jenkins host's own architecture). The buildx CLI plugin
# isn't in Debian's default apt repos (it only ships via Docker's own apt repo), so
# install the binary directly into Docker's system-wide plugin directory instead.
RUN mkdir -p /usr/libexec/docker/cli-plugins && \
    BUILDX_VERSION=$(curl -s https://api.github.com/repos/docker/buildx/releases/latest | \
        grep '"tag_name"' | cut -d '"' -f4) && \
    curl -sSL "https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.linux-amd64" \
        -o /usr/libexec/docker/cli-plugins/docker-buildx && \
    chmod +x /usr/libexec/docker/cli-plugins/docker-buildx

# Let the jenkins user run docker (the socket is mounted from the host at runtime)
RUN groupadd -f docker && usermod -aG docker jenkins

USER jenkins