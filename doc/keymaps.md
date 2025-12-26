# Keymaps Guide

## Default Behavior: No Keymaps

Prophet.nvim **does NOT set keymaps by default** to avoid conflicts with your existing configuration.

This follows the Neovim plugin best practice of letting users choose their own keybindings.

## Why `<leader>p` is Safe for VimZap

VimZap uses these `<leader>` prefixes:

- `<leader>w` - Save
- `<leader>e` - Explorer
- `<leader>f` - Files
- `<leader>c` - Code
- `<leader>g` - Git
- `<leader>s` - Search
- `<leader>d` - Debug
- `<leader>h` - Health
- `<leader>m` - Mason
- `<leader>b` - Buffer

**`<leader>p` is available!** That's why we suggest it for Prophet.

## Enabling Keymaps

### Option 1: Use Default Keymaps

Enable in your setup:

```lua
require("prophet").setup({
  keymaps = true,  -- Enable <leader>p prefix
})
```

This sets up:
- `<leader>pe` → ProphetEnable
- `<leader>pd` → ProphetDisable
- `<leader>pt` → ProphetToggle
- `<leader>pc` → ProphetClean

### Option 2: Custom Keymaps

Choose your own keys:

```lua
require("prophet").setup()

-- Use different prefix (e.g., <leader>u for "upload")
vim.keymap.set("n", "<leader>ue", "<cmd>ProphetEnable<cr>", { desc = "Prophet: Enable" })
vim.keymap.set("n", "<leader>ud", "<cmd>ProphetDisable<cr>", { desc = "Prophet: Disable" })
vim.keymap.set("n", "<leader>ut", "<cmd>ProphetToggle<cr>", { desc = "Prophet: Toggle" })
vim.keymap.set("n", "<leader>uc", "<cmd>ProphetClean<cr>", { desc = "Prophet: Clean" })
```

### Option 3: LazyVim Keys

If using lazy.nvim, you can set keymaps in the plugin spec:

```lua
{
  "IFAKA/prophet.nvim",
  keys = {
    { "<leader>pe", "<cmd>ProphetEnable<cr>", desc = "Prophet: Enable" },
    { "<leader>pd", "<cmd>ProphetDisable<cr>", desc = "Prophet: Disable" },
    { "<leader>pt", "<cmd>ProphetToggle<cr>", desc = "Prophet: Toggle" },
    { "<leader>pc", "<cmd>ProphetClean<cr>", desc = "Prophet: Clean" },
  },
  config = function()
    require("prophet").setup()
  end,
}
```

## Checking for Conflicts

To see if `<leader>p` is already used in your config:

```vim
:verbose map <leader>p
```

If it shows nothing or "No mapping found", it's safe to use!

## Which-Key Integration

When `keymaps = true`, Prophet automatically integrates with which-key if installed.

Press `<leader>p` to see a menu:

```
┌ prophet ──────────────────────┐
│ pe  enable auto-upload        │
│ pd  disable auto-upload       │
│ pt  toggle auto-upload        │
│ pc  clean upload all          │
└───────────────────────────────┘
```

## Recommended Approach

1. **For VimZap users**: Use `keymaps = true` (safe, `<leader>p` is free)
2. **For other configs**: Check for conflicts first, then enable
3. **For custom setups**: Set your own keymaps manually

## No Keymaps? No Problem!

You can always use commands directly:

```vim
:ProphetClean
:ProphetToggle
:ProphetEnable
:ProphetDisable
```

Or use the command palette (`<leader>sc` in VimZap) to search for "Prophet".
