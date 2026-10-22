-- Runs one benchmark scenario: nvim --clean -l bench/run.lua <scenario>
-- scripts/bench sets up the environment and the parsers, and codspeed.yml lists
-- the scenarios CodSpeed measures. Each scenario repeats its work enough times
-- that the plugin, rather than Neovim's startup, dominates the measurement.
local root = vim.fn.fnamemodify(arg[0], ":p:h:h")
local fixtures = vim.fs.joinpath(root, "tests", "fixtures")

vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(assert(vim.env.DBT_FT_TS_DIR, "DBT_FT_TS_DIR must hold the parser/ and queries/ to use"))
vim.opt.rtp:append(assert(vim.env.NVIM_TREESITTER, "NVIM_TREESITTER must hold an nvim-treesitter checkout"))
vim.cmd("runtime! plugin/dbt-ft.lua ftdetect/dbt.lua")
vim.o.shiftwidth = 4
vim.o.expandtab = true

local model = vim.fs.joinpath(fixtures, "project", "models", "orders.sql")

-- A model of many CTEs, each with the Jinja of the orders fixture, so parsing,
-- injections, and folds have a realistic amount of work.
local function large_model_lines(ctes)
  local lines = { "{{ config(materialized='table') }}", "{# a generated model #}", "{% set threshold = 1 %}", "" }
  for i = 1, ctes do
    local sep = i == 1 and "with" or ","
    vim.list_extend(lines, {
      ("%s cte_%d as ("):format(sep, i),
      "    select order_id, status, amount",
      ("    from {{ ref('stg_orders_%d') }}"):format(i),
      "    {% if target.name == 'dev' %}",
      "    where order_id >= {{ threshold }}",
      "    {% else %}",
      "    where status in ({{ order_statuses() | join(', ') }})",
      "    {% endif %}",
      ")",
    })
  end
  vim.list_extend(lines, { "", "select", "    order_id,", "    upper(status) as status", ("from cte_%d"):format(ctes) })
  return lines
end

local function open(path)
  vim.cmd("silent! %bwipeout!")
  vim.cmd.edit(vim.fn.fnameescape(path))
  return vim.api.nvim_get_current_buf()
end

-- A scratch dbt buffer holding the large model, parsed with its injections.
local function large_buffer(ctes)
  vim.cmd("silent! %bwipeout!")
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, large_model_lines(ctes))
  vim.api.nvim_set_current_buf(buf)
  vim.bo[buf].filetype = "dbt"
  local parser = assert(vim.treesitter.get_parser(buf))
  parser:parse(true)
  assert(parser:children().sql, "no SQL injection")
  return buf, parser
end

local scenarios = {}

-- Filetype detection of models, macros, packages, compiled output, and plain SQL.
function scenarios.detect()
  local paths = {
    "plain.sql",
    "project/dbt_packages/pkg/models/pkg_orders.sql",
    "project/macros/grant_select.sql",
    "project/models/orders.sql",
    "project/target/compiled/project/dbt_project.yml/hooks/project-on-run-start-0.sql",
    "project/target/compiled/project/models/orders.sql",
  }
  for _ = 1, 50 do
    for _, rel in ipairs(paths) do
      vim.filetype.match({ filename = vim.fs.joinpath(fixtures, rel) })
    end
  end
end

-- Opening a model: detection, ftplugin, indent, syntax, and the first parse.
function scenarios.open_model()
  for _ = 1, 10 do
    local buf = open(model)
    assert(vim.bo[buf].filetype == "dbt", "the model isn't filetype dbt")
  end
end

-- Parsing a large model from scratch, with the SQL injected through the
-- dbt-sql? predicate and the dbt-trim-indent! directive.
function scenarios.parse_large_model()
  for _ = 1, 3 do
    large_buffer(100)
  end
end

-- Re-parsing a large model after an edit to one of its lines.
function scenarios.reparse_after_edit()
  local buf, parser = large_buffer(100)
  for i = 1, 20 do
    local row = 4 + (i % 100) * 9 + 4
    vim.api.nvim_buf_set_lines(buf, row, row + 1, false, { ("    where order_id >= {{ threshold }} + %d"):format(i) })
    parser:parse(true)
  end
end

-- Running the highlights queries over a large model's Jinja and SQL trees.
function scenarios.highlight_large_model()
  local buf, parser = large_buffer(100)
  local count = 0
  for _ = 1, 5 do
    parser:for_each_tree(function(tree, ltree)
      local query = vim.treesitter.query.get(ltree:lang(), "highlights")
      if query then
        for _ in query:iter_captures(tree:root(), buf, 0, -1) do
          count = count + 1
        end
      end
    end)
  end
  assert(count > 0, "no highlight captures")
end

-- Computing Tree-sitter folds for every line of a large model.
function scenarios.fold_large_model()
  local buf = large_buffer(100)
  local lines = vim.api.nvim_buf_line_count(buf)
  for i = 1, 5 do
    -- An edit drops the cached folds, so each pass computes them again.
    vim.api.nvim_buf_set_lines(buf, 0, 1, false, { ("{{ config(materialized='table', tags=['%d']) }}"):format(i) })
    for row = 1, lines do
      vim.treesitter.foldexpr(row)
    end
  end
end

-- Computing nvim-treesitter indents for every line of a large model.
function scenarios.indent_large_model()
  local indent = require("nvim-treesitter.indent")
  local buf = large_buffer(30)
  for row = 1, vim.api.nvim_buf_line_count(buf) do
    indent.get_indent(row)
  end
end

local name = arg[1]
local scenario = scenarios[name]
if not scenario then
  local names = vim.tbl_keys(scenarios)
  table.sort(names)
  error(("unknown scenario %q, expected one of: %s"):format(tostring(name), table.concat(names, ", ")))
end
scenario()
os.exit(0)
