# Changelog

## [1.4.1](https://github.com/dobsontom/dbt-ft.nvim/compare/v1.4.0...v1.4.1) (2026-11-23)


### Bug Fixes

* read dbt's pre-1.0 path keys and packages-install-path ([62e0439](https://github.com/dobsontom/dbt-ft.nvim/commit/62e0439e3fb44910e8f740f8833c401fbb900e23))

## [1.4.0](https://github.com/dobsontom/dbt-ft.nvim/compare/v1.3.0...v1.4.0) (2026-11-23)


### Features

* **yaml:** map dbt's schemas onto the YAML in analyses, tests, functions, and checks, and wherever dbt_project.yml's *-paths point ([64e57a1](https://github.com/dobsontom/dbt-ft.nvim/commit/64e57a10d8e0245ab181d9eb949273b994ca718e))


### Bug Fixes

* **gf:** read a model-paths list written without indentation ([b6f6c96](https://github.com/dobsontom/dbt-ft.nvim/commit/b6f6c96e4e53e2c6b20cd1701626e8e865562a89))

## [1.3.0](https://github.com/dobsontom/dbt-ft.nvim/compare/v1.2.0...v1.3.0) (2026-11-19)


### Features

* **gf:** open the model a ref() names with gf, from the project's model-paths and packages ([ccbd5b7](https://github.com/dobsontom/dbt-ft.nvim/commit/ccbd5b707d5328ae78e910507353eba528e3c472))
* **highlights:** show dbt's functions and context variables as built-ins in dbt buffers ([748e531](https://github.com/dobsontom/dbt-ft.nvim/commit/748e5313bc48d909de4912e24971e62386f5e8b1))


### Bug Fixes

* **dbtpal:** keep models dbt while dbtpal is loaded ([e21aa78](https://github.com/dobsontom/dbt-ft.nvim/commit/e21aa78de5ce9bd9ee3a6474af9b68aa8f932c3b))

## [1.2.0](https://github.com/dobsontom/dbt-ft.nvim/compare/v1.1.1...v1.2.0) (2026-11-18)


### Features

* **ftplugin:** continue a -- comment onto the line `<CR>` or `o` opens ([43fb4d4](https://github.com/dobsontom/dbt-ft.nvim/commit/43fb4d43c31aedb0b10103bb486fb7ebe06a8c66))
* **ftplugin:** indent dbt buffers by four spaces, unless g:dbt_recommended_style is off ([d7c4539](https://github.com/dobsontom/dbt-ft.nvim/commit/d7c4539ac80e9278146cbb112c4b8853c619e13f))
* **ftplugin:** take the indent and 'textwidth' from the nearest SQLFluff config ([1f1f4a0](https://github.com/dobsontom/dbt-ft.nvim/commit/1f1f4a0bcb200b6948e2877019cba185240e030f))
* **health:** check that an enabled dbt language server covers dbt buffers and has the lsp command ([1a8c86b](https://github.com/dobsontom/dbt-ft.nvim/commit/1a8c86b6dee010c2baefb5f65f9717b031a191f3))
* **plugin:** turn the whole plugin off with g:loaded_dbt_ft, keeping only the query handlers ([c4c682a](https://github.com/dobsontom/dbt-ft.nvim/commit/c4c682a5164917419d7bbde9c5c9429965fa08d6))


### Bug Fixes

* **yaml:** leave yamlls's schema mappings alone when g:dbt_ft_yaml_schemas is 0, as when it is false ([d7e7583](https://github.com/dobsontom/dbt-ft.nvim/commit/d7e758316ab7b4b6d82a7cc52d7b61721f6fa931))

## [1.1.1](https://github.com/dobsontom/dbt-ft.nvim/compare/v1.1.0...v1.1.1) (2026-11-10)


### Bug Fixes

* **queries:** give SQL only an if's first branch, and parse the other branches on their own ([53a80b1](https://github.com/dobsontom/dbt-ft.nvim/commit/53a80b1bd6079fe3b241031dea75e9645a70aa71))

## [1.1.0](https://github.com/dobsontom/dbt-ft.nvim/compare/v1.0.5...v1.1.0) (2026-11-02)


### Features

* **yaml:** give a project's YAML dbt's schemas in yaml-language-server, whatever its directory is called ([0a64fc0](https://github.com/dobsontom/dbt-ft.nvim/commit/0a64fc072b43265e4648d723cb96ed7b9e2e50a2))

## [1.0.5](https://github.com/dobsontom/dbt-ft.nvim/compare/v1.0.4...v1.0.5) (2026-11-02)


### Bug Fixes

* **plugin:** detect URL buffers as Neovim 0.13 passes them ([f756b26](https://github.com/dobsontom/dbt-ft.nvim/commit/f756b26c242824ff96f63354681e7e9826b5ae87))

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
