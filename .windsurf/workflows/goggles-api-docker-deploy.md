---
description: Local Docker dev setup and production deployment for goggles_api and goggles_main — compose files, Dockerfiles, volumes, env vars
auto_execution_mode: 2
---

# Docker Deployment

Use this skill for setting up, debugging, or modifying the Docker-based deployment of `goggles_api` and `goggles_main`.

## Architecture

`goggles_api` and `goggles_main` run as Docker containers on the public server, sharing a MariaDB container on the same Docker network. Three environments are supported: **dev**, **staging**, **prod**.

## File Layout (goggles_api)

Path: `/home/steve/Projects/goggles_api/`

| File | Purpose |
| --- | --- |
| `Dockerfile.dev` | Dev image (full toolchain, debug gems) |
| `Dockerfile.staging` | Staging image |
| `Dockerfile.prod` | Production image (Alpine-based, minimal) |
| `docker-compose.dev.yml` | Dev compose: API + MariaDB |
| `docker-compose.staging.yml` | Staging compose |
| `docker-compose.prod.yml` | Production compose: API + MariaDB on `prod` network |
| `entrypoints/` | Docker entrypoint scripts |
| `.env` | Environment variables (not committed) |

## File Layout (goggles_main)

Path: `/home/steve/Projects/goggles_main/`

Same structure: `Dockerfile.dev`, `Dockerfile.staging`, `Dockerfile.prod`, plus matching `docker-compose.*.yml` files.

## Production Compose Structure (`docker-compose.prod.yml`)

```yaml
services:
  goggles-db:
    image: mariadb:latest
    command: --max_allowed_packet=67108864
    container_name: goggles-db
    env_file: .env
    ports: ['33060:3306']
    volumes:
      - "~/Projects/goggles_deploy/db.prod:/var/lib/mysql"

  api:
    build:
      context: .
      dockerfile: Dockerfile.prod
    image: "steveoro/goggles-api:prod-${TAG}"
    depends_on: [goggles-db]
    container_name: goggles-api
    env_file: .env
    ports: ['8081:8081']
    volumes:
      - "~/Projects/goggles_deploy/storage.prod:/app/storage"
      - "~/Projects/goggles_deploy/db.prod:/var/lib/mysql"
      - "~/Projects/goggles_deploy/backups:/app/db/dump"
      - "~/Projects/goggles_deploy/log.prod/api:/app/log"
      - "~/Projects/goggles_deploy/master-api.key:/app/config/master.key"

networks:
  default:
    name: prod
```

Key points:

- **Shared DB volume**: `~/Projects/goggles_deploy/db.prod` mounted in both DB and API containers
- **Separate log volumes**: per-service log directories
- **Master key**: mounted from deploy directory (not committed)
- **Network**: all prod services share the `prod` Docker network
- `max_allowed_packet=67108864` prevents "MySQL server has gone away" for large queries

## Dockerfile Pattern (Production)

The production Dockerfile uses a multi-stage Alpine build:

1. **`common_builder` stage**: Ruby 3.1.4 Alpine + system deps (build tools, MariaDB client, Node.js, Yarn)
2. **App stage**: Sets `RAILS_ENV=production`, installs gems, copies app code, precompiles assets, runs Puma

Environment variables set in the Dockerfile:

- `RAILS_ENV`, `DATABASE_NAME`, `DATABASE_HOST`, `DATABASE_PORT`
- `DATABASE_USER`, `DATABASE_PASSWORD` (from `.env` at runtime)

## Environment Variables (`.env`)

Required variables (set in `.env`, not committed):

- `DATABASE_NAME` — DB name (e.g. `goggles` for prod)
- `DATABASE_USER` — MariaDB user
- `DATABASE_PASSWORD` — MariaDB password (also `MYSQL_ROOT_PASSWORD` for the DB container)
- `TAG` — Image tag for versioning (e.g. `latest`, `v0.8.22`)
- `SECRET_KEY_BASE` — Rails secret key
- `RAILS_MASTER_KEY` — Rails master key (or mount the key file)

## Common Operations

### Build and Start (Production)

```bash
cd /home/steve/Projects/goggles_api
docker compose -f docker-compose.prod.yml build
docker compose -f docker-compose.prod.yml up -d
```

### View Logs

```bash
docker compose -f docker-compose.prod.yml logs -f api
docker compose -f docker-compose.prod.yml logs -f goggles-db
```

### Run Migrations in Container

```bash
docker compose -f docker-compose.prod.yml exec api rails db:migrate
```

### Rebuild After Engine Update

```bash
docker compose -f docker-compose.prod.yml build --no-cache api
docker compose -f docker-compose.prod.yml up -d api
```

### Local Dev Setup

```bash
cd /home/steve/Projects/goggles_api
docker compose -f docker-compose.dev.yml up -d
```

## Deploy Volume Layout

All persistent data on the server lives under `~/Projects/goggles_deploy/`:

```text
goggles_deploy/
├── db.prod/          # MariaDB data directory
├── storage.prod/     # ActiveStorage files
├── backups/          # DB dump files
├── log.prod/
│   ├── api/          # goggles_api logs
│   └── main/         # goggles_main logs
├── master-api.key    # Rails master key for API
└── master-main.key   # Rails master key for Main
```

## CI Integration

CircleCI builds and tests automatically on push. On success for tagged releases, the pipeline can trigger image builds and deployment (project-specific CI config in `.circleci/config.yml`).

## goggles_admin2 (Localhost Only)

`goggles_admin2` uses `docker-compose.yml` for local MariaDB only:

```bash
cd /home/steve/Projects/goggles_admin2
docker compose up -d  # Starts local MariaDB
```

It does not have production Docker images or deployment pipelines.
