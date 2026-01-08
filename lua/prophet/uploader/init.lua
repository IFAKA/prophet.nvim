local M = {}

local utils = require("prophet.utils")
local config_loader = require("prophet.config")

local watchers = {}
local file_queue = {}
local is_uploading = false

local MAX_PARALLEL = 4
local MAX_RETRIES = 3
local RETRY_DELAYS = { 2000, 4000, 6000 }

function M.init(dw_config, opts)
  M.dw_config = dw_config
  M.opts = opts
end

-- Direct file upload (for watch mode) - uses netrc for auth to handle special chars in password
function M.upload_file_async(dw_config, filepath, cartridge_path, callback, retry)
  retry = retry or 0

  -- Get relative path from cartridge parent (e.g., "app_custom_kiwoko/cartridge/templates/...")
  local parent_path = vim.fn.fnamemodify(cartridge_path, ":h")
  local relative_path = filepath:sub(#parent_path + 2) -- +2 for the trailing slash

  local url = string.format("https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s/%s",
    dw_config.hostname, dw_config["code-version"], relative_path)

  -- Write credentials to temp netrc file to avoid shell escaping issues
  local netrc = vim.fn.tempname()
  local netrc_content = string.format("machine %s login %s password %s",
    dw_config.hostname, dw_config.username, dw_config.password)
  vim.fn.writefile({netrc_content}, netrc)

  local cmd = string.format("curl -s --max-time 30 -X PUT --netrc-file %s --data-binary @%s %s -w '%%{http_code}'",
    vim.fn.shellescape(netrc), vim.fn.shellescape(filepath), vim.fn.shellescape(url))

  local output = {}
  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then table.insert(output, line) end
        end
      end
    end,
    on_exit = vim.schedule_wrap(function(_, code)
      vim.fn.delete(netrc)
      local response = table.concat(output, "")
      local http_code = tonumber(response:match("(%d+)$")) or 0

      if code ~= 0 or (http_code >= 400 and http_code ~= 404) then
        if retry < MAX_RETRIES and code ~= 22 then
          vim.defer_fn(function()
            M.upload_file_async(dw_config, filepath, cartridge_path, callback, retry + 1)
          end, RETRY_DELAYS[retry + 1] or 6000)
        else
          callback(false, string.format("HTTP %d", http_code))
        end
        return
      end
      callback(true, nil)
    end),
  })
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
      local full_path = cartridge.path .. "/" .. filename
      if utils.is_sfcc_file(full_path) and vim.fn.filereadable(full_path) == 1 then
        -- Queue the specific file with its cartridge info
        local already_queued = false
        for _, item in ipairs(file_queue) do
          if item.path == full_path then already_queued = true break end
        end
        if not already_queued then
          table.insert(file_queue, { path = full_path, cartridge_path = cartridge.path, cartridge_name = cartridge.name })
          if M.opts.notify then
            vim.notify("Prophet: Queued " .. filename, vim.log.levels.INFO)
          end
        end
        vim.defer_fn(M.process_file_queue, 500)
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
  vim.notify("Prophet: Upload disabled", vim.log.levels.INFO)
end

-- Process individual file uploads (watch mode)
function M.process_file_queue()
  if is_uploading or #file_queue == 0 then return end
  is_uploading = true

  local to_upload = vim.deepcopy(file_queue)
  file_queue = {}

  local total, completed, failed = #to_upload, 0, 0
  local active, idx = 0, 1

  local function on_done(success, item, err)
    vim.schedule(function()
      active = active - 1
      if success then
        completed = completed + 1
      else
        failed = failed + 1
        vim.notify(string.format("Prophet: Failed %s: %s", vim.fn.fnamemodify(item.path, ":t"), err or "unknown"), vim.log.levels.ERROR)
      end

      if completed + failed >= total then
        is_uploading = false
        local msg = failed == 0
          and string.format("Prophet: %d file(s) uploaded", completed)
          or string.format("Prophet: %d uploaded, %d failed", completed, failed)
        vim.notify(msg, failed == 0 and vim.log.levels.INFO or vim.log.levels.WARN)
        if #file_queue > 0 then vim.defer_fn(M.process_file_queue, 500) end
      else
        start_next()
      end
    end)
  end

  local function start_next()
    while active < MAX_PARALLEL and idx <= #to_upload do
      local item = to_upload[idx]
      idx = idx + 1
      active = active + 1
      M.upload_file_async(M.dw_config, item.path, item.cartridge_path, function(ok, err)
        on_done(ok, item, err)
      end, 0)
    end
  end

  start_next()
end

