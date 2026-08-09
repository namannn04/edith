use std::collections::HashSet;

use sqlx::PgPool;

const MIGRATIONS: &[(&str, &str)] = &[
    (
        "0001_foundation",
        include_str!("../migrations/0001_foundation.sql"),
    ),
    ("0002_chunks", include_str!("../migrations/0002_chunks.sql")),
    (
        "0003_observation_dedupe",
        include_str!("../migrations/0003_observation_dedupe.sql"),
    ),
    (
        "0004_beliefs",
        include_str!("../migrations/0004_beliefs.sql"),
    ),
];

pub async fn run_migrations(pool: &PgPool) -> Result<(), sqlx::Error> {
    sqlx::query(
        "CREATE TABLE IF NOT EXISTS schema_migrations (version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())",
    )
    .execute(pool)
    .await?;

    let applied = sqlx::query_scalar::<_, String>("SELECT version FROM schema_migrations")
        .fetch_all(pool)
        .await?
        .into_iter()
        .collect::<HashSet<_>>();

    for &(version, migration_sql) in MIGRATIONS {
        if applied.contains(version) {
            continue;
        }

        let mut transaction = pool.begin().await?;
        sqlx::raw_sql(migration_sql)
            .execute(&mut *transaction)
            .await?;
        sqlx::query("INSERT INTO schema_migrations (version) VALUES ($1)")
            .bind(version)
            .execute(&mut *transaction)
            .await?;
        transaction.commit().await?;
    }

    Ok(())
}

pub const fn migration_count() -> usize {
    MIGRATIONS.len()
}
