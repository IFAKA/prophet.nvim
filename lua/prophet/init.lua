local M = {}
local config, sfcc, uploader = require("prophet.config"), require("prophet.sfcc"), require("prophet.uploader")
M.config = { auto_upload = false, clean_on_start = false, notify = true, ignore_patterns = { "node_modules", "%.git", "%.zip$" }, dap = { enabled = false, vscode_extension_glob = "~/.vscode/extensions/sqrtt.prophet-*" } }
local function default_picker(opts) vim.ui.select(opts.items, { prompt = opts.title, format_item = function(i) return i.label end }, function(item) if item then opts.select(item) end end) end
local function choose(title, items) if #items == 0 then return vim.notify("Prophet: No " .. title:lower() .. " found", vim.log.levels.WARN) end; (M.config.picker or default_picker)({ title = title, items = items, select = function(item) vim.cmd.edit(vim.fn.fnameescape(item.path)); if item.lnum then vim.api.nvim_win_set_cursor(0, { item.lnum, 0 }) end end }) end
function M.setup(opts) M.config = vim.tbl_deep_extend("force", M.config, opts or {}); local dw = config.load(); if dw then uploader.init(dw, M.config); if M.config.clean_on_start then vim.defer_fn(M.clean_upload, 1000) end; if M.config.auto_upload then uploader.enable_watch() end end; require("prophet.dap").setup(M.config.dap) end
function M.controllers() choose("SFCC Controllers", sfcc.controllers()) end
function M.templates() choose("ISML Templates", sfcc.templates()) end
function M.logs() local dw = config.load(); if not dw or not dw.hostname then return vim.notify("Prophet: No dw.json found", vim.log.levels.WARN) end; vim.ui.open("https://" .. dw.hostname .. "/on/demandware.servlet/webdav/Sites/Logs") end
function M.refresh() sfcc.refresh(); vim.notify("Prophet: Project caches refreshed", vim.log.levels.INFO) end
function M.enable_upload() M.config.auto_upload = true; uploader.enable_watch() end
function M.disable_upload() M.config.auto_upload = false; uploader.disable_watch() end
function M.toggle_upload() if M.config.auto_upload then M.disable_upload() else M.enable_upload() end end
function M.clean_upload() local dw = config.load(); if dw then uploader.clean_upload(dw, M.config) end end
function M.upload_cartridge(name) local dw = config.load(); if dw then uploader.upload_single(dw, name, M.config) end end
M.default_picker = default_picker
return M
