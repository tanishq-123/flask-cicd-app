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
- [ ] Step 5 — Jenkinsfile (checkout → test → build → push → deploy → verify → notify)
- [ ] Step 6 — Email notification content (success/failure)
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
- **EC2 instance** (Amazon Linux 2023 or Ubuntu) with:
  - Docker installed and running (`yum install -y docker && systemctl enable --now docker`)
  - An **IAM instance role** attached with `AmazonEC2ContainerRegistryReadOnly` (or a scoped
    equivalent) so the instance can pull from ECR without static credentials
  - A **security group** allowing inbound traffic on the app port (5000) and on port 22 for
    SSH (since this project uses the SSH-based deploy method)
- **Connectivity for deploy**: SSH-based — the pipeline SSHes into the instance using a stored
  private key and runs the `docker pull` / `stop` / `rm` / `run` commands directly (see
  `deploy.sh` for the exact command sequence).

### 3. Jenkins server setup + GitHub webhook trigger
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
1. **Checkout** — pull latest source from `main`
2. **Install dependencies** — `pip install -r requirements.txt`
3. **Test** — run `pytest`; any failure halts the pipeline before build/deploy
4. **Build** — build the Docker image, tagged with the Git commit SHA (not `latest`), so every
   deployed image is traceable to a commit
5. **Push to ECR** — authenticate to ECR and push the tagged image
6. **Deploy to EC2** — SSH to the instance and:
   - pull the new image from ECR
   - stop and remove the currently running container (if any) — this is what makes deployment
     actually *replace* the running container rather than stacking a new one alongside it
   - run the new container, mapping the app port
7. **Verify Deployment** — curl `/health` from the instance; a non-2xx response (including a
   container that starts but crashes immediately) fails this stage and the whole run is
   reported as a failed deployment
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
