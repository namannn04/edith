FROM oven/bun:1-slim

WORKDIR /app

COPY package.json ./
RUN bun install

COPY src ./src
COPY migrations ./migrations

CMD ["bun", "src/main.ts"]
