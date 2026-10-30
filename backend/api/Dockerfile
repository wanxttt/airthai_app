# Multi-stage Dockerfile for AirthAI NestJS Backend API
# Stage 1: Build & Dependencies
FROM node:20-alpine AS builder

WORKDIR /usr/src/app

# Install build dependencies
RUN apk add --no-cache python3 make g++

# Copy package manifests & prisma schema first for aggressive layer caching
COPY package*.json ./
COPY prisma ./prisma/

# Install exact dependencies
RUN npm ci

# Generate Prisma Client
RUN npm run prisma:generate

# Copy application source code
COPY tsconfig*.json nest-cli.json ./
COPY src ./src

# Build production bundle
RUN npm run build

# Stage 2: Minimal Production / Staging Runtime
FROM node:20-alpine AS runner

WORKDIR /usr/src/app

# Security: Non-root runtime user
RUN addgroup -S -g 1001 airthai && \
    adduser -S -u 1001 -G airthai airthai

# Environment defaults
ENV NODE_ENV=staging \
    PORT=3000

# Copy necessary production artifacts from builder
COPY --from=builder --chown=airthai:airthai /usr/src/app/package*.json ./
COPY --from=builder --chown=airthai:airthai /usr/src/app/node_modules ./node_modules
COPY --from=builder --chown=airthai:airthai /usr/src/app/dist ./dist
COPY --from=builder --chown=airthai:airthai /usr/src/app/prisma ./prisma

USER airthai

EXPOSE 3000

# Container healthcheck probe
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/v1/health || exit 1

CMD ["node", "dist/main.js"]

