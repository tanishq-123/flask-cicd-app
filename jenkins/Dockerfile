FROM jenkins/jenkins:lts

USER root

# Tools required by this repo's Jenkinsfile / deploy.sh:
#   - docker.io          : docker build / push (needs the host's docker.sock mounted in)
#   - docker-buildx-plugin: cross-platform image builds (see Build stage — target EC2 is
#                           x86_64, so images must be built for linux/amd64 regardless of
#                           what architecture the Jenkins host itself runs on)
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
        docker-buildx-plugin \
        python3 \
        python3-venv \
        python3-pip \
        curl \
        openssh-client \
        awscli && \
    rm -rf /var/lib/apt/lists/*

# Let the jenkins user run docker (the socket is mounted from the host at runtime)
RUN groupadd -f docker && usermod -aG docker jenkins

USER jenkins