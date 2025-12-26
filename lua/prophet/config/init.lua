-- Copy of the original file with the fixed functions
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

-- Cache cartridges to avoid repeated slow scans
local cartridge_cache = nil
local cache_cwd = nil

function M.get_cartridges()
  local cwd = vim.fn.getcwd()

  -- Return cached result if same directory
  if cartridge_cache and cache_cwd == cwd then
    return cartridge_cache
  end

  local cartridges = {}

  -- Use find command with exclusions (much faster than vim.fn.glob)
  local excludes = {
    "node_modules", ".git", "dist", "build", ".next", ".nuxt",
    "coverage", ".cache", "tmp", ".tmp", "logs", "vendor", ".svn",
  }
  local exclude_args = {}
  for _, dir in ipairs(excludes) do
    table.insert(exclude_args, string.format("-not -path '*/%s/*'", dir))
  end
  local find_cmd = string.format(
    "find %s -name '.project' -type f %s 2>/dev/null",
    vim.fn.shellescape(cwd), table.concat(exclude_args, " ")
  )
  local result = vim.fn.system(find_cmd)
  local project_files = vim.split(result, "\n", { trimempty = true })

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

  -- Cache result
  cartridge_cache = cartridges
  cache_cwd = cwd

  return cartridges
end

-- Clear cache (call when cartridges might have changed)
function M.clear_cache()
  cartridge_cache = nil
  cache_cwd = nil
end

function M.check_sandbox_status(dw_config, callback)
  if not dw_config then
    callback(false, "No dw.json configuration found")
    return
  end
  
  -- Use exact VSCode Prophet PROPFIND approach for connectivity check
  local code_version = dw_config["code-version"] or "version1"
  local check_url = string.format("https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s/", 
    dw_config.hostname, code_version)
  
  local check_cmd = string.format(
    "curl -s --max-time 10 -X PROPFIND -H 'Depth: 1' -u %s:%s %s",
    vim.fn.shellescape(dw_config.username),
    vim.fn.shellescape(dw_config.password),
    vim.fn.shellescape(check_url)
  )
  
  vim.fn.jobstart(check_cmd, {
    on_exit = function(_, exit_code)
      if exit_code == 0 then
        callback(true, "Sandbox is online and accessible")
      elseif exit_code == 7 then
        callback(false, "Cannot connect to sandbox - check hostname and network connection")
      elseif exit_code == 22 then
        callback(false, "Authentication failed - check username and password in dw.json")
      elseif exit_code == 28 then
        callback(false, "Connection timeout - sandbox may be starting up or overloaded")
      elseif exit_code == 56 then
        callback(false, "Network receive error - check credentials and WebDAV permissions")
      else
        callback(false, string.format("Sandbox check failed (exit code %d) - sandbox may be offline", exit_code))
      end
    end,
    on_stdout = function() end, -- Ignore output
    on_stderr = function() end, -- Ignore errors (we handle via exit code)
  })
end

function M.check_sandbox_status_sync(dw_config)
  if not dw_config then
    return false, "No dw.json configuration found"
  end
  
  -- Use exact VSCode Prophet PROPFIND approach for connectivity check
  local code_version = dw_config["code-version"] or "version1"
  local check_url = string.format("https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s/", 
    dw_config.hostname, code_version)
  
  local check_cmd = string.format(
    "curl -s --max-time 10 -X PROPFIND -H 'Depth: 1' -u %s:%s %s",
    vim.fn.shellescape(dw_config.username),
    vim.fn.shellescape(dw_config.password),
    vim.fn.shellescape(check_url)
  )
  
  local result = vim.fn.system(check_cmd)
  local exit_code = vim.v.shell_error
  
  if exit_code == 0 then
    return true, "Sandbox is online and accessible"
  elseif exit_code == 7 then
    return false, "Cannot connect to sandbox - check hostname and network connection"
  elseif exit_code == 22 then
    return false, "Authentication failed - check username and password in dw.json"
  elseif exit_code == 28 then
    return false, "Connection timeout - sandbox may be starting up or overloaded"
  elseif exit_code == 56 then
    return false, "Network receive error - check credentials and WebDAV permissions"
  else
    return false, string.format("Sandbox check failed (exit code %d) - sandbox may be offline", exit_code)
  end
end

return M