-- Legacy queue processing (for compatibility)
function M.process_queue()
  M.process_file_queue()
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
  local start_next

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

  start_next = function()
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
  if not cartridge then
    callback(false, "Not found")
    return
  end

  local zip = vim.fn.tempname() .. ".zip"
  local parent_path = vim.fn.fnamemodify(cartridge.path, ":h")

  -- Zip from PARENT directory, including cartridge folder name
  -- This creates zip with: cartridge_name/cartridge/... (correct structure)
  local exclude_args = {}
  for _, pattern in ipairs(M.opts.ignore_patterns or {}) do
    table.insert(exclude_args, "-x " .. vim.fn.shellescape("*" .. pattern .. "*"))
  end
  local exclude = table.concat(exclude_args, " ")

  local cmd = string.format("cd %s && zip -r -q %s %s %s",
    vim.fn.shellescape(parent_path),
    vim.fn.shellescape(zip),
    vim.fn.shellescape(name),
    exclude)

  vim.fn.jobstart(cmd, {
    on_exit = vim.schedule_wrap(function(_, code)
      if code ~= 0 then
        callback(false, "Zip failed")
        return
      end
      M.upload_zip(dw_config, name, zip, cartridge.path, callback, retry)
    end),
  })
end

local function curl_error(code)
  local msg = { [6] = "Host not found", [7] = "Connection failed", [22] = "Auth failed", [28] = "Timeout", [56] = "Network error" }
  return msg[code] or "Upload failed"
end

function M.upload_zip(dw_config, name, zip, cartridge_path, callback, retry)
  local base_url = string.format("https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s",
    dw_config.hostname, dw_config["code-version"])
  local zip_url = base_url .. "/" .. name .. "_cartridge.zip"
  local cartridge_url = base_url .. "/" .. name

  -- Write credentials to temp netrc file to avoid shell escaping issues with special chars
  local netrc = vim.fn.tempname()
  local netrc_content = string.format("machine %s login %s password %s",
    dw_config.hostname, dw_config.username, dw_config.password)
  vim.fn.writefile({netrc_content}, netrc)

  -- Step 1: Delete existing cartridge folder first (like original Prophet)
  local delete_cartridge_cmd = string.format("curl -s --max-time 30 -X DELETE --netrc-file %s %s",
    vim.fn.shellescape(netrc), vim.fn.shellescape(cartridge_url))

  vim.fn.jobstart(delete_cartridge_cmd, {
    on_exit = vim.schedule_wrap(function(_, _)
      -- Step 2: Upload zip (ignore delete result, folder might not exist)
      local upload_cmd = string.format("curl -s --max-time 60 -X PUT -H 'Content-Type: application/zip' --netrc-file %s --data-binary @%s %s -w '%%{http_code}'",
        vim.fn.shellescape(netrc), vim.fn.shellescape(zip), vim.fn.shellescape(zip_url))

      local upload_output = {}
      vim.fn.jobstart(upload_cmd, {
        stdout_buffered = true,
        on_stdout = function(_, data)
          if data then for _, line in ipairs(data) do if line ~= "" then table.insert(upload_output, line) end end end
        end,
        on_exit = vim.schedule_wrap(function(_, upload_code)
          local response = table.concat(upload_output, "")
          local http_code = tonumber(response:match("(%d+)$")) or 0

          if upload_code ~= 0 or http_code >= 400 then
            vim.fn.delete(zip)
            vim.fn.delete(netrc)
            if retry < MAX_RETRIES and upload_code ~= 22 then
              vim.defer_fn(function() M.upload_cartridge_async(dw_config, name, callback, retry + 1) end, RETRY_DELAYS[retry + 1] or 6000)
            else
              callback(false, string.format("Upload failed (HTTP %d)", http_code))
            end
            return
          end

          -- Step 3: Unzip
          local unzip_cmd = string.format("curl -s --max-time 60 -X POST -d method=UNZIP --netrc-file %s %s -w '%%{http_code}'",
            vim.fn.shellescape(netrc), vim.fn.shellescape(zip_url))

          local unzip_output = {}
          vim.fn.jobstart(unzip_cmd, {
            stdout_buffered = true,
            on_stdout = function(_, data)
              if data then for _, line in ipairs(data) do if line ~= "" then table.insert(unzip_output, line) end end end
            end,
            on_exit = vim.schedule_wrap(function(_, unzip_code)
              local unzip_response = table.concat(unzip_output, "")
              local unzip_http = tonumber(unzip_response:match("(%d+)$")) or 0

              -- Step 4: Cleanup zip on server
              local cleanup_cmd = string.format("curl -s --max-time 10 -X DELETE --netrc-file %s %s",
                vim.fn.shellescape(netrc), vim.fn.shellescape(zip_url))

              vim.fn.jobstart(cleanup_cmd, {
                on_exit = vim.schedule_wrap(function()
                  vim.fn.delete(zip)
                  vim.fn.delete(netrc)
                  if unzip_code ~= 0 or unzip_http >= 400 then
                    callback(false, string.format("Unzip failed (HTTP %d)", unzip_http))
                  else
                    callback(true, nil)
                  end
                end),
              })
            end),
          })
        end),
      })
    end),
  })
end

return M
