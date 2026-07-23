return {
  "nvim-telescope/telescope.nvim",
  opts = {
    defaults = {
      hide_hidden = false,
    },
    pickers = {
      live_grep = {
        additional_args = function(_)
          return { "--hidden" }
        end,
      },
    },
  },
}
