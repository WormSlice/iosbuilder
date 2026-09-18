import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

// https://vitejs.dev/config/
export default defineConfig({
    base: '/',
    plugins: [react()],
    resolve: {
        alias: {
            '@': path.resolve(__dirname, './src'),
        },
    },
    server: {
        port: 3000,
        open: true,
        proxy: {

            '/api/yt-search': {
                target: 'https://invidious.f5.si/api/v1',
                changeOrigin: true,
                rewrite: (path) => path.replace(/^\/api\/yt-search/, '')
            },
        },
    },
})
