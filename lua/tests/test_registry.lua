local test_set = MiniTest.new_set()

test_set["addition works"] = function()
  MiniTest.expect.equality(1 + 1, 2)
end

return test_set
