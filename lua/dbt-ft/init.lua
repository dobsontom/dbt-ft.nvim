local M = {}

---Returns `"dbt"` for a `.sql` file in a dbt project, or nothing for dbt's compiled output and for
---files outside a project, which leaves them to Neovim's own detection.
---@param path string
---@return string?
function M.detect(path)
  path = vim.fs.normalize(vim.fs.abspath(path))
  -- Compiled output holds a directory of that name, so only a file marks a project.
  local project = vim.fs.find("dbt_project.yml", { upward = true, type = "file", path = vim.fs.dirname(path) })[1]
  if not project or vim.startswith(path, vim.fs.joinpath(vim.fs.dirname(project), "target") .. "/") then
    return nil
  end
  return "dbt"
end

return M
