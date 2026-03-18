import { defineConfig } from "vite";

export default defineConfig({
  root: "public",
  server: {
    port: 5173,
    proxy: {
      "/stream": "http://localhost:3000",
      "/bark": "http://localhost:3000",
      "/snapshot": "http://localhost:3000",
      "/api/clips": "http://localhost:3000",
      "/clips": "http://localhost:3000",
      "/events": {
        target: "http://localhost:3000",
        // SSE requires no response buffering
        configure: (proxy) => {
          proxy.on("proxyRes", (proxyRes) => {
            proxyRes.headers["cache-control"] = "no-cache";
          });
        },
      },
    },
  },
  build: {
    outDir: "../dist",
    emptyOutDir: true,
  },
});
