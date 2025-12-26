#!/usr/bin/env lua

-- Copy the function logic to test it standalone

local function is_cartridge_project(project_file)
  local file = io.open(project_file, "r")
  if not file then return false end
  
  local content = file:read("*a")
  file:close()
  
  return content:find("com%.demandware%.studio%.core%.beehiveNature") ~= nil
end

-- Test with a known project file
local test_file = "/Users/iskaypet/Code/Work/Projects/ikp-digi-wcp-custom-sfra/animalis_cartridges/cartridges/app_custom_animalis/.project"

print("Testing file:", test_file)
print("Is cartridge?", is_cartridge_project(test_file))

-- Test the logic step by step
local file = io.open(test_file, "r")
if file then
    local content = file:read("*a")
    file:close()
    print("Content length:", #content)
    print("Contains beehiveNature?", content:find("com%.demandware%.studio%.core%.beehiveNature") ~= nil)
    print("Raw search result:", content:find("com%.demandware%.studio%.core%.beehiveNature"))
    print("Contains literal string?", content:find("com.demandware.studio.core.beehiveNature") ~= nil)
else
    print("Cannot open file")
end