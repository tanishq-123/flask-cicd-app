# flask-cicd-app

A simple Python Flask application with a CI/CD pipeline (Jenkins, triggered by a GitHub webhook)
that tests, builds, pushes to Amazon ECR, deploys to EC2, and sends email notifications on
success/failure.

Built for the "Graded Assignment on CI/CD Pipeline" (Hero Vired).

## Status

- [x] Step 1 — Flask app, pytest suite, Dockerfile, deploy.sh
- [ ] Step 2 — AWS prerequisites (ECR repo, EC2 instance, IAM role)
- [ ] Step 3 — Jenkins server setup + GitHub webhook trigger
- [ ] Step 4 — Jenkins credentials (AWS, SSH key, SMTP)
- [x] Step 5 — Jenkinsfile (checkout → test → build → push → deploy → verify → notify)
- [x] Step 6 — Email notification content (success/failure) — built into Jenkinsfile's post blocks
- [ ] Step 7 — Screenshots / recording of a green run and a broken run
- [ ] Step 8 — Submission file with repo link

## Application

- `app.py` — Flask app with:
  - `GET /` — welcome message
  - `GET /health` — health/status endpoint used by the pipeline's deploy-verification gate
  - `GET /items/<id>` — sample route exercising both a success (200) and failure (404) case
- `requirements.txt` — Flask, gunicorn, pytest
- `test_app.py` — pytest suite covering success and failure cases for the routes above
- `Dockerfile` — builds a runnable image, served via gunicorn on port 5000
- `deploy.sh` — reference script for manually reproducing the deploy step on EC2 if Jenkins
  were unavailable (see "Manual deployment" below)

Run locally:

```bash
pip install -r requirements.txt
pytest
python app.py        # or: gunicorn --bind 0.0.0.0:5000 app:app
curl http://localhost:5000/health
```

Build and run in Docker:

```bash
docker build -t flask-cicd-app .
docker run -d --name flask-app -p 5000:5000 flask-cicd-app
curl http://localhost:5000/health
```

---

## Full project plan

### 1. Application (this repo) — ✅ done

Flask app + `/health` endpoint, `requirements.txt`, pytest suite (success + failure cases),
Dockerfile that builds a runnable image.

### 2. AWS prerequisites (manual, one-time setup)

- **ECR repository** to hold built images:
  ```bash
  aws ecr create-repository --repository-name flask-cicd-app
  ```
