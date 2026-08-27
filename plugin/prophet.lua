if vim.g.loaded_prophet then return end
vim.g.loaded_prophet = 1
if vim.fn.has("nvim-0.12") == 0 then error("prophet.nvim requires Neovim 0.12+") end
local prophet, config = require("prophet"), require("prophet.config")
for name, fn in pairs({ Enable = prophet.enable_upload, Disable = prophet.disable_upload, Toggle = prophet.toggle_upload, Clean = prophet.clean_upload, Controllers = prophet.controllers, Templates = prophet.templates, Logs = prophet.logs, Refresh = prophet.refresh }) do vim.api.nvim_create_user_command("Prophet" .. name, fn, {}) end
vim.api.nvim_create_user_command("ProphetUpload", function(o) if o.args ~= "" then return prophet.upload_cartridge(o.args) end; local items = vim.tbl_map(function(c) return { label = c.name, path = c.path, name = c.name } end, config.get_cartridges()); (prophet.config.picker or prophet.default_picker)({ title = "Upload cartridge", items = items, select = function(i) prophet.upload_cartridge(i.name) end }) end, { nargs = "?", complete = function() return vim.tbl_map(function(c) return c.name end, config.get_cartridges()) end })
vim.api.nvim_create_user_command("ProphetStatus", function() local dw = config.load(); vim.notify(dw and ("Prophet: " .. dw.hostname) or "Prophet: No dw.json found") end, {})
vim.api.nvim_create_user_command("ProphetCheckSandbox", function() config.check_sandbox_status(config.load(), function(ok, msg) vim.notify(msg, ok and vim.log.levels.INFO or vim.log.levels.ERROR) end) end, {})
vim.filetype.add({ extension = { isml = "isml", ds = "ds" } })
vim.treesitter.language.register("html", "isml")
vim.api.nvim_create_autocmd("FileType", { pattern = { "isml", "ds" }, callback = function() vim.bo.expandtab = true; vim.bo.shiftwidth = 4; vim.bo.tabstop = 4 end })
vim.api.nvim_create_autocmd("FileType", { pattern = "isml", callback = function() vim.bo.commentstring = "<iscomment> %s </iscomment>"; pcall(vim.treesitter.start, 0, "html") end })
vim.api.nvim_create_autocmd("FileType", { pattern = { "javascript", "javascriptreact", "typescript", "typescriptreact", "ds" }, callback = function() vim.bo.completefunc = "v:lua.require'prophet.sfcc'.completefunc"; vim.opt_local.complete:append("F") end })
