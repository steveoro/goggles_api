# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Goggles API v3: a Rails 8.1 / Ruby 3.4 app that is essentially a thin [Grape](https://github.com/ruby-grape/grape) JSON API layer over the `goggles_db` engine gem (models, grants, JWT, factories, DB structure live there, not here). Database is MariaDB/MySQL.

## Commands

```bash
RAILS_ENV=test bundle exec rspec                      # full suite
RAILS_ENV=test bundle exec rspec spec/api/goggles/badges_api_spec.rb       # one file
RAILS_ENV=test bundle exec rspec spec/api/goggles/badges_api_spec.rb:42    # one example
bundle exec rubocop                                   # lint (also haml-lint, brakeman -q)
bundle exec guard                                     # watcher used for local dev/testing
./update_engine.sh                                    # bump goggles_db (sets GIT_LFS_SKIP_SMUDGE=1)
./synch.sh                                            # git pull + bundle install (skips LFS dump)
```

- Always set `GIT_LFS_SKIP_SMUDGE=1` when running `bundle install/update`, otherwise the engine's embedded test dump is downloaded.
- Tests need a populated `test` DB. Build it from the `goggles_db` repo (`RAILS_ENV=test rails app:db:rebuild`) or load a `db/dump/test.sql.bz2`; see README "Database setup".
- Swagger UI at `/api/docs` is mounted only in `development`.
- Version lives in `lib/version.rb` (`PATCH` etc.); engine version bumps are usually followed by a version bump + CHANGELOG entry.

## Architecture

- `config/routes.rb` mounts `Goggles::API` at `/`; all endpoints are under `/api/v3/...` (path versioning, JSON only).
- `app/api/goggles/api.rb` is the master Grape class: audit logging (`log/api_audit.log`), Prosopite N+1 scanning in local envs, the `/status` endpoint, **an explicit list of `mount XxxAPI` lines**, and the `add_swagger_documentation` call with an explicit `models:` list of entities. **A new endpoint class or entity must be registered in both places.**
- One file per resource: `app/api/goggles/<resource>_api.rb` (`Goggles::XxxAPI < Grape::API`), with matching serializers in `app/api/goggles/entities/*_entity.rb` (Grape::Entity, extending `base_entity.rb`). Responses are documented via `desc ... success Entity`, so keep Swagger annotations up to date.
- Shared behavior is in `Goggles::APIHelpers` (`app/api/goggles/api_helpers.rb`): `check_jwt_session` (must be called first in every authenticated endpoint; also rejects non-admins during maintenance mode and updates daily-use stats), `reject_unless_authorized_for_crud[_or_has_id]`, `reject_unless_authorized_admin`, `reject_unless_found`, plus filter helpers (`filtering_hash_for`, `filtering_like_for`) and the `:pagination` / `:period` param sets.
- Auth: `app/commands/cmd_authenticate_user.rb` (login → JWT, used by `SessionAPI`) and `cmd_authorize_api_request.rb` (decodes the `Authorization: Bearer` header via `GogglesDb::JWTManager` with `Rails.application.credentials.api_static_key`). Authorization of writes goes through `GogglesDb::GrantChecker`.
- Naming convention for routes: `find` = single result, `list` = filtered collection, `search` = special/fuzzy backend strategy, `lookup` = read-only lookup tables. Detail endpoints (`GET /<entity>/:id`) accept an optional `locale` param (default `it`, also `en`).
- Errors are returned as 401 with an `X-Error-Detail` header (I18n strings under `api.message.*`), including for invalid params and missing grants.

## Testing

- Request specs in `spec/api/goggles/<resource>_api_spec.rb`; shared examples for auth/maintenance failures are in `spec/support/shared_api_response_behaviors.rb` and session/JWT helpers in `spec/support/api_session_helpers.rb`.
- Test data comes from FactoryBot factories shipped in the `goggles_db` engine, run against the real (anonymized) structure dump rather than an empty schema.
- In test/dev, `Prosopite.raise = true` is set but `Prosopite.enabled` may be toggled off in `config/environments/*.rb` when it complains too much.
