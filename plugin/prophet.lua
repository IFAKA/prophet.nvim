if vim.g.loaded_prophet then
  return
end
vim.g.loaded_prophet = 1

local prophet = require("prophet")

-- Create user commands to match SqrTT/prophet functionality
vim.api.nvim_create_user_command("ProphetEnable", function()
  prophet.enable_upload()
end, { desc = "Prophet: Enable Upload" })

vim.api.nvim_create_user_command("ProphetDisable", function()
  prophet.disable_upload()
end, { desc = "Prophet: Disable Upload" })

vim.api.nvim_create_user_command("ProphetToggle", function()
  prophet.toggle_upload()
end, { desc = "Prophet: Toggle Upload" })

vim.api.nvim_create_user_command("ProphetClean", function()
  prophet.clean_upload()
end, { desc = "Prophet: Clean Project/Upload All" })

vim.api.nvim_create_user_command("ProphetUpload", function(opts)
  if opts.args and opts.args ~= "" then
    prophet.upload_cartridge(opts.args)
  else
    -- Show cartridge picker
    local config_loader = require("prophet.config")
    local cartridges = config_loader.get_cartridges()
    if #cartridges == 0 then
      vim.notify("Prophet: No cartridges found", vim.log.levels.WARN)
      return
    end
    
    local choices = {}
    for _, cartridge in ipairs(cartridges) do
      table.insert(choices, cartridge.name)
    end
    
    vim.ui.select(choices, {
      prompt = "Select cartridge to upload:",
    }, function(choice)
      if choice then
        prophet.upload_cartridge(choice)
      end
    end)
  end
end, {
  desc = "Prophet: Upload Single Cartridge",
  nargs = "?",
  complete = function()
    local config_loader = require("prophet.config")
    local cartridges = config_loader.get_cartridges()
    local names = {}
    for _, cartridge in ipairs(cartridges) do
      table.insert(names, cartridge.name)
    end
    return names
  end
})

vim.api.nvim_create_user_command("ProphetStatus", function()
  local config_loader = require("prophet.config")
  local debugger = require("prophet.debugger")
  local dw_config = config_loader.load()
  local cartridges = config_loader.get_cartridges()
  local debug_status = debugger.get_status()
  
  local lines = {
    "Prophet Status",
    "==============",
    "",
    string.format("Configuration: %s", dw_config and "✓ Found" or "✗ Missing"),
  }
  
  if dw_config then
    table.insert(lines, string.format("Hostname: %s", dw_config.hostname))
    table.insert(lines, string.format("Username: %s", dw_config.username))
    table.insert(lines, string.format("Code Version: %s", dw_config["code-version"]))
  end
  
  table.insert(lines, "")
  table.insert(lines, string.format("Cartridges Found: %d", #cartridges))
  
  if #cartridges > 0 then
    table.insert(lines, "")
    table.insert(lines, "Cartridges:")
    for i, cartridge in ipairs(cartridges) do
      table.insert(lines, string.format("  %d. %s", i, cartridge.name))
    end
  end
  
  table.insert(lines, "")
  table.insert(lines, string.format("Debug Support: %s", debug_status.supported and "✓ Available" or "✗ Not Available"))
  table.insert(lines, string.format("Debug State: %s", debug_status.state))
  
  if dw_config then
    table.insert(lines, "")
    table.insert(lines, "Sandbox Status: Checking...")
    
    -- Create buffer first
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(buf, "filetype", "prophet")
    
    -- Open in a split
    vim.cmd("split")
    vim.api.nvim_win_set_buf(0, buf)
    vim.api.nvim_buf_set_name(buf, "Prophet Status " .. os.time())
    
    -- Check sandbox status asynchronously and update buffer
    config_loader.check_sandbox_status(dw_config, function(success, message)
      local status_line = string.format("Sandbox Status: %s %s", 
        success and "✓" or "✗", message)
      
      -- Update the last line with sandbox status
      if vim.api.nvim_buf_is_valid(buf) then
        local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        current_lines[#current_lines] = status_line
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, current_lines)
      end
    end)
  else
    -- Create a scratch buffer to display status
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(buf, "filetype", "prophet")
    
    -- Open in a split
    vim.cmd("split")
    vim.api.nvim_win_set_buf(0, buf)
    vim.api.nvim_buf_set_name(buf, "Prophet Status " .. os.time())
  end
end, { desc = "Prophet: Show Status" })

-- Debug commands (placeholder for future SDAPI 2.0 implementation)
vim.api.nvim_create_user_command("ProphetDebugConnect", function()
  local debugger = require("prophet.debugger")
  debugger.connect()
end, { desc = "Prophet: Connect Debugger" })

vim.api.nvim_create_user_command("ProphetDebugDisconnect", function()
  local debugger = require("prophet.debugger")
  debugger.disconnect()
end, { desc = "Prophet: Disconnect Debugger" })

vim.api.nvim_create_user_command("ProphetDebugBreakpoint", function()
  local debugger = require("prophet.debugger")
  local file = vim.fn.expand("%:p")
  local line = vim.fn.line(".")
  debugger.set_breakpoint(file, line)
end, { desc = "Prophet: Toggle Breakpoint" })

vim.api.nvim_create_user_command("ProphetCheckSandbox", function()
  local config_loader = require("prophet.config")
  local dw_config = config_loader.load()
  
  if not dw_config then
    vim.notify("Prophet: No dw.json found", vim.log.levels.ERROR)
    return
  end
  
  vim.notify("Prophet: Checking sandbox connectivity...", vim.log.levels.INFO)
  
  config_loader.check_sandbox_status(dw_config, function(success, message)
    local level = success and vim.log.levels.INFO or vim.log.levels.ERROR
    local status = success and "✓" or "✗"
    vim.notify(string.format("Prophet: %s %s", status, message), level)
  end)
end, { desc = "Prophet: Check Sandbox Status" })

-- Auto-commands for file watching and SFCC file detection
vim.api.nvim_create_augroup("ProphetAutoCommands", { clear = true })

-- Auto-detect SFCC files and set appropriate options
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
  group = "ProphetAutoCommands",
  pattern = {"*.isml", "*.ds"},
  callback = function()
    -- Set basic options for SFCC files
    vim.bo.expandtab = true
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
  end,
})

-- Set filetype for ISML files
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
  group = "ProphetAutoCommands",
  pattern = "*.isml",
  callback = function()
    vim.bo.filetype = "isml"
    vim.bo.syntax = "isml"  -- Use custom ISML syntax if available
  end,
})

-- Set filetype for DWScript files
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
  group = "ProphetAutoCommands",
  pattern = "*.ds",
  callback = function()
    vim.bo.filetype = "ds"
    vim.bo.syntax = "ds"  -- Use custom DWScript syntax if available
  end,
})
