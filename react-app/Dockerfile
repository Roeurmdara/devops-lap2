# ==============================================================================
# Multi-Stage Production Dockerfile for React.js Application
# dara.lifestyle
# ==============================================================================

# Stage 1: Build Application
FROM node:20-alpine AS builder
WORKDIR /app

# Copy package descriptors and install dependencies
COPY package*.json ./
RUN npm ci --prefer-offline --no-audit || npm install

# Copy source code and build production assets
COPY . .
RUN npm run build

# Stage 2: Serve Production Assets with Nginx
FROM nginx:alpine
WORKDIR /usr/share/nginx/html

# Clean default nginx website
RUN rm -rf ./*

# Copy built artifacts from Stage 1
COPY --from=builder /app/dist .

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose HTTP port
EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O - http://localhost/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
