local M = {}

-- Simple default configuration
M.config = {
  auto_upload = false,
  clean_on_start = true,
  notify = true,
  ignore_patterns = {
    "node_modules",
    "%.git",
    "%.zip$",
  },
}

local uploader = require("prophet.uploader")
local config_loader = require("prophet.config")

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  
  -- Load dw.json configuration
  local dw_config = config_loader.load()
  if not dw_config then
    vim.notify("Prophet: No dw.json found in project root", vim.log.levels.WARN)
    return
  end
  
  -- Initialize uploader
  uploader.init(dw_config, M.config)
  
  -- Auto clean on start if enabled
  if M.config.clean_on_start then
    vim.defer_fn(function()
      M.clean_upload()
    end, 1000)
  end
  
  -- Setup file watchers if auto upload is enabled
  if M.config.auto_upload then
    M.enable_upload()
  end
end

function M.enable_upload()
  M.config.auto_upload = true
  uploader.enable_watch()
  vim.notify("Prophet: Upload enabled", vim.log.levels.INFO)
end

function M.disable_upload()
  M.config.auto_upload = false
  uploader.disable_watch()
  vim.notify("Prophet: Upload disabled", vim.log.levels.INFO)
end

function M.toggle_upload()
  if M.config.auto_upload then
    M.disable_upload()
  else
    M.enable_upload()
  end
end

function M.clean_upload()
  local dw_config = config_loader.load()
  if not dw_config then
    vim.notify("Prophet: No dw.json found", vim.log.levels.ERROR)
    return
  end
  
  uploader.clean_upload(dw_config, M.config)
end

function M.upload_cartridge(cartridge_name)
  local dw_config = config_loader.load()
  if not dw_config then
    vim.notify("Prophet: No dw.json found", vim.log.levels.ERROR)
    return
  end
  
  uploader.upload_single(dw_config, cartridge_name, M.config)
end

return M
