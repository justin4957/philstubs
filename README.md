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

## Getting Started

```sh
# Install dependencies
gleam deps download

# Run the development server
gleam run

# Run tests
gleam test
```

## Contributing

Contributions are welcome! Check the [issues](../../issues) for current work items.

## License

MIT
