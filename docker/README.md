# Docker image

## Build

The build context is the repository root, not `docker/`, because the multi-stage
build needs access to `app/` while keeping the Dockerfile organized in its own
directory:

```
docker build -f docker/Dockerfile -t devops-platform-aws-eks:local .
```

## Choices

- **Multi-stage build** (`deps` / `builder` / `runner`): dependencies are
  installed in a cacheable layer, the app is compiled with `next build`
  (`output: "standalone"`, see `app/next.config.ts`), and only the traced
  runtime files are copied into the final image — no `node_modules`, no
  build toolchain, no source maps of the build process.
- **`node:22-alpine`**: matches the Node version used locally (22) and keeps
  the image small.
- **Non-root user**: the final stage creates and switches to `nextjs`
  (uid 1001), matching the `runAsNonRoot` requirement enforced later at the
  Kubernetes SecurityContext level.
- **Healthcheck**: calls the app's own `/health` endpoint using Node's
  built-in `fetch`, avoiding the need to install `curl`/`wget` in the alpine
  image.
- **`.dockerignore` at the repository root**: excludes `node_modules`,
  `.next`, and every non-application directory (`terraform/`, `helm/`,
  `docs/`, ...) so the build context stays small and irrelevant changes
  elsewhere in the repo don't invalidate the Docker layer cache.

## Local test

```
docker run --rm -p 3000:3000 -e APP_ENV=local devops-platform-aws-eks:local
curl http://localhost:3000/health
```
