# Configuration Examples

## Basic Setup (Lazy.nvim)

```lua
-- In your lazy.nvim configuration
{
  "IFAKA/prophet.nvim",
  config = function()
    require("prophet").setup()
  end,
}
```

## Advanced Setup with Keymaps

```lua
-- In your lazy.nvim configuration
{
  "IFAKA/prophet.nvim",
  config = function()
    require("prophet").setup({
      auto_upload = false,
      clean_on_start = false,
      notify = true,
      progress_style = "float",
      ignore_patterns = {
        "node_modules",
        "%.git",
        "%.zip$",
        "%.DS_Store",
        "__pycache__",
      },
    })
  end,
  keys = {
    { "<leader>pe", "<cmd>ProphetEnable<cr>", desc = "Prophet: Enable auto-upload" },
    { "<leader>pd", "<cmd>ProphetDisable<cr>", desc = "Prophet: Disable auto-upload" },
    { "<leader>pt", "<cmd>ProphetToggle<cr>", desc = "Prophet: Toggle auto-upload" },
    { "<leader>pc", "<cmd>ProphetClean<cr>", desc = "Prophet: Clean upload all" },
  },
}
```

## Auto-Enable Upload for SFRA Projects

```lua
-- In your lazy.nvim configuration
{
  "IFAKA/prophet.nvim",
  config = function()
    require("prophet").setup({
      auto_upload = true,  -- Auto-enable watching
      clean_on_start = false,
      notify = true,
    })
  end,
}
```

## Clean Upload on Startup

```lua
-- In your lazy.nvim configuration
{
  "IFAKA/prophet.nvim",
  config = function()
    require("prophet").setup({
      auto_upload = false,
      clean_on_start = true,  -- Upload all cartridges on Neovim startup
      notify = true,
    })
  end,
}
```

## Sample dw.json

Place this in your SFRA project root:

```json
{
  "hostname": "your-sandbox.dx.commercecloud.salesforce.com",
  "username": "your.email@company.com",
  "password": "your-webdav-password-or-api-key",
  "code-version": "version1"
}
```

**Note**: Keep `dw.json` in `.gitignore` to avoid committing credentials!

## Integration with Which-Key

```lua
-- In your which-key.nvim configuration
{
  "<leader>p", 
  group = "Prophet",
  {
    { "<leader>pe", "<cmd>ProphetEnable<cr>", desc = "Enable auto-upload" },
    { "<leader>pd", "<cmd>ProphetDisable<cr>", desc = "Disable auto-upload" },
    { "<leader>pt", "<cmd>ProphetToggle<cr>", desc = "Toggle auto-upload" },
    { "<leader>pc", "<cmd>ProphetClean<cr>", desc = "Clean upload all" },
  },
}
```

## Custom Ignore Patterns

```lua
require("prophet").setup({
  ignore_patterns = {
    "node_modules",
    "%.git",
    "%.zip$",
    "%.log$",
    "%.swp$",
    "%.swo$",
    "__pycache__",
    "%.pyc$",
    "%.DS_Store",
    "Thumbs%.db",
    "desktop%.ini",
  },
})
```

## Usage Tips

### Development Workflow

```vim
" Start editing your SFRA project
:cd /path/to/your-sfra-project

" Enable auto-upload (watches for file changes)
:ProphetEnable

" Edit files, save - they auto-upload!
" To see status:
:messages

" When done, disable auto-upload
:ProphetDisable
```

### Production Deployment

```vim
" For one-time upload of all cartridges:
:ProphetClean

" Check upload status
:messages
```

### Upload Specific Cartridge

```vim
" Upload just one cartridge
:ProphetUpload app_custom_kiwoko

" Tab completion works!
:ProphetUpload <Tab>
```

## Troubleshooting Commands

```lua
-- Debug: List detected cartridges
:lua print(vim.inspect(require('prophet.config').get_cartridges()))

-- Debug: Check dw.json config
:lua print(vim.inspect(require('prophet.config').load()))

-- Debug: See all messages
:messages
```
