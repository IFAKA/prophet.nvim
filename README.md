# Prophet.nvim

**SFCC cartridge uploader for Neovim** - Upload cartridges to Salesforce Commerce Cloud sandboxes with real-time progress feedback.

Zero configuration. Reads from your existing `dw.json`. Shows upload progress like `4/72`.

## Features

- Upload cartridges to SFCC sandboxes via WebDAV
- Auto-upload on file save (optional)
- Real-time progress notifications (`Uploading 4/72: app_storefront_core`)
- Reads configuration from existing `dw.json` (no extra setup needed)
- Clean upload all cartridges at once
- File watching with smart debouncing
- Ignore patterns support (node_modules, .git, etc.)

## Requirements

- Neovim 0.9+
- `curl` (for WebDAV uploads)
- `zip` (for creating cartridge archives)
- Valid `dw.json` in project root

## Installation

### Lazy.nvim

```lua
{
  "IFAKA/prophet.nvim",
  config = function()
    require("prophet").setup({
      auto_upload = false,       -- Enable/disable auto-upload on save
      clean_on_start = true,     -- Clean upload all on startup (default: true)
      notify = true,             -- Show progress notifications
      progress_style = "float",  -- "float" or "statusline"
      ignore_patterns = {        -- Files/folders to ignore
        "node_modules",
        "%.git",
        "%.zip$",
      },
    })
  end,
}
```

### Packer

```lua
use {
  "IFAKA/prophet.nvim",
  config = function()
    require("prophet").setup()
  end
}
```

## Configuration

Prophet.nvim reads your existing `dw.json` file. No additional configuration needed!

### Example `dw.json`

```json
{
  "hostname": "your-sandbox.dx.commercecloud.salesforce.com",
  "username": "your.email@company.com",
  "password": "your-api-key",
  "code-version": "version1"
}
```

Place this file in your project root (where your `*_cartridges` folders are).

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:ProphetEnable` | Enable auto-upload on file save |
| `:ProphetDisable` | Disable auto-upload |
| `:ProphetToggle` | Toggle auto-upload on/off |
| `:ProphetClean` | Clean upload all cartridges |
| `:ProphetUpload <name>` | Upload a specific cartridge |

### Example Workflow

**Option 1: Manual Upload (Recommended for Production)**

```vim
:ProphetClean  " Upload all cartridges once
```

**Option 2: Auto Upload (Development)**

```vim
:ProphetEnable  " Start watching files
" Now edit any file and save - it auto-uploads!
:ProphetDisable " Stop watching
```

### Keymaps (Optional)

Add to your Neovim config:

```lua
vim.keymap.set("n", "<leader>pe", "<cmd>ProphetEnable<cr>", { desc = "Prophet: Enable auto-upload" })
vim.keymap.set("n", "<leader>pd", "<cmd>ProphetDisable<cr>", { desc = "Prophet: Disable auto-upload" })
vim.keymap.set("n", "<leader>pt", "<cmd>ProphetToggle<cr>", { desc = "Prophet: Toggle auto-upload" })
vim.keymap.set("n", "<leader>pc", "<cmd>ProphetClean<cr>", { desc = "Prophet: Clean upload all" })
```

## How It Works

1. **Detects cartridges**: Scans for `*_cartridges` directories in your project
2. **Watches for changes**: Uses Neovim's built-in file watcher when auto-upload is enabled
3. **Zips cartridges**: Creates temporary zip files with smart ignore patterns
4. **Uploads via WebDAV**: Uses SFCC's WebDAV API to upload to your sandbox
5. **Shows progress**: Displays real-time upload progress in a floating window

### Progress Notification

When uploading multiple cartridges, you'll see:

```
╭─────────────────────────────────────╮
│ Prophet Upload Progress             │
├─────────────────────────────────────┤
│ Uploading 4/72: app_storefront_core │
│ ████████████░░░░░░░░░░░░░░░░░░░░░░░ │
╰─────────────────────────────────────╯
```

## Project Structure

Prophet.nvim expects your SFRA project to follow this structure:

```
your-project/
├── dw.json                    # SFCC configuration
├── animalis_cartridges/       # Cartridge folder
│   ├── app_custom_animalis/   # Individual cartridge
│   └── int_custom_payment/
├── kiwoko_cartridges/
│   └── app_custom_kiwoko/
└── site_kiwoko/
    └── cartridges/
```

The plugin automatically detects all `*_cartridges` directories and their subdirectories.

## Comparison with VSCode Prophet

| Feature | VSCode Prophet | prophet.nvim |
|---------|---------------|--------------|
| Upload cartridges | ✅ | ✅ |
| Auto-upload on save | ✅ | ✅ |
| Progress feedback | ✅ | ✅ |
| Debugger | ✅ | ❌ |
| ISML syntax | ✅ | ❌ |
| Logs viewer | ✅ | ❌ |

**Note**: Prophet.nvim focuses on **cartridge uploading only**. For debugging and ISML support, consider using VSCode with the original Prophet extension.

## Troubleshooting

### No cartridges found

Make sure your project has folders ending with `_cartridges` and they contain subdirectories with a `.project` file or `cartridge/` directory.

### Upload fails

- Check your `dw.json` credentials
- Verify your sandbox is accessible
- Ensure `curl` and `zip` are installed: `which curl zip`
- Check Neovim messages: `:messages`

### Auto-upload not working

- Verify it's enabled: `:ProphetEnable`
- Check file watching is active (you'll see a notification)
- Make sure your file is inside a `*_cartridges` directory

## FAQ

**Q: Does this work with multi-workspace projects?**
A: Yes! Place your `dw.json` in the root where your cartridge folders are.

**Q: Can I use this with the original Prophet VSCode extension?**
A: Yes! They both read the same `dw.json` file. Use VSCode for debugging and Neovim for editing.

**Q: Does it support `dw.js` files?**
A: Currently only `dw.json` is fully supported. `dw.js` support is planned.

**Q: How do I see which cartridges will be uploaded?**
A: Run `:lua print(vim.inspect(require('prophet.config').get_cartridges()))`

## Contributing

PRs welcome! This plugin is focused on **upload functionality only**.

For feature requests or bugs, please open an issue at:
https://github.com/IFAKA/prophet.nvim/issues

## License

MIT

## Credits

Inspired by the excellent [Prophet VSCode extension](https://github.com/SqrTT/prophet) by SqrTT.

---

**Made with ❤️ for SFCC developers who prefer Neovim**
