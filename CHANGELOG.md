# Changelog

## [1.0.1](https://github.com/dobsontom/dbt-ft.nvim/compare/v1.0.0...v1.0.1) (2026-10-26)


### Bug Fixes

* **plugin:** give SQL only the name of a {{ }} call, which keeps Jinja's colour ([706a65f](https://github.com/dobsontom/dbt-ft.nvim/commit/706a65f2fd728e23c174334664aaafc60127b30c))

## 1.0.0 (2026-10-26)

First release.

Gives dbt models a Jinja-aware `dbt` filetype. Tree-sitter parses a model as Jinja and hands the SQL to the SQL parser, so highlighting, folding, and indenting understand both languages.

Needs Neovim 0.12 or later and the `jinja`, `jinja_inline`, and `sql` Tree-sitter parsers.
