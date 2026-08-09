FROM rust:1.97-slim AS builder

WORKDIR /app

COPY Cargo.toml ./
COPY src ./src
COPY migrations ./migrations
RUN cargo build --release

FROM debian:trixie-slim

COPY --from=builder /app/target/release/companion /usr/local/bin/companion

CMD ["companion"]
