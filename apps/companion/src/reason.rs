use std::env;
use std::error::Error;
use std::fmt::{Display, Formatter};

use reqwest::Client;
use serde_json::{Value, json};

#[derive(Debug)]
pub struct ReasonError(String);

impl Display for ReasonError {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> std::fmt::Result {
        formatter.write_str(&self.0)
    }
}

impl Error for ReasonError {}

impl ReasonError {
    pub fn unconfigured() -> Self {
        Self(
            "no reasoning provider: set ANTHROPIC_API_KEY, or REASON_PROVIDER=openai with REASON_URL"
                .to_owned(),
        )
    }

    pub fn is_unconfigured(&self) -> bool {
        self.0.starts_with("no reasoning provider")
    }
}

#[derive(Clone)]
enum Provider {
    Anthropic { key: String },
    OpenAiCompatible { base_url: String },
    Unconfigured,
}

#[derive(Clone)]
pub struct ReasonClient {
    client: Client,
    provider: Provider,
    model: String,
}

impl ReasonClient {
    pub fn from_env() -> Self {
        let provider_name = env::var("REASON_PROVIDER").unwrap_or_default();
        let key = env::var("ANTHROPIC_API_KEY")
            .ok()
            .filter(|key| !key.is_empty());
        let provider = match provider_name.as_str() {
            "openai" => match env::var("REASON_URL").ok().filter(|url| !url.is_empty()) {
                Some(base_url) => Provider::OpenAiCompatible {
                    base_url: base_url.trim_end_matches('/').to_owned(),
                },
                None => Provider::Unconfigured,
            },
            _ => match key {
                Some(key) => Provider::Anthropic { key },
                None => Provider::Unconfigured,
            },
        };
        let model = env::var("REASON_MODEL").unwrap_or_else(|_| match provider {
            Provider::Anthropic { .. } => "claude-sonnet-5".to_owned(),
            _ => "qwen3:1.7b".to_owned(),
        });
        Self {
            client: Client::new(),
            provider,
            model,
        }
    }

    pub fn configured(&self) -> bool {
        !matches!(self.provider, Provider::Unconfigured)
    }

    pub fn describe(&self) -> String {
        match &self.provider {
            Provider::Anthropic { .. } => format!("anthropic, model {}", self.model),
            Provider::OpenAiCompatible { base_url } => {
                format!("openai-compatible at {base_url}, model {}", self.model)
            }
            Provider::Unconfigured => "not configured".to_owned(),
        }
    }

    pub async fn complete(&self, system: &str, user: &str) -> Result<String, ReasonError> {
        match &self.provider {
            Provider::Anthropic { key } => self.anthropic(key, system, user).await,
            Provider::OpenAiCompatible { base_url } => {
                self.openai(base_url, system, user).await
            }
            Provider::Unconfigured => Err(ReasonError(
                "no reasoning provider: set ANTHROPIC_API_KEY, or REASON_PROVIDER=openai with REASON_URL".to_owned(),
            )),
        }
    }

    async fn anthropic(&self, key: &str, system: &str, user: &str) -> Result<String, ReasonError> {
        let body = json!({
            "model": self.model,
            "max_tokens": 2048,
            "system": system,
            "messages": [{"role": "user", "content": user}],
        });
        let response = self
            .client
            .post("https://api.anthropic.com/v1/messages")
            .header("x-api-key", key)
            .header("anthropic-version", "2023-06-01")
            .json(&body)
            .send()
            .await
            .map_err(|error| ReasonError(format!("Reasoning request failed: {error}")))?;
        let status = response.status();
        let body = response
            .text()
            .await
            .map_err(|error| ReasonError(format!("Reasoning response unreadable: {error}")))?;
        if !status.is_success() {
            return Err(ReasonError(format!("Reasoning returned {status}: {body}")));
        }
        let value = serde_json::from_str::<Value>(&body)
            .map_err(|error| ReasonError(format!("Invalid reasoning response: {error}")))?;
        value
            .pointer("/content/0/text")
            .and_then(Value::as_str)
            .map(str::to_owned)
            .ok_or_else(|| ReasonError("Reasoning response had no text".to_owned()))
    }

    async fn openai(
        &self,
        base_url: &str,
        system: &str,
        user: &str,
    ) -> Result<String, ReasonError> {
        let body = json!({
            "model": self.model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
        });
        let response = self
            .client
            .post(format!("{base_url}/chat/completions"))
            .json(&body)
            .send()
            .await
            .map_err(|error| ReasonError(format!("Reasoning request failed: {error}")))?;
        let status = response.status();
        let body = response
            .text()
            .await
            .map_err(|error| ReasonError(format!("Reasoning response unreadable: {error}")))?;
        if !status.is_success() {
            return Err(ReasonError(format!("Reasoning returned {status}: {body}")));
        }
        let value = serde_json::from_str::<Value>(&body)
            .map_err(|error| ReasonError(format!("Invalid reasoning response: {error}")))?;
        value
            .pointer("/choices/0/message/content")
            .and_then(Value::as_str)
            .map(str::to_owned)
            .ok_or_else(|| ReasonError("Reasoning response had no text".to_owned()))
    }
}

pub fn extract_json_array(text: &str) -> Option<Value> {
    let start = text.find('[')?;
    let end = text.rfind(']')?;
    if end <= start {
        return None;
    }
    serde_json::from_str::<Value>(&text[start..=end])
        .ok()
        .filter(Value::is_array)
}

#[cfg(test)]
mod tests {
    use super::extract_json_array;

    #[test]
    fn finds_array_inside_prose() {
        let text = "Here you go:\n[{\"statement\": \"x\"}]\nDone.";
        let value = extract_json_array(text).unwrap();
        assert_eq!(value[0]["statement"], "x");
    }

    #[test]
    fn rejects_missing_array() {
        assert!(extract_json_array("no json here").is_none());
        assert!(extract_json_array("] backwards [").is_none());
    }
}
