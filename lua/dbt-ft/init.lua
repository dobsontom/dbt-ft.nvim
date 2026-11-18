local M = {}

---@param path string
---@return string
local function local_path(path)
  -- Neovim 0.13 passes fugitive:///repo/.git//0/a.sql to detect() as it is,
  -- and earlier versions as <cwd>/fugitive:/repo/.git/0/a.sql, so this takes
  -- the path after the scheme from either.
  local rel = vim.fn.has("nvim-0.13") == 0 and vim.fs.relpath(assert(vim.uv.cwd()), path)
  local url = path:match("^%a[%w+.-]*:(//.*)$") or rel and rel:match("^%a[%w+.-]*:(/.*)$")
  return vim.fs.normalize(url or vim.fs.abspath(path))
end

---@param path string
---@return string?
function M.root(path)
  -- Compiled output holds a directory of that name, so only a file counts.
  local project = vim.fs.find("dbt_project.yml", { upward = true, type = "file", path = vim.fs.dirname(path) })[1]
  return project and vim.fs.dirname(project)
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
