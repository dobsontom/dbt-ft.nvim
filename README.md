# dbt-ft.nvim

A Jinja-aware filetype for [dbt](https://www.getdbt.com/) models in Neovim.

Neovim opens dbt models as plain SQL, so the SQL parser trips over every `{{ ref() }}` and none of the
Jinja is highlighted. dbt-ft.nvim gives models their own `dbt` filetype, which tree-sitter parses as
Jinja with the SQL between the tags handed to the SQL parser. Highlighting, folding, and indenting then
understand both languages, and a `dbt` buffer still gets what Neovim gives a `sql` buffer.

On a public [Snowflake demo project](https://github.com/dpguthrie/snowflake-dbt-demo-project), all 59
SQL files have SQL parse errors as plain SQL, against 30 as `dbt`, and every Jinja tag is highlighted.

There are no commands, options, or setup function.

## Requirements

- Neovim 0.12 or later
- The `jinja`, `jinja_inline`, and `sql` tree-sitter parsers, for example from
  [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) with
  `:TSInstall jinja jinja_inline sql`

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ "dobsontom/dbt-ft.nvim" }
```

LazyVim starts tree-sitter for the new filetype by itself. If you start it per filetype, add `dbt` to
your list.

The dbt language server (`dbt lsp`, from dbt v2) starts only for the filetypes its config lists. Until
nvim-lspconfig's `dbt` config lists `dbt`, add it:

```lua
vim.lsp.config("dbt", { filetypes = { "sql", "dbt" } })
```

Then run `:checkhealth dbt-ft`.

## What it does

- `.sql` files under a `dbt_project.yml` become filetype `dbt`, except dbt's compiled output in
  `target/`.
- The text between Jinja tags and each `{{ }}` expression go to the SQL parser as one document, so
  `from {{ ref('orders') }} where` parses as SQL. `config()` renders nothing and stays out. Other Jinja
  files get no SQL.
- Jinja blocks fold, and SQL keeps its tree-sitter folds and indents.
- `gc` uses `{# #}` on a line that starts with a Jinja tag, indented or not, and `--` elsewhere. With
  matchit, `%` moves between Jinja block tags.
- Without tree-sitter, SQL's regex syntax and indenting apply, with Jinja's tags highlighted on top.

See `:help dbt-ft` for details and limitations.

## License

MIT
