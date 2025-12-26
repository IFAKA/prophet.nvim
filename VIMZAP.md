# VimZap Integration

Prophet.nvim works seamlessly with VimZap (or any Neovim distribution). No modifications to VimZap needed!

## Quick Setup for VimZap Users

### 1. Add to your VimZap plugins

Create or edit `~/.config/nvim/vimzap-custom.lua`:

```lua
-- VimZap custom configuration
-- This file is loaded automatically by VimZap

-- Add Prophet.nvim for SFCC development
return {
  -- Add to your existing plugins table
  plugins = {
    {
      "IFAKA/prophet.nvim",
      lazy = false,  -- Load on startup for SFCC projects
      config = function()
        require("prophet").setup({
          auto_upload = false,       -- Toggle on/off with :ProphetToggle
          clean_on_start = true,     -- Auto-upload all cartridges on Neovim startup
          notify = true,             -- Show progress notifications
          progress_style = "float",  -- Floating window progress
          keymaps = true,            -- Enable default keymaps (<leader>p)
          ignore_patterns = {
            "node_modules",
            "%.git",
            "%.zip$",
          },
        })
      end,
    },
  },
}
```

### 2. Or use VimZap's standard plugin directory

If you prefer the standard approach, add to your lazy plugin config:

**File**: `~/.config/nvim/lua/plugins/prophet.lua`

```lua
return {
  "IFAKA/prophet.nvim",
  lazy = false,
  config = function()
    require("prophet").setup()
  end,
}
```

## Integration Benefits

Prophet.nvim integrates naturally with VimZap's features:

### ✅ Works with VimZap's features out of the box

- **Notifications**: Uses VimZap's notification system (Snacks.nvim)
- **Keymaps**: Follows VimZap's `<leader>` keymap conventions
- **Lazy loading**: Compatible with VimZap's lazy.nvim setup
- **File explorer**: Works alongside VimZap's file tree (neo-tree)
- **Terminal**: Use VimZap's terminal (`Ctrl+/`) to run SFCC commands

### ✅ VimZap + Prophet Workflow

1. **Open SFRA project**: `cd /path/to/sfra-project && nvim`
2. **Prophet auto-uploads**: Cartridges upload automatically (if `clean_on_start = true`)
3. **Edit files**: Use VimZap's LSP, fuzzy finder, file explorer
4. **Toggle auto-upload**: Press `<leader>pt` to enable/disable watching
5. **Terminal**: Press `Ctrl+/` to open terminal for SFCC logs

## Recommended VimZap + Prophet Setup

For the best SFRA development experience:

```lua
-- ~/.config/nvim/vimzap-custom.lua
return {
  plugins = {
    {
      "IFAKA/prophet.nvim",
      lazy = false,
      config = function()
        require("prophet").setup({
          auto_upload = false,      -- Don't watch by default
          clean_on_start = true,    -- Upload all on startup
          notify = true,
          keymaps = true,           -- Enable default keymaps (<leader>p)
        })
      end,
    },
  },
}
```

**Note**: `<leader>p` is safe to use - VimZap doesn't use this prefix!

## Which-Key Integration

When you enable `keymaps = true`, Prophet.nvim registers with which-key (used by VimZap).

Press `<leader>p` to see the Prophet menu:

```
┌ prophet ──────────────────────┐
│ pe  enable auto-upload        │
│ pd  disable auto-upload       │
│ pt  toggle auto-upload        │
│ pc  clean upload all          │
└───────────────────────────────┘
```

**Safe from conflicts**: `<leader>p` is not used by VimZap, so it's safe to use!

## VimZap Command Menu Integration

Prophet commands also appear in VimZap's command palette (`<leader>sc`):

Search for "Prophet" to see:
- ProphetEnable: Enable auto-upload
- ProphetDisable: Disable auto-upload
- ProphetToggle: Toggle auto-upload
- ProphetClean: Clean upload all

## SFRA Project Detection

Prophet.nvim automatically detects SFRA projects by looking for:

1. `dw.json` in project root
2. Directories ending with `_cartridges`
3. Subdirectories with `.project` files or `cartridge/` folders

If VimZap opens a non-SFRA project, Prophet will silently do nothing (no errors).

## Troubleshooting in VimZap

### Check if Prophet loaded

```vim
:lua print(vim.inspect(package.loaded["prophet"]))
```

### View Prophet messages

```vim
:messages
```

Or use VimZap's `:Notifications` (if using Snacks.nvim).

### Debug cartridge detection

```vim
:lua print(vim.inspect(require('prophet.config').get_cartridges()))
```

### Check dw.json config

```vim
:lua print(vim.inspect(require('prophet.config').load()))
```

## FAQ

**Q: Do I need to modify VimZap's core files?**
A: No! Prophet.nvim is a standard Neovim plugin. Just add it to your plugins.

**Q: Will Prophet slow down VimZap's startup?**
A: No. Prophet only runs when `dw.json` is found. It adds ~0-5ms startup time.

**Q: Can I use Prophet with other Neovim distros?**
A: Yes! Works with LazyVim, NvChad, AstroNvim, or vanilla Neovim.

**Q: Does it work with VimZap's file explorer?**
A: Yes! Edit files in neo-tree, save, and Prophet auto-uploads (if enabled).

---

**Made to work seamlessly with VimZap!**
