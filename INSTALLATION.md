# Installation Guide

Prophet.nvim is an **independent Neovim plugin** that works with any Neovim setup.

---

## VimZap

**Prophet is pre-installed in VimZap!** Just use it:

```bash
# Install VimZap (includes Prophet)
curl -fsSL ifaka.github.io/vimzap/i | bash
```

**Keymaps (already configured):**
- `<leader>pe` - Enable auto-upload
- `<leader>pd` - Disable auto-upload
- `<leader>pt` - Toggle auto-upload
- `<leader>pc` - Clean upload all

**Commands:**
- `:ProphetClean` - Upload all cartridges
- `:ProphetToggle` - Toggle auto-upload
- `:ProphetEnable` - Enable file watching
- `:ProphetDisable` - Disable file watching

---

## LazyVim

Add to your `~/.config/nvim/lua/plugins/prophet.lua`:

```lua
return {
  "IFAKA/prophet.nvim",
  lazy = false,
  opts = {
    keymaps = true,  -- Enable default keymaps
  },
  keys = {
    { "<leader>pe", "<cmd>ProphetEnable<cr>", desc = "Prophet: Enable" },
    { "<leader>pd", "<cmd>ProphetDisable<cr>", desc = "Prophet: Disable" },
    { "<leader>pt", "<cmd>ProphetToggle<cr>", desc = "Prophet: Toggle" },
    { "<leader>pc", "<cmd>ProphetClean<cr>", desc = "Prophet: Clean" },
  },
}
```

---

## NvChad

Add to your `~/.config/nvim/lua/plugins/init.lua`:

```lua
return {
  {
    "IFAKA/prophet.nvim",
    lazy = false,
    config = function()
      require("prophet").setup({
        keymaps = true,
      })
    end,
  },
}
```

Then add keymaps to `~/.config/nvim/lua/mappings.lua`:

```lua
M.prophet = {
  n = {
    ["<leader>pe"] = { "<cmd>ProphetEnable<cr>", "Prophet: Enable" },
    ["<leader>pd"] = { "<cmd>ProphetDisable<cr>", "Prophet: Disable" },
    ["<leader>pt"] = { "<cmd>ProphetToggle<cr>", "Prophet: Toggle" },
    ["<leader>pc"] = { "<cmd>ProphetClean<cr>", "Prophet: Clean" },
  },
}
```

---

## AstroNvim

Add to your `~/.config/nvim/lua/plugins/prophet.lua`:

```lua
return {
  "IFAKA/prophet.nvim",
  lazy = false,
  opts = {},
  keys = {
    { "<leader>P", desc = "Prophet" },
    { "<leader>Pe", "<cmd>ProphetEnable<cr>", desc = "Enable auto-upload" },
    { "<leader>Pd", "<cmd>ProphetDisable<cr>", desc = "Disable auto-upload" },
    { "<leader>Pt", "<cmd>ProphetToggle<cr>", desc = "Toggle auto-upload" },
    { "<leader>Pc", "<cmd>ProphetClean<cr>", desc = "Clean upload all" },
  },
}
```

---

## Vanilla Neovim (lazy.nvim)

If you use lazy.nvim as your plugin manager:

**File:** `~/.config/nvim/lua/plugins/prophet.lua`

```lua
return {
  "IFAKA/prophet.nvim",
  lazy = false,
  config = function()
    require("prophet").setup({
      auto_upload = false,
      clean_on_start = true,
      notify = true,
      keymaps = true,  -- Enable default keymaps
    })
  end,
}
```

---

## Vanilla Neovim (packer.nvim)

Add to your `init.lua`:

```lua
use {
  "IFAKA/prophet.nvim",
  config = function()
    require("prophet").setup({
      keymaps = true,
    })
  end,
}
```

---

## Vanilla Neovim (vim-plug)

Add to your `init.vim`:

```vim
Plug 'IFAKA/prophet.nvim'

lua << EOF
require("prophet").setup({
  keymaps = true,
})
EOF
```

---

## Manual Installation (No Plugin Manager)

```bash
# Clone to Neovim's plugin directory
mkdir -p ~/.local/share/nvim/site/pack/plugins/start
cd ~/.local/share/nvim/site/pack/plugins/start
git clone https://github.com/IFAKA/prophet.nvim
```

Then add to your `~/.config/nvim/init.lua`:

```lua
require("prophet").setup({
  keymaps = true,
})
```

---

## Configuration Options

All distributions use the same configuration options:

```lua
require("prophet").setup({
  auto_upload = false,       -- Enable auto-upload on file save
  clean_on_start = true,     -- Upload all cartridges on startup
  notify = true,             -- Show progress notifications
  progress_style = "float",  -- "float" or "statusline"
  keymaps = false,           -- Enable default keymaps (<leader>p)
  ignore_patterns = {
    "node_modules",
    "%.git",
    "%.zip$",
  },
})
```

---

## Project Setup

Prophet.nvim requires a `dw.json` file in your SFRA project root:

```json
{
  "hostname": "your-sandbox.dx.commercecloud.salesforce.com",
  "username": "your.email@company.com",
  "password": "your-webdav-password",
  "code-version": "version1"
}
```

**Security tip:** Add `dw.json` to `.gitignore` to avoid committing credentials!

---

## Troubleshooting

### Check if Prophet loaded

```vim
:lua print(vim.inspect(package.loaded["prophet"]))
```

### View detected cartridges

```vim
:lua print(vim.inspect(require('prophet.config').get_cartridges()))
```

### Check dw.json config

```vim
:lua print(vim.inspect(require('prophet.config').load()))
```

### View all messages

```vim
:messages
```

---

## Platform-Specific Notes

### macOS
Requires `curl` and `zip` (pre-installed on macOS)

### Linux
Install dependencies:
```bash
# Ubuntu/Debian
sudo apt install curl zip

# Fedora/RHEL
sudo dnf install curl zip

# Arch
sudo pacman -S curl zip
```

### Windows (WSL)
Works in WSL2 with curl and zip installed

---

**Made to work everywhere!**
