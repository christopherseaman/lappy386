// Tomorrow Night Bright theme for Blink.sh
// Based on the official Tomorrow Night Bright theme by Chris Kempson
// Colors extracted from the official vim theme file

// ANSI colors - using official hex values from Tomorrow Night Bright vim theme
const black = "#000000";        // Official background color
const red = "#d54e53";          // Official red
const green = "#b9ca4a";        // Official green  
const yellow = "#e7c547";       // Official yellow
const blue = "#7aa6da";         // Official blue
const magenta = "#c397d8";      // Official purple/magenta
const cyan = "#70c0b1";         // Official aqua/cyan
const white = "#eaeaea";        // Official foreground

// Bright colors - using enhanced versions for better contrast
const lightBlack = "#969896";   // Official comment color (gray)
const lightRed = "#d54e53";     // Bright red (same as red for consistency)
const lightGreen = "#b9ca4a";   // Bright green
const lightYellow = "#e7c547";  // Bright yellow
const lightBlue = "#7aa6da";    // Bright blue
const lightMagenta = "#c397d8"; // Bright magenta
const lightCyan = "#70c0b1";    // Bright cyan
const lightWhite = "#ffffff";   // Pure white for maximum contrast

// Theme colors based on Tomorrow Night Bright
const colorMap = [
  black,
  red,
  green,
  yellow,
  blue,
  magenta,
  cyan,
  white,
  lightBlack,
  lightRed,
  lightGreen,
  lightYellow,
  lightBlue,
  lightMagenta,
  lightCyan,
  lightWhite
];

const t = {
  black,
  red,
  green,
  yellow,
  blue,
  magenta,
  cyan,
  white,
  lightBlack,
  lightRed,
  lightGreen,
  lightYellow,
  lightBlue,
  lightMagenta,
  lightCyan,
  lightWhite,

  // Terminal colors (from official Tomorrow Night Bright vim theme)
  background: "#000000",        // Official background: pure black
  foreground: "#eaeaea",        // Official foreground: light gray 
  cursor: "#eaeaea",           // Same as foreground for consistency
  selection: "#424242",        // Official selection color

  colorMap,
};

export default t;