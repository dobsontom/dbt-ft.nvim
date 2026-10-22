# Changelog

## 1.0.0 (2026-10-22)


### Features

* **ftdetect:** detect dbt models as the dbt filetype ([205da2b](https://github.com/dobsontom/dbt-ft.nvim/commit/205da2b6b9daebf6807f91572db5f47ddd26625f))
* **ftdetect:** honour vim.g.loaded_dbt_ft, as Neovim's plugin guide recommends ([c08de79](https://github.com/dobsontom/dbt-ft.nvim/commit/c08de79661031c83960135ad4b2fac3d2dfe480a))
* **ftplugin:** build on SQL's ftplugin, indent, and syntax, adding Jinja comments and matchit words ([559dbc9](https://github.com/dobsontom/dbt-ft.nvim/commit/559dbc99438b936656cb5274d998d21b714a8254))
* **health:** add :checkhealth dbt-ft ([c8b730c](https://github.com/dobsontom/dbt-ft.nvim/commit/c8b730c9022b94cdf25f61f8aa80ca1f4606d25e))
* **queries:** fold Jinja blocks and turn on tree-sitter indents for dbt ([e80775f](https://github.com/dobsontom/dbt-ft.nvim/commit/e80775f299380b13a9a0a4a229bc76de2d20e5ce))
* **queries:** parse dbt models as Jinja with the SQL injected ([d399dbc](https://github.com/dobsontom/dbt-ft.nvim/commit/d399dbc47bb9752b08a5f07e4ac4b7c3dd7efc89))


### Bug Fixes

* **detect:** judge a URL buffer by its path, not the current directory ([a50dd13](https://github.com/dobsontom/dbt-ft.nvim/commit/a50dd13f9ec4b1b5de65985e22d5fad030e4da6f))
* **ftplugin:** add the Jinja match words even when matchit loads later ([1bf47d5](https://github.com/dobsontom/dbt-ft.nvim/commit/1bf47d5710cb9054e13b667dc0ed8d1431670b43))
* **ftplugin:** jump from {% for %} to {% endfor %} past a nested {% else %} ([0f293fb](https://github.com/dobsontom/dbt-ft.nvim/commit/0f293fb5989b03052b9da671b709389ebdf2d094))
* **ftplugin:** parse a model in full on open so its SQL folds show ([6dcf84f](https://github.com/dobsontom/dbt-ft.nvim/commit/6dcf84fc0a590388e244c90b312aeec106b609a9))
* **health:** stop pointing at an nvim-lspconfig config that doesn't exist yet ([6c97051](https://github.com/dobsontom/dbt-ft.nvim/commit/6c970511d532bf87d70744bd4b6f72456499dda2))
* **queries:** comment an indented Jinja tag with {# #} rather than SQL's -- ([5b52b4d](https://github.com/dobsontom/dbt-ft.nvim/commit/5b52b4dfe10176f7c2f2a25b1fe9798866d854c8))
* **queries:** fold {% raw %} blocks ([bd5a991](https://github.com/dobsontom/dbt-ft.nvim/commit/bd5a99195c44b2c3e53a930e179a9c66470bada6))
* **queries:** keep return(), log(), and exceptions calls out of the SQL ([ead1304](https://github.com/dobsontom/dbt-ft.nvim/commit/ead1304995e22f34a3420be8a18ddc6d5e34a6e2))
* **scripts:** build the parsers again while any of the three is missing ([f7221f8](https://github.com/dobsontom/dbt-ft.nvim/commit/f7221f8aac8439f24744b36890cfbd676491672d))
* **scripts:** force the parser build, since nvim-treesitter skips a language whose queries exist ([0a087bb](https://github.com/dobsontom/dbt-ft.nvim/commit/0a087bb1143cc9b84259be2ff4f0c943e013490c))
* **scripts:** read the Neovim to test from DBT_FT_NVIM, since Neovim sets NVIM in its terminals ([852b144](https://github.com/dobsontom/dbt-ft.nvim/commit/852b144bf498319966be9c9306766b5250d395ca))


### Performance Improvements

* **plugin:** read the filetype with nvim_get_option_value in dbt-sql?, which vim.bo wraps ([1aa604a](https://github.com/dobsontom/dbt-ft.nvim/commit/1aa604a441f7ff7b9a5647f2587f55fc082e041f))
* **queries:** gate the SQL injection with a predicate, so other Jinja buffers skip it ([95c6991](https://github.com/dobsontom/dbt-ft.nvim/commit/95c6991b37df2d039fdedb95b7a0b39110461c86))
