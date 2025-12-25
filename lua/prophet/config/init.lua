local M = {}

local function find_dw_config()
  -- Search for dw.json in current working directory
  local cwd = vim.fn.getcwd()
  local dw_json_path = cwd .. "/dw.json"
  
  if vim.fn.filereadable(dw_json_path) == 1 then
    return dw_json_path
  end
  
  -- Try dw.js as fallback
  local dw_js_path = cwd .. "/dw.js"
  if vim.fn.filereadable(dw_js_path) == 1 then
    return dw_js_path
  end
  
  return nil
end

local function parse_json_file(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return nil
  end
  
  local content = file:read("*a")
  file:close()
  
  -- Remove comments from JSON (simple implementation)
  content = content:gsub("//[^\n]*", "")
  content = content:gsub("/%*.-%*/", "")
  
  local ok, decoded = pcall(vim.json.decode, content)
  if not ok then
    vim.notify("Prophet: Failed to parse " .. filepath, vim.log.levels.ERROR)
    return nil
  end
  
  return decoded
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
  
  -- Validate required fields
  if not config.hostname or not config.username or not config.password then
    vim.notify("Prophet: dw.json missing required fields (hostname, username, password)", vim.log.levels.ERROR)
    return nil
  end
  
  -- Set defaults
  config["code-version"] = config["code-version"] or "version1"
  
  return config
end

function M.get_cartridges()
  local cwd = vim.fn.getcwd()
  local cartridges = {}
  
  -- Look for directories ending with _cartridges
  local dirs = vim.fn.glob(cwd .. "/*_cartridges", false, true)
  
  for _, dir in ipairs(dirs) do
    if vim.fn.isdirectory(dir) == 1 then
      -- Get subdirectories (actual cartridges)
      local subdirs = vim.fn.glob(dir .. "/*", false, true)
      for _, subdir in ipairs(subdirs) do
        if vim.fn.isdirectory(subdir) == 1 then
          local cartridge_name = vim.fn.fnamemodify(subdir, ":t")
          -- Check if it has a .project file or cartridge structure
          if vim.fn.filereadable(subdir .. "/.project") == 1 or 
             vim.fn.isdirectory(subdir .. "/cartridge") == 1 then
            table.insert(cartridges, {
              name = cartridge_name,
              path = subdir,
            })
          end
        end
      end
    end
  end
  
  return cartridges
end

return M
