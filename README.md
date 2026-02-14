# PHILSTUBS

**P**eople **H**ardly **I**nspect **L**egislation — **S**earchable **T**emplates **U**sed **B**efore anyone read**S**

A web application for ingesting, browsing, and sharing legislation across all levels of US democracy — federal, state, county, and municipal.

Because if template legislation is going to be copy-pasted into law anyway, the least we can do is make it searchable.

## What is PHILSTUBS?

PHILSTUBS is an open platform that:

- **Ingests legislation** from federal, state, county, and municipal sources
- **Displays legislation** in a readable, searchable format across government levels
- **Allows template uploads** — users can submit model/template legislation for others to find
- **Enables search & download** — find legislation templates by topic, jurisdiction, or keyword

## Tech Stack

- **[Gleam](https://gleam.run)** — type-safe functional language targeting the BEAM
- **[Lustre](https://hexdocs.pm/lustre/)** — Gleam's frontend framework for building SPAs
- **BEAM/OTP** — runtime platform for reliability and concurrency

## Government Levels

PHILSTUBS organizes legislation across the US democratic hierarchy:

| Level | Examples |
|-------|----------|
| **Federal** | Congressional bills, resolutions, federal regulations |
| **State** | State legislature bills, state constitutional amendments |
| **County** | County ordinances, resolutions |
| **Municipal** | City ordinances, local bylaws, town resolutions |

## Quick Start

### Prerequisites

- [Gleam](https://gleam.run/getting-started/installing/) (v1.0+)
- [Erlang/OTP](https://www.erlang.org/downloads) (v26+)

### Setup

```sh
# Clone the repo
git clone https://github.com/justin4957/philstubs.git
cd philstubs

# Install dependencies
gleam deps download

# Run tests to verify everything works
gleam test

# Start the dev server
gleam run
```

The server starts at **http://localhost:8000**. Visit it in your browser to see the landing page.

### Try it out

```sh
# Health check
curl http://localhost:8000/health

# Browse the landing page
open http://localhost:8000

# Search legislation
curl "http://localhost:8000/api/search?q=environment"

# List legislation via REST API
curl http://localhost:8000/api/legislation

# Browse templates
curl http://localhost:8000/api/templates
```

### Optional: Data Ingestion

PHILSTUBS can ingest live legislation from external sources. Set the relevant API keys to enable ingestion:

| Source | Env Var | Level |
|--------|---------|-------|
| [Congress.gov](https://api.congress.gov/) | `CONGRESS_API_KEY` | Federal |
| [Open States](https://v3.openstates.org/) | `PLURAL_POLICY_KEY` | State |
| [Legistar](https://webapi.legistar.com/) | None (public) | County/Municipal |

### Optional: GitHub OAuth

To enable user authentication and template ownership, set:

```sh
export GITHUB_CLIENT_ID=your_client_id
export GITHUB_CLIENT_SECRET=your_client_secret
```

## Contributing

Contributions are welcome! Check the [issues](../../issues) for current work items.

## License

MIT
