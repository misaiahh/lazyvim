-- DAP setup for JavaScript / TypeScript using Microsoft's vscode-js-debug
-- (installed via Mason as `js-debug-adapter`). No nvim-dap-vscode-js needed.

return {
  -- Ensure js-debug-adapter is installed via Mason.
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "js-debug-adapter" })
    end,
  },

  -- Configure nvim-dap with the pwa-node adapter and JS/TS configurations.
  {
    "mfussenegger/nvim-dap",
    opts = function()
      local dap = require("dap")

      -- Adapter: launches Mason's js-debug DAP server on a free port.
      if not dap.adapters["pwa-node"] then
        dap.adapters["pwa-node"] = {
          type = "server",
          host = "localhost",
          port = "${port}",
          executable = {
            command = "node",
            args = {
              vim.fn.stdpath("data")
                .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js",
              "${port}",
            },
          },
        }
      end
      -- Reuse the same adapter for the other request types js-debug exposes.
      if not dap.adapters["node"] then
        dap.adapters["node"] = function(cb, config)
          if config.type == "node" then
            config.type = "pwa-node"
          end
          local nativeAdapter = dap.adapters["pwa-node"]
          if type(nativeAdapter) == "function" then
            nativeAdapter(cb, config)
          else
            cb(nativeAdapter)
          end
        end
      end

      local js_filetypes = {
        "typescript",
        "javascript",
        "typescriptreact",
        "javascriptreact",
      }

      local resolve_source_map_locations = {
        "${workspaceFolder}/**",
        "!**/node_modules/**",
      }

      local configurations = {
        -- 1. Launch the current file directly with tsx (zero-config TS runner).
        --    Falls back to `node` if the file is plain JS.
        {
          type = "pwa-node",
          request = "launch",
          name = "Launch current file (tsx)",
          program = "${file}",
          cwd = "${workspaceFolder}",
          runtimeExecutable = "npx",
          runtimeArgs = { "--yes", "tsx" },
          sourceMaps = true,
          resolveSourceMapLocations = resolve_source_map_locations,
          skipFiles = { "<node_internals>/**", "**/node_modules/**" },
          console = "integratedTerminal",
        },
        -- 2. Launch the compiled JS entry (uses package.json "main" or dist/server.js).
        {
          type = "pwa-node",
          request = "launch",
          name = "Launch compiled (dist/server.js)",
          program = "${workspaceFolder}/dist/server.js",
          cwd = "${workspaceFolder}",
          sourceMaps = true,
          resolveSourceMapLocations = resolve_source_map_locations,
          skipFiles = { "<node_internals>/**", "**/node_modules/**" },
          console = "integratedTerminal",
        },
        -- 3. Attach to a Node process started with --inspect / --inspect-brk.
        --    Pick from a list of running Node processes.
        {
          type = "pwa-node",
          request = "attach",
          name = "Attach to Node process",
          processId = require("dap.utils").pick_process,
          cwd = "${workspaceFolder}",
          sourceMaps = true,
          resolveSourceMapLocations = resolve_source_map_locations,
          skipFiles = { "<node_internals>/**", "**/node_modules/**" },
          restart = true,
        },
        -- 4. Attach to a fixed port (e.g. node --inspect=9229 dist/server.js).
        {
          type = "pwa-node",
          request = "attach",
          name = "Attach on port 9229",
          address = "localhost",
          port = 9229,
          cwd = "${workspaceFolder}",
          sourceMaps = true,
          resolveSourceMapLocations = resolve_source_map_locations,
          skipFiles = { "<node_internals>/**", "**/node_modules/**" },
          restart = true,
        },
        -- 5. Debug current Jest test file.
        {
          type = "pwa-node",
          request = "launch",
          name = "Debug Jest (current file)",
          cwd = "${workspaceFolder}",
          runtimeExecutable = "node",
          runtimeArgs = {
            "${workspaceFolder}/node_modules/.bin/jest",
            "--runInBand",
            "--no-coverage",
            "${file}",
          },
          sourceMaps = true,
          resolveSourceMapLocations = resolve_source_map_locations,
          skipFiles = { "<node_internals>/**", "**/node_modules/**" },
          console = "integratedTerminal",
        },
        -- 6. Debug current Vitest test file.
        {
          type = "pwa-node",
          request = "launch",
          name = "Debug Vitest (current file)",
          cwd = "${workspaceFolder}",
          runtimeExecutable = "node",
          runtimeArgs = {
            "${workspaceFolder}/node_modules/vitest/vitest.mjs",
            "run",
            "${file}",
          },
          sourceMaps = true,
          resolveSourceMapLocations = resolve_source_map_locations,
          skipFiles = { "<node_internals>/**", "**/node_modules/**" },
          console = "integratedTerminal",
        },
      }

      for _, ft in ipairs(js_filetypes) do
        dap.configurations[ft] = configurations
      end
    end,
  },
}
