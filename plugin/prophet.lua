if vim.g.loaded_prophet then
  return
end
vim.g.loaded_prophet = 1

-- Create commands
vim.api.nvim_create_user_command("ProphetEnable", function()
  require("prophet").enable_upload()
end, { desc = "Enable Prophet auto-upload" })

vim.api.nvim_create_user_command("ProphetDisable", function()
  require("prophet").disable_upload()
end, { desc = "Disable Prophet auto-upload" })

vim.api.nvim_create_user_command("ProphetToggle", function()
  require("prophet").toggle_upload()
end, { desc = "Toggle Prophet auto-upload" })

vim.api.nvim_create_user_command("ProphetClean", function()
  require("prophet").clean_upload()
end, { desc = "Clean upload all cartridges" })

vim.api.nvim_create_user_command("ProphetUpload", function(opts)
  if opts.args and opts.args ~= "" then
    require("prophet").upload_cartridge(opts.args)
  else
    vim.notify("Prophet: Please specify a cartridge name", vim.log.levels.WARN)
  end
end, {
  nargs = "?",
  desc = "Upload a specific cartridge",
  complete = function()
    local config = require("prophet.config")
    local cartridges = config.get_cartridges()
    local names = {}
    for _, c in ipairs(cartridges) do
      table.insert(names, c.name)
    end
    return names
  end,
})

-- Keymaps are NOT set by default to avoid conflicts
-- Users can set them via the setup() function or manually
-- See :h prophet-keymaps for recommended keybindings
