---
name: ops/registry
description: >
  Container registry push discipline. Use when pushing a built image
  to a registry (ECR, GCR, GHCR, Docker Hub), tagging an image for
  a release or deployment, signing images for supply-chain
  verification (Cosign, Notary), authenticating to a registry, or
  choosing between immutable (v1.2.3, sha-abc123) and mutable
  (latest, canary, stable) tag strategies. Trigger on `docker push`,
  `crane`, registry-auth errors, tag rollouts, image-signing
  questions, or any task that produces an image destined for a
  remote registry. Part of the opt-in `ops-skills` plugin — requires
  `ops_enabled=true` in session context; if disabled, report the
  intended push as a follow-up with the proposed tag. Pair with
  core/docker for local image build discipline.
---

# Container Registry

Pushing an image is publication. Downstream consumers — deployments, CI, other services — pull your images by tag. A bad push can poison production, a missing tag can strand a rollback, a mutable `latest` can make a bug irreproducible. This skill covers the discipline. For local build discipline (multi-stage, non-root, layer caching), see `core/docker`.

## When to Use

- Pushing a built image to a container registry
- Tagging an image for a release or deployment
- Signing an image for supply-chain verification
- Authenticating to a registry (ECR, GCR, GHCR, Docker Hub)
- Deciding between immutable and mutable tag strategies

## When NOT to Use

- Session context has `ops_enabled=false` — **do not push**, report the intended push as a follow-up
- The image has not been built locally yet — build first via `core/docker`
- The image has not been tested locally or in CI — do not push broken images anywhere

## Core Process

### 1. Build before tagging

A push is the end of the build pipeline, not the start. Before `docker push`:

- Image builds cleanly (`docker build` exits 0)
- Image passes security scan (Trivy, grype, or your scanner of choice)
- Health check runs cleanly inside the image (`docker run ...` then hit `/healthz`)
- Size is within the target (Go: <20MB; Node: <150MB; Python: <200MB)

If any of these fail, **do not push** — fix the build first. Common size-related causes: dev dependencies not excluded from the runtime stage, wrong base image (alpine/debian when distroless would do), unnecessary intermediate layers copied across stages. Common scan failures: outdated base image with known CVEs — rebuild with a patched base before pushing.

### 2. Tag immutably by default, mutably by exception

**Immutable tags (required).** Immutable tags — version (`myservice:v1.2.3`), commit SHA (`myservice:sha-abc123def`), or build ID — are your default. Once pushed, they refer to that exact image forever. Production deployments pull by immutable tag. Downstream consumers can pin to them safely. Always push the immutable tag.

**Mutable tags (sparingly).** Mutable tags — `latest`, `stable`, `canary` — change what they refer to over time. They are convenient for local development and rollout channels, but dangerous for production because "the image that was there yesterday" is not guaranteed to be "the image that is there today".

Rules for mutable tags:

- Never use them for production deployments
- Never rely on them for reproducible builds
- When you do update one, treat it as a policy decision (auditable, announced) — not a routine
- Pair them with the immutable tag: push `v1.2.3` first, then update `latest` to point at that same digest

Never update a mutable tag without a corresponding immutable tag that pins the content.

### 3. Authenticate explicitly

Registry authentication is project-specific:

- **ECR:** `aws ecr get-login-password | docker login --username AWS --password-stdin <account>.dkr.ecr.<region>.amazonaws.com` — ECR uses IAM for access control, so credentials come from the AWS CLI session
- **GCR / Artifact Registry:** `gcloud auth configure-docker` once, then normal `docker push` — credentials flow from gcloud's keyring
- **GHCR:** `echo $GITHUB_TOKEN | docker login ghcr.io -u <user> --password-stdin` — use a PAT with `write:packages` scope, never a username/password
- **Docker Hub:** `docker login` with a PAT (never username/password) for CI; interactive for local

Credentials come from environment variables or a secrets manager. Never from source code, Dockerfiles, or shell history. See `core/security` §4.

### 4. Sign if your registry supports it

Image signing (Cosign, Notary v2, GPG) makes supply-chain attacks detectable. If your platform supports it:

- Sign every image you push
- Verify signatures on pull in deployment pipelines
- Rotate signing keys on schedule, not on incident

Unsigned images are acceptable for scratch work; they are not acceptable for anything that runs in production.

### 5. Never overwrite an immutable tag

If you push `myservice:v1.2.3` a second time with different content, you have created an incident waiting to happen: downstream consumers will get inconsistent results depending on when they pulled. Immutable means immutable.

If v1.2.3 was bad: cut v1.2.4. Do not re-push v1.2.3.

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "I'll just push `latest` and call it good." | `latest` is convenient and untraceable. Push a version tag too. |
| "The image passed local health check — skip the scan." | Scanners find CVEs health checks don't. Run the scanner. |
| "I'll re-push the version tag with the fix." | Downstream consumers are now in an inconsistent state. Cut a new version. |
| "Credentials in the Dockerfile are fine for CI." | Credentials in layers leak via `docker history`. Use build secrets. |
| "Signing is overhead; we trust our network." | Supply-chain attacks are in-network attacks. Sign. |
| "The image is 5MB over target — we can push it anyway." | The target is a budget. Budget creep compounds — next quarter you're pulling 200MB images in every deploy. Fix the build. |

## Red Flags

- `docker push myservice:latest` without also pushing a version tag
- Images pushed without passing a security scan
- Credentials embedded in Dockerfile layers, even in build stages
- Version tags overwritten after initial push
- `docker push` commands in CI scripts without authentication guards
- Unsigned images deployed to production
- Push commands without error handling in automation
- Mutable tag updated without a corresponding immutable tag

## Verification

- [ ] `ops_enabled=true` confirmed in session context before any push command
- [ ] Image built, scanned, and health-checked before push
- [ ] Immutable tag (version or SHA) pushed, not only a mutable tag
- [ ] Registry authentication from environment/secrets, not source
- [ ] Signature applied if the platform supports it
- [ ] Never overwrote an existing version tag
- [ ] When `ops_enabled=false`: push reported as a follow-up with the proposed tag
