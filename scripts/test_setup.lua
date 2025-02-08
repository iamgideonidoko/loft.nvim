require("mini.test").setup({
  collect = {
    find_files = function()
      return vim.fn.globpath("lua/tests", "**/test_*.lua", true, true)
    end,
  },
})
