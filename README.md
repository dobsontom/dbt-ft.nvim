# dbt-ft.nvim

A Jinja-aware filetype for [dbt](https://www.getdbt.com/) models in Neovim.

Neovim opens dbt models as plain SQL, so the SQL parser trips over every `{{ ref() }}` and none of
the Jinja is highlighted. dbt-ft.nvim gives models their own `dbt` filetype, which Tree-sitter
parses as Jinja with the SQL between the tags handed to the SQL parser. Highlighting, folding, and
indenting then understand both languages, and a `dbt` buffer still gets what Neovim gives a `sql`
buffer.

![The same dbt model without and with dbt-ft.nvim, with the lines SQL can't parse marked in red](https://raw.githubusercontent.com/dobsontom/dbt-ft.nvim/assets/sql-vs-dbt.png)

There are no commands, options, or setup function.

## Features

- `.sql` files in a dbt project become filetype `dbt`, except dbt's compiled output in `target/`.
- The text between Jinja tags and each `{{ }}` expression go to the SQL parser as one document, so
  `from {{ ref('orders') }} where` parses as SQL.
- Jinja blocks fold, and SQL keeps its Tree-sitter folds and indents.
- `gc` uses `{# #}` on a line that starts with a Jinja tag, indented or not, and `--` elsewhere.
- With matchit, `%` moves between Jinja block tags.

See [`:help dbt-ft`](doc/dbt-ft.txt) for details and limitations.

## Requirements

- Neovim 0.12 or later
- The `jinja`, `jinja_inline`, and `sql` Tree-sitter parsers, for example from
  [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) with
  `:TSInstall jinja jinja_inline sql`

## Installation

With `vim.pack`:

```lua
vim.pack.add({ "https://github.com/dobsontom/dbt-ft.nvim" })
```

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ "dobsontom/dbt-ft.nvim" }
```

LazyVim starts Tree-sitter for `dbt` buffers by itself. If your config starts it for a list of
filetypes, add `dbt` to the list.

Language servers, formatters, and linters set up for `sql` don't run on `dbt` buffers, which keeps
the ones that can't read Jinja off your models. Add `dbt` to those that can, such as the dbt
language server (`dbt lsp`, from dbt v2):

```lua
vim.lsp.config("dbt", { filetypes = { "sql", "dbt" } })
```

Then run `:checkhealth dbt-ft`.
