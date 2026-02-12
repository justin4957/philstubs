# PHILSTUBS Project Instructions

## Overview
PHILSTUBS (People Hardly Inspect Legislation — Searchable Templates Used Before anyone readS) is a Gleam web application for ingesting, browsing, and sharing legislation across all levels of US democracy.

## Tech Stack
- **Gleam** (target: erlang) — Core language
- **Lustre** — HTML rendering (server-side for now, SPA later)
- **Wisp** — Web framework (routing, middleware, request handling)
- **Mist** — HTTP server
- **sqlight** — SQLite database access

## Development Commands
```sh
gleam deps download   # Install dependencies
gleam build           # Compile the project
gleam test            # Run tests
gleam run             # Start the dev server on port 8000
gleam format          # Format code
```

## Project Structure
- `src/philstubs.gleam` — Application entry point (starts HTTP server)
- `src/philstubs/web/` — HTTP layer (router, middleware, context)
- `src/philstubs/ui/` — Lustre view components and page layouts
- `src/philstubs/core/` — Domain types and business logic (pure functions)
- `src/philstubs/data/` — Database access and queries
- `src/philstubs/ingestion/` — Legislation data ingestion
- `test/` — Test files
- `priv/static/` — Static assets (CSS, JS, images)
- `priv/migrations/` — Database migration files

## Architecture Principles
- **Domain-organized modules**: Group by what they represent, not by layer
- **Types first**: Model domain concepts before writing logic
- **Pure core, impure shell**: Keep business logic pure; isolate IO at boundaries
- **Exhaustive pattern matching**: Let the compiler enforce completeness
- **Result over exceptions**: Handle errors explicitly with Result types

## Endpoints
- `GET /` — Landing page
- `GET /health` — Health check (200 OK)
- `GET /static/*` — Static assets

## Database
SQLite via sqlight. Development database: `philstubs_dev.sqlite`
Database files (*.sqlite, *.db) are gitignored.
