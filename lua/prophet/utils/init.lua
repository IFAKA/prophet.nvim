local M = {}

local SFCC_EXTENSIONS = { isml = true, ds = true, js = true, json = true, properties = true, xml = true }

function M.should_ignore(filename, patterns)
  if not (filename and patterns) then return false end
  for _, pattern in ipairs(patterns) do
    if filename:match(pattern) then return true end
  end
  return false
end

function M.is_sfcc_file(filepath)
  return SFCC_EXTENSIONS[vim.fn.fnamemodify(filepath, ":e")] or false
end

function M.get_cartridge_from_path(filepath)
  local parts = vim.split(filepath, "/")
  for i, part in ipairs(parts) do
    if part == "cartridge" and i > 1 then
      return parts[i - 1]
    end
  end
  return nil
end

return M
