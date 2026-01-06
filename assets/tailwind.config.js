/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
"../deps/salad_ui/lib/**/*.ex",
    "../lib/typster_web/**/*.{heex,ex}",
    "../priv/repo/migrations/**/*.exs"
  ],
  theme: {
    extend: {
      colors: require("./tailwind.colors.json"),
      fontFamily: {
        sans: ["Inter", "system-ui", "sans-serif"],
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
    },
  },
  plugins: [
    require("@tailwindcss/typography"),
    require("./vendor/tailwindcss-animate"),],
}
