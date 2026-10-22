local M = {}

---@param path string
---@return string?
function M.detect(path)
  -- Neovim passes fugitive:///repo/.git//0/a.sql here as
  -- <cwd>/fugitive:/repo/.git/0/a.sql, so this takes the path after the scheme.
  local rel = vim.fs.relpath(assert(vim.uv.cwd()), path)
  path = rel and rel:match("^%a[%w+.-]*:(/.*)$") or vim.fs.normalize(vim.fs.abspath(path))
  -- Compiled output holds a directory of that name, so only a file counts.
  local project = vim.fs.find("dbt_project.yml", { upward = true, type = "file", path = vim.fs.dirname(path) })[1]
  if not project or vim.fs.relpath(vim.fs.joinpath(vim.fs.dirname(project), "target"), path) then
    return nil
  end
  return "dbt"
end

return M
