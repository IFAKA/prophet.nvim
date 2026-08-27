local M = { _controllers = {} }
local config = require("prophet.config")
local function files(root, predicate)
  return vim.tbl_filter(function(p) return not p:find("/node_modules/", 1, true) end, vim.fs.find(predicate, { path = root, type = "file", limit = math.huge }))
end
function M.controllers(path)
  local root = config.root(path); if M._controllers[root] then return M._controllers[root] end
  local out = {}
  for _, file in ipairs(files(root, function(n) return n:match("%.js$") ~= nil end)) do
    if file:find("/cartridge/controllers/", 1, true) then
      local controller = vim.fs.basename(file):gsub("%.js$", "")
      for lnum, line in ipairs(vim.fn.readfile(file)) do
        local method, endpoint = line:match("server%.(%w+)%s*%(%s*['\"]([^'\"]+)['\"]")
        if method then out[#out + 1] = { label = string.format("[%s] %s-%s", method:upper(), controller, endpoint), path = file, lnum = lnum } end
      end
    end
  end
  table.sort(out, function(a, b) return a.label < b.label end); M._controllers[root] = out; return out
end
function M.templates(path)
  local root, out = config.root(path), {}
  for _, file in ipairs(files(root, function(n) return n:match("%.isml$") ~= nil end)) do out[#out + 1] = { label = vim.fs.basename(file):gsub("%.isml$", "") .. " - " .. file:sub(#root + 2), path = file } end
  table.sort(out, function(a, b) return a.label < b.label end); return out
end
function M.refresh(path) M._controllers[config.root(path)] = nil; config.clear_cache(path) end
local function candidates(line)
  local out = {}; local function add(names, menu) for _, n in ipairs(names) do out[#out + 1] = { word = n, kind = "Function", menu = menu } end end
  if line:match("URLUtils%.$") then add({ "url", "http", "https", "abs", "home", "staticURL", "webRoot", "imageURL" }, "[SFCC URLUtils]")
  elseif line:match("server%.$") then add({ "get", "post", "append", "prepend", "replace", "use", "exports" }, "[SFCC server]")
  elseif line:match("res%.$") then add({ "render", "json", "redirect", "setViewData", "getViewData", "setStatusCode", "cachePeriod", "cacheExpiration", "print" }, "[SFCC response]")
  elseif line:match("Transaction%.$") then add({ "wrap", "begin", "commit", "rollback" }, "[SFCC Transaction]")
  elseif line:match("Resource%.msg[f]?%s*%(['\"]?$") then add({ "Resource.msg('', '', null)", "Resource.msgf('', '', null)" }, "[SFCC Resource]")
  elseif line:match("require%s*%(['\"]dw/[^/]*$") then for _, n in ipairs({ "catalog", "content", "crypto", "customer", "extensions", "i18n", "io", "net", "object", "order", "rpc", "system", "template", "util", "value", "web", "ws" }) do out[#out + 1] = { word = "dw/" .. n, kind = "Module", menu = "[SFCC]" } end end
  return out
end
function M.completefunc(findstart, base)
  local before = vim.api.nvim_get_current_line():sub(1, vim.fn.col(".") - 1)
  if findstart == 1 then local s = before:find("[%w_/'\"]*$"); return (s or 1) - 1 end
  return vim.tbl_filter(function(i) return base == "" or i.word:lower():find(base:lower(), 1, true) == 1 end, candidates(before))
end
M.candidates = candidates
return M
