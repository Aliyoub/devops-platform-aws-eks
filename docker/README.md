# Image Docker

## Build

Le contexte de build est la racine du repository, pas `docker/`, car le
build multi-stage a besoin d'accéder à `app/` tout en gardant le Dockerfile
rangé dans son propre dossier :

```
docker build -f docker/Dockerfile -t devops-platform-aws-eks:local .
```

## Choix effectués

- **Build multi-stage** (`deps` / `builder` / `runner`) : les dépendances
  sont installées dans une couche cacheable, l'app est compilée avec
  `next build` (`output: "standalone"`, voir `app/next.config.ts`), et seuls
  les fichiers runtime nécessaires (tracés automatiquement) sont copiés dans
  l'image finale — pas de `node_modules`, pas de toolchain de build, pas de
  source maps du processus de compilation.
- **`node:22-alpine`** : correspond à la version de Node utilisée en local
  (22) tout en gardant une image légère.
- **Utilisateur non-root** : le stage final crée l'utilisateur `nextjs`
  (uid 1001) et bascule dessus, cohérent avec l'exigence `runAsNonRoot`
  appliquée plus tard au niveau du SecurityContext Kubernetes.
- **Healthcheck** : appelle le endpoint `/health` de l'application avec le
  `fetch` intégré à Node, sans avoir besoin d'installer `curl`/`wget` dans
  l'image alpine.
- **`.dockerignore` à la racine du repository** : exclut `node_modules`,
  `.next`, et tous les dossiers non liés à l'application (`terraform/`,
  `helm/`, `docs/`, ...) pour garder un contexte de build petit et éviter que
  des changements ailleurs dans le repo invalident le cache des couches
  Docker.
- **`apk upgrade` et suppression de `npm`/`npx` dans le stage final**
  (Phase 9) : trouvé via un vrai scan Trivy, pas anticipé à l'avance. Le
  runtime n'exécute jamais `npm` (seulement `node server.js`), mais l'image
  de base `node:22-alpine` l'embarque quand même avec ses propres
  dépendances vendorisées (`tar`, `pacote`, `sigstore`...), qui portaient
  plusieurs CVE HIGH/CRITICAL réelles au moment du scan. Les retirer élimine
  à la fois ces CVE et de la surface d'attaque inutile en production.
  Revérifié par un scan Trivy après correction : 0 vulnérabilité
  HIGH/CRITICAL.

## Test en local

```
docker run --rm -p 3000:3000 -e APP_ENV=local devops-platform-aws-eks:local
curl http://localhost:3000/health
```
