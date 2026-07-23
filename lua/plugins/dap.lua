-- DAP setup for JavaScript / TypeScript using Microsoft's vscode-js-debug
-- (installed via Mason as `js-debug-adapter`). No nvim-dap-vscode-js needed.

return {
  -- Ensure js-debug-adapter is installed via Mason.
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "js-debug-adapter" })
    end,
  },

  -- Configure nvim-dap with the pwa-node adapter and JS/TS configurations.
  {
    "mfussenegger/nvim-dap",
    config = function(_, opts)
      local dap = require("dap")


      dap.defaults.fallback.terminal_win_cmd = "tabnew"

      -- Adapter: launches Mason's js-debug DAP server on a free port.
      dap.adapters["pwa-node"] = {
        type = "server",
        host = "localhost",
        port = "${port}",
        executable = {
          command = "node",
          args = {
            vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js",
            "${port}",
          },
        },
      }

      -- Alias "node" → "pwa-node" so .vscode/launch.json configs work.
      dap.adapters["node"] = dap.adapters["pwa-node"]

      -- When a breakpoint is hit, make that session the active one so that
      -- dap.continue() targets the correct child session (js-debug spawns a
      -- separate child session for each Node worker process).
      dap.listeners.after.event_stopped["focus_session"] = function(session)
        dap.set_session(session)
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
        -- 5. Attach to AppSync Event Publisher debug session (port 9330).
        --    Use this when running with --inspect-brk flag.
        {
          type = "pwa-node",
          request = "attach",
          name = "Attach to Event Publisher (9330)",
          address = "localhost",
          port = 9330,
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
        -- 7. Debug Live E2E tests (clportal-functions).
        --    Uses node + vitest.mjs directly to avoid pnpm-as-runtimeExecutable
        --    bug in js-debug-adapter (duplicate configurationDone → immediate exit).
        {
          type = "pwa-node",
          request = "launch",
          name = "Debug Live E2E",
          cwd = "${workspaceFolder}",
          runtimeExecutable = "node",
          runtimeArgs = {
            "${workspaceFolder}/node_modules/vitest/vitest.mjs",
            "run",
            "--no-file-parallelism",
            "--testTimeout=60000",
            "tests/e2e/live/live.e2e.spec.ts",
          },
          env = { RUN_LIVE = "true" },
          sourceMaps = true,
          resolveSourceMapLocations = { "${workspaceFolder}/**", "!**/node_modules/**" },
          skipFiles = { "<node_internals>/**" },
          console = "integratedTerminal",
        },
        -- 8. Debug AppSync Event Publisher with production AWS.
        --    Runs the syncSession resolver which calls publishEvent().
        --    Requires APPsync_EVENTS_API_ID to be set in environment.
        {
          type = "pwa-node",
          request = "launch",
          name = "Debug AppSync Event Publisher (Production)",
          program = "${workspaceFolder}/src-ts/appsync/index.ts",
          cwd = "${workspaceFolder}",
          runtimeExecutable = "npx",
          runtimeArgs = { "--yes", "tsx" },
          env = {
            APPsync_REGION = "us-east-1",
            APPsync_EVENTS_API_ID = "${env:APPsync_EVENTS_API_ID}",
            AWS_REGION = "us-east-1",
            AWS_PROFILE = "Encova-PermSet-SysAdmin-296519309226",
          },
          sourceMaps = true,
          resolveSourceMapLocations = { "${workspaceFolder}/**", "!**/node_modules/**" },
          skipFiles = { "<node_internals>/**", "**/node_modules/**" },
          console = "integratedTerminal",
        },
        -- 9. Debug AppSync Event Publisher with mock data (no AWS calls).
        {
          type = "pwa-node",
          request = "launch",
          name = "Debug Event Publisher (Mock)",
          program = "${workspaceFolder}/src-ts/appsync/index.ts",
          cwd = "${workspaceFolder}",
          runtimeExecutable = "npx",
          runtimeArgs = { "--yes", "tsx" },
          env = {
            APPsync_REGION = "us-east-1",
            APPsync_EVENTS_API_ID = "mock-api-id",
            AWS_REGION = "us-east-1",
          },
          sourceMaps = true,
          resolveSourceMapLocations = { "${workspaceFolder}/**", "!**/node_modules/**" },
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
