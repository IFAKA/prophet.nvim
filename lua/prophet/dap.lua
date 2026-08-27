local M = {}
function M.setup(opts)
  if not opts.enabled then return false end
  local ok, dap = pcall(require, "dap"); if not ok then return false end
  local matches = vim.fn.glob(vim.fn.expand(opts.vscode_extension_glob) .. "/out/debugAdapter.js", false, true); if #matches == 0 then return false end
  dap.adapters.prophet = { type = "executable", command = "node", args = { matches[#matches] } }
  dap.configurations.javascript = dap.configurations.javascript or {}; table.insert(dap.configurations.javascript, { type = "prophet", request = "attach", name = "Attach to SFCC (Prophet)" }); return true
end
return M
