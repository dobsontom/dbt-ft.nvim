local M = {}

---@param root string
---@return string
function M.path(root)
  local paths, packages = require("dbt-ft").paths(root)
  local dirs = paths["model-paths"]
  dirs[#dirs + 1] = vim.fs.joinpath(packages, "*/models")
  for i, dir in ipairs(dirs) do
    dirs[i] = vim.fn.escape(vim.fs.joinpath(root, dir), "\\ ,") .. "/**"
  end
  return table.concat(dirs, ",")
end

---@return string
function M.includeexpr()
  local line, col = vim.api.nvim_get_current_line(), vim.fn.col(".")
  for from, args, to in line:gmatch("()%f[%w_]ref%s*(%b())()") do
    if from <= col and col < to then
      local _, model = args:match(".*[(,]%s*(['\"])(.-)%1")
      return model or vim.v.fname
    end
  end
  return vim.v.fname
end

return M
