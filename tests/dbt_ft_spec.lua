local root = vim.fn.fnamemodify(arg[0], ":p:h:h")
local fixtures = vim.fs.joinpath(root, "tests", "fixtures")

vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(assert(vim.env.DBT_FT_TS_DIR, "DBT_FT_TS_DIR must hold the parser/ and queries/ to test with"))
vim.opt.rtp:append(assert(vim.env.NVIM_TREESITTER, "NVIM_TREESITTER must hold an nvim-treesitter checkout"))
vim.cmd("runtime! plugin/dbt-ft.lua ftdetect/dbt.lua")

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

local function tmpdir()
  local dir = vim.fn.tempname()
  defer(function()
    vim.fn.delete(dir, "rf")
  end)
  return dir
end

---@param files table<string, string>
local function write_files(dir, files)
  for rel, text in pairs(files) do
    local path = vim.fs.joinpath(dir, rel)
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    vim.fn.writefile(vim.split(text, "\n"), path)
  end
end

local function open(path, with_treesitter)
  vim.cmd("silent! %bwipeout!")
  local whole = vim.fn.isabsolutepath(path) == 1 or path:find("://", 1, true)
  vim.cmd.edit(vim.fn.fnameescape(whole and path or vim.fs.joinpath(fixtures, path)))
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

---The capture that shows: the last one at the highest priority.
local function top(buf, text, token)
  local at = pos(buf, text, token)
  local best, highest = nil, -math.huge
  for _, c in ipairs(vim.treesitter.get_captures_at_pos(buf, at[1] - 1, at[2])) do
    local priority = tonumber(c.metadata.priority) or 100
    if priority >= highest then
      best, highest = c.lang .. ":" .. c.capture, priority
    end
  end
  return best
end

---Runs Lua in a fresh Neovim with this suite's runtimepath, and returns its
---process without waiting for it. Extra arguments go last, where a `--cmd`
---still runs first.
local function nvim(lua, ...)
  return vim.system({
    vim.v.progpath,
    "--clean",
    "--headless",
    "--cmd",
    ("lua vim.o.rtp = %q"):format(vim.o.rtp),
    "-c",
    "lua " .. lua:gsub("\n", " "),
    "-c",
    "qa!",
    ...,
  })
end

test("turns off with vim.g.loaded_dbt_ft, but keeps Jinja templates parsing and highlighting", function()
  local model = vim.fs.joinpath(fixtures, "project", "models", "orders.sql")
  local template = vim.fs.joinpath(fixtures, "template.jinja")
  local function state(...)
    return nvim(
      ([[vim.cmd.edit(%q)
      io.write(vim.json.encode({
        vim.filetype.match({ filename = %q }),
        vim.treesitter.language.get_lang("dbt"),
        vim.fn.exists("#dbt-ft.yaml#LspAttach"),
        (pcall(function()
          local tree = vim.treesitter.get_parser():parse(true)[1]
          for _ in vim.treesitter.query.get("jinja", "highlights"):iter_captures(tree:root(), 0) do end
        end)),
      }))]]):format(template, model),
      ...
    )
  end
  local off, on = state("--cmd", "let g:loaded_dbt_ft = 1"), state()
  eq(
    { off = off:wait().stdout, on = on:wait().stdout },
    { off = '["sql","dbt",0,true]', on = '["dbt","jinja",1,true]' },
    "filetype, parser, YAML hook, and a template's parse and highlights"
  )
end)

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

test("keeps models dbt while dbtpal is loaded, and leaves other SQL and setups without it alone", function()
  local got = {}
  open("project/models/orders.sql")
  vim.bo.filetype = "sql"
  got["model set to sql without dbtpal"] = vim.bo.filetype
  local group = vim.api.nvim_create_augroup("dbtPal", {})
  defer(function()
    vim.api.nvim_del_augroup_by_id(group)
  end)
  -- dbtpal's own autocmd, as its lua/dbtpal/files.lua sets it up without its
  -- custom syntax.
  vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    group = group,
    pattern = { "*.sql" },
    callback = function()
      vim.bo.filetype = "sql"
    end,
  })
  open("project/models/orders.sql")
  got.model = vim.bo.filetype
  open("plain.sql")
  got.plain = vim.bo.filetype
  eq(got, { model = "dbt", plain = "sql", ["model set to sql without dbtpal"] = "sql" }, "filetypes")
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

