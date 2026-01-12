# Repository Guidelines

## Project Structure & Module Organization
- `lib/` contains the Readability library modules (core logic under `lib/readability/`).
- `test/` holds ExUnit tests, with HTML/text fixtures in `test/fixtures/`.
- `README.md` documents usage and options; `mix.exs` defines deps and tooling.

## Build, Test, and Development Commands
- `mix deps.get` installs dependencies.
- `mix test` runs the full ExUnit suite.
- `mix test.watch` runs tests on change (uses `mix_test_watch`).
- `mix coveralls` or `mix coveralls.html` runs coverage via ExCoveralls.
- `mix format` formats source files (see `.formatter.exs`).
- `mix credo` runs static analysis; `mix dialyzer` runs type checks.
- `mix test --failed` reruns only previously failing tests when iterating.

## Coding Style & Naming Conventions
- Use `mix format` for all `.ex`/`.exs` files.
- Indentation: 2 spaces, standard Elixir conventions.
- Module names use `Readability.*`; functions use `snake_case`.
- Test files end with `_test.exs` and live under `test/`.
- Avoid multiple modules per file to keep compilation and navigation clear.

## Testing Guidelines
- Framework: ExUnit (see `test/test_helper.exs`).
- Keep fixtures in `test/fixtures/` and reference them from tests.
- Run `mix test` before opening a PR; add coverage runs for larger changes.
- Prefer `start_supervised!/1` for processes you need in tests; avoid `Process.sleep/1`.

## Elixir Library Guidelines
- Lists do not support `list[index]`; use `Enum.at/2`, pattern matching, or `List`.
- Avoid `String.to_atom/1` on user input.
- Predicate functions end with `?` and avoid the `is_` prefix unless used as guards.
- Prefer existing dependencies; add new ones only with clear justification.

## Agent-Specific Notes
- Follow `AGENTS.md` when modifying this repository.
- Prefer small, focused patches over large refactors.

## Commit & Pull Request Guidelines
- Recent commits use short, imperative summaries with context and issue IDs, e.g.
  `Fix Issue 65: incorrect node return format for doctype when using html5ever (#66)`.
- PRs should include: a clear description, linked issues (if any), and tests
  covering behavior changes. Add README updates for user-facing changes.
