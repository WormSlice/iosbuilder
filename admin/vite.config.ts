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
            '/api/mailgun': {
                target: 'https://api.mailgun.net/v3',
                changeOrigin: true,
                rewrite: (path) => path.replace(/^\/api\/mailgun/, ''),
                onProxyRes: (proxyRes) => {
                    delete proxyRes.headers['www-authenticate'];
                }
            },
            '/api/mailgun-storage': {
                target: 'https://storage.mailgun.net/v3',
                changeOrigin: true,
                rewrite: (path) => path.replace(/^\/api\/mailgun-storage/, ''),
                onProxyRes: (proxyRes) => {
                    delete proxyRes.headers['www-authenticate'];
                }
            },
            '/api/mailgun-storage-eu': {
                target: 'https://storage.de.mailgun.net/v3',
                changeOrigin: true,
                rewrite: (path) => path.replace(/^\/api\/mailgun-storage-eu/, ''),
                onProxyRes: (proxyRes) => {
                    delete proxyRes.headers['www-authenticate'];
                }
            },
        },
    },
})