- **EC2 instance** (Amazon Linux 2023, **x86_64** — must match the image architecture built
  in the pipeline; see Section 5) with:
  - Docker installed, **enabled and started** (a common gotcha: `yum install docker` alone
    does not start the daemon or make it survive a reboot — `systemctl enable --now docker`
    is required too)
  - **`ec2-user` added to the `docker` group**, so `deploy.sh` can run `docker` commands over
    SSH without `sudo` (needed since it's a plain SSH exec, not an interactive login shell)
  - **AWS CLI v2 installed** — `deploy.sh` runs on the instance itself and calls
    `aws ecr get-login-password`, so the CLI must be present there (Amazon Linux 2023 ships
    it by default; on Ubuntu install via `apt install -y awscli` or the official installer)

  Recommended launch `user-data`, which handles all three of the above in one shot:

  ```bash
  #!/bin/bash
  yum install -y docker
  systemctl enable --now docker
  usermod -aG docker ec2-user
  ```

  If the instance is already running without this, apply it manually via SSH:

  ```bash
  sudo systemctl enable --now docker
  sudo usermod -aG docker ec2-user
  # log out and reconnect (or open a fresh SSH session) for the group change to take effect
  ```

  - An **IAM instance role** attached with `AmazonEC2ContainerRegistryReadOnly` (or a scoped
    equivalent) so the instance can pull from ECR without static credentials
  - A **security group** allowing inbound traffic on the app port (5000) and on port 22 for
    SSH (since this project uses the SSH-based deploy method)

- **Connectivity for deploy**: SSH-based — the pipeline SSHes into the instance using a stored
  private key and runs the `docker pull` / `stop` / `rm` / `run` commands directly (see
  `deploy.sh` for the exact command sequence).

### 3. Jenkins server setup + GitHub webhook trigger

For local dev, use the custom image in [`jenkins/`](./jenkins) — it bakes in Docker CLI,
Python/pip/venv, curl, and openssh-client on top of stock Jenkins, so the pipeline's tool
dependencies don't need to be re-installed by hand after every container restart. See
[`jenkins/README.md`](./jenkins/README.md) for build/run instructions.

**Running Jenkins on an EC2 server instead of locally.** The `jenkins/Dockerfile` isn't an
AMI or anything AWS-native — it's a normal Dockerfile that has to be built _on_ the Jenkins
EC2 instance, the same way it's built locally. That instance needs Docker installed first.

1. **Launch the instance with Docker pre-installed via user-data** (see
   [`jenkins/README.md`](./jenkins/README.md) for the architecture/security-group rationale —
   use x86_64, e.g. `t3.medium`):

   ```bash
   aws ec2 run-instances \
     --image-id <amazon-linux-2023-ami-id> \
     --instance-type t3.medium \
     --key-name <your-keypair-name> \
     --security-group-ids <jenkins-sg-id> \
     --user-data '#!/bin/bash
   yum install -y docker git
   systemctl enable --now docker
   usermod -aG docker ec2-user' \
     --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=jenkins-server}]'
   ```

   Security group needs inbound `8080` (Jenkins UI + GitHub webhook target) and `22` (your own
   SSH access).

2. **SSH in and pull this repo**, so the Dockerfile is actually present on the box:

   ```bash
   ssh -i your-key.pem ec2-user@<jenkins-server-public-ip>
   git clone https://github.com/<your-username>/flask-cicd-app.git
   cd flask-cicd-app/jenkins
   ```

3. **Build and run** — identical commands to local dev:

   ```bash
   docker build -t flask-cicd-jenkins .
   docker volume create jenkins_home
   docker run -d --name jenkins \
     -p 8080:8080 -p 50000:50000 \
     -v jenkins_home:/var/jenkins_home \
     -v /var/run/docker.sock:/var/run/docker.sock \
     -u root \
     flask-cicd-jenkins
   ```

4. **Unlock** via the instance's public IP:

   ```bash
   docker exec -it jenkins cat /var/jenkins_home/secrets/initialAdminPassword
   ```

   Visit `http://<jenkins-server-public-ip>:8080` and paste it in.

   Note: unless the local `jenkins_home` Docker volume is explicitly migrated over (e.g. via
   `docker save`/`load`, an EBS snapshot, or an S3 copy), this is a **fresh Jenkins instance**
   — the setup wizard, plugin installs, the Pipeline job, and all three credentials
   (`ec2-ssh-key`, `aws-creds`, SMTP) need to be re-created from scratch, since none of that
   lives in this repo by design (it's secrets/instance state, not code).

- Install Jenkins with plugins: GitHub, Pipeline, Docker Pipeline, Email Extension (Email-ext),
  AWS/ECR credentials support, SSH Agent.
- **Webhook wiring:**
  1. Jenkins job → Build Triggers → enable "GitHub hook trigger for GITScm polling."
  2. GitHub repo → Settings → Webhooks → Add webhook:
     - Payload URL: `http://<jenkins-host>:8080/github-webhook/`
     - Content type: `application/json`
     - Event: "Just the push event"
  3. Jenkins must be reachable from GitHub (public IP/DNS, or a tunnel such as ngrok for local
     dev; security group open on 8080 to GitHub's traffic).
  4. Set the GitHub project URL in the Jenkins job's General config so it's tied to this repo.

### 4. Jenkins credentials (never hardcoded in the pipeline file)

Stored under Manage Jenkins → Credentials:

- `aws-creds` — AWS access key/secret, or better: an IAM role attached directly to the Jenkins
  EC2 instance with ECR push permissions, avoiding static keys entirely
- `ec2-ssh-key` — SSH private key ("SSH Username with private key" credential type)
- SMTP settings for Email-ext configured under Manage Jenkins → Configure System →
  Extended E-mail Notification, with the SMTP username/password stored as a credential

### 5. Jenkinsfile — pipeline stages (in order)

See [`Jenkinsfile`](./Jenkinsfile) at the repo root — this is what the Jenkins job actually
executes on each triggered run. Before first use, edit the placeholder values in its
`environment {}` block: `AWS_REGION`, `ECR_REPO` (your ECR repo URI), and `EC2_HOST` (your
instance's SSH target). The pipeline also relies on `env.LAST_STAGE`, set explicitly at the
start of every stage, so the failure email can reliably report which stage failed — Jenkins'
built-in `env.STAGE_NAME` is not guaranteed to be populated correctly inside the top-level
`post` block.

1. **Checkout** — pull latest source from `main`
2. **Install dependencies** — `pip install -r requirements.txt`
3. **Test** — run `pytest`; any failure halts the pipeline before build/deploy
4. **Build** — build the Docker image, tagged with the Git commit SHA (not `latest`), so every
   deployed image is traceable to a commit
5. **Push to ECR** — authenticate to ECR and push the tagged image
6. **Deploy to EC2** — `scp`s `deploy.sh` to the instance and runs it over SSH; `deploy.sh` is
   the single source of truth for the deploy logic (used both by the pipeline and for manual
   reproduction — see below), so there's no duplicated deploy logic to keep in sync. It pulls
   the new image from ECR, stops and removes the currently running container (if any) — this
   is what makes deployment actually _replace_ the running container rather than stacking a
   new one alongside it — runs the new container, and does its own internal health check.
7. **Verify Deployment** — an independent curl against `/health` from the pipeline side, on
   top of `deploy.sh`'s own check; a non-2xx response (including a container that starts but
   crashes immediately) fails this stage and the whole run is reported as a failed deployment
8. **Notify** — send the outcome email (see below)

### 6. Email notifications

Sent via Jenkins Email-ext in `post { success {} failure {} }` blocks.

**On success**, subject prefixed with a clear success indicator, body includes:

- Git commit SHA and branch deployed
- Docker image tag pushed to ECR
- EC2 instance/target updated
- Link back to the pipeline run

**On failure**, subject prefixed with a clear failure indicator, body includes:

- Which stage failed (`env.STAGE_NAME`) — test / build / push / deploy / verify
- Git commit SHA and branch
- Link to the pipeline run/logs

### 7. Secrets management

All sensitive values (AWS credentials or role ARN, SSH private key, EC2 host details) live in
Jenkins Credentials — never committed to this repository.

**IAM policy for the `aws-creds` credential's underlying IAM user.** The AWS CLI's ECR login
flow needs more than just ECR push permissions — it also does an implicit availability-zone
check, so `ec2:DescribeAvailabilityZones` must be granted too or `docker login` fails with an
unauthorized error before it ever reaches Docker:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ec2:DescribeAvailabilityZones"
      ],
      "Resource": "*"
    }
  ]
}
```

A cleaner long-term alternative to a static-key IAM user: attach an **IAM instance role** to
the Jenkins EC2 server itself (the same pattern already used for the target EC2 instance in
Section 2), with this same policy, and drop the `aws-creds` credential/`withCredentials` block
from the Jenkinsfile entirely — the AWS CLI picks up instance-role credentials automatically.

### 8. Verification deliverables

- Screenshot/recording of a full green run ending in a successful EC2 deployment, plus the
  success email received.
- Screenshot/recording of an intentionally broken run (failing test) showing the pipeline
  stopping at the Test stage, plus the failure email showing the correct failed stage.

---

## Manual deployment (if the pipeline were unavailable)

SSH into the EC2 instance and run:

```bash
./deploy.sh <ECR_REPO_URI> <IMAGE_TAG> <AWS_REGION>
```

This performs the same `ecr login → docker pull → stop/rm old container → docker run new
container → curl /health` sequence the Jenkins "Deploy to EC2" and "Verify Deployment" stages
run automatically.

## Why SSH over SSM

This project uses SSH-based deployment: Jenkins holds a stored private key credential and
connects directly to the EC2 instance's public IP to run Docker commands. It was chosen for
simplicity in a single-instance setup. AWS Systems Manager (SSM) Session Manager would avoid
opening port 22 entirely (connections proxied through AWS instead), which is a stronger
security posture worth adopting if this were extended beyond a single-instance assignment.
