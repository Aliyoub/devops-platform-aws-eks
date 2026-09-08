# app

Application Next.js (TypeScript, App Router) qui sert de workload de démo
pour la plateforme : une page d'accueil, une page `/architecture`, et les
endpoints `/health` / `/ready` utilisés comme probes Kubernetes
liveness/readiness.

## Commandes

```
npm run dev      # serveur de dev local
npm run lint     # ESLint
npm run test     # Vitest (tests unitaires pour /health et /ready)
npm run build    # build de production (next.config.ts fixe output: "standalone")
npm run start    # lance le build de production en local
```

## Environnement

- `APP_ENV` : affiché comme badge dans l'en-tête et renvoyé par `/ready`
  (vaut `local` par défaut ; fixé via le ConfigMap du chart Helm dans le
  cluster).

Voir `../docker/README.md` pour la conteneurisation de cette application.
