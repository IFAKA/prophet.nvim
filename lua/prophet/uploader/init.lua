local M = {}

local utils = require("prophet.utils")
local config_loader = require("prophet.config")

local watchers = {}
local upload_queue = {}
local is_uploading = false
local progress_state = {
  total = 0,
  completed = 0,
  failed = 0,
  current_items = {}
}

-- Match VSCode Prophet performance settings
local MAX_PARALLEL_UPLOADS = 4  -- VSCode uses 4
local MAX_RETRIES = 3           -- VSCode uses 3 retries
local RETRY_DELAYS = { 2000, 4000, 6000 }  -- Exponential backoff in ms

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
  
  M.upload_cartridges_parallel(M.dw_config, cartridges_to_upload, M.opts, function()
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
  
  vim.notify(string.format("Prophet: Starting clean upload of %d cartridge(s)...", #cartridges), vim.log.levels.INFO)
  
  local names = vim.tbl_map(function(c) return c.name end, cartridges)
  M.upload_cartridges_parallel(dw_config, names, opts)
end

function M.upload_single(dw_config, cartridge_name, opts)
  M.upload_cartridges_parallel(dw_config, { cartridge_name }, opts)
end

-- NEW: Parallel upload system that doesn't block Neovim
function M.upload_cartridges_parallel(dw_config, cartridge_names, opts, callback)
  progress_state.total = #cartridge_names
  progress_state.completed = 0
  progress_state.failed = 0
  progress_state.current_items = {}
  
  -- Initialize progress display
  utils.init_progress_display(progress_state.total)
  
  local active_uploads = 0
  local max_parallel = math.min(MAX_PARALLEL_UPLOADS, #cartridge_names)
  local upload_index = 1
  
  local function start_next_upload()
    if upload_index > #cartridge_names then
      return
    end
    
    local cartridge_name = cartridge_names[upload_index]
    upload_index = upload_index + 1
    active_uploads = active_uploads + 1
    
    -- Update progress to show this cartridge is starting
    progress_state.current_items[cartridge_name] = "uploading"
    utils.update_progress_display(progress_state)
    
    -- Start upload asynchronously
    M.upload_cartridge_async(dw_config, cartridge_name, function(success, err)
      vim.schedule(function() -- Ensure UI updates happen on main thread
        active_uploads = active_uploads - 1
        progress_state.current_items[cartridge_name] = nil
        
        if success then
          progress_state.completed = progress_state.completed + 1
          if opts.notify then
            vim.notify(string.format("Prophet: ✓ %s uploaded (%d/%d)", 
              cartridge_name, progress_state.completed, progress_state.total), vim.log.levels.INFO)
          end
        else
          progress_state.failed = progress_state.failed + 1
          vim.notify(string.format("Prophet: ✗ %s failed: %s", cartridge_name, err or "unknown"), vim.log.levels.ERROR)
        end
        
        utils.update_progress_display(progress_state)
        
        -- Check if we're done
        if progress_state.completed + progress_state.failed >= progress_state.total then
          utils.close_progress_display()
          local msg = progress_state.failed == 0 
            and string.format("Prophet: ✓ All %d cartridge(s) uploaded successfully", progress_state.completed)
            or string.format("Prophet: Upload completed: %d succeeded, %d failed", progress_state.completed, progress_state.failed)
          vim.notify(msg, progress_state.failed == 0 and vim.log.levels.INFO or vim.log.levels.WARN)
          
          if callback then callback() end
        else
          -- Start next upload if there's capacity
          if active_uploads < max_parallel then
            start_next_upload()
          end
        end
      end)
    end)
    
    -- Start more uploads in parallel if possible
    if active_uploads < max_parallel then
      start_next_upload()
    end
  end
  
  -- Start initial batch of parallel uploads
  start_next_upload()
end

-- Upload with retry logic (matches VSCode Prophet behavior)
function M.upload_cartridge_async(dw_config, cartridge_name, callback, retry_count)
  retry_count = retry_count or 0

  local cartridges = config_loader.get_cartridges()
  local cartridge = nil

  for _, c in ipairs(cartridges) do
    if c.name == cartridge_name then cartridge = c break end
  end

  if not cartridge then
    callback(false, "Cartridge not found")
    return
  end

  -- Step 1: Create zip asynchronously
  local zip_file = vim.fn.tempname() .. ".zip"
  local exclude = table.concat(vim.tbl_map(vim.fn.shellescape, M.opts.ignore_patterns or {}), " -x ")
  local zip_cmd = string.format("cd %s && zip -r -q %s * -x %s",
    vim.fn.shellescape(cartridge.path), vim.fn.shellescape(zip_file), exclude)

  local zip_job = vim.fn.jobstart(zip_cmd, {
    on_exit = vim.schedule_wrap(function(_, exit_code)
      if exit_code ~= 0 then
        callback(false, "Failed to create zip")
        return
      end

      -- Step 2: Upload zip with retry wrapper
      M.upload_zip_with_retry(dw_config, cartridge_name, zip_file, callback, retry_count)
    end),
    stdout_buffered = false,
    stderr_buffered = false,
  })

  if not zip_job or zip_job <= 0 then
    callback(false, "Failed to start zip process")
  end
end

-- Retry wrapper for upload operations
function M.upload_zip_with_retry(dw_config, cartridge_name, zip_file, callback, retry_count)
  M.upload_zip_file_async(dw_config, cartridge_name, zip_file, function(success, err)
    if success then
      callback(true, nil)
    elseif retry_count < MAX_RETRIES and M.is_retryable_error(err) then
      -- Retry with exponential backoff
      local delay = RETRY_DELAYS[retry_count + 1] or 6000
      vim.defer_fn(function()
        -- Create new zip for retry (old one was deleted on failure)
        M.upload_cartridge_async(dw_config, cartridge_name, callback, retry_count + 1)
      end, delay)
    else
      callback(false, err)
    end
  end)
end

-- Check if error is retryable (not auth failures)
function M.is_retryable_error(err)
  if not err then return true end
  -- Don't retry auth failures or host resolution errors
  local non_retryable = { "authentication", "credentials", "resolve host" }
  for _, pattern in ipairs(non_retryable) do
    if string.find(err:lower(), pattern) then return false end
  end
  return true
end

-- Async zip upload with proper cleanup
function M.upload_zip_file_async(dw_config, cartridge_name, zip_file, callback)
  local upload_cmd = string.format(
    "curl -s --max-time 20 -X PUT -H 'Content-Type: application/zip' -u %s:%s --data-binary @%s https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s/%s_cartridge.zip",
    vim.fn.shellescape(dw_config.username), vim.fn.shellescape(dw_config.password),
    vim.fn.shellescape(zip_file), dw_config.hostname, dw_config["code-version"], cartridge_name)
  
  local upload_job = vim.fn.jobstart(upload_cmd, {
    on_exit = vim.schedule_wrap(function(_, upload_exit_code)
      if upload_exit_code == 0 then
        -- Step 3: Unzip on server asynchronously
        M.unzip_on_server_async(dw_config, cartridge_name, zip_file, callback)
      else
        vim.fn.delete(zip_file)
        
        -- Provide specific error messages based on curl exit codes
        local error_msg = "upload failed"
        if upload_exit_code == 7 then
          error_msg = "connection failed - cannot reach sandbox"
        elseif upload_exit_code == 22 then
          error_msg = "authentication failed - check credentials"
        elseif upload_exit_code == 28 then
          error_msg = "timeout - sandbox not responding"
        elseif upload_exit_code == 6 then
          error_msg = "couldn't resolve host - check hostname"
        elseif upload_exit_code == 56 then
          error_msg = "network receive error - check credentials and WebDAV permissions"
        end
        
        callback(false, error_msg)
      end
    end),
    stdout_buffered = false,
    stderr_buffered = false,
  })
  
  if not upload_job or upload_job <= 0 then
    vim.fn.delete(zip_file)
    callback(false, "Failed to start upload process")
  end
end

-- Async server-side unzip
function M.unzip_on_server_async(dw_config, cartridge_name, zip_file, callback)
  local unzip_cmd = string.format(
    "curl -s --max-time 20 -X POST -H 'Content-Type: application/x-www-form-urlencoded' --data 'method=UNZIP' -u %s:%s https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s/%s_cartridge.zip",
    vim.fn.shellescape(dw_config.username), vim.fn.shellescape(dw_config.password),
    dw_config.hostname, dw_config["code-version"], cartridge_name)
  
  local unzip_job = vim.fn.jobstart(unzip_cmd, {
    on_exit = vim.schedule_wrap(function(_, unzip_exit_code)
      -- Step 4: Cleanup zip file on server asynchronously
      M.cleanup_server_zip_async(dw_config, cartridge_name, zip_file, unzip_exit_code == 0, callback)
    end),
    stdout_buffered = false,
    stderr_buffered = false,
  })
  
  if not unzip_job or unzip_job <= 0 then
    vim.fn.delete(zip_file)
    callback(false, "Failed to start unzip process")
  end
end

-- Async server cleanup
function M.cleanup_server_zip_async(dw_config, cartridge_name, zip_file, unzip_success, callback)
  local cleanup_cmd = string.format(
    "curl -s --max-time 10 -X DELETE -u %s:%s https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s/%s_cartridge.zip",
    vim.fn.shellescape(dw_config.username), vim.fn.shellescape(dw_config.password),
    dw_config.hostname, dw_config["code-version"], cartridge_name)
  
  local cleanup_job = vim.fn.jobstart(cleanup_cmd, {
    on_exit = vim.schedule_wrap(function(_, _)
      -- Always delete local zip file
      vim.fn.delete(zip_file)
      
      if unzip_success then
        callback(true, nil)
      else
        callback(false, "unzip failed on server")
      end
    end),
    stdout_buffered = false,
    stderr_buffered = false,
  })
  
  if not cleanup_job or cleanup_job <= 0 then
    vim.fn.delete(zip_file)
    callback(unzip_success, unzip_success and nil or "unzip failed, cleanup also failed")
  end
end

-- Compatibility aliases
M.upload_cartridges = M.upload_cartridges_parallel
M.upload_cartridge_zip = M.upload_cartridge_async

return M