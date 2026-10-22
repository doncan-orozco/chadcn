/// <reference types="node" />
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import path from 'path'

// Parity harness: scenario trees carry `className` values that appear nowhere in the catalog sources. Tailwind must
// generate them on this side too (the host build already scans docs/), so the scenarios directory becomes a @source.
const scenarioSources = {
  name: 'parity-scenario-sources',
  enforce: 'pre' as const,
  transform(code: string, id: string) {
    if (id.split('?')[0].endsWith('/src/index.css')) return `${code}\n@source "../../port/scenarios";\n`
  },
}

export default defineConfig(({ command }) => ({
  plugins: [scenarioSources, react(), tailwindcss()],
  resolve: { alias: { '@': path.resolve(__dirname, './src'), '@scenarios': path.resolve(__dirname, '../port/scenarios'), '@host-theme': path.resolve(__dirname, '../../app/assets/tailwind/chadcn') } },
  server: { fs: { allow: ['..', '../..'] } },
  base: command === 'build' ? '/react-catalog/' : '/',
  // The host serves this build at /react-catalog/ from its committed public/: the output stays there (chunk 2 moves the host assets).
  build: { outDir: '../../../../public/react-catalog', emptyOutDir: true },
}))
