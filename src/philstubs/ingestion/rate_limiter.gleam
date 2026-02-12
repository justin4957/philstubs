import gleam/erlang/process

/// Default interval for Congress.gov (5000 req/hour = 720ms min gap, 750ms for safety).
const default_interval_ms = 750

/// State for the delay-based rate limiter.
pub type RateLimiterState {
  RateLimiterState(last_request_time_ms: Int, interval_ms: Int)
}

/// Create a new rate limiter state with the default 750ms interval (Congress.gov).
pub fn new() -> RateLimiterState {
  new_with_interval(default_interval_ms)
}

/// Create a new rate limiter state with a custom interval between requests.
pub fn new_with_interval(interval_ms: Int) -> RateLimiterState {
  RateLimiterState(last_request_time_ms: 0, interval_ms: interval_ms)
}

/// Wait until enough time has elapsed since the last request, then
/// return an updated state recording the current time.
pub fn wait_for_capacity(state: RateLimiterState) -> RateLimiterState {
  let current_time_ms = erlang_system_time_ms()
  let elapsed = current_time_ms - state.last_request_time_ms

  case elapsed < state.interval_ms {
    True -> {
      let wait_time = state.interval_ms - elapsed
      process.sleep(wait_time)
      RateLimiterState(
        last_request_time_ms: current_time_ms + wait_time,
        interval_ms: state.interval_ms,
      )
    }
    False -> {
      RateLimiterState(
        last_request_time_ms: current_time_ms,
        interval_ms: state.interval_ms,
      )
    }
  }
}

@external(erlang, "philstubs_erlang_ffi", "system_time_ms")
fn erlang_system_time_ms() -> Int
