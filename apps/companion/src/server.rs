use std::collections::HashMap;
use std::path::PathBuf;

use axum::body::to_bytes;
use axum::extract::{Query, Request, State};
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Json, Router};
use chrono::{DateTime, SecondsFormat, Utc};
use redis::Client;
use serde::Serialize;
use serde_json::{Value, json};
use sqlx::PgPool;
use uuid::Uuid;

use crate::doctor::run_doctor;
use crate::ingest::{IngestFile, ingest_files, parse_file_date};

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub redis: Client,
    pub vault_dir: PathBuf,
}

#[derive(Serialize)]
struct StatusResult {
    sources: i64,
    episodes: i64,
    claims: i64,
    observations: i64,
    latest_ingested_at: Option<String>,
}

#[derive(Serialize)]
struct EpisodeResult {
    id: Uuid,
    occurred_at: String,
    kind: String,
    title: String,
    sha256: String,
}

fn date_string(date: DateTime<Utc>) -> String {
    date.to_rfc3339_opts(SecondsFormat::AutoSi, true)
}

fn error_response(status: StatusCode, detail: impl ToString) -> Response {
    (status, Json(json!({ "error": detail.to_string() }))).into_response()
}

async fn health(State(state): State<AppState>) -> Response {
    let result = run_doctor(&state.pool, &state.redis, &state.vault_dir).await;
    let status = if result.ok {
        StatusCode::OK
    } else {
        StatusCode::SERVICE_UNAVAILABLE
    };
    (status, Json(result)).into_response()
}

fn parse_files(body: Value) -> Result<Vec<IngestFile>, &'static str> {
    let object = body.as_object().ok_or("Body must be an object")?;
    let values = object
        .get("files")
        .and_then(Value::as_array)
        .ok_or("files must be an array")?;
    if values.len() > 200 {
        return Err("files must contain at most 200 items");
    }

    let mut files = Vec::with_capacity(values.len());
    for value in values {
        let Some(file) = value.as_object() else {
            return Err("Each file requires name and text");
        };
        let Some(name) = file.get("name").and_then(Value::as_str) else {
            return Err("Each file requires name and text");
        };
        let Some(text) = file.get("text").and_then(Value::as_str) else {
            return Err("Each file requires name and text");
        };
        if name.is_empty() {
            return Err("Each file requires name and text");
        }
        let mtime = match file.get("mtime") {
            None => None,
            Some(value) => {
                let Some(value) = value.as_str() else {
                    return Err("Each file requires name and text");
                };
                if parse_file_date(value).is_none() {
                    return Err("Each file requires name and text");
                }
                Some(value.to_owned())
            }
        };
        files.push(IngestFile {
            name: name.to_owned(),
            text: text.to_owned(),
            mtime,
        });
    }

    if files.iter().any(|file| file.text.len() > 2 * 1024 * 1024) {
        return Err("Each file must be at most 2MB");
    }

    Ok(files)
}

async fn ingest(State(state): State<AppState>, request: Request) -> Response {
    let bytes = match to_bytes(request.into_body(), 420 * 1024 * 1024).await {
        Ok(bytes) => bytes,
        Err(_) => return error_response(StatusCode::BAD_REQUEST, "Invalid JSON body"),
    };
    let body = match serde_json::from_slice::<Value>(&bytes) {
        Ok(body) => body,
        Err(_) => return error_response(StatusCode::BAD_REQUEST, "Invalid JSON body"),
    };
    let files = match parse_files(body) {
        Ok(files) => files,
        Err(error) => return error_response(StatusCode::BAD_REQUEST, error),
    };

    match ingest_files(&state.pool, &state.vault_dir, files).await {
        Ok(results) => Json(results).into_response(),
        Err(error) => error_response(StatusCode::INTERNAL_SERVER_ERROR, error),
    }
}

async fn status(State(state): State<AppState>) -> Response {
    let result = sqlx::query_as::<_, (i64, i64, i64, i64, Option<DateTime<Utc>>)>(
        "SELECT (SELECT count(*) FROM sources), (SELECT count(*) FROM episodes), (SELECT count(*) FROM claims), (SELECT count(*) FROM observations), (SELECT max(ingested_at) FROM episodes)",
    )
    .fetch_one(&state.pool)
    .await;

    match result {
        Ok((sources, episodes, claims, observations, latest_ingested_at)) => Json(StatusResult {
            sources,
            episodes,
            claims,
            observations,
            latest_ingested_at: latest_ingested_at.map(date_string),
        })
        .into_response(),
        Err(error) => error_response(StatusCode::INTERNAL_SERVER_ERROR, error),
    }
}

fn requested_limit(value: Option<&str>) -> i64 {
    let numeric = match value {
        None => 20.0,
        Some(value) if value.trim().is_empty() => 0.0,
        Some(value) => value.trim().parse::<f64>().unwrap_or(20.0),
    };
    let integral = if numeric.is_finite() {
        numeric.trunc()
    } else {
        20.0
    };
    integral.clamp(1.0, 200.0) as i64
}

async fn episodes(
    State(state): State<AppState>,
    Query(query): Query<HashMap<String, String>>,
) -> Response {
    let limit = requested_limit(query.get("limit").map(String::as_str));
    let result = sqlx::query_as::<_, (Uuid, DateTime<Utc>, String, String, String)>(
        "SELECT e.id, e.occurred_at, e.kind, e.title, s.sha256 FROM episodes e JOIN sources s ON s.id = e.source_id ORDER BY e.occurred_at DESC LIMIT $1",
    )
    .bind(limit)
    .fetch_all(&state.pool)
    .await;

    match result {
        Ok(rows) => {
            let episodes = rows
                .into_iter()
                .map(|(id, occurred_at, kind, title, sha256)| EpisodeResult {
                    id,
                    occurred_at: date_string(occurred_at),
                    kind,
                    title,
                    sha256,
                })
                .collect::<Vec<_>>();
            Json(episodes).into_response()
        }
        Err(error) => error_response(StatusCode::INTERNAL_SERVER_ERROR, error),
    }
}

pub fn router(state: AppState) -> Router {
    Router::new()
        .route("/v1/health", get(health))
        .route("/v1/ingest", post(ingest))
        .route("/v1/status", get(status))
        .route("/v1/episodes", get(episodes))
        .with_state(state)
}
