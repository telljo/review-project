# Bookshelf

Bookshelf is a Rails app for tracking books and writing reviews, with Hotwire for
the UI and PostgreSQL/Redis backing the app locally and in production.

## Requirements

- Ruby 4.0.3
- Bundler 4.0.6
- Node.js 24.13.0
- Yarn 1.22.19
- PostgreSQL
- Redis

## Local setup

1. Copy `.env.example` to `.env` and fill in `GOOGLE_BOOKS_API_KEY`.
2. Make sure PostgreSQL and Redis are running locally.
3. Run `bin/setup`.
4. Start the app with `bin/dev`.

`bin/dev` will choose an available app port automatically and start Rails, the JS
watcher, the CSS watcher, and Redis when needed.

## Common commands

- `bin/setup` installs gems and JS packages, then prepares the database.
- `bin/dev` starts the local development stack.
- `bundle exec rails test` runs the test suite.
- `bundle exec rubocop` runs the Ruby linter.

## Production configuration

Set these environment variables in production:

- `DATABASE_URL`
- `RAILS_MASTER_KEY`
- `REDIS_URL`

This app uses `local` Active Storage in production because it does not rely on
persistent uploaded attachments.

If you later decide to support uploaded attachments in production, you will need
to change the production Active Storage config and then set:

- `ACTIVE_STORAGE_SERVICE`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `AWS_BUCKET`

When using S3-compatible storage such as Tigris, you can also set:

- `AWS_ENDPOINT`
- `AWS_FORCE_PATH_STYLE=true`

## Deployment

Pushes to `main` now build in GitHub Actions and automatically deploy to Fly.io
after the build job succeeds.

To enable this, add a repository secret named `FLY_API_TOKEN` in GitHub with a deploy token for the Fly app.

## Notes

- Review broadcasts depend on Redis in production.
- Rich text file/image attachments are disabled.
- Local Redis snapshots such as `dump.rdb` are intentionally ignored.
