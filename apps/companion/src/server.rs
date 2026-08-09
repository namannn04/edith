use std::collections::HashMap;
use std::path::PathBuf;

use axum::body::to_bytes;
use axum::extract::{Query, Request, State};
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Json, Router};
use base64::Engine;
use chrono::{DateTime, SecondsFormat, Utc};
use redis::Client;
use serde::Serialize;
use serde_json::{Value, json};
use sqlx::PgPool;
use uuid::Uuid;

use crate::doctor::run_doctor;
use crate::embed::EmbedClient;
use crate::indexer::{halfvec_literal, index_pending};
use crate::ingest::{IngestFile, ingest_audio, ingest_files, parse_file_date};
use crate::stt::SttClient;

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub redis: Client,
    pub vault_dir: PathBuf,
    pub embed: EmbedClient,
    pub stt: SttClient,
}

#[derive(Serialize)]
struct StatusResult {
    sources: i64,
    episodes: i64,
    claims: i64,
    observations: i64,
    chunks: i64,
    pending_episodes: i64,
    latest_ingested_at: Option<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct SearchResult {
    chunk_id: Uuid,
    episode_id: Uuid,
    ord: i32,
    title: String,
    occurred_at: String,
    kind: String,
    snippet: String,
    score: f64,
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
    let result = run_doctor(
        &state.pool,
        &state.redis,
        &state.vault_dir,
        &state.embed,
        &state.stt,
    )
    .await;
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
        Ok(results) => {
            if results.iter().any(|result| result.status == "ingested") {
                spawn_index(&state);
            }
            Json(results).into_response()
        }
        Err(error) => error_response(StatusCode::INTERNAL_SERVER_ERROR, error),
    }
}

fn spawn_index(state: &AppState) {
    let pool = state.pool.clone();
    let embed = state.embed.clone();
    tokio::spawn(async move {
        if let Err(error) = index_pending(&pool, &embed).await {
            eprintln!("background indexing failed: {error}");
        }
    });
}

async fn ingest_audio_route(State(state): State<AppState>, request: Request) -> Response {
    let bytes = match to_bytes(request.into_body(), 64 * 1024 * 1024).await {
        Ok(bytes) => bytes,
        Err(_) => return error_response(StatusCode::BAD_REQUEST, "Invalid JSON body"),
    };
    let body = match serde_json::from_slice::<Value>(&bytes) {
        Ok(body) => body,
        Err(_) => return error_response(StatusCode::BAD_REQUEST, "Invalid JSON body"),
    };
    let Some(object) = body.as_object() else {
        return error_response(StatusCode::BAD_REQUEST, "Body must be an object");
    };
    let Some(name) = object
        .get("name")
        .and_then(Value::as_str)
        .filter(|value| !value.is_empty())
    else {
        return error_response(StatusCode::BAD_REQUEST, "name is required");
    };
    let Some(data) = object.get("dataB64").and_then(Value::as_str) else {
        return error_response(StatusCode::BAD_REQUEST, "dataB64 is required");
    };
    let mtime = match object.get("mtime") {
        None => None,
        Some(value) => match value
            .as_str()
            .filter(|value| parse_file_date(value).is_some())
        {
            Some(value) => Some(value.to_owned()),
            None => return error_response(StatusCode::BAD_REQUEST, "mtime must be a date"),
        },
    };
    let audio = match base64::engine::general_purpose::STANDARD.decode(data) {
        Ok(audio) if !audio.is_empty() => audio,
        Ok(_) => return error_response(StatusCode::BAD_REQUEST, "dataB64 is empty"),
        Err(_) => return error_response(StatusCode::BAD_REQUEST, "dataB64 is not valid base64"),
    };
    if audio.len() > 48 * 1024 * 1024 {
        return error_response(StatusCode::BAD_REQUEST, "Audio must be at most 48MB");
    }

    match ingest_audio(
        &state.pool,
        &state.vault_dir,
        &state.stt,
        name.to_owned(),
        audio,
        mtime,
    )
    .await
    {
        Ok(outcome) => {
            if outcome.status == "ingested" {
                spawn_index(&state);
            }
            Json(outcome).into_response()
        }
        Err(error) => error_response(StatusCode::BAD_GATEWAY, error),
    }
}

async fn index(State(state): State<AppState>) -> Response {
    match index_pending(&state.pool, &state.embed).await {
        Ok(outcome) => Json(outcome).into_response(),
        Err(failure) => {
            let status = if failure.is_embedding() {
                StatusCode::BAD_GATEWAY
            } else {
                StatusCode::INTERNAL_SERVER_ERROR
            };
            error_response(status, failure)
        }
    }
}

