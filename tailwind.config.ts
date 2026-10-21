import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        ink: {
          50: "#f6f7f7",
          100: "#e9ebec",
          200: "#d2d6d8",
          300: "#aeb4b8",
          400: "#838b90",
          500: "#657074",
          600: "#515a5e",
          700: "#43494d",
          800: "#393e41",
          900: "#232627",
          950: "#17181a",
        },
        brand: {
          50: "#eefaf4",
          100: "#d5f1e2",
          200: "#aee3c9",
          300: "#79ccab",
          400: "#45ac87",
          500: "#24906d",
          600: "#1a7a5f",
          700: "#145c47",
          800: "#134a3a",
          900: "#123e31",
          950: "#08221b",
        },
        sand: {
          400: "#d9a155",
          500: "#c68638",
        },
      },
      fontFamily: {
        sans: ["var(--font-inter)", "system-ui", "sans-serif"],
        display: ["var(--font-outfit)", "var(--font-inter)", "system-ui", "sans-serif"],
      },
      borderRadius: {
        card: "20px",
        control: "10px",
      },
      maxWidth: {
        page: "1360px",
      },
      boxShadow: {
        card: "0 1px 2px rgb(23 24 26 / 0.04), 0 8px 24px -12px rgb(23 24 26 / 0.12)",
        "card-hover": "0 1px 2px rgb(23 24 26 / 0.05), 0 16px 32px -14px rgb(23 24 26 / 0.18)",
      },
      transitionTimingFunction: {
        out: "cubic-bezier(0.16, 1, 0.3, 1)",
      },
      keyframes: {
        "fade-up": {
          "0%": { opacity: "0", transform: "translateY(16px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
      },
      animation: {
        "fade-up": "fade-up 0.6s cubic-bezier(0.16, 1, 0.3, 1) both",
      },
    },
  },
  plugins: [],
};

export default config;
