local M = {}

-- The directories dbt reads property YAML from, with defaults as of dbt-core
-- 1.12.4 and dbt 2.0.11. Only dbt 2.0 has check-paths, or reads `analysis`
-- for an unset analysis-paths.
local source_paths = {
  ["analysis-paths"] = { "analysis", "analyses" },
  ["check-paths"] = { "checks" },
  ["function-paths"] = { "functions" },
  ["macro-paths"] = { "macros" },
  ["model-paths"] = { "models" },
  ["seed-paths"] = { "seeds" },
  ["snapshot-paths"] = { "snapshots" },
  ["test-paths"] = { "tests" },
}

-- Names from before dbt 1.0, which dbt-core still reads. dbt 2.0 reads only
-- `data-paths`.
local renamed = { ["data-paths"] = "seed-paths", ["source-paths"] = "model-paths" }

---@param path string
---@return string
local function local_path(path)
  -- Neovim 0.13 passes fugitive:///repo/.git//0/a.sql to detect() as it is,
  -- and earlier versions as <cwd>/fugitive:/repo/.git/0/a.sql, so this takes
  -- the path after the scheme from either.
  local scheme = "^%a[%w+.-]*:"
  local url = path:match(scheme .. "(//.*)$")
  if not url and vim.fn.has("nvim-0.13") == 0 then
    local rel = vim.fs.relpath(assert(vim.uv.cwd()), path)
    url = rel and rel:match(scheme .. "(/.*)$")
  end
  return vim.fs.normalize(url or vim.fs.abspath(path))
end

---@param path string
---@return string?
function M.root(path)
  -- Compiled output holds a directory of that name, so only a file counts.
  local project = vim.fs.find("dbt_project.yml", { upward = true, type = "file", path = vim.fs.dirname(path) })[1]
  return project and vim.fs.dirname(project)
end

---@param item string
---@return string
local function unquote(item)
  return (vim.trim(item):gsub("^(['\"])(.*)%1$", "%2"))
end

---@param root string
---@return table<string, string[]> paths each source `*-paths` key and its directories
---@return string packages the directory dbt installs packages into
function M.paths(root)
  local ok, lines = pcall(vim.fn.readfile, vim.fs.joinpath(root, "dbt_project.yml"))
  local found, list, packages = {}, nil, "dbt_packages"
  for _, line in ipairs(ok and lines or {}) do
    line = line:gsub("^#.*", ""):gsub("%s#.*", "")
    local key, value = line:match("^([%w%-]+):%s*(.-)%s*$")
    key = renamed[key] or key
    local install = key == "packages-install-path" and unquote(value)
    if install and install ~= "" then
      packages = install
    end
    local item = line:match("^%s*%-%s*(.-)%s*$")
    if source_paths[key] then
      list = {}
      found[key] = list
      for each in value:gsub("^%[(.*)%]$", "%1"):gmatch("[^,]+") do
        list[#list + 1] = unquote(each)
      end
    elseif list and item and not key then
      list[#list + 1] = unquote(item)
    elseif line:match("^%S") then
      list = nil
    end
  end
  for key, default in pairs(source_paths) do
    if not found[key] or #found[key] == 0 then
      found[key] = vim.list_slice(default)
    end
  end
  return found, packages
end

---@param path string
---@return string?
function M.detect(path)
  path = local_path(path)
  local root = M.root(path)
  if not root or vim.fs.relpath(vim.fs.joinpath(root, "target"), path) then
    return nil
  end
  return "dbt"
end

---@param buf integer
---@return string?
function M.buf_path(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  return name ~= "" and local_path(name) or nil
end

---@param option string
---@return boolean
function M.enabled(option)
  local value = vim.g[option]
  return value ~= false and value ~= 0
end

return M
