/// Levels of government in the US democratic hierarchy.
/// Legislation is organized by the level at which it was enacted.
pub type GovernmentLevel {
  Federal
  State
  County
  Municipal
}

/// Convert a GovernmentLevel to its display string.
pub fn government_level_to_string(level: GovernmentLevel) -> String {
  case level {
    Federal -> "Federal"
    State -> "State"
    County -> "County"
    Municipal -> "Municipal"
  }
}
