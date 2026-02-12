import gleam/option.{type Option}
import philstubs/core/government_level.{type GovernmentLevel}
import philstubs/ingestion/congress_types.{type ApiError}
import sqlight

/// Configuration for a single jurisdiction's ingestion source.
/// Used by adapters to describe the jurisdiction and authentication
/// for a given ingestion run.
pub type JurisdictionConfig {
  JurisdictionConfig(
    source_name: String,
    client_id: String,
    government_level: GovernmentLevel,
    api_token: Option(String),
  )
}

/// Result of a single jurisdiction ingestion run.
/// Reports how many bills were fetched from the API and stored in the database.
pub type AdapterResult {
  AdapterResult(
    source_name: String,
    client_id: String,
    bills_fetched: Int,
    bills_stored: Int,
  )
}

/// Errors that can occur during adapter ingestion.
pub type AdapterError {
  AdapterApiError(ApiError)
  AdapterDatabaseError(sqlight.Error)
}
