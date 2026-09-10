# Build context is the repository root (see docker/README.md) so this image
# can be built with: docker build -f docker/Dockerfile .

# ---- deps: install dependencies with a cacheable layer ----
FROM node:22-alpine AS deps
WORKDIR /app
COPY app/package.json app/package-lock.json ./
RUN npm ci

# ---- builder: compile the Next.js standalone output ----
FROM node:22-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY app/ ./
RUN npm run build

# ---- runner: minimal, non-root runtime image ----
FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

# Durcissement trouve via un vrai scan Trivy (voir docker/README.md), pas
# anticipe a l'avance :
# - `apk upgrade` applique les correctifs Alpine disponibles (ex. OpenSSL)
#   au moment du build, plutot que de rester figes sur ceux de l'image de
#   base.
# - npm/npx et leurs dependances vendorisees (tar, pacote, sigstore...)
#   sont retires : le runtime n'execute jamais `npm`, uniquement
#   `node server.js`. Les garder ne fait qu'ajouter de la surface
#   d'attaque et des CVE inutiles a une image de production.
RUN apk upgrade --no-cache \
    && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

RUN addgroup --system --gid 1001 nodejs \
    && adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD node -e "fetch('http://127.0.0.1:'+process.env.PORT+'/health').then(r=>{if(r.status!==200)process.exit(1)}).catch(()=>process.exit(1))"

CMD ["node", "server.js"]
