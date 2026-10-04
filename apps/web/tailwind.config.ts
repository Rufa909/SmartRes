import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        ink: "#17201c",
        leaf: "#2f6f4e",
        saffron: "#d58a1f",
        mist: "#eef3ef",
        coral: "#ff5948"
      }
    }
  },
  plugins: []
};

export default config;

