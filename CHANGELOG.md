# Changelog

## [1.0.4](https://github.com/dobsontom/dbt-ft.nvim/compare/v1.0.3...v1.0.4) (2026-10-28)


### Bug Fixes

* **plugin:** give SQL an inline if's first operand ([c0dc826](https://github.com/dobsontom/dbt-ft.nvim/commit/c0dc826daf601a77e4ddb64a4c2c2b34702bf874))

## [1.0.3](https://github.com/dobsontom/dbt-ft.nvim/compare/v1.0.2...v1.0.3) (2026-10-27)


### Bug Fixes

* **plugin:** give SQL a call's name without its package, so Jinja inside a name joins it ([7523030](https://github.com/dobsontom/dbt-ft.nvim/commit/752303053cf33d3581a4ab0819676a346764ef95))

## [1.0.2](https://github.com/dobsontom/dbt-ft.nvim/compare/v1.0.1...v1.0.2) (2026-10-26)


### Bug Fixes

* **plugin:** keep a loop's punctuation separators out of the SQL ([faf6ae7](https://github.com/dobsontom/dbt-ft.nvim/commit/faf6ae72bba9348843733305cab3968826b8b4ac))

## [1.0.1](https://github.com/dobsontom/dbt-ft.nvim/compare/v1.0.0...v1.0.1) (2026-10-26)


### Bug Fixes

* **plugin:** give SQL only the name of a {{ }} call, which keeps Jinja's colour ([706a65f](https://github.com/dobsontom/dbt-ft.nvim/commit/706a65f2fd728e23c174334664aaafc60127b30c))

## 1.0.0 (2026-10-26)

First release.

Gives dbt models a Jinja-aware `dbt` filetype. Tree-sitter parses a model as Jinja and hands the SQL to the SQL parser, so highlighting, folding, and indenting understand both languages.

Needs Neovim 0.12 or later and the `jinja`, `jinja_inline`, and `sql` Tree-sitter parsers.
