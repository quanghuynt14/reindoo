import { defineConfig } from 'vitest/config'
import viteReact from '@vitejs/plugin-react'
import { fileURLToPath } from 'node:url'

export default defineConfig({
  // Component tests need the JSX transform and the "@/" alias, which the app's
  // vite.config.ts only provides through plugins that do not apply under Vitest.
  plugins: [viteReact()],
  resolve: {
    alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) },
  },
  test: {
    environment: 'node', 
  },
})