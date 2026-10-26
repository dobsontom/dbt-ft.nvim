local M = {}

function M.check()
  local health = vim.health
  health.start("dbt-ft")

  if vim.fn.has("nvim-0.12") == 1 then
    health.ok("Neovim " .. tostring(vim.version()))
  else
    health.error("Neovim 0.12 or later is required")
  end

  if vim.treesitter.language.get_lang("dbt") == "jinja" then
    health.ok("The `dbt` filetype uses the `jinja` parser")
  else
    health.error(
      "The `dbt` filetype isn't mapped to the `jinja` parser",
      "Check that dbt-ft.nvim's `plugin/` is loaded"
    )
  end

  for _, lang in ipairs({ "jinja", "jinja_inline", "sql" }) do
    if vim.treesitter.language.add(lang) then
      health.ok(("`%s` parser found"):format(lang))
    else
      health.error(
        ("`%s` parser not found"):format(lang),
        ("Install it, for example with `:TSInstall %s`"):format(lang)
      )
    end
  end

  if vim.treesitter.language.add("jinja") then
    for _, name in ipairs({ "folds", "highlights", "indents", "injections" }) do
      local ok, err = pcall(vim.treesitter.query.get, "jinja", name)
      if ok then
        health.ok(("`jinja` %s query loads"):format(name))
      else
        health.error(
          ("`jinja` %s query doesn't load: %s"):format(name, err),
          "Update dbt-ft.nvim and the `jinja` parser together"
        )
      end
    end
  end

  local ok, config = pcall(function()
    return vim.lsp.config.dbt
  end)
  if not ok or not config then
    health.info("No `dbt` language server config found")
  elseif config.filetypes and not vim.list_contains(config.filetypes, "dbt") then
    health.warn(
      "The `dbt` language server config doesn't list the `dbt` filetype, so the server won't start for models",
      "Add it with `vim.lsp.config('dbt', { filetypes = { 'sql', 'dbt' } })`"
    )
  else
    health.ok("The `dbt` language server config covers the `dbt` filetype")
  end

  if vim.fn.exists("#dbtPal#BufRead") == 1 then
    health.warn("dbtpal is loaded, and it sets 'filetype' to `sql` on every `.sql` file it reads, which replaces `dbt`")
  end
end

return M
