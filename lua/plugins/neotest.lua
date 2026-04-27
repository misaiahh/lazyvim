-- Vitest adapter for neotest. Requires `vitest` to be installed in the
-- project's node_modules. See marilari88/neotest-vitest README.
return {
  {
    "nvim-neotest/neotest",
    dependencies = { "marilari88/neotest-vitest" },
    opts = {
      adapters = {
        ["neotest-vitest"] = {
          -- Skip node_modules when discovering tests.
          filter_dir = function(name, _, _)
            return name ~= "node_modules"
          end,
        },
      },
    },
  },
}
