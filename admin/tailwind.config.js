/** @type {import('tailwindcss').Config} */
export default {
    content: [
        "./index.html",
        "./src/**/*.{js,ts,jsx,tsx}",
    ],
    theme: {
        extend: {
            colors: {
                background: "#F8FAFC",
                foreground: "#0F172A",
                primary: {
                    DEFAULT: "#0094FF",
                    hover: "#0080DF",
                    dark: "#0070C0",
                    light: "#E0F2FE",
                },
                sidebar: "#0A0A0A",
                surface: "#FFFFFF",
                obsidian: {
                    DEFAULT: "#07080A",
                    card: "#0C0D12",
                    border: "rgba(255, 255, 255, 0.07)",
                    hover: "#12141C",
                }
            },
            fontFamily: {
                sans: ['"Plus Jakarta Sans"', 'Inter', 'system-ui', '-apple-system', 'sans-serif'],
                archivo: ['Archivo', 'sans-serif'],
            },
        },
    },
    plugins: [],
}
