local M = {}

local url = "https://raw.githubusercontent.com/dbt-labs/dbt-jsonschema/main/schemas/latest_fusion/%s-latest-fusion.json"

-- SchemaStore's patterns for dbt's schemas.
local files = {
  catalogs = { "catalogs" },
  dbt_project = { "dbt_project" },
  dbt_yml_files = { "macros/**/*", "models/**/*", "seeds/**/*", "snapshots/**/*" },
  dependencies = { "dependencies" },
  packages = { "packages" },
  selectors = { "selectors" },
}

---@param client vim.lsp.Client
---@param buf integer
function M.attach(client, buf)
  local dbt_ft = require("dbt-ft")
  local server = client.server_info and client.server_info.name
  -- yaml-language-server reports its name only from 1.20.0.
  if (server ~= "yaml-language-server" and client.name ~= "yamlls") or not dbt_ft.enabled("dbt_ft_yaml_schemas") then
    return
  end
  local file = dbt_ft.buf_path(buf)
  local root = file and dbt_ft.root(file)
  if not root then
    return
  end
  local settings = vim.deepcopy(client.settings) --[[@as table]]
  settings.yaml = settings.yaml or {}
  settings.yaml.schemas = settings.yaml.schemas or {}
  local schemas = settings.yaml.schemas
  local added = false
  for schema, stems in pairs(files) do
    local key = url:format(schema)
    local mapped = schemas[key]
    mapped = type(mapped) == "string" and { mapped } or mapped or {}
    for _, stem in ipairs(stems) do
      for _, ext in ipairs({ ".yaml", ".yml" }) do
        -- yaml-language-server strips a glob's leading `/` and puts `**/`
        -- before it, so only the project's full path keeps the schemas to it.
        local path = vim.fs.joinpath(root, stem .. ext)
        if not vim.list_contains(mapped, path) then
          mapped[#mapped + 1] = path
          added = true
        end
      end
    end
    schemas[key] = mapped
  end
  if added then
    client.settings = settings
    client:notify("workspace/didChangeConfiguration", { settings = settings })
  end
end

return M