local function sql_parses(buf, what)
  for _, tree in ipairs(vim.treesitter.get_parser(buf):children().sql:trees()) do
    assert(not tree:root():has_error(), what .. " reached SQL: " .. tree:root():sexpr())
  end
end

test("gives SQL only a call's name, which keeps Jinja's colour", function()
  local buf = open("project/models/order_payments.sql", true)
  sql_parses(buf, "a call's arguments or package")
  eq(top(buf, "generate_surrogate_key", "generate_surrogate_key"), "jinja:function.call", "capture above SQL's")
end)

test("highlights dbt's functions and context variables as built-ins, in dbt buffers only", function()
  local got = {}
  local buf = open("project/models/order_payments.sql", true)
  got.model = {
    ref = top(buf, "{{ ref(", "ref"),
    project_macro = top(buf, "order_statuses()", "order_statuses"),
    target = top(buf, "target.name", "target"),
    member_named_target = top(buf, "node.config.target", "target"),
  }
  buf = open("template.jinja", true)
  vim.treesitter.get_parser(buf):parse()
  got.template = { ref = top(buf, "{{ ref(", "ref"), target = top(buf, "{{ target", "target") }
  eq(got, {
    model = {
      ref = "jinja:function.builtin",
      project_macro = "jinja:function.call",
      target = "jinja:variable.builtin",
      member_named_target = "jinja:variable.member",
    },
    template = { ref = "jinja:function.call", target = "jinja:variable" },
  }, "top capture")
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
  sql_parses(open("project/macros/order_statuses.sql", true), "exceptions.warn(), log(), or return()")
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

test("falls back to SQL's regex syntax with Jinja's tags", function()
  local buf = open("project/models/orders.sql")
  eq(vim.b[buf].current_syntax, "dbt", "syntax")
  eq(vim.fn.synIDattr(vim.fn.synID(row_of(buf, "{{ config("), 1, 1), "name"), "dbtJinjaExpression", "syntax at {{")
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

test("gives text objects a Jinja block's body, and the whole block", function()
  local buf = open("project/macros/grant_select.sql", true)
  local tree = vim.treesitter.get_parser(buf):parse()[1]
  local query = assert(vim.treesitter.query.get("jinja", "textobjects"))
  local ranges = {}
  for _, match in query:iter_matches(tree:root(), buf) do
    for id, nodes in pairs(match) do
      local sr, sc = nodes[1]:range()
      local _, _, er, ec = nodes[#nodes]:range()
      local name = query.captures[id]
      ranges[name] = ranges[name] or {}
      table.insert(ranges[name], { sr, sc, er, ec })
    end
  end
  for _, list in pairs(ranges) do
    table.sort(list, function(a, b)
      return vim.inspect(a) < vim.inspect(b)
    end)
  end
  eq(ranges["function.inner"], { { 0, 30, 6, 0 } }, "function.inner")
  eq(ranges["function.outer"], { { 0, 0, 6, 14 } }, "function.outer")
  eq(ranges["block.inner"], { { 0, 30, 6, 0 }, { 1, 34, 5, 4 } }, "block.inner")
  eq(ranges["block.outer"], { { 0, 0, 6, 14 }, { 1, 4, 5, 15 } }, "block.outer")
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

---A temporary repository whose dbt project, in `dbt/`, holds one model.
---@param files table<string, string> other files' text, by path from the repository's root
---@return string model
---@return string repo
local function temp_repo(files)
  local repo = tmpdir()
  write_files(
    repo,
    vim.tbl_extend("error", files, { ["dbt/dbt_project.yml"] = "", ["dbt/models/orders.sql"] = "select 1" })
  )
  return vim.fs.joinpath(repo, "dbt", "models", "orders.sql"), repo
end

local style_options = "expandtab, shiftwidth, softtabstop, tabstop, textwidth"
local default_style = { false, 8, 0, 8, 0 }

local function style()
  return { vim.bo.expandtab, vim.bo.shiftwidth, vim.bo.softtabstop, vim.bo.tabstop, vim.bo.textwidth }
end

test("sets dbt's indent and the project's line length until 'filetype' changes, unless turned off", function()
  defer(function()
    vim.g.dbt_recommended_style = nil
  end)
  local got = {}
  open("project/models/orders.sql")
  got.on = style()
  vim.bo.filetype = "sql"
  got.undone = style()
  vim.g.dbt_recommended_style = false
  vim.bo.filetype = "dbt"
  got.off = style()
  eq(got, { on = { true, 4, -1, 8, 100 }, undone = default_style, off = default_style }, style_options)
end)

test("takes each style setting from the nearest SQLFluff config at or above the model, pyproject.toml first", function()
  local pyproject =
    '[tool.ruff]\nmax_line_length = 60\n\n[tool.sqlfluff.core]\ndialect = "snowflake"\nmax_line_length = 120'
  local sqlfluff = "[sqlfluff:rules:layout.long_lines]\nmax_line_length = 70\n\n[sqlfluff]\nmax_line_length = 100"
  local tabs = "[tool.sqlfluff.indentation]\nindent_unit = 'tab'\ntab_space_size = 6"
  local two_spaces = "[sqlfluff]\ntab_space_size = 3\n\n[sqlfluff:indentation]\ntab_space_size = 2"
  local home = vim.env.HOME
  defer(function()
    vim.env.HOME = home
  end)
  local cases = {
    above = { files = { [".sqlfluff"] = sqlfluff }, style = { true, 4, -1, 8, 100 } },
    ["above home"] = { files = { [".sqlfluff"] = sqlfluff }, home = "dbt", style = { true, 4, -1, 8, 0 } },
    beside = {
      files = { ["dbt/pyproject.toml"] = pyproject, ["dbt/.sqlfluff"] = sqlfluff },
      style = { true, 4, -1, 8, 120 },
    },
    ["indent and length from different files"] = {
      files = { ["pyproject.toml"] = pyproject, ["dbt/.sqlfluff"] = two_spaces },
      style = { true, 2, -1, 8, 120 },
    },
    nearer = {
      files = { ["pyproject.toml"] = pyproject, ["dbt/models/.sqlfluff"] = sqlfluff },
      style = { true, 4, -1, 8, 100 },
    },
    ["nearer with no limit"] = {
      files = { ["pyproject.toml"] = pyproject, ["dbt/.sqlfluff"] = "[sqlfluff]\nmax_line_length = -1" },
      style = { true, 4, -1, 8, 0 },
    },
    tabs = { files = { ["dbt/pyproject.toml"] = tabs }, style = { false, 0, 0, 6, 0 } },
  }
  for what, case in pairs(cases) do
    local model, repo = temp_repo(case.files)
    vim.env.HOME = case.home and vim.fs.joinpath(repo, case.home) or home
    open(model)
    eq(style(), case.style, what .. ": " .. style_options)
    vim.bo.filetype = "sql"
    eq(style(), default_style, what .. " undone: " .. style_options)
  end
end)

test("lets a project's EditorConfig override the style", function()
  local model = temp_repo({
    [".editorconfig"] = "root = true\n\n[*.sql]\nindent_size = 2\nmax_line_length = 90",
    [".sqlfluff"] = "[sqlfluff]\nmax_line_length = 100",
  })
  -- A fresh Neovim, as `nvim -l` loads no plugins, EditorConfig's included.
  local shown =
    nvim(("vim.cmd.edit(%q) io.write(vim.bo.filetype, ' ', vim.bo.shiftwidth, ' ', vim.bo.textwidth)"):format(model))
  eq(shown:wait().stdout, "dbt 2 90", "filetype, shiftwidth, and textwidth")
end)

test("takes a URL buffer's 'textwidth' from the project its path is in", function()
  open("fugitive://" .. fixtures .. "/project/.git//0/models/orders.sql")
  eq({ vim.bo.filetype, vim.bo.textwidth }, { "dbt", 100 }, "filetype and textwidth")
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

test("continues a -- comment onto the line <CR> or o opens", function()
  local buf = open("project/models/orders.sql")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "-- per customer", "    -- per day" })
  vim.cmd([[execute "normal 1GA\<CR>and hour\<Esc>3Goand week"]])
  eq(
    vim.api.nvim_buf_get_lines(buf, 0, -1, false),
    { "-- per customer", "-- and hour", "    -- per day", "    -- and week" },
    "lines"
  )
end)

test("uses Jinja's comment string on top of SQL's buffer settings", function()
  local buf = open("project/models/orders.sql")
  eq(vim.bo[buf].commentstring, "{# %s #}", "commentstring")
  assert(vim.bo[buf].comments:find(":--", 1, true), "SQL's 'comments' are missing: " .. vim.bo[buf].comments)
  eq(vim.b[buf].did_indent, 1, "SQL's indent script")
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

test("goes from anywhere in a ref() to its model with gf, through the project's model-paths and packages", function()
  local model = "transform/marts/payments.sql"
  local line = "select * from {{ ref('stg_payments') }} join {{ ref('pkg', 'pkg_orders') }}"
  for what, case in pairs({
    flow = { 'name: p\nmodel-paths: ["staging", "transform"]  # not models/', "dbt_packages" },
    block = { "name: p\nmodel-paths:\n  - 'staging'\n  - transform\nprofile: p", "dbt_packages" },
    indentless = { "name: p\nmodel-paths:\n- staging\n- transform\nprofile: p", "dbt_packages" },
    ["pre-1.0 key, own packages directory"] = {
      'name: p\nsource-paths: ["staging", "transform"]\npackages-install-path: "vendor"',
      "vendor",
    },
  }) do
    local config, packages = unpack(case)
    local project = tmpdir()
    write_files(project, {
      ["dbt_project.yml"] = config,
      [model] = line,
      ["transform/staging/stg_payments.sql"] = "select 1",
      [packages .. "/pkg/models/pkg_orders.sql"] = "select 1",
    })
    for token, want in pairs({
      ["ref('stg"] = "transform/staging/stg_payments.sql",
      ["pkg',"] = packages .. "/pkg/models/pkg_orders.sql",
    }) do
      local buf = open(vim.fs.joinpath(project, model))
      vim.api.nvim_win_set_cursor(0, pos(buf, line, token))
      vim.cmd("normal! gf")
      eq(vim.fs.relpath(project, vim.api.nvim_buf_get_name(0)), want, ("%s: gf on %s"):format(what, token))
    end
  end
end)

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

local yml_files_schema =
  "https://raw.githubusercontent.com/dbt-labs/dbt-jsonschema/main/schemas/latest_fusion/dbt_yml_files-latest-fusion.json"

test("maps a project's YAML to dbt's schemas when yamlls attaches", function()
  local project = vim.fs.joinpath(fixtures, "project")
  local packages = yml_files_schema:gsub("dbt_yml_files", "packages")
  local client, sent =
    yaml_client("yamlls", { yaml = { schemas = { [yml_files_schema] = "**/*dbt*/models/**/*.yml" } } })
  vim.lsp.buf_attach_client(open("project/models/schema.yml"), client.id)
  eq(#sent, 1, "notifications")
  local schemas = sent[1].yaml.schemas
  eq(schemas[yml_files_schema][1], "**/*dbt*/models/**/*.yml", "the mapping yamlls had")
  assert(
    vim.list_contains(schemas[yml_files_schema], project .. "/models/**/*.yml"),
    vim.inspect(schemas[yml_files_schema])
  )
  assert(vim.list_contains(schemas[packages], project .. "/packages.yml"), vim.inspect(schemas[packages]))
  eq(client.settings, sent[1], "the settings the client keeps")
  vim.lsp.buf_attach_client(open("project/models/other.yml"), client.id)
  eq(#sent, 1, "notifications after a second file in the project")
end)

test("maps the YAML under the directories dbt_project.yml lists, and dbt's defaults for the rest", function()
  local project = tmpdir()
  write_files(project, {
    ["dbt_project.yml"] = 'name: p\nmodel-paths:\n  - transform\ndata-paths: ["data/"]\nprofile: p',
    ["transform/schema.yml"] = "version: 2",
  })
  local client, sent = yaml_client("yamlls", {})
  vim.lsp.buf_attach_client(open(vim.fs.joinpath(project, "transform/schema.yml")), client.id)
  local got = sent[1].yaml.schemas[yml_files_schema]
  table.sort(got)
  local want = {}
  for _, dir in ipairs({
    "analyses",
    "analysis",
    "checks",
    "data",
    "functions",
    "macros",
    "snapshots",
    "tests",
    "transform",
  }) do
    vim.list_extend(want, { ("%s/%s/**/*.yaml"):format(project, dir), ("%s/%s/**/*.yml"):format(project, dir) })
  end
  eq(got, want, "dbt_yml_files mappings")
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
  for what, case in pairs({
    ["another server"] = { client = "jsonls", file = "project/packages.yml", sent = 0 },
    ["outside a project"] = { client = "yamlls", file = "settings.yml", sent = 0 },
    ["turned off"] = { client = "yamlls", file = "project/packages.yml", option = false, sent = 0 },
    ["turned off with 0"] = { client = "yamlls", file = "project/packages.yml", option = 0, sent = 0 },
    ["yamlls in a project"] = { client = "yamlls", file = "project/packages.yml", sent = 1 },
  }) do
    local client, sent = yaml_client(case.client, {})
    vim.g.dbt_ft_yaml_schemas = case.option
    vim.lsp.buf_attach_client(open(case.file), client.id)
    eq(#sent, case.sent, "notifications for " .. what)
  end
end)

test("has help tags that build", function()
  vim.cmd.helptags(vim.fs.joinpath(root, "doc"))
  vim.cmd("help dbt-ft-detection")
  eq(vim.bo.filetype, "help", "filetype")
  vim.cmd("helpclose")
end)

-- Each report comes from a fresh Neovim, as a test's language server config
-- can't be unset afterwards. Neovim 0.13 fills the report asynchronously.
local function health(setup)
  return nvim(setup .. [[
 vim.cmd("checkhealth dbt-ft")
 local buf, report = vim.api.nvim_get_current_buf(), ""
 vim.wait(10000, function()
   report = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
   return report:find("language server", 1, true) or report:find("turned off", 1, true)
 end, 50)
 io.write(report)]])
end

test("reports healthy, and checks the dbt language server only once it's enabled", function()
  local dir = tmpdir()
  -- Real dbt v2 exits 0 from `dbt lsp --help`, and dbt-core 1.x exits 2.
  local function fake_exe(rel, code)
    local path = vim.fs.joinpath(dir, rel)
    write_files(dir, { [rel] = "#!/bin/sh\nexit " .. code })
    vim.fn.setfperm(path, "rwxr-xr-x")
    return path
  end
  local function config(cmd, filetype)
    return ("vim.lsp.config.dbt = { cmd = %s, filetypes = { %q } }"):format(vim.inspect(cmd), filetype or "dbt")
  end
  local enable = " vim.lsp.enable('dbt')"
  local dbt1, dbt2 = fake_exe("1/dbt", 2), fake_exe("2/dbt", 0)
  local other = fake_exe("other/dbt-language-server", 2)
  local covered = "OK The `dbt` language server config covers the `dbt` filetype"
  local cases = {
    ["dbt 1.x"] = { setup = config({ dbt1, "lsp" }) .. enable, line = "WARNING `" .. dbt1 .. "` has no `lsp` command" },
    ["dbt 2"] = { setup = config({ dbt2, "lsp" }) .. enable, line = "OK `" .. dbt2 .. "` has the `lsp` command" },
    ["no config"] = { setup = enable, line = "WARNING The `dbt` language server is enabled but has no config" },
    ["no dbt filetype"] = {
      setup = config({ dbt2, "lsp" }, "sql") .. enable,
      line = "WARNING The `dbt` language server config doesn't list the `dbt` filetype",
    },
    ["no executable"] = {
      setup = config({ vim.fs.joinpath(dir, "missing", "dbt"), "lsp" }) .. enable,
      line = covered,
    },
    ["not enabled"] = { setup = config({ dbt1, "lsp" }), line = "The `dbt` language server isn't enabled" },
    ["nothing set up"] = { setup = "", line = "OK `jinja` injections query loads" },
    ["other server"] = { setup = config({ other, "--stdio" }) .. enable, line = covered },
    ["turned off"] = { setup = "vim.g.loaded_dbt_ft = 1", line = "dbt-ft.nvim is turned off by `g:loaded_dbt_ft`" },
  }
  -- Started together, then awaited, so the reports are built side by side.
  local runs = vim.tbl_map(function(case)
    return health(case.setup)
  end, cases)
  for what, case in pairs(cases) do
    local report = runs[what]:wait().stdout
    assert(report:find(case.line, 1, true), ("%s: no %q in\n%s"):format(what, case.line, report))
    local others = vim.tbl_filter(function(line)
      return not line:find(case.line, 1, true) and (line:find("WARNING", 1, true) or line:find("ERROR", 1, true))
    end, vim.split(report, "\n"))
    eq(others, {}, what .. ": other warnings and errors")
  end
end)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
