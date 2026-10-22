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
    health.ok("The dbt filetype uses the jinja parser")
  else
    health.error("The dbt filetype isn't mapped to the jinja parser", "Check that dbt-ft.nvim's plugin/ is loaded")
  end

  local have_jinja = false
  for _, lang in ipairs({ "jinja", "jinja_inline", "sql" }) do
    if vim.treesitter.language.add(lang) then
      have_jinja = have_jinja or lang == "jinja"
      health.ok(("%s parser found"):format(lang))
    else
      health.error(("%s parser not found"):format(lang), ("Install it, for example with `:TSInstall %s`"):format(lang))
    end
  end

  if have_jinja then
    for _, name in ipairs({ "injections", "folds", "indents" }) do
      local ok, query = pcall(vim.treesitter.query.get, "jinja", name)
      if not ok then
        health.error(
          ("jinja %s query doesn't load: %s"):format(name, query),
          "Update dbt-ft.nvim and the jinja parser together"
        )
      elseif not query then
        health.error(("jinja %s query not found"):format(name), "Check that dbt-ft.nvim is on 'runtimepath'")
      else
        health.ok(("jinja %s query loads"):format(name))
      end
    end
  end

  local ok, config = pcall(function()
    return vim.lsp.config.dbt
  end)
  if not ok or not config then
    health.info("No `dbt` language server config found. nvim-lspconfig provides one.")
  elseif config.filetypes and not vim.list_contains(config.filetypes, "dbt") then
    health.warn(
      "The `dbt` language server config doesn't list the dbt filetype, so the server won't start for models",
      "Add it with `vim.lsp.config('dbt', { filetypes = { 'sql', 'dbt' } })`"
    )
  else
    health.ok("The `dbt` language server config covers the dbt filetype")
  end

  local has_group, dbtpal = pcall(vim.api.nvim_get_autocmds, { group = "dbtPal", event = "BufRead" })
  if has_group and #dbtpal > 0 then
    health.warn("dbtpal is loaded, and it sets 'filetype' to sql on every .sql file it reads, which replaces dbt")
  end
end

return M
