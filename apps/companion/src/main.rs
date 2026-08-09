mod ask;
mod chunker;
mod claims;
mod doctor;
mod embed;
mod frontmatter;
mod github;
mod indexer;
mod ingest;
mod migrate;
mod nightly;
mod reason;
mod reflect;
mod server;
mod stt;
mod turns;
mod vault;

use std::env;

use sqlx::postgres::PgPoolOptions;

use crate::embed::EmbedClient;
use crate::github::GithubConnector;
use crate::nightly::{NightlyDeps, spawn_scheduler};
use crate::reason::ReasonClient;
use crate::server::AppState;
use crate::stt::SttClient;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let database_url = env::var("DATABASE_URL").unwrap_or_else(|_| {
        "postgres://companion:companion-dev@127.0.0.1:5432/companion".to_owned()
    });
    let redis_url = env::var("REDIS_URL").unwrap_or_else(|_| "redis://127.0.0.1:6379".to_owned());
    let vault_dir = env::var("VAULT_DIR").unwrap_or_else(|_| "/vault".to_owned());

    let pool = PgPoolOptions::new().connect(&database_url).await?;
    migrate::run_migrations(&pool).await?;
    let redis = redis::Client::open(redis_url)?;
    let state = AppState {
        pool,
        redis,
        vault_dir: vault_dir.into(),
        embed: EmbedClient::from_env(),
        stt: SttClient::from_env(),
        github: GithubConnector::from_env(),
        reason: ReasonClient::from_env(),
    };
    spawn_scheduler(NightlyDeps {
        pool: state.pool.clone(),
        embed: state.embed.clone(),
        reason: state.reason.clone(),
        github: state.github.clone(),
    });
    let listener = tokio::net::TcpListener::bind("0.0.0.0:4820").await?;

    println!("companion api listening on 0.0.0.0:4820");
    axum::serve(listener, server::router(state)).await?;

    Ok(())
}
