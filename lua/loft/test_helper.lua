---@diagnostic disable: inject-field
local helpers = {}

-- Add extra expectations
helpers.expect = vim.deepcopy(MiniTest.expect)

helpers.expect.truthy = MiniTest.new_expectation("truthy", function(value)
  return value ~= nil and value ~= false
end, function(value)
  return string.format("%s is not truthy", value)
end)

helpers.expect.falsy = MiniTest.new_expectation("falsy", function(value)
  return value == nil or value == false
end, function(value)
  return string.format("%s is not falsy", value)
end)

--- Monkey-patch `MiniTest.new_child_neovim` with helpful wrappers
helpers.new_child_neovim = function()
  local child = MiniTest.new_child_neovim()

  child.setup = function()
    child.restart({ "-u", "scripts/minimal_init.vim" })
    -- Change initial buffer to be readonly. This not only increases execution
    -- speed, but more closely resembles manually opened Neovim.
    child.bo.readonly = false
  end

  return child
end

-- Detect CI
helpers.is_ci = function()
  return os.getenv("CI") ~= nil
end
helpers.skip_in_ci = function(msg)
  if helpers.is_ci() then
    MiniTest.skip(msg or "Does not test properly in CI")
  end
end

-- Detect OS
helpers.is_windows = function()
  return vim.fn.has("win32") == 1
end
helpers.skip_on_windows = function(msg)
  if helpers.is_windows() then
    MiniTest.skip(msg or "Does not test properly on Windows")
  end
end

helpers.is_macos = function()
  return vim.fn.has("mac") == 1
end
helpers.skip_on_macos = function(msg)
  if helpers.is_macos() then
    MiniTest.skip(msg or "Does not test properly on MacOS")
  end
end

helpers.is_linux = function()
  return vim.fn.has("linux") == 1
end
helpers.skip_on_linux = function(msg)
  if helpers.is_linux() then
    MiniTest.skip(msg or "Does not test properly on Linux")
  end
end

-- Standardized way of dealing with time
helpers.is_slow = function()
  return helpers.is_ci() and (helpers.is_windows() or helpers.is_macos())
end
helpers.skip_if_slow = function(msg)
  if helpers.is_slow() then
    MiniTest.skip(msg or "Does not test properly in slow context")
  end
end

helpers.get_time_const = function(delay)
  local coef = 1
  if helpers.is_ci() then
    if helpers.is_linux() then
      coef = 2
    end
    if helpers.is_windows() then
      coef = 5
    end
    if helpers.is_macos() then
      coef = 15
    end
  end
  return coef * delay
end

helpers.sleep = function(ms, child, skip_slow)
  if skip_slow then
    helpers.skip_if_slow("Skip because state checks after sleep are hard to make robust in slow context")
  end
  vim.loop.sleep(math.max(ms, 1))
  if child ~= nil then
    child.poke_eventloop()
  end
end

-- Standardized way of setting number of retries
helpers.get_n_retry = function(n)
  local coef = 1
  if helpers.is_ci() then
    if helpers.is_linux() then
      coef = 2
    end
    if helpers.is_windows() then
      coef = 3
    end
    if helpers.is_macos() then
      coef = 4
    end
  end
  return coef * n
end

return helpers
