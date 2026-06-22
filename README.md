# intercode-import

A Ruby toolkit for exporting legacy convention management system data into the [Intercode](https://github.com/neinteractiveliterature/intercode) convention import format.

Four source systems are supported: **Intercode 1** (PHP/MySQL), **ProCon** (MySQL), **Illyan** (the user authentication database used alongside ProCon), and **Eventlite** (Rails/PostgreSQL).

## Output format

Each export produces one or more JSON files conforming to `convention-export.schema.json`. A single file represents one convention and contains:

- Convention metadata (name, domain, timezone, ticket mode, schedule settings)
- Users and per-convention profiles
- Events, event proposals, runs, and signups
- Team members and staff positions
- Tickets, store items, and store orders
- CMS pages, partials, navigation items, and files

The JSON can then be imported into Intercode via its convention import tooling.

## Setup

```sh
bundle install
```

Ruby version is specified in `.ruby-version`. You will also need a working MySQL client library for the `mysql2` gem, and PHP in your `PATH` for Intercode 1 exports (it parses the legacy PHP constants file).

## Usage

All exports are Rake tasks. Set the required environment variables and run:

### Intercode 1

Exports a single Intercode 1 MySQL database to `convention-export.json`.

```sh
CONSTANTS_FILE=/path/to/constants.php \
  bundle exec rake export:intercode1
```

| Variable | Required | Description |
|---|---|---|
| `CONSTANTS_FILE` | Yes | Path to the Intercode 1 `constants.php` file. Database credentials and convention settings are read from this file. |
| `CON_DOMAIN` | No | Override the convention domain (defaults to a `.intercode.test` domain derived from `CON_NAME`). |
| `OUTPUT_FILE` | No | Output path (default: `convention-export.json`). Pass `-` to print to stdout. |

The exporter reads database credentials directly from the PHP constants file by executing a small PHP snippet. Legacy MD5 password hashes are re-hashed with BCrypt during export so users can log in without a password reset (this step runs in parallel and can take a few minutes for large databases).

### ProCon

Exports one JSON file per convention whose domain matches `CONVENTION_DOMAIN_REGEX`.

```sh
PROCON_DB_URL=mysql2://user:pass@host/procon_db \
ILLYAN_DB_URL=mysql2://user:pass@host/illyan_db \
CONVENTION_DOMAIN_REGEX='\.arisia\.org$' \
ORGANIZATION_NAME='Arisia' \
  bundle exec rake export:procon
```

| Variable | Required | Description |
|---|---|---|
| `PROCON_DB_URL` | Yes | Sequel-compatible connection URL for the ProCon database. |
| `ILLYAN_DB_URL` | Yes | Sequel-compatible connection URL for the Illyan database. |
| `CONVENTION_DOMAIN_REGEX` | Yes | Ruby regex matched against convention domains to select which conventions to export. |
| `ORGANIZATION_NAME` | Yes | Organization name written into each export file. |
| `OUTPUT_FILE` | No | Output path. Only used when exactly one convention matches; otherwise files are named `convention-export-<domain>.json`. Pass `-` to print to stdout. |

### Eventlite

Exports one JSON file per event from an Eventlite PostgreSQL database. Each event becomes a separate single-event Intercode convention.

```sh
EVENTLITE_DB_URL=postgres://user:pass@host/eventlite_db \
DOMAIN_SUFFIX=example.com \
TIMEZONE=America/New_York \
  bundle exec rake export:eventlite
```

| Variable | Required | Description |
|---|---|---|
| `EVENTLITE_DB_URL` | Yes | Sequel-compatible connection URL for the Eventlite PostgreSQL database. |
| `DOMAIN_SUFFIX` | No | Domain suffix appended to each event's slug to form the convention domain (default: `example.com`). |
| `TIMEZONE` | No | IANA timezone name applied to all conventions (default: `UTC`). |
| `FILE_BASE_URL` | No | Base URL for CMS file attachments stored in S3 (e.g. `https://my-bucket.s3.amazonaws.com/`). |
| `OUTPUT_FILE` | No | Output path. Only used when exactly one event is found; otherwise files are named `convention-export-<domain>.json`. Pass `-` to print to stdout. |

Each Eventlite event is exported as a `single_event` Intercode convention using the `ticket_per_event` ticket mode. Ticket types become Intercode ticket types and store items; users who purchased multiple ticket types get one ticket (the type with the most available slots wins) and additional store order entries for the rest. Pages containing Eventlite-specific Liquid tags (e.g. `{% ticket_form %}`) are omitted, as is any navigation pointing to those pages.

### Illyan (standalone user export)

Exports a set of users from the Illyan database by email address. Useful for migrating user accounts without a full convention export.

```sh
ILLYAN_DB_URL=mysql2://user:pass@host/illyan_db \
EMAILS='alice@example.com bob@example.com' \
  bundle exec rake export:illyan
```

| Variable | Required | Description |
|---|---|---|
| `ILLYAN_DB_URL` | Yes | Sequel-compatible connection URL for the Illyan database. |
| `EMAILS` | Yes | Whitespace-separated list of email addresses to export. |
| `OUTPUT_FILE` | No | Output path (default: `illyan-users.json`). Pass `-` to print to stdout. |

## Background

This repository was extracted from Intercode's legacy importer scripts to provide a standalone, reproducible way to migrate old convention data. The `convention-export.schema.json` schema is the shared contract between these exporters and Intercode's import pipeline.
