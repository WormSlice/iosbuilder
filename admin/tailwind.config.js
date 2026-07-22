/** @type {import('tailwindcss').Config} */
export default {
    content: [
        "./index.html",
        "./src/**/*.{js,ts,jsx,tsx}",
    ],
    theme: {
        extend: {
            colors: {
                background: "#0a0a0a",
                foreground: "#ffffff",
                primary: {
                    DEFAULT: "#0094FF",
                    dark: "#007acc",
                    glow: "rgba(0, 148, 255, 0.4)",
                },
                secondary: "#a1a1aa",
                muted: "#18181b",
                border: "rgba(255, 255, 255, 0.1)",
                accent: "#1E88E5",
            },
            fontFamily: {
                sans: ['Inter', 'system-ui', 'sans-serif'],
                archivo: ['Archivo', 'sans-serif'],
            },
            boxShadow: {
                'premium': '0 0 50px -12px rgba(0, 148, 255, 0.25)',
                'premium-glow': '0 4px 12px rgba(0, 148, 255, 0.2)',
                'glass': '0 8px 32px 0 rgba(0, 0, 0, 0.37)',
            },
            backgroundImage: {
                'gradient-premium': 'radial-gradient(circle at top center, rgba(0, 148, 255, 0.15) 0%, transparent 70%)',
            }
        },
    },
    plugins: [],
}
