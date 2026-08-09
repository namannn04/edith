use std::error::Error;

use chrono::{DateTime, Utc};
use serde::Serialize;
use serde_json::Value;
use sqlx::PgPool;
use uuid::Uuid;

use crate::reason::{ReasonClient, ReasonError, extract_json_array};

const EXTRACTOR_VERSION: &str = "reflect-v1";

const SYSTEM_PROMPT: &str = "You distill durable beliefs about one person from their notes, \
voice memos and activity. A belief is a higher-order statement about how they work, feel or \
decide, not a restatement of a single note. Answer with a JSON array only. Each item: \
{\"statement\": string, \"kind\": \"pattern\"|\"preference\"|\"state\", \"confidence\": \
number 0..1, \"evidence\": [episode ids the belief rests on]}. Two to five beliefs. Only use \
episode ids you were given. If the material supports nothing durable, answer [].";

#[derive(Debug, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ReflectOutcome {
    pub episodes_considered: usize,
    pub beliefs_formed: usize,
    pub model: String,
}

pub async fn reflect_run(
    pool: &PgPool,
    reason: &ReasonClient,
) -> Result<ReflectOutcome, Box<dyn Error + Send + Sync>> {
    if !reason.configured() {
        return Err(Box::new(ReasonError::unconfigured()));
    }

    let episodes = sqlx::query_as::<_, (Uuid, DateTime<Utc>, String, String)>(
        "SELECT id, occurred_at, title, left(body_original, 1200) FROM episodes ORDER BY ingested_at DESC LIMIT 20",
    )
    .fetch_all(pool)
    .await?;
    let mut outcome = ReflectOutcome {
        episodes_considered: episodes.len(),
        beliefs_formed: 0,
        model: reason.describe(),
    };
    if episodes.is_empty() {
        return Ok(outcome);
    }

    let material = episodes
        .iter()
        .map(|(id, occurred_at, title, body)| {
            format!(
                "episode {id} ({}) {title}\n{body}",
                occurred_at.format("%Y-%m-%d")
            )
        })
        .collect::<Vec<_>>()
        .join("\n\n");
    let known_ids = episodes.iter().map(|row| row.0).collect::<Vec<_>>();

    let answer = reason.complete(SYSTEM_PROMPT, &material).await?;
    let Some(candidates) = extract_json_array(&answer) else {
        return Err(format!("reflection answer had no JSON array: {answer}").into());
    };

    for candidate in candidates.as_array().into_iter().flatten() {
        let Some(statement) = candidate
            .get("statement")
            .and_then(Value::as_str)
            .map(str::trim)
            .filter(|statement| statement.len() > 10)
        else {
            continue;
        };
        let kind = candidate
            .get("kind")
            .and_then(Value::as_str)
            .filter(|kind| ["pattern", "preference", "state"].contains(kind))
            .unwrap_or("pattern");
        let confidence = candidate
            .get("confidence")
            .and_then(Value::as_f64)
            .unwrap_or(0.5)
            .clamp(0.0, 1.0) as f32;
        let evidence = candidate
            .get("evidence")
            .and_then(Value::as_array)
            .map(|values| {
                values
                    .iter()
                    .filter_map(Value::as_str)
                    .filter_map(|value| Uuid::parse_str(value).ok())
                    .filter(|id| known_ids.contains(id))
                    .collect::<Vec<_>>()
            })
            .unwrap_or_default();
        if evidence.is_empty() {
            continue;
        }

        let duplicate = sqlx::query_scalar::<_, i64>(
            "SELECT count(*) FROM beliefs WHERE status = 'active' AND lower(statement) = lower($1)",
        )
        .fetch_one(pool)
        .await?;
        if duplicate > 0 {
            continue;
        }

        sqlx::query(
            "INSERT INTO beliefs (statement, kind, confidence, evidence_episode_ids, extractor_version) VALUES ($1, $2, $3, $4, $5)",
        )
        .bind(statement)
        .bind(kind)
        .bind(confidence)
        .bind(&evidence)
        .bind(EXTRACTOR_VERSION)
        .execute(pool)
        .await?;
        outcome.beliefs_formed += 1;
    }

    sqlx::query(
        "INSERT INTO reflections (episodes_considered, beliefs_formed, model) VALUES ($1, $2, $3)",
    )
    .bind(outcome.episodes_considered as i32)
    .bind(outcome.beliefs_formed as i32)
    .bind(&outcome.model)
    .execute(pool)
    .await?;

    Ok(outcome)
}
