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
            },
            fontFamily: {
                sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
                archivo: ['Archivo', 'sans-serif'],
            },
        },
    },
    plugins: [],
}
