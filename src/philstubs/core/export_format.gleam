/// Supported data export formats.
pub type ExportFormat {
  Json
  Csv
}

/// Parse an export format from a string value.
/// Returns Json for any unrecognized value.
pub fn from_string(format_str: String) -> ExportFormat {
  case format_str {
    "csv" -> Csv
    _ -> Json
  }
}

/// Get the HTTP Content-Type header value for a format.
pub fn content_type(format: ExportFormat) -> String {
  case format {
    Json -> "application/json; charset=utf-8"
    Csv -> "text/csv; charset=utf-8"
  }
}

/// Get the file extension for a format (including the dot).
pub fn file_extension(format: ExportFormat) -> String {
  case format {
    Json -> ".json"
    Csv -> ".csv"
  }
}

/// Convert an ExportFormat to its string representation.
pub fn to_string(format: ExportFormat) -> String {
  case format {
    Json -> "json"
    Csv -> "csv"
  }
}
