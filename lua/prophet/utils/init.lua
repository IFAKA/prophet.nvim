local M = {}

local progress_win, progress_buf

function M.should_ignore(filename, patterns)
  if not (filename and patterns) then return false end
  for _, pattern in ipairs(patterns) do
    if string.match(filename, pattern) then return true end
  end
  return false
end

function M.show_progress(current, total, item_name)
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
  
  local ui = vim.api.nvim_list_uis()[1]
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
