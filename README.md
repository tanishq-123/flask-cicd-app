# flask-cicd-app

A simple Python Flask application with a CI/CD pipeline (Jenkins, triggered by a GitHub webhook)
that tests, builds, pushes to Amazon ECR, deploys to EC2, and sends email notifications on
success/failure.

Built for the "Graded Assignment on CI/CD Pipeline" (Hero Vired).

## Status

- [x] Step 1 — Flask app, pytest suite, Dockerfile, deploy.sh
- [x] Step 2 — AWS prerequisites (ECR repo, EC2 instance, IAM role) — both instances running,
      see [evidence #6](./screenshots/06-aws-ec2-instances-running.png)
- [x] Step 3 — Jenkins server setup on EC2 + GitHub webhook trigger — confirmed working, see
      [evidence #8-10](./screenshots/) (`Started by GitHub push`, webhook delivery `200`)
- [x] Step 4 — Jenkins credentials (AWS, SSH key, SMTP) — all three working, see
      [build log](./logs/jenkins-build4-full-console-log.txt) and
      [evidence #3-4](./screenshots/)
- [x] Step 5 — Jenkinsfile (checkout → test → build → push → deploy → verify → notify)
- [x] Step 6 — Email notification content (success/failure) — both cases confirmed, see
      [evidence #5, #11](./screenshots/) (success) and [evidence #12](./screenshots/) (failure)
- [x] Step 7 — Green run ✅ and broken run ❌, both with matching emails — see Test Evidence below
- [ ] Step 8 — Submission file with repo link

## Test Evidence

All screenshots live in [`screenshots/`](./screenshots); the full Jenkins console log lives
in [`logs/`](./logs).

- **Green run (manual trigger):** build #4, commit [`bbd40cb`](https://github.com/tanishq-123/flask-cicd-app/commit/bbd40cb41bef76cbcf07ccf22ebd6b6331cfa4bd), deployed to `13.219.227.60`.
- **Green run (GitHub webhook trigger):** build #5, commit `cf4f154`, `Started by GitHub push by tanishq-123` — confirms Section 4's auto-trigger-on-push requirement.
- **Failed run (intentional):** `test_health_check_success` broken on purpose — pipeline stopped at the `Test` stage, failure email correctly reported it.

| #   | File                                                                                                     | What it shows                                                                                                                                                                                                                                                                                                                                                                                         |
| --- | -------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | [`01-jenkins-ec2-unlock-screen.png`](./screenshots/01-jenkins-ec2-unlock-screen.png)                     | Jenkins running on the EC2 server (`100.27.15.135:8080`), unlock screen — confirms Jenkins is reachable on the provisioned instance, not just locally                                                                                                                                                                                                                                                 |
| 2   | [`02-jenkins-container-recreate-terminal.png`](./screenshots/02-jenkins-container-recreate-terminal.png) | Terminal on the Jenkins EC2 instance recreating the `jenkins` container from the custom image and confirming it comes up healthy                                                                                                                                                                                                                                                                      |
| 3   | [`03-git-pull-buildx-verify-smtp-config.png`](./screenshots/03-git-pull-buildx-verify-smtp-config.png)   | `git pull` picking up the latest `Jenkinsfile`/`jenkins/Dockerfile`, image rebuild, and `docker --version` / `docker buildx version` confirming both are present inside the container after the Docker-CLI-install fix                                                                                                                                                                                |
| 4   | [`04-smtp-authentication-config.png`](./screenshots/04-smtp-authentication-config.png)                   | Manage Jenkins → System SMTP config: `smtp.gmail.com`, port `465`, SSL enabled — the working config after the port-25-blocked-by-AWS issue was fixed                                                                                                                                                                                                                                                  |
| 5   | [`05-success-email.png`](./screenshots/05-success-email.png)                                             | Success email received for build #4 — subject prefixed ✅, includes commit SHA, image tag, EC2 target, and pipeline run link, satisfying Section 5's success-email content requirements                                                                                                                                                                                                               |
| 6   | [`06-aws-ec2-instances-running.png`](./screenshots/06-aws-ec2-instances-running.png)                     | AWS Console showing both EC2 instances running: `flask-cicd-ec2` (app target, t2.micro) and `jenkins-server` (t3.medium)                                                                                                                                                                                                                                                                              |
| 7   | [`07-external-health-check-curl.png`](./screenshots/07-external-health-check-curl.png)                   | `curl -v` from an external machine (not the instance itself) against `http://13.219.227.60:5000/health` returning `200 OK` — confirms the app is genuinely reachable from outside AWS, not just over loopback/SSH                                                                                                                                                                                     |
| 8   | [`08-build5-github-push-triggered.png`](./screenshots/08-build5-github-push-triggered.png)               | Build #5 status page: **"Started by GitHub push by tanishq-123"** — proof the pipeline auto-triggers on push, not just via manual "Build Now"                                                                                                                                                                                                                                                         |
| 9   | [`09-github-webhook-delivery-200.png`](./screenshots/09-github-webhook-delivery-200.png)                 | GitHub's Webhooks → Recent Deliveries tab: `push` event delivered to `http://100.27.15.135:8080/github-webhook/`, response `200`, completed in 0.07s, with the full payload shown                                                                                                                                                                                                                     |
| 10  | [`10-build5-console-github-push.png`](./screenshots/10-build5-console-github-push.png)                   | Console output for build #5 confirming the same — first line `Started by GitHub push by tanishq-123`                                                                                                                                                                                                                                                                                                  |
| 11  | [`11-build5-success-email.png`](./screenshots/11-build5-success-email.png)                               | Success email for the webhook-triggered build #5 (commit `cf4f154`), same required fields as evidence #5                                                                                                                                                                                                                                                                                              |
| 12  | [`12-failed-build-email-test-stage.png`](./screenshots/12-failed-build-email-test-stage.png)             | Failure email — subject prefixed ❌, **`Failed stage: Test`**, commit SHA, branch, and a console-log link — confirms `env.LAST_STAGE` correctly identifies the failed stage per Section 5's failure-email requirements                                                                                                                                                                                |
| 13  | [`13-failed-build-jenkins-status.png`](./screenshots/13-failed-build-jenkins-status.png)                 | Jenkins build status page for the intentionally broken run: red ❌, `Tests (1 failure)` naming `test_app.test_health_check_success` specifically                                                                                                                                                                                                                                                      |
| 14  | [`14-github-pr-check-status-failed.png`](./screenshots/14-github-pr-check-status-failed.png)             | GitHub PR #3 (`test-build-fail` → `main`) showing the Jenkins result synced back as a required status check: `continuous-integration/jenkins/pr-head` — "All checks have failed". This is what the `PR-1` branch reference in evidence #12's failure email refers to — Jenkins' Multibranch Pipeline auto-builds pull requests too, not just branch pushes, and reports the result directly on the PR |
| —   | [`jenkins-build4-full-console-log.txt`](./logs/jenkins-build4-full-console-log.txt)                      | Full console log for build #4: Checkout → Install dependencies → Test (5 passed) → Build (buildx, linux/amd64) → Push to ECR (login + push succeeded) → Deploy to EC2 (`deploy.sh` pull/stop/rm/run + internal health check) → Verify Deployment (independent curl) → Notify. Ends `Finished: SUCCESS`.                                                                                               |

**Note on how the failure test was run:** rather than breaking `main` directly and reverting,
the intentional test failure was pushed on a separate branch (Jenkins auto-discovered it via
branch indexing, consistent with a Multibranch Pipeline job structure — see
`flask-cicd-app/test-build-fail/#1` in evidence #13). This demonstrates the same `Test` stage
gate without ever leaving `main` in a broken state.

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
   ssh -i tanishq-US-keypair.pem ec2-user@100.27.15.135
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

   Visit `http://100.27.15.135:8080` and paste it in.

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

See [Test Evidence](#test-evidence) above for the indexed screenshots and full console log.

- ✅ Screenshot/recording of a full green run ending in a successful EC2 deployment, plus the
  success email received.
- ✅ Screenshot/recording of an intentionally broken run (failing test) showing the pipeline
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
