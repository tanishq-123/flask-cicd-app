# Custom Jenkins image for this project

The stock `jenkins/jenkins:lts` image ships with nothing but Jenkins itself — no Docker CLI,
no Python, no curl. Every tool this repo's `Jenkinsfile` and `deploy.sh` shell out to has to be
added on top. This `Dockerfile` bakes all of that in once, so you don't need to `docker exec`
package installs by hand after every container restart/recreation.

## Build

```bash
cd jenkins
docker build -t flask-cicd-jenkins .
```

## Run

```bash
docker volume create jenkins_home

docker run -d --name jenkins \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -u root \
  flask-cicd-jenkins
```

Notes:

- `-u root` is still used at runtime (even though the image adds the `jenkins` user to a
  `docker` group) because the mounted `/var/run/docker.sock` is owned by whatever group ID
  Docker uses on your _host_, which usually won't match the container's `docker` group ID.
  Running as root sidesteps that mismatch. This is fine for local dev; a production Jenkins
  setup would instead match GIDs or use a rootless Docker setup.
- `jenkins_home` is a named volume, so Jenkins config/jobs/credentials/plugins persist across
  container restarts and recreations — you only need to rebuild this image if the pipeline
  starts needing a new tool.

## Running this on an EC2 "Jenkins server" instead of locally

Same image, same `docker run` command as above — just run it on an EC2 instance instead of
your laptop. A few things that bit us in local testing, addressed by doing this on EC2:

- **Instance architecture: use x86_64 (e.g. `t3.medium`), not Graviton/arm64.** Locally, if
  Jenkins runs on an Apple Silicon Mac, `docker build` silently produces an **arm64** image —
  which then fails to start on the (x86_64) target EC2 instance with `exec format error`. The
  Jenkinsfile's Build stage now explicitly builds with `docker buildx build --platform
linux/amd64`, so this is handled either way — but matching architectures means no QEMU
  cross-platform emulation is needed, so builds stay fast.
- **Security group:** open inbound `8080` (Jenkins UI + GitHub webhook target) and `22` (your
  own SSH access to manage the box). Don't open `8080` to `0.0.0.0/0` long-term — scope it to
  GitHub's webhook IP ranges or put it behind a reverse proxy once this moves past assignment
  scope.
- **Docker on the host:** the EC2 instance itself needs Docker installed and running before
  you can `docker run` this image (it mounts `/var/run/docker.sock` from the host):
  ```bash
  sudo yum install -y docker
  sudo systemctl enable --now docker
  sudo usermod -aG docker ec2-user
  ```
- **IAM instead of static keys:** rather than storing an `aws-creds` credential in Jenkins,
  consider attaching an IAM instance role to this Jenkins EC2 server (mirroring the target
  EC2's role) with the ECR + `DescribeAvailabilityZones` permissions documented in the main
  [`README.md`](../README.md#7-secrets-management) — the AWS CLI in the container picks up
  instance-role credentials automatically, no credential to rotate or leak.

## Unlock

```bash
docker exec -it jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Paste that at `http://localhost:8080` (or `http://<ec2-public-ip>:8080` when run on EC2) to
finish setup.
