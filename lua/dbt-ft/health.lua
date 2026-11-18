local M = {}

local health = vim.health

local function check_treesitter()
  if vim.treesitter.language.get_lang("dbt") == "jinja" then
    health.ok("The `dbt` filetype uses the `jinja` parser")
  else
    health.error(
      "The `dbt` filetype isn't mapped to the `jinja` parser",
      "Check that dbt-ft.nvim's `plugin/` is loaded"
    )
  end

  local found = {}
  for _, lang in ipairs({ "jinja", "jinja_inline", "sql" }) do
    found[lang] = vim.treesitter.language.add(lang)
    if found[lang] then
      health.ok(("`%s` parser found"):format(lang))
    else
      health.error(
        ("`%s` parser not found"):format(lang),
        ("Install it, for example with `:TSInstall %s`"):format(lang)
      )
    end
  end
  if not found.jinja then
    return
  end

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

local function check_lsp()
  if not vim.lsp.is_enabled("dbt") then
    health.info("The `dbt` language server isn't enabled, see :help dbt-ft-lsp")
    return
  end
  local config = vim.lsp.config.dbt
  if not config then
    health.warn("The `dbt` language server is enabled but has no config", "See :help dbt-ft-lsp")
    return
  end
  if config.filetypes and not vim.list_contains(config.filetypes, "dbt") then
    health.warn(
      "The `dbt` language server config doesn't list the `dbt` filetype, so the server won't start for models",
      "Add it with `vim.lsp.config('dbt', { filetypes = { 'sql', 'dbt' } })`"
    )
  else
    health.ok("The `dbt` language server config covers the `dbt` filetype")
  end

  local cmd = config.cmd
  if type(cmd) ~= "table" or cmd[2] ~= "lsp" then
    return -- Another server under the `dbt` name, or dbt behind a wrapper.
  end
  local path = vim.fn.exepath(cmd[1])
  if path == "" then
    return -- `:checkhealth vim.lsp` reports a command that isn't executable.
  end
  -- wait() returns nil when the timeout kills a shell wrapper whose child
  -- lives on.
  local result = vim.system({ path, "lsp", "--help" }, { timeout = 10000 }):wait()
  if result and result.code == 0 then
    health.ok(("`%s` has the `lsp` command"):format(path))
  else
    health.warn(
      ("`%s` has no `lsp` command, so the `dbt` language server can't start"):format(path),
      "Install dbt v2, not dbt-core 1.x. If another `dbt` comes first on `PATH`, give dbt v2's full path in"
        .. " `vim.lsp.config('dbt', { cmd = { '/path/to/dbt', 'lsp' } })`"
    )
  end
end

local function check_dbtpal()
  if vim.fn.exists("#dbtPal#BufRead") == 1 then
    health.warn("dbtpal is loaded, and it sets 'filetype' to `sql` on every `.sql` file it reads, which replaces `dbt`")
  end
end

function M.check()
  health.start("dbt-ft")
  if vim.fn.has("nvim-0.12") == 0 then
    health.error("Neovim 0.12 or later is required")
    return
  end
  health.ok("Neovim " .. tostring(vim.version()))
  check_treesitter()
  check_lsp()
  check_dbtpal()
end

return M
