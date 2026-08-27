local M, caches = {}, {}
local function start(path)
  path = path or vim.api.nvim_buf_get_name(0); if path == "" then path = vim.fn.getcwd() end
  if vim.fn.isdirectory(path) == 0 then path = vim.fs.dirname(path) end
  return vim.fs.normalize(path)
end
function M.root(path)
  local marker = vim.fs.find({ "dw.json", "dw.js" }, { path = start(path), upward = true })[1]
  return marker and vim.fs.dirname(marker) or start(path)
end
function M.path(path)
  local root = M.root(path)
  for _, name in ipairs({ "dw.json", "dw.js" }) do local p = root .. "/" .. name; if vim.fn.filereadable(p) == 1 then return p end end
end
function M.load(path)
  local p = M.path(path); if not p then return nil end
  local ok, value = pcall(vim.json.decode, table.concat(vim.fn.readfile(p), "\n")); if not ok then return nil end
  value["code-version"] = value["code-version"] or "version1"
  if value.cartridgePath and value.cartridgePath ~= "" then value.cartridge = vim.split(value.cartridgePath, ":", { plain = true })
  elseif type(value.cartridge) == "string" then value.cartridge = { value.cartridge } else value.cartridge = value.cartridge or {} end
  value._root = vim.fs.dirname(p); return value
end
function M.get_cartridges(path)
  local root = M.root(path); if caches[root] then return caches[root] end
  local out = {}
  for _, file in ipairs(vim.fs.find(".project", { path = root, type = "file", limit = math.huge })) do
    local content = table.concat(vim.fn.readfile(file), "\n")
    if not file:find("/node_modules/", 1, true) and content:find("com.demandware.studio.core.beehiveNature", 1, true) then
      local dir = vim.fs.dirname(file); out[#out + 1] = { name = vim.fs.basename(dir), path = dir }
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end); caches[root] = out; return out
end
function M.clear_cache(path) if path then caches[M.root(path)] = nil else caches = {} end end
function M.check_sandbox_status(dw, callback)
  if not dw then return callback(false, "No dw.json configuration found") end
  local url = string.format("https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s/", dw.hostname, dw["code-version"])
  vim.system({ "curl", "-s", "--max-time", "10", "-X", "PROPFIND", "-H", "Depth: 1", "-u", dw.username .. ":" .. dw.password, url }, {}, function(r)
    vim.schedule(function() callback(r.code == 0, r.code == 0 and "Sandbox is online and accessible" or "Sandbox check failed") end)
  end)
end
return M
