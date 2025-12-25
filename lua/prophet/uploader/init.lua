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
    return -- Already watching
  end

  local cartridges = config_loader.get_cartridges()

  for _, cartridge in ipairs(cartridges) do
    local watcher = vim.loop.new_fs_event()
    if watcher then
      watcher:start(
        cartridge.path,
        { recursive = true },
        vim.schedule_wrap(function(err, filename, events)
          if err then
            return
          end

          -- Ignore files matching patterns
          if M.opts and utils.should_ignore(filename, M.opts.ignore_patterns) then
            return
          end

          -- Add to upload queue
          if not vim.tbl_contains(upload_queue, cartridge.name) then
            table.insert(upload_queue, cartridge.name)
          end

          -- Debounce uploads
          vim.defer_fn(function()
            M.process_queue()
          end, 1000)
        end)
      )
      table.insert(watchers, watcher)
    end
  end

  vim.notify("Prophet: Watching " .. #cartridges .. " cartridge(s)", vim.log.levels.INFO)
end

function M.disable_watch()
  for _, watcher in ipairs(watchers) do
    if watcher then
      watcher:stop()
    end
  end
  watchers = {}
end

function M.process_queue()
  if is_uploading or #upload_queue == 0 then
    return
  end

  is_uploading = true
  local cartridges_to_upload = vim.deepcopy(upload_queue)
  upload_queue = {}

  M.upload_cartridges(M.dw_config, cartridges_to_upload, M.opts, function()
    is_uploading = false
    if #upload_queue > 0 then
      vim.defer_fn(function()
        M.process_queue()
      end, 500)
    end
  end)
end

function M.clean_upload(dw_config, opts)
  local cartridges = config_loader.get_cartridges()

  if #cartridges == 0 then
    vim.notify("Prophet: No cartridges found", vim.log.levels.WARN)
    return
  end

  vim.notify(
    string.format("Prophet: Starting clean upload of %d cartridge(s)...", #cartridges),
    vim.log.levels.INFO
  )

  local cartridge_names = {}
  for _, c in ipairs(cartridges) do
    table.insert(cartridge_names, c.name)
  end

  M.upload_cartridges(dw_config, cartridge_names, opts)
end

function M.upload_single(dw_config, cartridge_name, opts)
  M.upload_cartridges(dw_config, { cartridge_name }, opts)
end

function M.upload_cartridges(dw_config, cartridge_names, opts, callback)
  local total = #cartridge_names
  local completed = 0
  local failed = 0

  local function upload_next(index)
    if index > total then
      -- All done
      if failed == 0 then
        vim.notify(
          string.format("Prophet: Successfully uploaded %d/%d cartridge(s)", completed, total),
          vim.log.levels.INFO
        )
      else
        vim.notify(
          string.format("Prophet: Upload completed with errors: %d succeeded, %d failed", completed, failed),
          vim.log.levels.WARN
        )
      end

      if callback then
        callback()
      end
      return
    end

    local cartridge_name = cartridge_names[index]

    -- Show progress
    if opts.notify then
      utils.show_progress(index, total, cartridge_name)
    end

    -- Execute upload
    M.upload_cartridge_zip(dw_config, cartridge_name, function(success, err)
      if success then
        completed = completed + 1
      else
        failed = failed + 1
        vim.notify(
          string.format("Prophet: Failed to upload %s: %s", cartridge_name, err or "unknown error"),
          vim.log.levels.ERROR
        )
      end

      -- Upload next
      upload_next(index + 1)
    end)
  end

  upload_next(1)
end

function M.upload_cartridge_zip(dw_config, cartridge_name, callback)
  local cartridges = config_loader.get_cartridges()
  local cartridge = nil

  for _, c in ipairs(cartridges) do
    if c.name == cartridge_name then
      cartridge = c
      break
    end
  end

  if not cartridge then
    callback(false, "Cartridge not found")
    return
  end

  -- Create zip file
  local zip_file = vim.fn.tempname() .. ".zip"
  local zip_cmd = string.format(
    "cd %s && zip -r -q %s * -x %s",
    vim.fn.shellescape(cartridge.path),
    vim.fn.shellescape(zip_file),
    table.concat(vim.tbl_map(function(p)
      return vim.fn.shellescape(p)
    end, M.opts.ignore_patterns or {}), " -x ")
  )

  vim.fn.jobstart(zip_cmd, {
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        callback(false, "Failed to create zip")
        return
      end

      -- Upload zip via WebDAV
      local upload_cmd = string.format(
        "curl -s -f -X PUT -u %s:%s --data-binary @%s https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s/%s.zip",
        vim.fn.shellescape(dw_config.username),
        vim.fn.shellescape(dw_config.password),
        vim.fn.shellescape(zip_file),
        dw_config.hostname,
        dw_config["code-version"],
        cartridge_name
      )

      vim.fn.jobstart(upload_cmd, {
        on_exit = function(_, upload_exit_code)
          -- Clean up
          vim.fn.delete(zip_file)

          if upload_exit_code == 0 then
            callback(true)
          else
            callback(false, "Upload failed")
          end
        end,
      })
    end,
  })
end

return M
