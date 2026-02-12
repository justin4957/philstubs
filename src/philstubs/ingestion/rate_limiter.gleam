import gleam/erlang/process

/// Minimum milliseconds between API requests.
/// Congress.gov allows 5000 req/hour = 720ms min gap. Use 750ms for safety.
const minimum_interval_ms = 750

/// State for the delay-based rate limiter.
pub type RateLimiterState {
  RateLimiterState(last_request_time_ms: Int)
}

/// Create a new rate limiter state with no prior request.
pub fn new() -> RateLimiterState {
  RateLimiterState(last_request_time_ms: 0)
}

/// Wait until enough time has elapsed since the last request, then
/// return an updated state recording the current time.
pub fn wait_for_capacity(state: RateLimiterState) -> RateLimiterState {
  let current_time_ms = erlang_system_time_ms()
  let elapsed = current_time_ms - state.last_request_time_ms

  case elapsed < minimum_interval_ms {
    True -> {
      let wait_time = minimum_interval_ms - elapsed
      process.sleep(wait_time)
      RateLimiterState(last_request_time_ms: current_time_ms + wait_time)
    }
    False -> {
      RateLimiterState(last_request_time_ms: current_time_ms)
    }
  }
}

@external(erlang, "philstubs_erlang_ffi", "system_time_ms")
fn erlang_system_time_ms() -> Int
