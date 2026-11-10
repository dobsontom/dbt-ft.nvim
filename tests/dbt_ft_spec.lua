local root = vim.fn.fnamemodify(arg[0], ":p:h:h")
local fixtures = vim.fs.joinpath(root, "tests", "fixtures")

vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(assert(vim.env.DBT_FT_TS_DIR, "DBT_FT_TS_DIR must hold the parser/ and queries/ to test with"))
vim.opt.rtp:append(assert(vim.env.NVIM_TREESITTER, "NVIM_TREESITTER must hold an nvim-treesitter checkout"))
vim.cmd("runtime! plugin/dbt-ft.lua ftdetect/dbt.lua")
vim.o.shiftwidth = 4
vim.o.expandtab = true

local passed, failed, cleanups = 0, 0, {}

local function defer(fn)
  table.insert(cleanups, 1, fn)
end

local function test(name, fn)
  local ok, err = pcall(fn)
  for _, cleanup in ipairs(cleanups) do
    cleanup()
  end
  cleanups = {}
  if ok then
    passed = passed + 1
    print("ok   " .. name)
  else
    failed = failed + 1
    print("FAIL " .. name .. "\n     " .. tostring(err))
  end
end

local function eq(actual, expected, what)
  if not vim.deep_equal(actual, expected) then
    error(("%s: expected %s, got %s"):format(what, vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

local function open(rel, with_treesitter)
  vim.cmd("silent! %bwipeout!")
  vim.cmd.edit(vim.fn.fnameescape(vim.fs.joinpath(fixtures, rel)))
  local buf = vim.api.nvim_get_current_buf()
  if with_treesitter then
    vim.treesitter.start(buf)
  end
  return buf
end

local function row_of(buf, text)
  for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if line:find(text, 1, true) then
      return row
    end
  end
  error("no line containing " .. text, 2)
end

local function pos(buf, text, token)
  local row = row_of(buf, text)
  local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, true)[1]
  return { row, assert(line:find(token, 1, true), token .. " is not on the line") - 1 }
end

local function captures(buf, text, token)
  local at = pos(buf, text, token)
  local names = {}
  for _, c in ipairs(vim.treesitter.get_captures_at_pos(buf, at[1] - 1, at[2])) do
    names[#names + 1] = c.lang .. ":" .. c.capture
  end
  return names
end

local function has_capture(buf, text, token, want)
  local got = captures(buf, text, token)
  assert(vim.list_contains(got, want), ("%s on %q: no %s in %s"):format(token, text, want, vim.inspect(got)))
end

local function sql_parses(buf, what)
  for _, tree in ipairs(vim.treesitter.get_parser(buf):children().sql:trees()) do
    assert(not tree:root():has_error(), what .. " reached SQL: " .. tree:root():sexpr())
  end
end

-- A real client of an in-process server, so attaching it runs the plugin's
-- LspAttach autocmd.
local function yaml_client(name, settings, server_name)
  local sent = {}
  local id = assert(vim.lsp.start({
    name = name,
    settings = settings,
    cmd = function()
      return {
        request = function(_, _, callback)
          callback(nil, { capabilities = {}, serverInfo = server_name and { name = server_name } })
          return true, 1
        end,
        notify = function(method, params)
          if method == "workspace/didChangeConfiguration" then
            sent[#sent + 1] = params.settings
          end
          return true
        end,
        is_closing = function()
          return false
        end,
        terminate = function() end,
      }
    end,
  }, {
    attach = false,
    reuse_client = function()
      return false
    end,
  }))
  sent = {} -- core sends one as a client with settings starts
  return assert(vim.lsp.get_client_by_id(id)), sent
end

test("detects dbt models, and leaves compiled output and other SQL as sql", function()
  for rel, ft in pairs({
    ["plain.sql"] = "sql",
    ["project/dbt_packages/pkg/models/pkg_orders.sql"] = "dbt",
    ["project/macros/grant_select.sql"] = "dbt",
    ["project/models/orders.sql"] = "dbt",
    ["project/target/compiled/project/dbt_project.yml/hooks/project-on-run-start-0.sql"] = "sql",
    ["project/target/compiled/project/models/orders.sql"] = "sql",
  }) do
    eq(vim.filetype.match({ filename = vim.fs.joinpath(fixtures, rel) }), ft, rel)
  end
end)

test("leaves models as sql when vim.g.loaded_dbt_ft is set first", function()
  local model = vim.fs.joinpath(fixtures, "project", "models", "orders.sql")
  local function filetype(...)
    return vim.system({
      vim.v.progpath,
      "--clean",
      "--headless",
      "--cmd",
      "set rtp^=" .. root,
      "-c",
      ("lua io.write(vim.filetype.match({ filename = %q }))"):format(model),
      "-c",
      "qa!",
      ...,
    })
  end
  local guarded, unguarded = filetype("--cmd", "let g:loaded_dbt_ft = 1"), filetype()
  eq(
    { guarded = guarded:wait().stdout, unguarded = unguarded:wait().stdout },
    { guarded = "sql", unguarded = "dbt" },
    "filetype"
  )
end)

test("detects a URL by the path after its scheme, not the current directory", function()
  local project = vim.fs.joinpath(fixtures, "project")
  local previous = vim.fn.chdir(project)
  defer(function()
    vim.fn.chdir(previous)
  end)
  for url, ft in pairs({
    ["fugitive://" .. fixtures .. "/.git//0/plain.sql"] = "sql",
    ["fugitive://" .. project .. "/.git//0/models/orders.sql"] = "dbt",
    ["oil-ssh://host//srv/models/orders.sql"] = "sql",
  }) do
    eq(vim.filetype.match({ filename = url }), ft, url)
  end
end)

test("injects SQL into dbt buffers, {{ }} expressions included", function()
  local buf = open("project/models/orders.sql", true)
  local parser = assert(vim.treesitter.get_parser(buf))
  eq(parser:lang(), "jinja", "parser")
  assert(parser:children().sql, "no SQL injection")
  has_capture(buf, "where order_id", "where", "sql:keyword")
  has_capture(buf, ">= {{ threshold", "threshold", "sql:variable.member")
end)

test("injects no SQL into other Jinja templates", function()
  local function injected(rel)
    local buf = open(rel)
    local parser = assert(vim.treesitter.get_parser(buf))
    -- Nothing parses a template as it opens, so without this it has no SQL
    -- child either way.
    parser:parse(true)
    return { vim.bo[buf].filetype, parser:children().sql ~= nil }
  end
  eq(
    { model = injected("project/models/orders.sql"), template = injected("template.jinja") },
    { model = { "dbt", true }, template = { "jinja", false } },
    "filetype and SQL injection"
  )
end)

test("gives SQL only a call's name, which keeps Jinja's colour", function()
  local buf = open("project/models/order_payments.sql", true)
  sql_parses(buf, "a call's arguments or package")
  local at = pos(buf, "generate_surrogate_key", "generate_surrogate_key")
  local above
  for _, c in ipairs(vim.treesitter.get_captures_at_pos(buf, at[1] - 1, at[2])) do
    if tonumber(c.metadata.priority or 100) > 100 then
      above = c.lang .. ":" .. c.capture
    end
  end
  eq(above, "jinja:function.call", "capture above SQL's")
end)

test("gives SQL an inline if's first operand", function()
  local buf = open("project/models/completed_orders.sql", true)
  sql_parses(buf, "the whole inline if")
  has_capture(buf, "where status", "'completed'", "sql:string")
end)

test("gives SQL an if's first branch, and parses its other branches on their own", function()
  local buf = open("project/models/order_updates.sql", true)
  local at = pos(buf, "select order_id", "select")
  local main =
    assert(vim.treesitter.get_parser(buf):children().sql:tree_for_range({ at[1] - 1, at[2], at[1] - 1, at[2] }))
  assert(not main:root():has_error(), "the else branch reached the model's SQL: " .. main:root():sexpr())
  eq(require("nvim-treesitter.indent").get_indent(row_of(buf, "refunded as (")), 0, "the CTE between else branches")
  has_capture(open("project/macros/grant_select.sql", true), "select 1", "select", "sql:keyword")
end)

test("keeps calls that render nothing out of the SQL", function()
  local buf = open("project/models/orders.sql", true)
  for _, name in ipairs(captures(buf, "config(", "materialized")) do
    assert(not vim.startswith(name, "sql:"), "config() reached SQL as " .. name)
  end
  sql_parses(open("project/macros/order_statuses.sql", true), "log() or return()")
end)

test("keeps a loop's separators out of the SQL, but not its keywords", function()
  sql_parses(open("project/models/payment_methods.sql", true), "a separator")
  local buf = open("project/macros/union_relations.sql", true)
  has_capture(buf, "union all", "union", "sql:keyword.operator")
end)

test("highlights Jinja tags and comments", function()
  local buf = open("project/models/orders.sql", true)
  has_capture(buf, "{{ config(", "{{", "jinja:keyword.directive")
  has_capture(buf, "{#", "orders below", "jinja:comment")
end)

test("folds Jinja blocks and SQL statements", function()
  for text, rel in pairs({
    ["select order_id, status"] = "project/models/orders.sql",
    ["{% if target.name"] = "project/models/orders.sql",
    ["{% raw %}"] = "template.jinja",
  }) do
    local fold = vim.treesitter.foldexpr(row_of(open(rel, true), text))
    assert(vim.startswith(fold, ">"), ("no fold starts at %q: %s"):format(text, fold))
  end
end)

test("has its SQL folds as soon as a model opens", function()
  local buf = open("project/models/orders.sql", true)
  vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
  vim.wo.foldmethod = "expr"
  local row = row_of(buf, "select order_id, status")
  local folded = vim.wait(2000, function()
    return vim.fn.foldlevel(row) > 0
  end, 20)
  vim.wo.foldmethod = "manual"
  assert(folded, "no fold holds the CTE's select")
end)

test("indents dbt buffers by SQL's rules and leaves other Jinja to autoindent", function()
  local indent = require("nvim-treesitter.indent")
  local buf = open("project/models/orders.sql", true)
  eq(indent.get_indent(row_of(buf, "select order_id, status")), 4, "select inside the CTE")
  buf = open("template.jinja", true)
  for row = 2, vim.api.nvim_buf_line_count(buf) do
    eq(indent.get_indent(row), -1, "template line " .. row)
  end
end)

test("comments a line starting with a Jinja tag as Jinja, indented or not, and SQL as SQL", function()
  for text, commented in pairs({
    ["{% set threshold"] = "{# {% set threshold = 1 %} #}",
    ["{% if target.name"] = "    {# {% if target.name == 'dev' %} #}",
    ["where order_id"] = "    -- where order_id >= {{ threshold }}",
  }) do
    local buf = open("project/models/orders.sql", true)
    vim.api.nvim_win_set_cursor(0, { row_of(buf, text), 0 })
    vim.cmd("normal gcc")
    eq(vim.api.nvim_get_current_line(), commented, "gcc on " .. text)
  end
end)

test("uses Jinja's comment string on top of SQL's buffer settings", function()
  local buf = open("project/models/orders.sql")
  eq(vim.bo[buf].commentstring, "{# %s #}", "commentstring")
  assert(vim.bo[buf].comments:find(":--", 1, true), "SQL's 'comments' are missing: " .. vim.bo[buf].comments)
  eq(vim.b[buf].did_indent, 1, "SQL's indent script")
end)

test("falls back to SQL's regex syntax with Jinja's tags", function()
  local buf = open("project/models/orders.sql")
  eq(vim.b[buf].current_syntax, "dbt", "syntax")
  eq(vim.fn.synIDattr(vim.fn.synID(row_of(buf, "{{ config("), 1, 1), "name"), "dbtJinjaExpression", "syntax at {{")
end)

test("moves between Jinja block tags with %", function()
  assert(vim.g.loaded_matchit, "matchit isn't loaded")
  local buf = open("project/macros/grant_select.sql")
  vim.api.nvim_win_set_cursor(0, pos(buf, "{% if", "if"))
  vim.cmd("normal %")
  eq(vim.api.nvim_win_get_cursor(0)[1], row_of(buf, "{% else"), "% from {% if %}")
  vim.cmd("normal %")
  eq(vim.api.nvim_win_get_cursor(0)[1], row_of(buf, "{% endif"), "% from {% else %}")
end)

test("moves from {% for %} to {% endfor %}, past the {% else %} of an if inside", function()
  local buf = open("project/macros/union_relations.sql")
  vim.api.nvim_win_set_cursor(0, pos(buf, "{% for", "for"))
  vim.cmd("normal %")
  eq(vim.api.nvim_win_get_cursor(0)[1], row_of(buf, "{% endfor"), "% from {% for %}")
end)

test("maps a project's YAML to dbt's schemas when yamlls attaches", function()
  local project = vim.fs.joinpath(fixtures, "project")
  local models =
    "https://raw.githubusercontent.com/dbt-labs/dbt-jsonschema/main/schemas/latest_fusion/dbt_yml_files-latest-fusion.json"
  local packages = models:gsub("dbt_yml_files", "packages")
  local client, sent = yaml_client("yamlls", { yaml = { schemas = { [models] = "**/*dbt*/models/**/*.yml" } } })
  vim.lsp.buf_attach_client(open("project/models/schema.yml"), client.id)
  eq(#sent, 1, "notifications")
  local schemas = sent[1].yaml.schemas
  eq(schemas[models][1], "**/*dbt*/models/**/*.yml", "the mapping yamlls had")
  assert(vim.list_contains(schemas[models], project .. "/models/**/*.yml"), vim.inspect(schemas[models]))
  assert(vim.list_contains(schemas[packages], project .. "/packages.yml"), vim.inspect(schemas[packages]))
  eq(client.settings, sent[1], "the settings the client keeps")
  vim.lsp.buf_attach_client(open("project/models/other.yml"), client.id)
  eq(#sent, 1, "notifications after a second file in the project")
end)

test("knows yaml-language-server by the name it reports, whatever the client is called", function()
  local client, sent = yaml_client("yaml", {}, "yaml-language-server")
  vim.lsp.buf_attach_client(open("project/models/schema.yml"), client.id)
  eq(#sent, 1, "notifications")
end)

test("leaves yamlls alone outside a project, for other servers, and when turned off", function()
  defer(function()
    vim.g.dbt_ft_yaml_schemas = nil
  end)
  local got = {}
  for what, case in pairs({
    ["another server"] = { "jsonls", "project/packages.yml" },
    ["outside a project"] = { "yamlls", "settings.yml" },
    ["turned off"] = { "yamlls", "project/packages.yml", false },
    ["yamlls in a project"] = { "yamlls", "project/packages.yml" },
  }) do
    local client, sent = yaml_client(case[1], {})
    vim.g.dbt_ft_yaml_schemas = case[3]
    vim.lsp.buf_attach_client(open(case[2]), client.id)
    got[what] = #sent
  end
  eq(
    got,
    { ["another server"] = 0, ["outside a project"] = 0, ["turned off"] = 0, ["yamlls in a project"] = 1 },
    "notifications"
  )
end)

test("has help tags that build", function()
  vim.cmd.helptags(vim.fs.joinpath(root, "doc"))
  vim.cmd("help dbt-ft-detection")
  eq(vim.bo.filetype, "help", "filetype")
  vim.cmd("helpclose")
end)

test("reports healthy", function()
  vim.cmd("silent! %bwipeout!")
  vim.cmd("checkhealth dbt-ft")
  local buf, report = vim.api.nvim_get_current_buf(), ""
  -- Neovim 0.13 fills the report asynchronously.
  vim.wait(10000, function()
    report = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    return report:find("language server", 1, true) ~= nil
  end, 50)
  assert(report:find("`jinja` injections query loads", 1, true), report)
  assert(not report:find("ERROR"), report)
end)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
