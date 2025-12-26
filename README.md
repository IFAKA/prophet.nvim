# Prophet.nvim

**SFCC Cartridge Uploader for Neovim** - Upload cartridges to Salesforce Commerce Cloud sandboxes.

> **Scope:** Upload functionality only. For debugging, ISML syntax, and logs, use the [VSCode Prophet extension](https://github.com/SqrTT/prophet).

## What This Does

- ✅ Upload cartridges to SFCC sandboxes via WebDAV
- ✅ Auto-upload on file save (optional)
- ✅ Clean upload all cartridges
- ✅ Progress notifications
- ✅ Reads existing `dw.json` configuration

## What This Doesn't Do

- ❌ Debugger (use VSCode Prophet)
- ❌ ISML syntax highlighting (use treesitter)
- ❌ Server logs viewer (use VSCode Prophet)
- ❌ ISML validation/formatting

## Requirements

- Neovim 0.9+
- `curl` (for WebDAV uploads)
- `zip` (for creating cartridge archives)
- Valid `dw.json` in project root

## Installation

### lazy.nvim

```lua
{
  "IFAKA/prophet.nvim",
  config = function()
    require("prophet").setup()
  end,
}
```

## Configuration

### Minimal Setup

```lua
require("prophet").setup()
```

### Full Options

```lua
require("prophet").setup({
  auto_upload = false,    -- Auto-upload on save
  clean_on_start = true,  -- Upload all on startup
  notify = true,          -- Show notifications
  ignore_patterns = {
    "node_modules",
    "%.git",
    "%.zip$",
  },
})
```

### dw.json Example

Place in your project root:

```json
{
  "hostname": "your-sandbox.dx.commercecloud.salesforce.com",
  "username": "your.email@company.com",
  "password": "your-api-key",
  "code-version": "version1"
}
```

## Commands

| Command | Description |
|---------|-------------|
| `:ProphetEnable` | Enable auto-upload on save |
| `:ProphetDisable` | Disable auto-upload |
| `:ProphetToggle` | Toggle auto-upload |
| `:ProphetClean` | Upload all cartridges |
| `:ProphetUpload <name>` | Upload specific cartridge |

## Keymaps

**No default keymaps** - set your own:

```lua
vim.keymap.set("n", "<leader>pe", "<cmd>ProphetEnable<cr>", { desc = "Enable SFCC upload" })
vim.keymap.set("n", "<leader>pd", "<cmd>ProphetDisable<cr>", { desc = "Disable SFCC upload" })
vim.keymap.set("n", "<leader>pt", "<cmd>ProphetToggle<cr>", { desc = "Toggle SFCC upload" })
vim.keymap.set("n", "<leader>pc", "<cmd>ProphetClean<cr>", { desc = "Upload all cartridges" })
```

Or use commands directly via `:Prophet<Tab>`.

## Usage

### Manual Upload

```vim
:ProphetClean  " Upload all cartridges once
```

### Auto Upload (Development)

```vim
:ProphetEnable  " Start watching files
" Edit and save files - they auto-upload
:ProphetDisable " Stop watching
```

## Project Structure

```
your-project/
├── dw.json                    # SFCC credentials
├── animalis_cartridges/       # Cartridge folder
│   ├── app_custom_animalis/   # Individual cartridge
│   └── int_custom_payment/
└── kiwoko_cartridges/
    └── app_custom_kiwoko/
```

## Comparison: Prophet.nvim vs VSCode Prophet

| Feature | prophet.nvim | VSCode Prophet |
|---------|--------------|----------------|
| Upload cartridges | ✅ | ✅ |
| Auto-upload on save | ✅ | ✅ |
| Progress feedback | ✅ | ✅ |
| Debugger | ❌ | ✅ |
| ISML syntax | ❌ | ✅ |
| Logs viewer | ❌ | ✅ |
| Cartridges explorer | ❌ | ✅ |
| SOAP API download | ❌ | ✅ |

**Use both:** Edit in Neovim, debug in VSCode. They share the same `dw.json`.

## Troubleshooting

### No cartridges found

Ensure folders ending with `_cartridges` contain subdirectories with `.project` file or `cartridge/` directory.

### Upload fails

- Check `dw.json` credentials
- Verify sandbox is accessible
- Ensure `curl` and `zip` are installed: `which curl zip`
- Check messages: `:messages`

### Auto-upload not working

- Verify it's enabled: `:ProphetEnable`
- Check file is inside a `*_cartridges` directory
- See messages: `:messages`

## FAQ

**Q: Why doesn't this have debugging?**
A: Debugging requires complex SDAPI 2.0 integration. Use VSCode Prophet for debugging.

**Q: Can I use this with VSCode Prophet?**
A: Yes! They both read `dw.json`. Edit in Neovim, debug in VSCode.

**Q: Why no ISML syntax highlighting?**
A: Use Neovim's treesitter for syntax highlighting. Prophet.nvim focuses on uploads only.

**Q: How do I see which cartridges will be uploaded?**
A: Run `:lua print(vim.inspect(require('prophet.config').get_cartridges()))`

## Contributing

PRs welcome for **upload functionality** improvements only.

For feature requests or bugs: https://github.com/IFAKA/prophet.nvim/issues

## License

MIT

## Credits

Inspired by [Prophet VSCode extension](https://github.com/SqrTT/prophet) by SqrTT.

---

**Made for SFCC developers who prefer Neovim's speed for editing**
