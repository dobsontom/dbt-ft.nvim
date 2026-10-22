local root = vim.fs.dirname(vim.fs.dirname(vim.fs.abspath(debug.getinfo(1, "S").source:sub(2))))
local fixtures = vim.fs.joinpath(root, "tests", "fixtures")

vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(assert(vim.env.DBT_FT_TS_DIR, "DBT_FT_TS_DIR must hold the parser/ and queries/ to test with"))
if vim.env.NVIM_TREESITTER then
  vim.opt.rtp:append(vim.env.NVIM_TREESITTER)
end
vim.cmd("runtime! plugin/dbt-ft.lua ftdetect/dbt.lua")
vim.cmd("filetype plugin indent on")
vim.cmd("syntax on")
vim.o.swapfile = false
vim.o.shiftwidth = 4
vim.o.expandtab = true

local passed, failed = 0, 0

local function test(name, fn)
  local ok, err = pcall(fn)
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
    vim.treesitter.get_parser(buf):parse(true)
  end
  return buf
end

local function row_of(buf, text)
  for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if line:find(text, 1, true) then
      return row, line
    end
  end
  error("no line containing " .. text, 2)
end

local function captures(buf, text, token)
  local row, line = row_of(buf, text)
  local col = assert(line:find(token, 1, true), token .. " is not on the line")
  local names = {}
  for _, c in ipairs(vim.treesitter.get_captures_at_pos(buf, row - 1, col - 1)) do
    names[#names + 1] = c.lang .. ":" .. c.capture
  end
  return names
end

test("detects models, macros, and package models as dbt", function()
  for _, rel in ipairs({
    "project/models/orders.sql",
    "project/macros/grant_select.sql",
    "project/dbt_packages/pkg/models/pkg_orders.sql",
  }) do
    eq(vim.filetype.match({ filename = vim.fs.joinpath(fixtures, rel) }), "dbt", rel)
  end
end)

test("leaves compiled output and SQL outside a project as sql", function()
  for _, rel in ipairs({
    "project/target/compiled/project/models/orders.sql",
    "project/target/compiled/project/dbt_project.yml/hooks/project-on-run-start-0.sql",
    "plain.sql",
  }) do
    eq(vim.filetype.match({ filename = vim.fs.joinpath(fixtures, rel) }), "sql", rel)
  end
end)

test("detects a URL by the path after its scheme, not the current directory", function()
  local project = vim.fs.joinpath(fixtures, "project")
  vim.cmd.cd(vim.fn.fnameescape(project))
  for url, ft in pairs({
    ["fugitive://" .. project .. "/.git//0/models/orders.sql"] = "dbt",
    ["fugitive://" .. fixtures .. "/.git//0/plain.sql"] = "sql",
    ["oil-ssh://host//srv/models/orders.sql"] = "sql",
  }) do
    eq(vim.filetype.match({ filename = url }), ft, url)
  end
  vim.cmd.cd("-")
end)

test("maps the dbt filetype to the jinja parser", function()
  eq(vim.treesitter.language.get_lang("dbt"), "jinja", "language")
end)

test("injects SQL into dbt buffers, {{ }} expressions included", function()
  local buf = open("project/models/orders.sql", true)
  local parser = vim.treesitter.get_parser(buf)
  eq(parser:lang(), "jinja", "parser")
  assert(parser:children().sql, "no SQL injection")
  local after_ref = captures(buf, "where order_id", "where")
  assert(
    vim.list_contains(after_ref, "sql:keyword"),
    "`where` after a ref() isn't a keyword: " .. vim.inspect(after_ref)
  )
  local ref = captures(buf, "from {{ ref(", "ref")
  assert(vim.list_contains(ref, "sql:function.call"), "ref() didn't reach SQL: " .. vim.inspect(ref))
end)

test("keeps calls that render nothing out of the SQL", function()
  local buf = open("project/models/orders.sql", true)
  for _, name in ipairs(captures(buf, "config(", "materialized")) do
    assert(not vim.startswith(name, "sql:"), "config() reached SQL as " .. name)
  end
  buf = open("project/macros/order_statuses.sql", true)
  for _, tree in ipairs(vim.treesitter.get_parser(buf):children().sql:trees()) do
    assert(not tree:root():has_error(), "log() or return() reached SQL: " .. tree:root():sexpr())
  end
end)

test("highlights Jinja tags and comments", function()
  local buf = open("project/models/orders.sql", true)
  local tag = captures(buf, "{{ config(", "{{")
  assert(vim.list_contains(tag, "jinja:keyword.directive"), vim.inspect(tag))
  local comment = captures(buf, "{#", "orders below")
  assert(vim.list_contains(comment, "jinja:comment"), vim.inspect(comment))
end)

test("injects no SQL into other Jinja templates", function()
  local buf = open("template.jinja")
  eq(vim.bo[buf].filetype, "jinja", "filetype")
  local parser = vim.treesitter.get_parser(buf)
  parser:parse(true)
  eq(parser:children().sql, nil, "SQL injection")
end)

test("folds Jinja blocks and SQL statements", function()
  local buf = open("project/models/orders.sql", true)
  for _, text in ipairs({ "{% if target.name", "select order_id, status" }) do
    local fold = vim.treesitter.foldexpr((row_of(buf, text)))
    assert(vim.startswith(fold, ">"), ("no fold starts at %q: %s"):format(text, fold))
  end
  buf = open("template.jinja", true)
  local fold = vim.treesitter.foldexpr((row_of(buf, "{% raw %}")))
  assert(vim.startswith(fold, ">"), "no fold starts at {% raw %}: " .. fold)
end)

test("has its SQL folds as soon as a model opens", function()
  local buf = open("project/models/orders.sql")
  vim.treesitter.start(buf)
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
  local ok, indent = pcall(require, "nvim-treesitter.indent")
  assert(ok, "nvim-treesitter's indent module is needed; set NVIM_TREESITTER")
  local buf = open("project/models/orders.sql", true)
  eq(indent.get_indent((row_of(buf, "select order_id, status"))), 4, "select inside the CTE")
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
    vim.api.nvim_win_set_cursor(0, { (row_of(buf, text)), 0 })
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
  eq(vim.fn.synIDattr(vim.fn.synID((row_of(buf, "{{ config(")), 1, 1), "name"), "dbtJinjaExpression", "syntax at {{")
end)

test("moves between Jinja block tags with %", function()
  assert(vim.g.loaded_matchit, "matchit isn't loaded")
  local buf = open("project/macros/grant_select.sql")
  local if_row, if_line = row_of(buf, "{% if")
  vim.api.nvim_win_set_cursor(0, { if_row, if_line:find("if", 1, true) - 1 })
  vim.cmd("normal %")
  eq(vim.api.nvim_win_get_cursor(0)[1], (row_of(buf, "{% else")), "% from {% if %}")
  vim.cmd("normal %")
  eq(vim.api.nvim_win_get_cursor(0)[1], (row_of(buf, "{% endif")), "% from {% else %}")
end)

test("moves from {% for %} to {% endfor %}, past the {% else %} of an if inside", function()
  local buf = open("project/macros/union_relations.sql")
  local for_row, for_line = row_of(buf, "{% for")
  vim.api.nvim_win_set_cursor(0, { for_row, for_line:find("for", 1, true) - 1 })
  vim.cmd("normal %")
  eq(vim.api.nvim_win_get_cursor(0)[1], (row_of(buf, "{% endfor")), "% from {% for %}")
end)

test("has help tags that build", function()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir .. "/doc", "p")
  vim.fn.writefile(vim.fn.readfile(vim.fs.joinpath(root, "doc", "dbt-ft.txt")), dir .. "/doc/dbt-ft.txt")
  vim.cmd.helptags(dir .. "/doc")
  vim.opt.rtp:append(dir)
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
  assert(report:find("jinja injections query loads", 1, true), report)
  assert(not report:find("ERROR"), report)
end)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
