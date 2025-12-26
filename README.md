<img width="1280" height="640" alt="image" src="https://github.com/user-attachments/assets/250613a7-bea9-458d-acf9-80710fe2436f" />

# Prophet.nvim

Upload cartridges to Salesforce Commerce Cloud sandboxes from Neovim.

> Upload-only plugin. For debugging/logs, use [VSCode Prophet](https://github.com/SqrTT/prophet).

## Features

- Upload cartridges via WebDAV
- Auto-upload on save
- Progress notifications
- Works with existing `dw.json`

## Requirements

- Neovim 0.9+
- `curl` and `zip` commands
- `dw.json` in project root

## Installation

```lua
{
  "IFAKA/prophet.nvim",
  config = function()
    require("prophet").setup()
  end,
}
```

## Configuration

**Default:**
```lua
require("prophet").setup()
```

**Custom:**
```lua
require("prophet").setup({
  auto_upload = false,
  clean_on_start = true,
  notify = true,
  ignore_patterns = { "node_modules", "%.git", "%.zip$" },
})
```

**dw.json:**
```json
{
  "hostname": "your-sandbox.dx.commercecloud.salesforce.com",
  "username": "your.email@company.com",
  "password": "your-api-key",
  "code-version": "version1"
}
```

## Commands

- `:ProphetEnable` - Enable auto-upload
- `:ProphetDisable` - Disable auto-upload
- `:ProphetToggle` - Toggle auto-upload
- `:ProphetClean` - Upload all cartridges
- `:ProphetUpload <name>` - Upload specific cartridge

## Keymaps

No defaults. Example:

```lua
vim.keymap.set("n", "<leader>pe", "<cmd>ProphetEnable<cr>")
vim.keymap.set("n", "<leader>pd", "<cmd>ProphetDisable<cr>")
vim.keymap.set("n", "<leader>pc", "<cmd>ProphetClean<cr>")
```

## Usage

**Manual:**
```vim
:ProphetClean
```

**Auto:**
```vim
:ProphetEnable
" Edit files - auto-uploads on save
:ProphetDisable
```

## Project Structure

```
project/
├── dw.json
├── site_cartridges/
│   ├── app_custom_site/
│   └── int_payment/
```

Folders must end with `_cartridges` and contain subdirectories with `.project` or `cartridge/`.

## What's Missing

- Debugger (use VSCode Prophet)
- ISML syntax (use treesitter)
- Logs viewer (use VSCode Prophet)

Both tools share `dw.json` - edit in Neovim, debug in VSCode.

## Troubleshooting

**No cartridges found:**
- Check folder naming: `*_cartridges/cartridge_name/`
- Verify `.project` or `cartridge/` exists

**Upload fails:**
- Test credentials in `dw.json`
- Run `which curl zip`
- Check `:messages`

**Auto-upload not working:**
- Run `:ProphetEnable`
- Verify file is in `*_cartridges/` directory

## License

MIT

Inspired by [Prophet VSCode extension](https://github.com/SqrTT/prophet)
