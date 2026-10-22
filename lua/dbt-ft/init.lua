local M = {}

---Returns `"dbt"` for a `.sql` file in a dbt project, or nothing for dbt's compiled output and for
---files outside a project, which leaves them to Neovim's own detection.
---@param path string
---@return string?
function M.detect(path)
  path = vim.fs.normalize(vim.fs.abspath(path))
  for dir in vim.fs.parents(path) do
    local stat = vim.uv.fs_stat(vim.fs.joinpath(dir, "dbt_project.yml"))
    -- Compiled output holds a directory of that name, so only a file marks a project.
    if stat and stat.type == "file" then
      if vim.startswith(path, vim.fs.joinpath(dir, "target") .. "/") then
        return nil
      end
      return "dbt"
    end
  end
end

return M
