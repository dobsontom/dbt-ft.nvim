local M = {}

---@param path string
---@return string?
function M.detect(path)
  -- Neovim 0.13 passes fugitive:///repo/.git//0/a.sql here as it is, and
  -- earlier versions as <cwd>/fugitive:/repo/.git/0/a.sql, so this takes the
  -- path after the scheme from either.
  local rel = vim.fn.has("nvim-0.13") == 0 and vim.fs.relpath(assert(vim.uv.cwd()), path)
  local url = path:match("^%a[%w+.-]*:(//.*)$") or rel and rel:match("^%a[%w+.-]*:(/.*)$")
  path = vim.fs.normalize(url or vim.fs.abspath(path))
  -- Compiled output holds a directory of that name, so only a file counts.
  local project = vim.fs.find("dbt_project.yml", { upward = true, type = "file", path = vim.fs.dirname(path) })[1]
  if not project or vim.fs.relpath(vim.fs.joinpath(vim.fs.dirname(project), "target"), path) then
    return nil
  end
  return "dbt"
end

return M
