local M = {}

local uploader = require("prophet.uploader")
local config = require("prophet.config")

M.config = {
  auto_upload = false,
  clean_on_start = true,
  notify = true,
  ignore_patterns = { "node_modules", "%.git", "%.zip$" },
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  local dw = config.load()
  if not dw then
    vim.notify("Prophet: No dw.json found", vim.log.levels.WARN)
    return
  end
  uploader.init(dw, M.config)
  if M.config.clean_on_start then vim.defer_fn(M.clean_upload, 1000) end
  if M.config.auto_upload then uploader.enable_watch() end
end

function M.enable_upload()
  M.config.auto_upload = true
  uploader.enable_watch()
end

function M.disable_upload()
  M.config.auto_upload = false
  uploader.disable_watch()
  vim.notify("Prophet: Upload disabled", vim.log.levels.INFO)
end

function M.toggle_upload()
  if M.config.auto_upload then M.disable_upload() else M.enable_upload() end
end

function M.clean_upload()
  local dw = config.load()
  if not dw then
    vim.notify("Prophet: No dw.json found", vim.log.levels.ERROR)
    return
  end
  uploader.clean_upload(dw, M.config)
end

function M.upload_cartridge(name)
  local dw = config.load()
  if not dw then
    vim.notify("Prophet: No dw.json found", vim.log.levels.ERROR)
    return
  end
  uploader.upload_single(dw, name, M.config)
end

return M
