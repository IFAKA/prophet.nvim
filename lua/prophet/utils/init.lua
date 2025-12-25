local M = {}

function M.should_ignore(filename, patterns)
  if not filename or not patterns then
    return false
  end

  for _, pattern in ipairs(patterns) do
    if string.match(filename, pattern) then
      return true
    end
  end

  return false
end

local progress_win = nil
local progress_buf = nil

function M.show_progress(current, total, item_name)
  local msg = string.format("Uploading %d/%d: %s", current, total, item_name)

  -- Close previous window if exists
  if progress_win and vim.api.nvim_win_is_valid(progress_win) then
    vim.api.nvim_win_close(progress_win, true)
  end

  -- Create buffer
  if not progress_buf or not vim.api.nvim_buf_is_valid(progress_buf) then
    progress_buf = vim.api.nvim_create_buf(false, true)
  end

  -- Set content
  vim.api.nvim_buf_set_lines(progress_buf, 0, -1, false, {
    "╭─────────────────────────────────────╮",
    string.format("│ Prophet Upload Progress             │"),
    "├─────────────────────────────────────┤",
    string.format("│ %s", M.pad_right(msg, 36) .. "│"),
    string.format("│ %s", M.progress_bar(current, total, 36) .. "│"),
    "╰─────────────────────────────────────╯",
  })

  -- Calculate window position (center of screen)
  local width = 41
  local height = 6
  local ui = vim.api.nvim_list_uis()[1]
  local row = math.floor((ui.height - height) / 2)
  local col = math.floor((ui.width - width) / 2)

  -- Create floating window
  progress_win = vim.api.nvim_open_win(progress_buf, false, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "none",
  })

  -- Set highlight
  vim.api.nvim_win_set_option(progress_win, "winhl", "Normal:Normal,FloatBorder:Normal")

  -- Auto close after delay
  vim.defer_fn(function()
    if progress_win and vim.api.nvim_win_is_valid(progress_win) then
      vim.api.nvim_win_close(progress_win, true)
      progress_win = nil
    end
  end, 2000)
end

function M.pad_right(str, len)
  return str .. string.rep(" ", len - #str)
end

function M.progress_bar(current, total, width)
  local percentage = math.floor((current / total) * 100)
  local filled = math.floor((current / total) * width)
  local empty = width - filled

  local bar = string.rep("█", filled) .. string.rep("░", empty)
  return bar
end

function M.close_progress()
  if progress_win and vim.api.nvim_win_is_valid(progress_win) then
    vim.api.nvim_win_close(progress_win, true)
    progress_win = nil
  end
end

return M
