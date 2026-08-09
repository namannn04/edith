use std::path::Path;

use chrono::{DateTime, NaiveDate, SecondsFormat, Utc};
use serde::{Serialize, Serializer};
use sha2::{Digest, Sha256};
use sqlx::PgPool;
use uuid::Uuid;

use crate::frontmatter::parse_front_matter;
use crate::vault::write_vault_file;

#[derive(Debug)]
pub struct IngestFile {
    pub name: String,
    pub text: String,
    pub mtime: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct IngestOutcome {
    pub name: String,
    pub status: &'static str,
    #[serde(rename = "episodeId")]
    pub episode_id: Uuid,
    #[serde(rename = "occurredAt", serialize_with = "serialize_date")]
    pub occurred_at: DateTime<Utc>,
}

fn serialize_date<S>(date: &DateTime<Utc>, serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    serializer.serialize_str(&date.to_rfc3339_opts(SecondsFormat::AutoSi, true))
}

pub fn parse_file_date(value: &str) -> Option<DateTime<Utc>> {
    if value.len() == 10 {
        if let Ok(date) = NaiveDate::parse_from_str(value, "%Y-%m-%d") {
            return date.and_hms_opt(0, 0, 0).map(|date| date.and_utc());
        }
    }
    DateTime::parse_from_rfc3339(value)
        .ok()
        .map(|date| date.with_timezone(&Utc))
}

fn file_title(name: &str) -> String {
    Path::new(name)
        .file_stem()
        .or_else(|| Path::new(name).file_name())
        .unwrap_or_default()
        .to_string_lossy()
        .into_owned()
}

async fn existing_episode(
    transaction: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    sha256: &str,
) -> Result<Option<(Uuid, DateTime<Utc>)>, sqlx::Error> {
    sqlx::query_as::<_, (Uuid, DateTime<Utc>)>(
        "SELECT e.id, e.occurred_at FROM sources s JOIN episodes e ON e.source_id = s.id WHERE s.sha256 = $1 ORDER BY e.ingested_at LIMIT 1",
    )
    .bind(sha256)
    .fetch_optional(&mut **transaction)
    .await
}

pub async fn ingest_files(
    pool: &PgPool,
    vault_dir: &Path,
    files: Vec<IngestFile>,
) -> Result<Vec<IngestOutcome>, Box<dyn std::error::Error + Send + Sync>> {
    let mut outcomes = Vec::with_capacity(files.len());

    for file in files {
        let sha256 = hex::encode(Sha256::digest(file.text.as_bytes()));
        let mut transaction = pool.begin().await?;

        if let Some((episode_id, occurred_at)) = existing_episode(&mut transaction, &sha256).await?
        {
            transaction.commit().await?;
            outcomes.push(IngestOutcome {
                name: file.name,
                status: "duplicate",
                episode_id,
                occurred_at,
            });
            continue;
        }

        let uri = write_vault_file(vault_dir, &sha256, &file.name, &file.text).await?;
        let source_id = sqlx::query_scalar::<_, Uuid>(
            "INSERT INTO sources (kind, uri, sha256, bytes) VALUES ('md', $1, $2, $3) ON CONFLICT (sha256) DO NOTHING RETURNING id",
        )
        .bind(uri)
        .bind(&sha256)
        .bind(file.text.len() as i64)
        .fetch_optional(&mut *transaction)
        .await?;

        let Some(source_id) = source_id else {
            let raced_episode = existing_episode(&mut transaction, &sha256).await?;
            let Some((episode_id, occurred_at)) = raced_episode else {
                return Err(format!("Source {sha256} exists without an episode").into());
            };
            transaction.commit().await?;
            outcomes.push(IngestOutcome {
                name: file.name,
                status: "duplicate",
                episode_id,
                occurred_at,
            });
            continue;
        };

        let front_matter = parse_front_matter(&file.text);
        let occurred_at = front_matter
            .date
            .or_else(|| file.mtime.as_deref().and_then(parse_file_date))
            .unwrap_or_else(Utc::now);
        let title = front_matter.title.unwrap_or_else(|| file_title(&file.name));
        let (episode_id, occurred_at) = sqlx::query_as::<_, (Uuid, DateTime<Utc>)>(
            "INSERT INTO episodes (source_id, occurred_at, kind, title, body_original, langs) VALUES ($1, $2, 'md', $3, $4, ARRAY['en']::text[]) RETURNING id, occurred_at",
        )
        .bind(source_id)
        .bind(occurred_at)
        .bind(title)
        .bind(&file.text)
        .fetch_one(&mut *transaction)
        .await?;

        transaction.commit().await?;
        outcomes.push(IngestOutcome {
            name: file.name,
            status: "ingested",
            episode_id,
            occurred_at,
        });
    }

    Ok(outcomes)
}
