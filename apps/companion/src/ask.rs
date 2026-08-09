use std::error::Error;

use chrono::{DateTime, Utc};
use serde::Serialize;
use serde_json::Value;
use sqlx::PgPool;
use uuid::Uuid;

use crate::embed::EmbedClient;
use crate::indexer::halfvec_literal;
use crate::reason::ReasonClient;
use crate::turns::{RetrievedChunk, latency_since, log_turn};

const SYSTEM_PROMPT: &str = "You answer questions about one person from excerpts of their own \
notes, voice memos and records. Ground every claim in the excerpts; if they do not answer the \
question, say so plainly instead of guessing. Answer with JSON only: {\"answer\": string, \
\"citations\": [{\"episodeId\": string, \"quote\": string}]}. Cite only episode ids you were \
given, quoting the exact words the claim rests on.";

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AskCitation {
    pub episode_id: Uuid,
    pub quote: String,
    pub title: String,
    pub occurred_at: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AskOutcome {
    pub answer: String,
    pub citations: Vec<AskCitation>,
    pub chunks_considered: usize,
    pub model: String,
}

fn date_string(date: DateTime<Utc>) -> String {
    date.to_rfc3339_opts(chrono::SecondsFormat::AutoSi, true)
}

pub fn extract_json_object(text: &str) -> Option<Value> {
    let start = text.find('{')?;
    let end = text.rfind('}')?;
    if end <= start {
        return None;
    }
    serde_json::from_str::<Value>(&text[start..=end])
        .ok()
        .filter(Value::is_object)
}

pub async fn ask_run(
    pool: &PgPool,
    embed: &EmbedClient,
    reason: &ReasonClient,
    question: &str,
) -> Result<AskOutcome, Box<dyn Error + Send + Sync>> {
    let started = std::time::Instant::now();
    let query_embedding = halfvec_literal(&embed.embed(&[question.to_owned()]).await?.remove(0));
    type ChunkRow = (Uuid, Uuid, String, String, DateTime<Utc>);
    let chunks = sqlx::query_as::<_, ChunkRow>(
        "SELECT c.id, c.episode_id, c.text_original, e.title, e.occurred_at FROM chunks c JOIN episodes e ON e.id = c.episode_id WHERE c.embedding IS NOT NULL ORDER BY c.embedding <=> $1::halfvec LIMIT 8",
    )
    .bind(&query_embedding)
    .fetch_all(pool)
    .await?;

    if chunks.is_empty() {
        return Ok(AskOutcome {
            answer: "There is nothing in the memory yet to answer from.".to_owned(),
            citations: Vec::new(),
            chunks_considered: 0,
            model: reason.describe(),
        });
    }

    let material = chunks
        .iter()
        .map(|(_, episode_id, text, title, occurred_at)| {
            format!(
                "episode {episode_id} ({}) {title}\n{text}",
                occurred_at.format("%Y-%m-%d")
            )
        })
        .collect::<Vec<_>>()
        .join("\n\n");
    let prompt = format!("Excerpts:\n\n{material}\n\nQuestion: {question}");

    let answer_text = reason.complete(SYSTEM_PROMPT, &prompt).await?;
    let Some(parsed) = extract_json_object(&answer_text) else {
        return Err(format!("ask answer had no JSON object: {answer_text}").into());
    };
    let answer = parsed
        .get("answer")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|answer| !answer.is_empty())
        .ok_or("ask answer had no answer field")?
        .to_owned();

    let mut citations = Vec::new();
    for citation in parsed
        .get("citations")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
    {
        let Some(episode_id) = citation
            .get("episodeId")
            .and_then(Value::as_str)
            .and_then(|value| Uuid::parse_str(value).ok())
        else {
            continue;
        };
        let Some((_, _, _, title, occurred_at)) =
            chunks.iter().find(|(_, id, _, _, _)| *id == episode_id)
        else {
            continue;
        };
        let quote = citation
            .get("quote")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .trim()
            .to_owned();
        citations.push(AskCitation {
            episode_id,
            quote,
            title: title.clone(),
            occurred_at: date_string(*occurred_at),
        });
    }

    let retrieved = chunks
        .iter()
        .enumerate()
        .map(|(rank, (chunk_id, episode_id, _, _, _))| RetrievedChunk {
            chunk_id: *chunk_id,
            episode_id: *episode_id,
            rank: rank as i32 + 1,
            score_vec: Some(1.0 / (rank as f32 + 1.0)),
            score_text: None,
            score_fused: None,
            was_cited: citations
                .iter()
                .any(|citation| citation.episode_id == *episode_id),
        })
        .collect::<Vec<_>>();
    let model = reason.describe();
    log_turn(
        pool,
        "ask",
        question,
        Some(&model),
        latency_since(started),
        &retrieved,
    )
    .await;

    Ok(AskOutcome {
        answer,
        citations,
        chunks_considered: chunks.len(),
        model,
    })
}

#[cfg(test)]
mod tests {
    use super::extract_json_object;

    #[test]
    fn finds_object_inside_prose() {
        let text = "Sure:\n{\"answer\": \"yes\", \"citations\": []}\nthat is all";
        let value = extract_json_object(text).unwrap();
        assert_eq!(value["answer"], "yes");
    }

    #[test]
    fn rejects_missing_object() {
        assert!(extract_json_object("nothing structured").is_none());
    }
}
