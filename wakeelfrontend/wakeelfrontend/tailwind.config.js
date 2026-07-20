/** @type {import('tailwindcss').Config} */
const brand = {
  50: '#eeecfd',
  100: '#dcd9fb',
  200: '#b9b3f7',
  300: '#968df3',
  400: '#7367ef',
  500: '#2a15c8',
  600: '#1801ad',
  700: '#13018a',
  800: '#0e0168',
  900: '#090145',
};

module.exports = {
  content: [
    "./src/**/*.{js,jsx,ts,tsx}",
  ],
  darkMode: 'class',
  theme: {
    extend: {
      /* أوزان أثقل: أصناف مثل font-medium تضبط font-weight صراحةً وتلغي body */
      fontWeight: {
        normal: '500',
        medium: '600',
        semibold: '700',
        bold: '800',
        extrabold: '900',
      },
      fontFamily: {
        sans: ['Cairo', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        cairo: ['Cairo', 'sans-serif'],
      },
      colors: {
        primary: brand,
        purple: brand,
        indigo: brand,
        violet: brand,
      },
    },
  },
  plugins: [],
}
