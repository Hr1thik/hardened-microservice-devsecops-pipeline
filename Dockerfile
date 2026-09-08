# Stage 1: Build & Dependencies
FROM node:20-alpine AS builder

WORKDIR /app

# Copy dependency definitions explicitly
COPY package.json package-lock.json ./

# Use modern flag for production dependencies
RUN npm ci --omit=dev

# Copy application source
COPY server.js .

# Stage 2: Production Runtime
FROM node:20-alpine

WORKDIR /app

# Copy only node_modules and code from builder
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/server.js ./server.js

USER node

EXPOSE 3000

ENV NODE_ENV=production

# FIX (DS-0026): Add Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "server.js"]