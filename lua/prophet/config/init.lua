local M = {}

local function is_cartridge_project(project_file)
  if vim.fn.filereadable(project_file) ~= 1 then
    return false
  end
  
  local file = io.open(project_file, "r")
  if not file then return false end
  
  local content = file:read("*a")
  file:close()
  
  return content:find("com%.demandware%.studio%.core%.beehiveNature") ~= nil
end

local function find_dw_config()
  local cwd = vim.fn.getcwd()
  for _, file in ipairs({ "dw.json", "dw.js" }) do
    local path = cwd .. "/" .. file
    if vim.fn.filereadable(path) == 1 then return path end
  end
  return nil
end

local function parse_json_file(filepath)
  local file = io.open(filepath, "r")
  if not file then return nil end
  
  local content = file:read("*a")
  file:close()
  
  -- Remove JSON comments
  content = content:gsub("//[^\n]*", ""):gsub("/%*.-%*/", "")
  
  local ok, decoded = pcall(vim.json.decode, content)
  if not ok then
    vim.notify("Prophet: Failed to parse " .. filepath, vim.log.levels.ERROR)
    return nil
  end
  return decoded
end

local function validate_config(config)
  local required_fields = { "hostname", "username", "password" }
  local missing = {}
  
  for _, field in ipairs(required_fields) do
    if not config[field] or config[field] == "" then
      table.insert(missing, field)
    end
  end
  
  if #missing > 0 then
    vim.notify("Prophet: dw.json missing required fields: " .. table.concat(missing, ", "), vim.log.levels.ERROR)
    return false
  end
  
  -- Validate hostname format
  if not config.hostname:match("^[%w%-%.]+$") then
    vim.notify("Prophet: Invalid hostname format in dw.json", vim.log.levels.ERROR)
    return false
  end
  
  return true
end

local function normalize_config(config)
  -- Set defaults
  config["code-version"] = config["code-version"] or "version1"
  config.cartridge = config.cartridge or {}
  config.cartridgePath = config.cartridgePath or ""
  
  -- Normalize cartridge paths if specified
  if config.cartridgePath and config.cartridgePath ~= "" then
    config.cartridge = vim.split(config.cartridgePath, ":", { plain = true })
  end
  
  -- Ensure arrays
  if type(config.cartridge) == "string" then
    config.cartridge = { config.cartridge }
  end
  
  return config
end

function M.load()
  local config_path = find_dw_config()
  if not config_path then 
    return nil 
  end
  
  local config = parse_json_file(config_path)
  if not config then 
    return nil 
  end
  
  if not validate_config(config) then
    return nil
  end
  
  return normalize_config(config)
end

function M.get_cartridges()
  local cwd = vim.fn.getcwd()
  local cartridges = {}
  
  -- First, look for the SqrTT/prophet pattern: find all .project files recursively
  local project_files = vim.fn.glob(cwd .. "/**/.project", false, true)
  
  for _, project_file in ipairs(project_files) do
    if is_cartridge_project(project_file) then
      local cartridge_dir = vim.fn.fnamemodify(project_file, ":h")
      local name = vim.fn.fnamemodify(cartridge_dir, ":t")
      table.insert(cartridges, { name = name, path = cartridge_dir })
    end
  end
  
  -- Fallback: also check the old pattern for backwards compatibility
  if #cartridges == 0 then
    for _, dir in ipairs(vim.fn.glob(cwd .. "/*_cartridges", false, true)) do
      if vim.fn.isdirectory(dir) == 1 then
        for _, subdir in ipairs(vim.fn.glob(dir .. "/*", false, true)) do
          if vim.fn.isdirectory(subdir) == 1 then
            local name = vim.fn.fnamemodify(subdir, ":t")
            if vim.fn.filereadable(subdir .. "/.project") == 1 or 
               vim.fn.isdirectory(subdir .. "/cartridge") == 1 then
              table.insert(cartridges, { name = name, path = subdir })
            end
          end
        end
      end
    end
  end
  
  return cartridges
end

return M
