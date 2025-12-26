<img width="1280" height="640" alt="image" src="https://github.com/user-attachments/assets/250613a7-bea9-458d-acf9-80710fe2436f" />

# Prophet.nvim

A comprehensive Neovim plugin for Salesforce Commerce Cloud (SFCC) development, inspired by and designed to match the functionality of the [SqrTT/prophet VSCode extension](https://github.com/SqrTT/prophet).

## Features

### 🚀 **Upload & Sync**
- Upload cartridges via WebDAV to SFCC sandboxes
- Auto-upload on file save with smart change detection
- Enhanced progress notifications with visual progress bars
- Support for multiple cartridge upload
- Intelligent cartridge detection using `.project` files
- Works with existing `dw.json` configuration

### 📝 **SFCC Development Support**
- **File Type Detection**: Auto-detection of `.isml`, `.ds`, and SFCC JavaScript files
- **Code Snippets**: Comprehensive snippets for ISML templates and SFCC JavaScript
- **Enhanced Configuration**: Robust `dw.json` validation and error handling
- **Smart File Filtering**: Only uploads relevant SFCC files

### 🎯 **Developer Experience**
- **Status Reporting**: `:ProphetStatus` command for comprehensive plugin status
- **Interactive Cartridge Selection**: UI selector when no cartridge specified
- **Better Error Messages**: Clear, actionable error reporting
- **Auto-formatting**: Proper indentation settings for SFCC file types

### 🐛 **Debugging Foundation**
- Basic debugging command structure (foundation for future SDAPI 2.0 integration)
- Debug status reporting
- Placeholder for breakpoint management (requires full SDAPI implementation)

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

**dw.json Configuration:**
```json
{
  "hostname": "your-sandbox.dx.commercecloud.salesforce.com",
  "username": "your.email@company.com", 
  "password": "your-api-key",
  "code-version": "version1",
  "cartridge": ["app_custom_site", "int_payment"],
  "cartridgePath": "app_custom_site:int_payment"
}
```

*Note: Both `cartridge` array and `cartridgePath` string formats are supported. The plugin will auto-detect and normalize the configuration.*

## Commands

### **Upload & Sync Commands**
- `:ProphetEnable` - Enable auto-upload watching
- `:ProphetDisable` - Disable auto-upload watching  
- `:ProphetToggle` - Toggle auto-upload state
- `:ProphetClean` - Clean upload all cartridges (force upload)
- `:ProphetUpload [name]` - Upload specific cartridge (shows picker if no name)
- `:ProphetStatus` - Show comprehensive plugin status and configuration
- `:ProphetCheckSandbox` - Test sandbox connectivity and authentication

### **Debug Commands (Foundation)**
- `:ProphetDebugConnect` - Connect to SFCC debugger (placeholder)
- `:ProphetDebugDisconnect` - Disconnect from debugger (placeholder) 
- `:ProphetDebugBreakpoint` - Toggle breakpoint (placeholder)

*Note: Full debugging requires SDAPI 2.0 implementation - currently shows placeholders*

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

The plugin supports multiple SFCC project structures and automatically detects cartridges:

### **Standard Structure:**
```
project/
├── dw.json
├── cartridges/           # Any folder ending with '_cartridges'  
│   ├── app_custom_site/
│   │   ├── .project     # Required for cartridge detection
│   │   └── cartridge/
│   └── int_payment/
│       ├── .project
│       └── cartridge/
```

### **Complex Structure (like your project):**
```
project/
├── dw.json
└── kiwoko_cartridges/
    └── cartridges/       # Nested cartridge structure
        ├── app_custom_kiwoko/
        │   ├── .project
        │   └── cartridge/
        ├── plugin_seo/
        │   ├── .project
        │   └── cartridge/
        └── [75+ more cartridges...]
```

### **Detection Logic:**
The plugin now uses the same logic as SqrTT/prophet:
1. **Recursive Search**: Finds all `.project` files in the workspace
2. **Validation**: Checks each `.project` file for `com.demandware.studio.core.beehiveNature`
3. **Fallback**: Supports legacy `*_cartridges` directory pattern for backward compatibility

## Snippets & File Support

### **ISML Snippets**
Available in `.isml` files:
- `isinclude` - Include templates
- `ismodule` - Module inclusion  
- `isdecorate` - Template decoration
- `isif/iselseif/iselse` - Conditional blocks
- `isloop` - Collection iteration
- `isset` - Variable setting
- `isscript` - Script blocks
- `form` - Forms with CSRF protection
- `resource` - Resource message calls
- `url` - URL generation

### **JavaScript/SFCC Snippets**
Available in `.js` files:
- `controller` - Basic SFCC controller structure
- `req-dw` - DW API module requires
- `req-cart/req-base` - Cartridge module requires
- `middleware` - Server middleware
- `resource` - Resource message calls
- `transaction` - Transaction wrappers
- `model-extend/script-extend` - Extension patterns
- `decorator` - Object decorators
- `factory` - Factory functions

## Advanced Features

### **SqrTT/Prophet Compatibility**
This plugin is designed to match the functionality of the original SqrTT/prophet extension:
- ✅ **Cartridge Detection** - Uses same `.project` file validation logic
- ✅ **Configuration** - Full `dw.json` validation and normalization
- ✅ **Upload System** - WebDAV upload with progress tracking
- ✅ **File Type Support** - ISML and DWScript file recognition
- ✅ **Snippets** - Comprehensive SFCC development snippets
- 🏗️ **Debugging** - Foundation laid for SDAPI 2.0 integration (future)

### **What Still Requires VSCode Prophet**
- **Full SDAPI 2.0 Debugging** - Breakpoints, variable inspection, stepping
- **Advanced Language Server** - Deep ISML intellisense, goto definition
- **Log Viewer** - Real-time server log streaming  
- **SOAP WebService** - API documentation generation

*Both tools work together: edit and upload in Neovim, advanced debugging in VSCode.*

## Troubleshooting

### **No cartridges found:**
- ✅ **Fixed**: Plugin now uses recursive `.project` file detection like SqrTT/prophet
- Run `:ProphetStatus` to see detected cartridges
- Ensure `.project` files contain `com.demandware.studio.core.beehiveNature`
- For complex structures, the plugin now searches the entire workspace

### **Upload fails:**
- Check `:ProphetStatus` for configuration validation
- Test credentials in `dw.json` - plugin validates hostname format
- Ensure `curl` and `zip` are available: `which curl zip`
- Check `:messages` for detailed error information
- Plugin now provides clearer error messages with actionable steps

### **Auto-upload not working:**
- Run `:ProphetEnable` to start file watching
- Check `:ProphetStatus` to see watch status
- Plugin now only uploads SFCC-relevant files (`.js`, `.isml`, `.ds`, etc.)
- Verify file is within a cartridge directory structure

### **Plugin not loading:**
- Test basic loading: `:lua require('prophet')`
- Ensure Neovim 0.9+ is installed
- Check for conflicts with other plugins

### **Sandbox offline/authentication issues:**
- Run `:ProphetCheckSandbox` to test connectivity
- Check if your sandbox is started and accessible via browser
- Verify credentials in `dw.json` are correct
- Plugin will now check connectivity before uploads to avoid repeated failures

### **Getting Help:**
- Run `:ProphetStatus` for comprehensive diagnostic information including sandbox status
- Use `:ProphetCheckSandbox` for immediate connectivity testing
- Check GitHub issues for known problems
- Compare behavior with SqrTT/prophet if available

## License

MIT

Inspired by [Prophet VSCode extension](https://github.com/SqrTT/prophet)
