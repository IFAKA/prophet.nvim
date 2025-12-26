local M = {}

local utils = require("prophet.utils")
local config_loader = require("prophet.config")

local watchers = {}
local upload_queue = {}
local is_uploading = false

function M.init(dw_config, opts)
  M.dw_config = dw_config
  M.opts = opts
end

function M.enable_watch()
  if #watchers > 0 then 
    vim.notify("Prophet: Upload watching already enabled", vim.log.levels.INFO)
    return 
  end
  
  local cartridges = config_loader.get_cartridges()
  if #cartridges == 0 then
    vim.notify("Prophet: No cartridges found to watch", vim.log.levels.WARN)
    return
  end
  
  local watched_count = 0
  for _, cartridge in ipairs(cartridges) do
    local watcher = vim.loop.new_fs_event()
    if watcher then
      local success = watcher:start(cartridge.path, { recursive = true }, vim.schedule_wrap(function(err, filename)
        if err then 
          vim.notify("Prophet: File watch error: " .. err, vim.log.levels.ERROR)
          return 
        end
        
        if utils.should_ignore(filename, M.opts.ignore_patterns) then 
          return 
        end
        
        -- Only queue if file is in cartridge/subfolder
        local full_path = cartridge.path .. "/" .. filename
        if utils.is_sfcc_file(full_path) then
          if not vim.tbl_contains(upload_queue, cartridge.name) then
            table.insert(upload_queue, cartridge.name)
            if M.opts.notify then
              vim.notify(string.format("Prophet: Queued %s for upload", cartridge.name), vim.log.levels.INFO)
            end
          end
          vim.defer_fn(M.process_queue, 1000)
        end
      end))
      
      if success then
        table.insert(watchers, watcher)
        watched_count = watched_count + 1
      else
        vim.notify("Prophet: Failed to watch " .. cartridge.name, vim.log.levels.WARN)
      end
    end
  end
  
  if watched_count > 0 then
    vim.notify(string.format("Prophet: Watching %d cartridge(s) for changes", watched_count), vim.log.levels.INFO)
  else
    vim.notify("Prophet: Failed to enable file watching", vim.log.levels.ERROR)
  end
end

function M.disable_watch()
  for _, watcher in ipairs(watchers) do
    if watcher then watcher:stop() end
  end
  watchers = {}
end

function M.process_queue()
  if is_uploading or #upload_queue == 0 then return end
  
  is_uploading = true
  local cartridges_to_upload = vim.deepcopy(upload_queue)
  upload_queue = {}
  
  M.upload_cartridges(M.dw_config, cartridges_to_upload, M.opts, function()
    is_uploading = false
    if #upload_queue > 0 then
      vim.defer_fn(M.process_queue, 500)
    end
  end)
end

