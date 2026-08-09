use std::error::Error;

use serde::Serialize;
use sqlx::PgPool;
use uuid::Uuid;

pub const COLD_START_SECONDS: f64 = 20.0 * 3600.0;

const DEVIATION_KINDS: [&str; 6] = [
    "wpm",
    "pause_s",
    "f0_median",
    "f0_range",
    "rms",
    "filler_rate",
];

#[derive(Debug, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct BaselineOutcome {
    pub audio_seconds: f64,
    pub cold_start: bool,
    pub signals_scored: usize,
    pub chunks_scored: usize,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct BaselineRow {
    pub kind: String,
    pub context_bucket: String,
    pub median: f64,
    pub iqr: f64,
    pub samples: i64,
}

pub fn zscore(value: f64, median: f64, iqr: f64) -> f64 {
    let spread = if iqr.abs() < 1e-6 { 1e-6 } else { iqr };
    (value - median) / (spread / 1.349)
}

pub fn salience_from(deviation: f64, pause_weight: f64, events: f64, repairs: f64) -> f32 {
    let value = 0.45 * deviation.abs().min(4.0) / 4.0
        + 0.25 * pause_weight.min(1.0)
        + 0.2 * events.min(1.0)
        + 0.1 * repairs.min(1.0);
    value.clamp(0.0, 1.0) as f32
}

pub async fn audio_seconds(pool: &PgPool) -> Result<f64, sqlx::Error> {
    let total = sqlx::query_scalar::<_, Option<f64>>(
        "SELECT sum(duration_s)::float8 FROM episodes WHERE duration_s IS NOT NULL",
    )
    .fetch_one(pool)
    .await?;
    Ok(total.unwrap_or(0.0))
}

pub async fn baselines(pool: &PgPool) -> Result<Vec<BaselineRow>, sqlx::Error> {
    type Row = (String, String, Option<f64>, Option<f64>, Option<f64>, i64);
    let rows = sqlx::query_as::<_, Row>(
        "SELECT kind, context_bucket, percentile_cont(0.5) WITHIN GROUP (ORDER BY value)::float8, percentile_cont(0.25) WITHIN GROUP (ORDER BY value)::float8, percentile_cont(0.75) WITHIN GROUP (ORDER BY value)::float8, count(*) FROM signals WHERE value IS NOT NULL GROUP BY kind, context_bucket ORDER BY kind, context_bucket",
    )
    .fetch_all(pool)
    .await?;
    Ok(rows
        .into_iter()
        .map(|(kind, context_bucket, median, q1, q3, samples)| BaselineRow {
            kind,
            context_bucket,
            median: median.unwrap_or(0.0),
            iqr: (q3.unwrap_or(0.0) - q1.unwrap_or(0.0)).abs(),
            samples,
        })
        .collect())
}

pub async fn rescore(pool: &PgPool) -> Result<BaselineOutcome, Box<dyn Error + Send + Sync>> {
    let seconds = audio_seconds(pool).await?;
    let mut outcome = BaselineOutcome {
        audio_seconds: seconds,
        cold_start: seconds < COLD_START_SECONDS,
        signals_scored: 0,
        chunks_scored: 0,
    };
    if outcome.cold_start {
        sqlx::query("UPDATE signals SET zscore = NULL, baseline_window = NULL WHERE zscore IS NOT NULL")
            .execute(pool)
            .await?;
        return Ok(outcome);
    }

    for row in baselines(pool).await? {
        if row.samples < 20 || !DEVIATION_KINDS.contains(&row.kind.as_str()) {
            continue;
        }
        let scale = (row.iqr.abs().max(1e-6)) / 1.349;
        let updated = sqlx::query(
            "UPDATE signals SET zscore = (value - $3) / $4, baseline_window = $5, confidence = least(1.0, $6::real / 200.0) WHERE kind = $1 AND context_bucket = $2",
        )
        .bind(&row.kind)
        .bind(&row.context_bucket)
        .bind(row.median)
        .bind(scale)
        .bind(format!("{} samples, all history", row.samples))
        .bind(row.samples as f32)
        .execute(pool)
        .await?;
        outcome.signals_scored += updated.rows_affected() as usize;
    }

    outcome.chunks_scored = rescore_chunks(pool).await?;
    Ok(outcome)
}

pub async fn rescore_chunks(pool: &PgPool) -> Result<usize, sqlx::Error> {
    let updated = sqlx::query(
        "UPDATE chunks c SET salience = sub.salience FROM (
            SELECT c.id AS chunk_id,
                   least(1.0,
                     0.45 * least(4.0, coalesce(max(abs(s.zscore)), 0)) / 4.0
                   + 0.25 * least(1.0, coalesce(max(s.value) FILTER (WHERE s.kind = 'pause_s'), 0) / 20.0)
                   + 0.20 * least(1.0, count(*) FILTER (WHERE s.kind LIKE 'event_%')::real / 3.0)
                   + 0.10 * least(1.0, count(*) FILTER (WHERE s.kind IN ('repair', 'code_switch'))::real / 4.0)
                   )::real AS salience
            FROM chunks c
            JOIN signals s ON s.episode_id = c.episode_id
              AND c.t_start_s IS NOT NULL AND c.t_end_s IS NOT NULL
              AND s.t_start_s < c.t_end_s AND s.t_end_s > c.t_start_s
            GROUP BY c.id
        ) sub WHERE c.id = sub.chunk_id AND c.salience IS DISTINCT FROM sub.salience",
    )
    .execute(pool)
    .await?;
    Ok(updated.rows_affected() as usize)
}

pub async fn episode_context_bucket(pool: &PgPool, episode_id: Uuid) -> String {
    sqlx::query_scalar::<_, Option<String>>(
        "SELECT coalesce(meta->>'context', kind) || ':' || coalesce(array_to_string(langs, '+'), 'unknown') FROM episodes WHERE id = $1",
    )
    .bind(episode_id)
    .fetch_optional(pool)
    .await
    .ok()
    .flatten()
    .flatten()
    .unwrap_or_else(|| "default".to_owned())
}

#[cfg(test)]
mod tests {
    use super::{salience_from, zscore};

    #[test]
    fn zscore_is_zero_at_the_median() {
        assert!(zscore(10.0, 10.0, 4.0).abs() < 1e-9);
    }

    #[test]
    fn zscore_scales_with_spread() {
        let tight = zscore(14.0, 10.0, 1.0);
        let loose = zscore(14.0, 10.0, 8.0);
        assert!(tight > loose);
    }

    #[test]
    fn salience_stays_in_range() {
        assert_eq!(salience_from(0.0, 0.0, 0.0, 0.0), 0.0);
        assert!(salience_from(9.0, 5.0, 5.0, 5.0) <= 1.0);
        assert!(salience_from(2.0, 0.5, 0.3, 0.0) > 0.0);
    }
}
