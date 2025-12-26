local M = {}

-- SDAPI 2.0 Debugger - placeholder for future implementation
local config = require("prophet.config")

M.state = "disconnected"

function M.connect()
  local dw = config.load()
  if not dw then
    vim.notify("Prophet Debug: No dw.json found", vim.log.levels.ERROR)
    return
  end
  vim.notify("Prophet Debug: SDAPI 2.0 not yet implemented", vim.log.levels.WARN)
end

function M.disconnect()
  M.state = "disconnected"
  vim.notify("Prophet Debug: Disconnected", vim.log.levels.INFO)
end

function M.set_breakpoint(file, line)
  vim.notify(string.format("Prophet Debug: Breakpoints not yet implemented (%s:%d)", file, line), vim.log.levels.WARN)
end

function M.get_status()
  local dw = config.load()
  return {
    state = M.state,
    supported = dw and dw.hostname ~= nil,
  }
end

return M
