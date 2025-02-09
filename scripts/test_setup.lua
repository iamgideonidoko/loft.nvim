require("mini.test").setup({
  collect = {
    find_files = function()
      return vim.fn.globpath("tests", "**/*_spec.lua", true, true)
    end,
  },
})
