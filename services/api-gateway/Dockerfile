FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
COPY services/api-gateway/package*.json services/api-gateway/
COPY services/analysis-worker/package*.json services/analysis-worker/
COPY services/reasoning-service/package*.json services/reasoning-service/
COPY packages/shared/package*.json packages/shared/

RUN npm ci

COPY . .

ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=8080

EXPOSE 8080

CMD ["node", "services/api-gateway/simple-api.mjs"]
