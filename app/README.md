# app

Next.js (TypeScript, App Router) application that serves as the demo
workload for the platform: a home page, an `/architecture` page, and
`/health` / `/ready` endpoints used as Kubernetes liveness/readiness probes.

## Commands

```
npm run dev      # local dev server
npm run lint     # ESLint
npm run test     # Vitest (unit tests for /health and /ready)
npm run build    # production build (next.config.ts sets output: "standalone")
npm run start    # run the production build locally
```

## Environment

- `APP_ENV`: displayed as a badge in the header and returned by `/ready`
  (defaults to `local`; set via the Helm chart's ConfigMap in the cluster).

See `../docker/README.md` for how this app is containerized.
