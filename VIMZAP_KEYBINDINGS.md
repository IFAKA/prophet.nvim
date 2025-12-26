# Prophet.nvim Keybindings in VimZap

## Which-Key Integration

✅ **YES** - VimZap's which-key knows about Prophet keybindings!

When you press `<Space>p` in VimZap, which-key shows:

```
┌ prophet ──────────────────────┐
│ e   enable auto-upload        │
│ d   disable auto-upload       │
│ t   toggle auto-upload        │
│ c   clean upload all          │
└───────────────────────────────┘
```

## Keybindings

All Prophet keybindings use the `<leader>p` prefix (where `<leader>` = `Space` in VimZap):

| Key | Command | Description |
|-----|---------|-------------|
| `<Space>pe` | `:ProphetEnable` | Enable auto-upload on save |
| `<Space>pd` | `:ProphetDisable` | Disable auto-upload |
| `<Space>pt` | `:ProphetToggle` | Toggle auto-upload on/off |
| `<Space>pc` | `:ProphetClean` | Clean upload all cartridges |

## How It Works

**VimZap owns the keymaps**, not Prophet.nvim:

```lua
-- In VimZap's lua/keymaps.lua
require("which-key").add({
  { "<leader>p", group = "prophet" },
  { "<leader>pe", "<cmd>ProphetEnable<cr>", desc = "enable auto-upload" },
  { "<leader>pd", "<cmd>ProphetDisable<cr>", desc = "disable auto-upload" },
  { "<leader>pt", "<cmd>ProphetToggle<cr>", desc = "toggle auto-upload" },
  { "<leader>pc", "<cmd>ProphetClean<cr>", desc = "clean upload all" },
})

-- In VimZap's lua/plugins.lua
require("prophet").setup({
  auto_upload = false,    -- Don't watch by default
  clean_on_start = true,  -- Upload all on startup
  notify = true,          -- Show notifications
  -- NO keymaps option - VimZap handles them
})
```

## Design Philosophy

**Separation of Concerns:**
- Prophet.nvim provides **commands** (`:ProphetEnable`, etc.)
- VimZap provides **keymaps** (`<Space>pe`, etc.)
- Which-key provides **discoverability** (menu when you press `<Space>p`)

This way:
- Prophet.nvim stays simple (no keymap logic)
- Users can use commands directly (`:ProphetClean`)
- VimZap users get nice keybindings
- Other users set their own keymaps

## For VimZap Users

Just press `<Space>p` and the which-key menu appears!

Or use commands directly:
```vim
:ProphetClean
:ProphetToggle
:ProphetEnable
:ProphetDisable
```

## For Non-VimZap Users

Prophet.nvim has **no default keymaps**. Set your own:

```lua
vim.keymap.set("n", "<leader>pe", "<cmd>ProphetEnable<cr>", { desc = "Prophet: Enable" })
vim.keymap.set("n", "<leader>pd", "<cmd>ProphetDisable<cr>", { desc = "Prophet: Disable" })
vim.keymap.set("n", "<leader>pt", "<cmd>ProphetToggle<cr>", { desc = "Prophet: Toggle" })
vim.keymap.set("n", "<leader>pc", "<cmd>ProphetClean<cr>", { desc = "Prophet: Clean" })
```

Or just use commands (no keymaps needed).
