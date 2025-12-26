if vim.g.loaded_prophet then return end
vim.g.loaded_prophet = 1

local prophet = require("prophet")
local config = require("prophet.config")
local debugger = require("prophet.debugger")

-- Commands
vim.api.nvim_create_user_command("ProphetEnable", prophet.enable_upload, { desc = "Enable upload watching" })
vim.api.nvim_create_user_command("ProphetDisable", prophet.disable_upload, { desc = "Disable upload watching" })
vim.api.nvim_create_user_command("ProphetToggle", prophet.toggle_upload, { desc = "Toggle upload watching" })
vim.api.nvim_create_user_command("ProphetClean", prophet.clean_upload, { desc = "Upload all cartridges" })

vim.api.nvim_create_user_command("ProphetUpload", function(opts)
  if opts.args ~= "" then
    prophet.upload_cartridge(opts.args)
    return
  end
  local cartridges = config.get_cartridges()
  if #cartridges == 0 then
    vim.notify("Prophet: No cartridges found", vim.log.levels.WARN)
    return
  end
  vim.ui.select(vim.tbl_map(function(c) return c.name end, cartridges), { prompt = "Upload:" }, function(choice)
    if choice then prophet.upload_cartridge(choice) end
  end)
end, {
  desc = "Upload cartridge",
  nargs = "?",
  complete = function()
    return vim.tbl_map(function(c) return c.name end, config.get_cartridges())
  end,
})

vim.api.nvim_create_user_command("ProphetStatus", function()
  local dw = config.load()
  local cartridges = config.get_cartridges()
  local status = debugger.get_status()

  local lines = { "Prophet Status", "==============" }
  if dw then
    table.insert(lines, string.format("Host: %s | User: %s | Version: %s", dw.hostname, dw.username, dw["code-version"]))
  else
    table.insert(lines, "Config: Not found")
  end
  table.insert(lines, string.format("Cartridges: %d | Debug: %s", #cartridges, status.state))

  if #cartridges > 0 then
    table.insert(lines, "")
    for i, c in ipairs(cartridges) do table.insert(lines, string.format("  %d. %s", i, c.name)) end
  end

  if dw then
    table.insert(lines, "")
    table.insert(lines, "Sandbox: checking...")
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = "nofile"
  vim.cmd("split")
  vim.api.nvim_win_set_buf(0, buf)

  if dw then
    config.check_sandbox_status(dw, function(ok, msg)
      if vim.api.nvim_buf_is_valid(buf) then
        local l = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        l[#l] = string.format("Sandbox: %s %s", ok and "online" or "offline", msg)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, l)
      end
    end)
  end
end, { desc = "Show status" })

vim.api.nvim_create_user_command("ProphetCheckSandbox", function()
  local dw = config.load()
  if not dw then
    vim.notify("Prophet: No dw.json found", vim.log.levels.ERROR)
    return
  end
  vim.notify("Prophet: Checking sandbox...", vim.log.levels.INFO)
  config.check_sandbox_status(dw, function(ok, msg)
    vim.notify(string.format("Prophet: %s", msg), ok and vim.log.levels.INFO or vim.log.levels.ERROR)
  end)
end, { desc = "Check sandbox" })

-- Debug commands (placeholder)
vim.api.nvim_create_user_command("ProphetDebugConnect", debugger.connect, { desc = "Connect debugger" })
vim.api.nvim_create_user_command("ProphetDebugDisconnect", debugger.disconnect, { desc = "Disconnect debugger" })
vim.api.nvim_create_user_command("ProphetDebugBreakpoint", function()
  debugger.set_breakpoint(vim.fn.expand("%:p"), vim.fn.line("."))
end, { desc = "Set breakpoint" })

-- Autocommands for SFCC files
vim.api.nvim_create_augroup("Prophet", { clear = true })
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = "Prophet",
  pattern = { "*.isml", "*.ds" },
  callback = function()
    vim.bo.expandtab = true
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
    local ext = vim.fn.expand("%:e")
    vim.bo.filetype = ext
    vim.bo.syntax = ext
  end,
})
