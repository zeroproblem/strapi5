# =========
# Stage 1: deps + build
# =========
FROM node:20-alpine AS build
WORKDIR /app

# Dependências de build (para pacotes nativos, caso precisem)
RUN apk add --no-cache python3 make g++ libc6-compat

# Copia manifests primeiro (cache eficiente)
COPY package.json package-lock.json* yarn.lock* ./

# Instala dependências (suporta npm ou yarn, o que existir no projeto)
RUN if [ -f yarn.lock ]; then \
      corepack enable && yarn set version stable && yarn install --frozen-lockfile; \
    else \
      npm ci; \
    fi

# Copia o restante do código
COPY . .

# Build de produção
ENV NODE_ENV=production
RUN if [ -f yarn.lock ]; then \
      yarn build; \
    else \
      npm run build; \
    fi

# =========
# Stage 2: runtime leve
# =========
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=1337
ENV HOST=0.0.0.0

# Usuário não-root
RUN addgroup -S strapi && adduser -S strapi -G strapi

# Só deps de produção
COPY --from=build /app/package.json /app/package-lock.json* /app/yarn.lock* ./
RUN apk add --no-cache libc6-compat && \
    if [ -f yarn.lock ]; then \
      corepack enable && yarn set version stable && yarn workspaces focus --all --production && yarn cache clean; \
    else \
      npm ci --omit=dev; \
    fi

# Copia artefatos necessários para rodar
COPY --from=build /app/build ./build
COPY --from=build /app/config ./config
COPY --from=build /app/src ./src
COPY --from=build /app/public ./public
COPY --from=build /app/.cache ./.cache
# Se você tiver pastas personalizadas (ex.: ./database, ./extensions), copie também:
# COPY --from=build /app/database ./database
# COPY --from=build /app/extensions ./extensions

# Persistência de uploads
VOLUME ["/app/public/uploads"]

EXPOSE 1337
USER strapi

# Inicia em modo produção (usa seu script "start")
CMD [ "npm", "run", "start" ]
