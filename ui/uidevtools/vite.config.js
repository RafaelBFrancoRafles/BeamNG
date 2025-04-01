import { defineConfig } from "vite"
import { fileURLToPath, URL } from "url"
import vue from "@vitejs/plugin-vue"
import pkg from "./package.json";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
  server: (() => {
    const url = new URL(pkg.debug.env.UIDEVTOOLS_APP_URL)
    return {
      host: url.hostname,
      port: +url.port,
    }
  })(),
  define: {
    __VITE_SERVER_HOST__: JSON.stringify(process.env.VITE_SERVER_HOST || 'localhost'),
    __VITE_SERVER_PORT__: JSON.stringify(process.env.VITE_SERVER_PORT || '8085'),
  }
})
