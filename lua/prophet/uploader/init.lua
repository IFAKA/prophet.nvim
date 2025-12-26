local M = {}

local utils = require("prophet.utils")
local config_loader = require("prophet.config")

local watchers = {}
local upload_queue = {}
local is_uploading = false

local MAX_PARALLEL = 4
local MAX_RETRIES = 3
local RETRY_DELAYS = { 2000, 4000, 6000 }

function M.init(dw_config, opts)
  M.dw_config = dw_config
  M.opts = opts
end

function M.enable_watch()
  if #watchers > 0 then
    vim.notify("Prophet: Already watching", vim.log.levels.INFO)
    return
  end

  local cartridges = config_loader.get_cartridges()
  if #cartridges == 0 then
    vim.notify("Prophet: No cartridges found", vim.log.levels.WARN)
    return
  end

  local count = 0
  for _, cartridge in ipairs(cartridges) do
    local watcher = vim.loop.new_fs_event()
    if watcher and watcher:start(cartridge.path, { recursive = true }, vim.schedule_wrap(function(err, filename)
      if err or utils.should_ignore(filename, M.opts.ignore_patterns) then return end
      if utils.is_sfcc_file(cartridge.path .. "/" .. filename) then
        if not vim.tbl_contains(upload_queue, cartridge.name) then
          table.insert(upload_queue, cartridge.name)
          if M.opts.notify then
            vim.notify("Prophet: Queued " .. cartridge.name, vim.log.levels.INFO)
          end
        end
        vim.defer_fn(M.process_queue, 1000)
      end
    end)) then
      table.insert(watchers, watcher)
      count = count + 1
    end
  end

  vim.notify(string.format("Prophet: Watching %d cartridge(s)", count), vim.log.levels.INFO)
end

function M.disable_watch()
  for _, w in ipairs(watchers) do if w then w:stop() end end
  watchers = {}
end

function M.process_queue()
  if is_uploading or #upload_queue == 0 then return end
  is_uploading = true
  local to_upload = vim.deepcopy(upload_queue)
  upload_queue = {}
  M.upload_cartridges(M.dw_config, to_upload, M.opts, function()
    is_uploading = false
    if #upload_queue > 0 then vim.defer_fn(M.process_queue, 500) end
  end)
end

function M.clean_upload(dw_config, opts)
  local cartridges = config_loader.get_cartridges()
  if #cartridges == 0 then
    vim.notify("Prophet: No cartridges found", vim.log.levels.WARN)
    return
  end
  M.upload_cartridges(dw_config, vim.tbl_map(function(c) return c.name end, cartridges), opts)
end

function M.upload_single(dw_config, name, opts)
  M.upload_cartridges(dw_config, { name }, opts)
end

function M.upload_cartridges(dw_config, names, opts, callback)
  local total, completed, failed = #names, 0, 0
  local active, idx = 0, 1
  local current = {}

  local function notify_progress()
    if not opts.notify then return end
    local status = string.format("Prophet: %d/%d", completed + failed, total)
    if #current > 0 then status = status .. " [" .. table.concat(current, ", ") .. "]" end
    if failed > 0 then status = status .. string.format(" (%d failed)", failed) end
    vim.notify(status, vim.log.levels.INFO, { id = "prophet_upload", replace = "prophet_upload" })
  end

  local function on_done(success, name, err)
    vim.schedule(function()
      active = active - 1
      for i, n in ipairs(current) do if n == name then table.remove(current, i) break end end

      if success then
        completed = completed + 1
      else
        failed = failed + 1
        vim.notify(string.format("Prophet: %s failed: %s", name, err or "unknown"), vim.log.levels.ERROR)
      end

      if completed + failed >= total then
        local msg = failed == 0
          and string.format("Prophet: All %d uploaded", completed)
          or string.format("Prophet: %d succeeded, %d failed", completed, failed)
        vim.notify(msg, failed == 0 and vim.log.levels.INFO or vim.log.levels.WARN, { id = "prophet_upload", replace = "prophet_upload" })
        if callback then callback() end
      else
        notify_progress()
        start_next()
      end
    end)
  end

  local function start_next()
    while active < MAX_PARALLEL and idx <= #names do
      local name = names[idx]
      idx = idx + 1
      active = active + 1
      table.insert(current, name)
      notify_progress()
      M.upload_cartridge_async(dw_config, name, function(ok, err) on_done(ok, name, err) end, 0)
    end
  end

  start_next()
end

function M.upload_cartridge_async(dw_config, name, callback, retry)
  retry = retry or 0
  local cartridge
  for _, c in ipairs(config_loader.get_cartridges()) do
    if c.name == name then cartridge = c break end
  end
  if not cartridge then callback(false, "Not found") return end

  local zip = vim.fn.tempname() .. ".zip"
  local exclude = table.concat(vim.tbl_map(vim.fn.shellescape, M.opts.ignore_patterns or {}), " -x ")
  local cmd = string.format("cd %s && zip -r -q %s * -x %s",
    vim.fn.shellescape(cartridge.path), vim.fn.shellescape(zip), exclude)

  vim.fn.jobstart(cmd, {
    on_exit = vim.schedule_wrap(function(_, code)
      if code ~= 0 then callback(false, "Zip failed") return end
      M.upload_zip(dw_config, name, zip, callback, retry)
    end),
  })
end

local function curl_error(code)
  local msg = { [6] = "Host not found", [7] = "Connection failed", [22] = "Auth failed", [28] = "Timeout", [56] = "Network error" }
  return msg[code] or "Upload failed"
end

function M.upload_zip(dw_config, name, zip, callback, retry)
  local base = string.format("https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s/%s_cartridge.zip",
    dw_config.hostname, dw_config["code-version"], name)
  local auth = string.format("-u %s:%s", vim.fn.shellescape(dw_config.username), vim.fn.shellescape(dw_config.password))

  -- Upload
  vim.fn.jobstart(string.format("curl -s --max-time 20 -X PUT -H 'Content-Type: application/zip' %s --data-binary @%s %s",
    auth, vim.fn.shellescape(zip), base), {
    on_exit = vim.schedule_wrap(function(_, code)
      if code ~= 0 then
        vim.fn.delete(zip)
        if retry < MAX_RETRIES and code ~= 22 and code ~= 6 then
          vim.defer_fn(function() M.upload_cartridge_async(dw_config, name, callback, retry + 1) end, RETRY_DELAYS[retry + 1] or 6000)
        else
          callback(false, curl_error(code))
        end
        return
      end
      -- Unzip
      vim.fn.jobstart(string.format("curl -s --max-time 20 -X POST -H 'Content-Type: application/x-www-form-urlencoded' --data 'method=UNZIP' %s %s", auth, base), {
        on_exit = vim.schedule_wrap(function(_, unzip_code)
          -- Cleanup
          vim.fn.jobstart(string.format("curl -s --max-time 10 -X DELETE %s %s", auth, base), {
            on_exit = vim.schedule_wrap(function()
              vim.fn.delete(zip)
              callback(unzip_code == 0, unzip_code ~= 0 and "Unzip failed" or nil)
            end),
          })
        end),
      })
    end),
  })
end

return M
