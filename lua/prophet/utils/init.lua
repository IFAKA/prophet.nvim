local M = {}

local progress_win, progress_buf

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

function M.show_progress(current, total, item_name)
  -- Check if we're in a headless mode or no UI is available
  local ui_list = vim.api.nvim_list_uis()
  if #ui_list == 0 then
    -- Fallback to simple notification in headless mode
    vim.notify(string.format("Prophet: Uploading %d/%d: %s", current, total, item_name), vim.log.levels.INFO)
    return
  end
  
  if progress_win and vim.api.nvim_win_is_valid(progress_win) then
    vim.api.nvim_win_close(progress_win, true)
  end
  
  if not (progress_buf and vim.api.nvim_buf_is_valid(progress_buf)) then
    progress_buf = vim.api.nvim_create_buf(false, true)
  end
  
  local msg = string.format("Uploading %d/%d: %s", current, total, item_name)
  local bar = string.rep("█", math.floor((current / total) * 36)) .. string.rep("░", 36 - math.floor((current / total) * 36))
  
  vim.api.nvim_buf_set_lines(progress_buf, 0, -1, false, {
    "╭─────────────────────────────────────╮",
    "│ Prophet Upload Progress             │",
    "├─────────────────────────────────────┤",
    string.format("│ %s│", msg .. string.rep(" ", 36 - #msg)),
    string.format("│ %s│", bar),
    "╰─────────────────────────────────────╯",
  })
  
  local ui = ui_list[1]
  progress_win = vim.api.nvim_open_win(progress_buf, false, {
    relative = "editor",
    width = 41,
    height = 6,
    row = math.floor((ui.height - 6) / 2),
    col = math.floor((ui.width - 41) / 2),
    style = "minimal",
    border = "none",
  })
  
  vim.api.nvim_win_set_option(progress_win, "winhl", "Normal:Normal")
  
  vim.defer_fn(function()
    if progress_win and vim.api.nvim_win_is_valid(progress_win) then
      vim.api.nvim_win_close(progress_win, true)
      progress_win = nil
    end
  end, 2000)
end

return M
