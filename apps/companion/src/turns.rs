use sqlx::PgPool;
use uuid::Uuid;

pub struct RetrievedChunk {
    pub chunk_id: Uuid,
    pub episode_id: Uuid,
    pub rank: i32,
    pub score_vec: Option<f32>,
    pub score_text: Option<f32>,
    pub score_fused: Option<f32>,
    pub was_cited: bool,
}

pub async fn log_turn(
    pool: &PgPool,
    kind: &str,
    query: &str,
    model: Option<&str>,
    latency_ms: i32,
    retrieved: &[RetrievedChunk],
) {
    let turn_id = match sqlx::query_scalar::<_, Uuid>(
        "INSERT INTO turns (kind, query, model, latency_ms) VALUES ($1, $2, $3, $4) RETURNING id",
    )
    .bind(kind)
    .bind(query)
    .bind(model)
    .bind(latency_ms)
    .fetch_one(pool)
    .await
    {
        Ok(turn_id) => turn_id,
        Err(error) => {
            eprintln!("turn logging failed: {error}");
            return;
        }
    };

    for chunk in retrieved {
        if let Err(error) = sqlx::query(
            "INSERT INTO retrievals (turn_id, chunk_id, episode_id, rank, score_vec, score_text, score_fused, was_cited) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
        )
        .bind(turn_id)
        .bind(chunk.chunk_id)
        .bind(chunk.episode_id)
        .bind(chunk.rank)
        .bind(chunk.score_vec)
        .bind(chunk.score_text)
        .bind(chunk.score_fused)
        .bind(chunk.was_cited)
        .execute(pool)
        .await
        {
            eprintln!("retrieval logging failed: {error}");
            return;
        }
    }
}

pub fn latency_since(started: std::time::Instant) -> i32 {
    i32::try_from(started.elapsed().as_millis()).unwrap_or(i32::MAX)
}
