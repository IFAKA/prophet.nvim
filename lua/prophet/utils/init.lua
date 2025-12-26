local M = {}

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

-- Progress display disabled - notifications are sufficient and modal causes lag
function M.init_progress_display(total)
  -- No-op: notifications already show progress per-cartridge
end

function M.update_progress_display(state)
  -- No-op: modal disabled
end

function M.close_progress_display()
  -- No-op: modal disabled
end

-- LEGACY: Keep for compatibility - just uses notification
function M.show_progress(current, total, item_name)
  vim.notify(string.format("Prophet: Uploading %d/%d: %s", current, total, item_name), vim.log.levels.INFO)
end

return M