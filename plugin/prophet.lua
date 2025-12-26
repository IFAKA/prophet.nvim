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

-- Setup keymaps (works with which-key)
-- These will auto-register if which-key is installed
vim.schedule(function()
  local has_wk, wk = pcall(require, "which-key")
  
  if has_wk then
    -- Register with which-key (VimZap style)
    wk.add({
      { "<leader>p", group = "prophet" },
      { "<leader>pe", "<cmd>ProphetEnable<cr>", desc = "enable auto-upload" },
      { "<leader>pd", "<cmd>ProphetDisable<cr>", desc = "disable auto-upload" },
      { "<leader>pt", "<cmd>ProphetToggle<cr>", desc = "toggle auto-upload" },
      { "<leader>pc", "<cmd>ProphetClean<cr>", desc = "clean upload all" },
    })
  else
    -- Fallback: set keymaps directly
    vim.keymap.set("n", "<leader>pe", "<cmd>ProphetEnable<cr>", { desc = "Prophet: Enable auto-upload" })
    vim.keymap.set("n", "<leader>pd", "<cmd>ProphetDisable<cr>", { desc = "Prophet: Disable auto-upload" })
    vim.keymap.set("n", "<leader>pt", "<cmd>ProphetToggle<cr>", { desc = "Prophet: Toggle auto-upload" })
    vim.keymap.set("n", "<leader>pc", "<cmd>ProphetClean<cr>", { desc = "Prophet: Clean upload all" })
  end
end)