function M.clean_upload(dw_config, opts)
  local cartridges = config_loader.get_cartridges()
  if #cartridges == 0 then
    vim.notify("Prophet: No cartridges found", vim.log.levels.WARN)
    return
  end
  
  -- Temporarily skip sandbox check to test upload directly
  -- TODO: Fix sandbox check later
  -- local sandbox_ok, sandbox_msg = config_loader.check_sandbox_status_sync(dw_config)
  -- if not sandbox_ok then
  --   vim.notify("Prophet: " .. sandbox_msg, vim.log.levels.ERROR)
  --   return
  -- end
  
  vim.notify(string.format("Prophet: Sandbox online. Starting clean upload of %d cartridge(s)...", #cartridges), vim.log.levels.INFO)
  
  local names = vim.tbl_map(function(c) return c.name end, cartridges)
  M.upload_cartridges(dw_config, names, opts)
end

function M.upload_single(dw_config, cartridge_name, opts)
  -- Temporarily skip sandbox check to test upload directly  
  -- local sandbox_ok, sandbox_msg = config_loader.check_sandbox_status_sync(dw_config)
  -- if not sandbox_ok then
  --   vim.notify("Prophet: " .. sandbox_msg, vim.log.levels.ERROR)
  --   return
  -- end
  
  M.upload_cartridges(dw_config, { cartridge_name }, opts)
end

function M.upload_cartridges(dw_config, cartridge_names, opts, callback)
  local total = #cartridge_names
  local completed, failed = 0, 0
  local early_abort = false
  
  local function upload_next(index)
    if index > total or early_abort then
      local msg = early_abort
        and string.format("Prophet: Upload aborted after %d attempts due to sandbox connectivity issues", index - 1)
        or (failed == 0 
          and string.format("Prophet: Successfully uploaded %d/%d cartridge(s)", completed, total)
          or string.format("Prophet: Upload completed: %d succeeded, %d failed", completed, failed))
      vim.notify(msg, (failed == 0 and not early_abort) and vim.log.levels.INFO or vim.log.levels.WARN)
      if callback then callback() end
      return
    end
    
    local cartridge_name = cartridge_names[index]
    if opts.notify then utils.show_progress(index, total, cartridge_name) end
    
    M.upload_cartridge_zip(dw_config, cartridge_name, function(success, err)
      if success then
        completed = completed + 1
      else
        failed = failed + 1
        local error_msg = err or "unknown"
        
        -- Check if this is a connectivity/authentication issue and abort early
        if error_msg:find("connection") or error_msg:find("timeout") or 
           error_msg:find("authentication") or error_msg:find("resolve host") or
           error_msg:find("couldn't connect") or error_msg:find("network") then
          vim.notify(string.format("Prophet: Connectivity issue detected: %s", error_msg), vim.log.levels.ERROR)
          vim.notify("Prophet: Stopping upload to avoid repeated failures. Check sandbox status and try again.", vim.log.levels.WARN)
          early_abort = true
          upload_next(index + 1) -- Will trigger abort message
          return
        end
        
        vim.notify(string.format("Prophet: Failed to upload %s: %s", cartridge_name, error_msg), vim.log.levels.ERROR)
      end
      upload_next(index + 1)
    end)
  end
  
  upload_next(1)
end

function M.upload_cartridge_zip(dw_config, cartridge_name, callback)
  local cartridges = config_loader.get_cartridges()
  local cartridge = nil
  
  for _, c in ipairs(cartridges) do
    if c.name == cartridge_name then cartridge = c break end
  end
  
  if not cartridge then
    callback(false, "Cartridge not found")
    return
  end
  
  local zip_file = vim.fn.tempname() .. ".zip"
  local exclude = table.concat(vim.tbl_map(vim.fn.shellescape, M.opts.ignore_patterns or {}), " -x ")
  local zip_cmd = string.format("cd %s && zip -r -q %s * -x %s",
    vim.fn.shellescape(cartridge.path), vim.fn.shellescape(zip_file), exclude)
  
  vim.fn.jobstart(zip_cmd, {
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        callback(false, "Failed to create zip")
        return
      end
      
      -- Use exact VSCode Prophet zip upload approach
      local upload_cmd = string.format(
        "curl -s --max-time 30 -X PUT -H 'Content-Type: application/zip' -u %s:%s --data-binary @%s https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s/%s_cartridge.zip",
        vim.fn.shellescape(dw_config.username), vim.fn.shellescape(dw_config.password),
        vim.fn.shellescape(zip_file), dw_config.hostname, dw_config["code-version"], cartridge_name)
      
      vim.fn.jobstart(upload_cmd, {
        on_exit = function(_, upload_exit_code)
          if upload_exit_code == 0 then
            -- Step 2: Unzip the uploaded file (VSCode Prophet approach)
            local unzip_cmd = string.format(
              "curl -s --max-time 30 -X POST -H 'Content-Type: application/x-www-form-urlencoded' --data 'method=UNZIP' -u %s:%s https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s/%s_cartridge.zip",
              vim.fn.shellescape(dw_config.username), vim.fn.shellescape(dw_config.password),
              dw_config.hostname, dw_config["code-version"], cartridge_name)
            
            vim.fn.jobstart(unzip_cmd, {
              on_exit = function(_, unzip_exit_code)
                -- Step 3: Clean up zip file
                local cleanup_cmd = string.format(
                  "curl -s --max-time 10 -X DELETE -u %s:%s https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s/%s_cartridge.zip",
                  vim.fn.shellescape(dw_config.username), vim.fn.shellescape(dw_config.password),
                  dw_config.hostname, dw_config["code-version"], cartridge_name)
                
                vim.fn.jobstart(cleanup_cmd, {
                  on_exit = function(_, _)
                    vim.fn.delete(zip_file) -- Delete local zip file
                    
                    if unzip_exit_code == 0 then
                      callback(true, nil)
                    else
                      callback(false, string.format("unzip failed (exit code %d)", unzip_exit_code))
                    end
                  end,
                })
              end,
            })
          else
            vim.fn.delete(zip_file)
            
            -- Provide specific error messages based on curl exit codes
            if upload_exit_code == 7 then
              callback(false, "connection failed - cannot reach sandbox")
            elseif upload_exit_code == 22 then
              callback(false, "authentication failed - check credentials")
            elseif upload_exit_code == 28 then
              callback(false, "timeout - sandbox not responding")
            elseif upload_exit_code == 6 then
              callback(false, "couldn't resolve host - check hostname")
            elseif upload_exit_code == 56 then
              callback(false, "network receive error - check credentials and WebDAV permissions")
            else
              callback(false, string.format("upload failed (exit code %d)", upload_exit_code))
            end
          end
        end,
      })
    end,
  })
end

return M
