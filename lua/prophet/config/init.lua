local M = {}

local function is_cartridge_project(project_file)
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
  content = content:gsub("//[^\n]*", ""):gsub("/%*.-%*/", "")
  local ok, decoded = pcall(vim.json.decode, content)
  if not ok then
    vim.notify("Prophet: Failed to parse " .. filepath, vim.log.levels.ERROR)
    return nil
  end
  return decoded
end

function M.load()
  local config_path = find_dw_config()
  if not config_path then return nil end

  local config = parse_json_file(config_path)
  if not config then return nil end

  -- Validate required fields
  for _, field in ipairs({ "hostname", "username", "password" }) do
    if not config[field] or config[field] == "" then
      vim.notify("Prophet: dw.json missing " .. field, vim.log.levels.ERROR)
      return nil
    end
  end

  -- Normalize config
  config["code-version"] = config["code-version"] or "version1"
  if config.cartridgePath and config.cartridgePath ~= "" then
    config.cartridge = vim.split(config.cartridgePath, ":", { plain = true })
  end
  config.cartridge = config.cartridge or {}
  if type(config.cartridge) == "string" then
    config.cartridge = { config.cartridge }
  end

  return config
end

-- Cache to avoid repeated slow scans
local cartridge_cache, cache_cwd = nil, nil

function M.get_cartridges()
  local cwd = vim.fn.getcwd()
  if cartridge_cache and cache_cwd == cwd then
    return cartridge_cache
  end

  local cartridges = {}
  local excludes = "node_modules .git dist build .next .nuxt coverage .cache tmp .tmp logs vendor .svn"
  local exclude_args = {}
  for dir in excludes:gmatch("%S+") do
    table.insert(exclude_args, string.format("-not -path '*/%s/*'", dir))
  end

  local find_cmd = string.format("find %s -name '.project' -type f %s 2>/dev/null",
    vim.fn.shellescape(cwd), table.concat(exclude_args, " "))

  for _, project_file in ipairs(vim.split(vim.fn.system(find_cmd), "\n", { trimempty = true })) do
    if is_cartridge_project(project_file) then
      local dir = vim.fn.fnamemodify(project_file, ":h")
      table.insert(cartridges, { name = vim.fn.fnamemodify(dir, ":t"), path = dir })
    end
  end

  -- Fallback for legacy *_cartridges pattern
  if #cartridges == 0 then
    for _, dir in ipairs(vim.fn.glob(cwd .. "/*_cartridges", false, true)) do
      if vim.fn.isdirectory(dir) == 1 then
        for _, subdir in ipairs(vim.fn.glob(dir .. "/*", false, true)) do
          if vim.fn.isdirectory(subdir) == 1 and
             (vim.fn.filereadable(subdir .. "/.project") == 1 or vim.fn.isdirectory(subdir .. "/cartridge") == 1) then
            table.insert(cartridges, { name = vim.fn.fnamemodify(subdir, ":t"), path = subdir })
          end
        end
      end
    end
  end

  cartridge_cache, cache_cwd = cartridges, cwd
  return cartridges
end

function M.clear_cache()
  cartridge_cache, cache_cwd = nil, nil
end

-- Shared curl error code mapping
local function get_error_message(exit_code)
  local errors = {
    [0] = "Sandbox is online and accessible",
    [7] = "Cannot connect to sandbox - check hostname and network",
    [22] = "Authentication failed - check credentials",
    [28] = "Connection timeout - sandbox may be starting up",
    [56] = "Network receive error - check WebDAV permissions",
  }
  return errors[exit_code] or string.format("Failed (exit code %d)", exit_code)
end

local function build_sandbox_check_cmd(dw_config)
  local url = string.format("https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s/",
    dw_config.hostname, dw_config["code-version"] or "version1")
  return string.format("curl -s --max-time 10 -X PROPFIND -H 'Depth: 1' -u %s:%s %s",
    vim.fn.shellescape(dw_config.username), vim.fn.shellescape(dw_config.password),
    vim.fn.shellescape(url))
end

function M.check_sandbox_status(dw_config, callback)
  if not dw_config then
    callback(false, "No dw.json configuration found")
    return
  end
  vim.fn.jobstart(build_sandbox_check_cmd(dw_config), {
    on_exit = function(_, exit_code)
      callback(exit_code == 0, get_error_message(exit_code))
    end,
    on_stdout = function() end,
    on_stderr = function() end,
  })
end

function M.check_sandbox_status_sync(dw_config)
  if not dw_config then
    return false, "No dw.json configuration found"
  end
  vim.fn.system(build_sandbox_check_cmd(dw_config))
  local exit_code = vim.v.shell_error
  return exit_code == 0, get_error_message(exit_code)
end

return M
