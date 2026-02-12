/// Application context carried through the request handling pipeline.
/// Holds resources and configuration that handlers need access to.
pub type Context {
  Context(static_directory: String)
}
