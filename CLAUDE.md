# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

### Development
- `mix setup` - Install and setup dependencies (runs deps.get, ecto.setup, assets.setup, assets.build)
- `mix phx.server` - Start Phoenix server at localhost:4000
- `iex -S mix phx.server` - Start server with interactive shell

### Database
- `mix ecto.create` - Create database
- `mix ecto.migrate` - Run migrations
- `mix ecto.reset` - Drop and recreate database with seeds
- `mix run priv/repo/seeds.exs` - Run seeds

### Assets
- `mix assets.build` - Build assets (compile, tailwind, esbuild)
- `mix assets.deploy` - Build minified assets for production

### Testing and Quality
- `mix test` - Run tests (automatically creates/migrates test DB)
- `mix test test/path/to/file.exs` - Run specific test file
- `mix test --failed` - Run previously failed tests
- `mix precommit` - Run full quality check (compile with warnings as errors, clean unused deps, format, test)

### Code Quality
- `mix format` - Format code
- `mix compile --warning-as-errors` - Strict compilation

## Architecture

### Phoenix Framework Structure
This is a Phoenix 1.8 web application using:
- **Database**: SQLite via Ecto with ecto_sqlite3
- **Frontend**: Phoenix LiveView with Tailwind CSS v4 and esbuild
- **AI Providers**: Dual support for OpenAI and Anthropic APIs (compile-time selection)
- **HTTP Client**: Req library (avoid httpoison, tesla, httpc)
- **Web Server**: Bandit adapter
- **Email**: Swoosh with local adapter (dev mailbox at /dev/mailbox)

### Key Modules
- `StudyBot.Application` - OTP application supervision tree
- `StudyBot` - Main domain context module
- `StudyBotWeb` - Web interface entrypoint with shared imports/aliases
- `StudyBotWeb.Router` - Routes with browser and API pipelines
- `StudyBotWeb.Endpoint` - Phoenix endpoint configuration

### Directory Structure
- `lib/study_bot/` - Core business logic and contexts
- `lib/study_bot_web/` - Web interface (controllers, views, templates, components)
- `config/` - Environment-specific configuration
- `priv/repo/` - Database migrations and seeds
- `assets/` - Frontend assets (JS, CSS)
- `test/` - Test files

## Project Guidelines

### Code Quality
- Always use `mix precommit` before committing changes - this runs compile --warning-as-errors, deps.unlock --unused, format, and test
- Use the `:req` library for HTTP requests (already included)

### AI Provider Configuration
- AI provider is selected at compile time via `:ai_provider` config in `config/config.exs`
- Default is `:openai`, can be changed to `:anthropic` 
- OpenAI API key always required (used for embeddings)
- Anthropic API key required only when using `:anthropic` provider
- Use `StudyBot.AI.Client` module for all AI operations (abstracts provider differences)

### Phoenix/LiveView Patterns
- LiveView templates must begin with `<Layouts.app flash={@flash} ...>`
- Use `<.icon name="hero-x-mark" class="w-5 h-5"/>` for heroicons
- Use imported `<.input>` component from core_components.ex for form inputs
- Use `<.link navigate={href}>` and `<.link patch={href}>` instead of deprecated live_redirect/live_patch
- Always use LiveView streams for collections with `phx-update="stream"`

### Asset Management  
- Tailwind CSS v4 with new import syntax in app.css
- No tailwind.config.js needed
- Import vendor dependencies into app.js/app.css rather than external links
- Never write inline `<script>` tags in templates

### Development Environment
- Development server runs on port 4000 (configurable via PORT env var)
- Live reload watches lib/study_bot_web/ files and assets
- SQLite database stored as study_bot_dev.db
- Development routes enabled at /dev/dashboard and /dev/mailbox
- PDF processing requires `pdftotext` command (install with `brew install poppler` on macOS)