fn snippet(text: &str) -> String {
    if text.chars().count() <= 300 {
        return text.to_owned();
    }
    let cut = text.char_indices().nth(300).map_or(text.len(), |(i, _)| i);
    format!("{}\u{2026}", &text[..cut])
}

async fn search(
    State(state): State<AppState>,
    Query(query): Query<HashMap<String, String>>,
) -> Response {
    let Some(q) = query
        .get("q")
        .map(|value| value.trim())
        .filter(|value| !value.is_empty())
    else {
        return error_response(StatusCode::BAD_REQUEST, "q is required");
    };
    let k = query
        .get("k")
        .and_then(|value| value.trim().parse::<i64>().ok())
        .unwrap_or(8)
        .clamp(1, 50) as usize;

    let query_embedding = match state.embed.embed(&[q.to_owned()]).await {
        Ok(mut vectors) => halfvec_literal(&vectors.remove(0)),
        Err(error) => return error_response(StatusCode::BAD_GATEWAY, error),
    };

    type CandidateRow = (Uuid, Uuid, i32, String, String, DateTime<Utc>, String);
    let vector_rows = sqlx::query_as::<_, CandidateRow>(
        "SELECT c.id, c.episode_id, c.ord, c.text_original, e.title, e.occurred_at, e.kind FROM chunks c JOIN episodes e ON e.id = c.episode_id WHERE c.embedding IS NOT NULL ORDER BY c.embedding <=> $1::halfvec LIMIT 50",
    )
    .bind(&query_embedding)
    .fetch_all(&state.pool)
    .await;
    let text_rows = sqlx::query_as::<_, CandidateRow>(
        "SELECT c.id, c.episode_id, c.ord, c.text_original, e.title, e.occurred_at, e.kind FROM chunks c JOIN episodes e ON e.id = c.episode_id WHERE c.tsv @@ websearch_to_tsquery('english', $1) ORDER BY ts_rank_cd(c.tsv, websearch_to_tsquery('english', $1)) DESC LIMIT 50",
    )
    .bind(q)
    .fetch_all(&state.pool)
    .await;

    let (vector_rows, text_rows) = match (vector_rows, text_rows) {
        (Ok(vector_rows), Ok(text_rows)) => (vector_rows, text_rows),
        (Err(error), _) | (_, Err(error)) => {
            return error_response(StatusCode::INTERNAL_SERVER_ERROR, error);
        }
    };

    let mut fused: HashMap<Uuid, (CandidateRow, f64)> = HashMap::new();
    for rows in [vector_rows, text_rows] {
        for (rank, row) in rows.into_iter().enumerate() {
            let contribution = 1.0 / (60.0 + rank as f64 + 1.0);
            fused
                .entry(row.0)
                .and_modify(|entry| entry.1 += contribution)
                .or_insert((row, contribution));
        }
    }
    let mut ranked: Vec<(CandidateRow, f64)> = fused.into_values().collect();
    ranked.sort_by(|a, b| b.1.total_cmp(&a.1));
    ranked.truncate(k);

    let results = ranked
        .into_iter()
        .map(
            |((chunk_id, episode_id, ord, text, title, occurred_at, kind), score)| SearchResult {
                chunk_id,
                episode_id,
                ord,
                title,
                occurred_at: date_string(occurred_at),
                kind,
                snippet: snippet(&text),
                score: (score * 1e6).round() / 1e6,
            },
        )
        .collect::<Vec<_>>();
    Json(results).into_response()
}

async fn status(State(state): State<AppState>) -> Response {
    let result = sqlx::query_as::<_, (i64, i64, i64, i64, i64, i64, Option<DateTime<Utc>>)>(
        "SELECT (SELECT count(*) FROM sources), (SELECT count(*) FROM episodes), (SELECT count(*) FROM claims), (SELECT count(*) FROM observations), (SELECT count(*) FROM chunks), (SELECT count(*) FROM episodes e WHERE NOT EXISTS (SELECT 1 FROM chunks c WHERE c.episode_id = e.id)), (SELECT max(ingested_at) FROM episodes)",
    )
    .fetch_one(&state.pool)
    .await;

    match result {
        Ok((
            sources,
            episodes,
            claims,
            observations,
            chunks,
            pending_episodes,
            latest_ingested_at,
        )) => Json(StatusResult {
            sources,
            episodes,
            claims,
            observations,
            chunks,
            pending_episodes,
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
        .route("/v1/ingest/audio", post(ingest_audio_route))
        .route("/v1/index", post(index))
        .route("/v1/search", get(search))
        .route("/v1/status", get(status))
        .route("/v1/episodes", get(episodes))
        .with_state(state)
}
