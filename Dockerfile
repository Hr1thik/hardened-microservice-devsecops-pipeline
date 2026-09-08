# Step 1: Secure minimal base image
FROM node:20-alpine AS builder

WORKDIR /app

# Step 2: Leverage layer caching for dependencies
COPY package.json package-lock.json* ./
RUN npm ci --only=production

COPY server.js .

# Step 3: Minimal runner stage
FROM node:20-alpine

WORKDIR /app

COPY --from=builder /app /app

# Step 4: Drop root privileges (run as non-privileged 'node' user)
USER node

EXPOSE 3000

ENV NODE_ENV=production

CMD ["node", "server.js"]