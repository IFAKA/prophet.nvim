local M = {}

local progress_state = {
  buf = nil,
  win = nil,
  timer = nil,
  active = false
}

function M.should_ignore(filename, patterns)
  if not (filename and patterns) then return false end
  for _, pattern in ipairs(patterns) do
    if string.match(filename, pattern) then return true end
  end
  return false
end

function M.is_sfcc_file(filepath)
  local extension = vim.fn.fnamemodify(filepath, ":e")
  local sfcc_extensions = { "isml", "ds", "js", "json", "properties", "xml" }
  return vim.tbl_contains(sfcc_extensions, extension)
end

function M.get_cartridge_from_path(filepath)
  -- Extract cartridge name from file path
  local parts = vim.split(filepath, "/")
  for i, part in ipairs(parts) do
    if part == "cartridge" and i > 1 then
      return parts[i - 1]
    end
  end
  return nil
end

function M.is_in_cartridge(filepath)
  return M.get_cartridge_from_path(filepath) ~= nil
end

function M.get_relative_cartridge_path(filepath)
  -- Convert absolute path to cartridge-relative path for upload
  local parts = vim.split(filepath, "/")
  local cartridge_index = nil

  for i, part in ipairs(parts) do
    if part == "cartridge" then
      cartridge_index = i
      break
    end
  end

  if cartridge_index and cartridge_index < #parts then
    local relative_parts = {}
    for i = cartridge_index + 1, #parts do
      table.insert(relative_parts, parts[i])
    end
    return table.concat(relative_parts, "/")
  end

  return nil
end

function M.create_temp_zip(cartridge_path, ignore_patterns)
  local zip_file = vim.fn.tempname() .. ".zip"
  local exclude_args = {}

  if ignore_patterns then
    for _, pattern in ipairs(ignore_patterns) do
      table.insert(exclude_args, "-x")
      table.insert(exclude_args, pattern)
    end
  end

  local cmd = {
    "zip", "-r", "-q", zip_file, ".",
    unpack(exclude_args)
  }

  local result = vim.fn.system(cmd, nil, cartridge_path)
  local exit_code = vim.v.shell_error

  if exit_code == 0 then
    return zip_file
  else
    return nil, "Failed to create zip: " .. (result or "Unknown error")
  end
end

-- NEW: Non-blocking progress display system
function M.init_progress_display(total)
  -- Check if we're in a headless mode or no UI is available
  local ui_list = vim.api.nvim_list_uis()
  if #ui_list == 0 then
    return
  end

  M.close_progress_display() -- Clean up any existing display

  progress_state.active = true
  
  -- Create a floating buffer for progress
  progress_state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(progress_state.buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(progress_state.buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(progress_state.buf, "swapfile", false)

  local ui = ui_list[1]
  local width = 50
  local height = 8

  progress_state.win = vim.api.nvim_open_win(progress_state.buf, false, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((ui.height - height) / 2),
    col = math.floor((ui.width - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " Prophet Upload Progress ",
    title_pos = "center"
  })

  -- Set window options
  vim.api.nvim_win_set_option(progress_state.win, "winhl", "Normal:Normal,FloatBorder:FloatBorder")

  -- Start update timer (non-blocking)
  progress_state.timer = vim.loop.new_timer()
  if progress_state.timer then
    progress_state.timer:start(0, 100, vim.schedule_wrap(function()
      if not progress_state.active then
        return
      end
      M.refresh_progress_display()
    end))
  end
end

function M.update_progress_display(state)
  if not progress_state.active then return end
  
  progress_state.current_state = state
end

function M.refresh_progress_display()
  if not (progress_state.active and progress_state.buf and vim.api.nvim_buf_is_valid(progress_state.buf)) then
    return
  end

  local state = progress_state.current_state
  if not state then return end

  local lines = {}
  local completed = state.completed or 0
  local failed = state.failed or 0
  local total = state.total or 0
  local current_items = state.current_items or {}

  -- Progress bar
  local progress_width = 40
  local progress_pct = total > 0 and (completed + failed) / total or 0
  local filled = math.floor(progress_pct * progress_width)
  local bar = string.rep("█", filled) .. string.rep("░", progress_width - filled)

  table.insert(lines, "")
  table.insert(lines, string.format("  Progress: %d/%d completed, %d failed", completed, total, failed))
  table.insert(lines, string.format("  [%s] %.1f%%", bar, progress_pct * 100))
  table.insert(lines, "")

  -- Current uploads
  local current_list = {}
  for cartridge, status in pairs(current_items) do
    table.insert(current_list, string.format("  • %s (%s)", cartridge, status))
  end

  if #current_list > 0 then
    table.insert(lines, "  Currently uploading:")
    for _, line in ipairs(current_list) do
      table.insert(lines, line)
    end
  else
    table.insert(lines, "  Preparing next uploads...")
  end

  -- Safely update buffer
  pcall(function()
    vim.api.nvim_buf_set_lines(progress_state.buf, 0, -1, false, lines)
  end)
end

function M.close_progress_display()
  progress_state.active = false

  if progress_state.timer then
    if not progress_state.timer:is_closing() then
      progress_state.timer:stop()
      progress_state.timer:close()
    end
    progress_state.timer = nil
  end

  if progress_state.win and vim.api.nvim_win_is_valid(progress_state.win) then
    vim.api.nvim_win_close(progress_state.win, true)
  end
  progress_state.win = nil

  if progress_state.buf and vim.api.nvim_buf_is_valid(progress_state.buf) then
    vim.api.nvim_buf_delete(progress_state.buf, { force = true })
  end
  progress_state.buf = nil

  progress_state.current_state = nil
end

-- LEGACY: Keep old function for compatibility but make it non-blocking
function M.show_progress(current, total, item_name)
  -- Check if we're in a headless mode or no UI is available
  local ui_list = vim.api.nvim_list_uis()
  if #ui_list == 0 then
    -- Fallback to simple notification in headless mode
    vim.notify(string.format("Prophet: Uploading %d/%d: %s", current, total, item_name), vim.log.levels.INFO)
    return
  end

  -- Use new progress system
  if not progress_state.active then
    M.init_progress_display(total)
  end

  M.update_progress_display({
    total = total,
    completed = current - 1,
    failed = 0,
    current_items = { [item_name] = "uploading" }
  })
end

return M