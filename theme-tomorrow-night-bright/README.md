# Tomorrow Night Bright Theme

An authentic port of Chris Kempson's "Tomorrow Night Bright" color scheme for multiple platforms. This repository contains the exact color values from the official theme, formatted for different terminal emulators and editors.

## Installation Instructions

### Blink.sh (iOS Terminal)

#### Method 1: Direct Import
1. Download `TomorrowNightBright.js` to your iOS device
2. Open Blink.sh
3. Go to Settings → Appearance → Themes
4. Import the theme file
5. Select "TomorrowNightBright" from your themes

#### Method 2: Manual Entry
1. In Blink.sh, go to Settings → Appearance → Themes → Add
2. Copy and paste the contents of `TomorrowNightBright.js`
3. Save with name "TomorrowNightBright"

### macOS Terminal.app

#### Method 1: Using the .terminal file
1. Double-click `Tomorrow Night Bright.terminal` to import
2. Open Terminal preferences (Cmd+,)
3. Go to Profiles tab
4. Select "Tomorrow Night Bright" and click "Default"

#### Method 2: Manual Setup
1. Open Terminal preferences (Cmd+,)
2. Create a new profile or duplicate an existing one
3. Go to the "Text" tab and set:
   - **Text**: `#eaeaea` (foreground)
   - **Background**: `#000000` (background)
   - **Selection**: `#424242`
   - **Cursor**: `#eaeaea`
4. In the "ANSI Colors" section, set:
   - **Black**: `#000000` / **Bright Black**: `#969896`
   - **Red**: `#d54e53` / **Bright Red**: `#d54e53`
   - **Green**: `#b9ca4a` / **Bright Green**: `#b9ca4a`
   - **Yellow**: `#e7c547` / **Bright Yellow**: `#e7c547`
   - **Blue**: `#7aa6da` / **Bright Blue**: `#7aa6da`
   - **Magenta**: `#c397d8` / **Bright Magenta**: `#c397d8`
   - **Cyan**: `#70c0b1` / **Bright Cyan**: `#70c0b1`
   - **White**: `#eaeaea` / **Bright White**: `#ffffff`

### Vim/Neovim

#### Installation
1. **For LazyVim users** (recommended):
   Add to your `~/.config/nvim/lua/plugins/colorscheme.lua`:
   ```lua
   return {
     {
       "chriskempson/tomorrow-theme",
       name = "tomorrow-theme",
       config = function()
         vim.cmd([[colorscheme Tomorrow-Night-Bright]])
       end,
     },
   }
   ```

2. **Using the included file**:
   ```bash
   # Copy to Neovim colors directory
   cp Tomorrow-Night-Bright.vim ~/.config/nvim/colors/
   ```
   Then add to your LazyVim config:
   ```lua
   vim.cmd([[colorscheme Tomorrow-Night-Bright]])
   ```

3. **Using lazy.nvim directly**:
   ```lua
   {
     "chriskempson/tomorrow-theme",
     lazy = false,
     priority = 1000,
     config = function()
       vim.cmd([[colorscheme Tomorrow-Night-Bright]])
     end,
   }
   ```

4. **Manual download**:
   ```bash
   mkdir -p ~/.config/nvim/colors
   curl -o ~/.config/nvim/colors/Tomorrow-Night-Bright.vim https://raw.githubusercontent.com/chriskempson/tomorrow-theme/master/vim/colors/Tomorrow-Night-Bright.vim
   ```

#### Activation
For LazyVim, the colorscheme should be set in the plugin configuration above. If you need to set it manually, add to your `~/.config/nvim/init.lua`:
```lua
vim.cmd([[colorscheme Tomorrow-Night-Bright]])
```

For traditional Vim, add to your `~/.vimrc`:
```vim
colorscheme Tomorrow-Night-Bright
```

### VS Code

#### Method 1: Extension (Recommended)
1. Open VS Code
2. Go to Extensions (Ctrl/Cmd+Shift+X)
3. Search for "Tomorrow Night Bright" or "Tomorrow Theme" extensions
4. Install and select from Command Palette (Ctrl/Cmd+Shift+P) → "Preferences: Color Theme"

#### Method 2: Manual Theme Installation
1. Open Command Palette (Ctrl/Cmd+Shift+P)
2. Type "Preferences: Open Settings (JSON)"
3. Add custom theme configuration or install a Tomorrow Night extension from the marketplace

#### Method 3: Settings Sync
If you have a Tomorrow Night theme file for VS Code:
1. Place theme file in: `~/.vscode/extensions/` (create if needed)
2. Restart VS Code
3. Select theme from Command Palette → "Preferences: Color Theme"

### iTerm2 (macOS)

#### Installation
1. Download a Tomorrow Night Bright iTerm2 color scheme file
2. Open iTerm2 preferences (Cmd+,)
3. Go to Profiles → Colors
4. Click "Color Presets..." dropdown
5. Select "Import..." and choose the color scheme file
6. Select "Tomorrow Night Bright" from the presets

#### Manual Setup
In iTerm2 preferences → Profiles → Colors, set:
- **Foreground**: `#eaeaea`
- **Background**: `#000000`
- **Selection**: `#424242`
- **Cursor**: `#eaeaea`
- Set ANSI colors as listed in the macOS Terminal section above

## Platform-Specific Files

This repository includes theme files for different platforms:

- **`TomorrowNightBright.js`** - Blink.sh theme file
- **`Tomorrow Night Bright.terminal`** - macOS Terminal.app profile
- **`Tomorrow-Night-Bright.vim`** - Vim/Neovim color scheme (official)

## Color Palette

This theme uses the **official** Tomorrow Night Bright colors as defined by Chris Kempson:

### Standard ANSI Colors
| Color | Hex Code | Official Name | Usage |
|-------|----------|---------------|-------|
| Black | `#000000` | Background | Terminal background |
| Red | `#d54e53` | Red | Errors, important text |
| Green | `#b9ca4a` | Green | Success messages, strings |
| Yellow | `#e7c547` | Yellow | Warnings, numbers |
| Blue | `#7aa6da` | Blue | Information, functions |
| Magenta | `#c397d8` | Purple | Keywords, special |
| Cyan | `#70c0b1` | Aqua | Constants, operators |
| White | `#eaeaea` | Foreground | Default text |

### Bright Colors
| Color | Hex Code | Usage |
|-------|----------|-------|
| Bright Black | `#969896` | Comments, dimmed text |
| Bright Red | `#d54e53` | Highlighted errors |
| Bright Green | `#b9ca4a` | Highlighted success |
| Bright Yellow | `#e7c547` | Highlighted warnings |
| Bright Blue | `#7aa6da` | Highlighted info |
| Bright Magenta | `#c397d8` | Highlighted keywords |
| Bright Cyan | `#70c0b1` | Highlighted constants |
| Bright White | `#ffffff` | Maximum contrast text |

### UI Colors
- **Background**: `#000000` (Pure black)
- **Foreground**: `#eaeaea` (Light gray, official foreground)
- **Cursor**: `#eaeaea` (Matches foreground)
- **Selection**: `#424242` (Medium gray, official selection)

## Platform Compatibility

| Platform | File | Status |
|----------|------|--------|
| Blink.sh (iOS) | `TomorrowNightBright.js` | ✅ Ready |
| macOS Terminal | `Tomorrow Night Bright.terminal` | ✅ Ready |
| Vim/Neovim | `Tomorrow-Night-Bright.vim` | ✅ Official |
| VS Code | Extension/Manual | ⚠️ Use marketplace |
| iTerm2 | Manual setup | ⚠️ Manual colors |

## Features

- ✅ **100% Official Colors**: Uses exact hex values from Chris Kempson's vim theme
- ✅ **Multi-Platform**: Installation instructions for all major terminals/editors
- ✅ **Pure Black Background**: True black (#000000) perfect for OLED displays
- ✅ **High Contrast**: Excellent readability in all lighting conditions  
- ✅ **Syntax Friendly**: Optimized color choices for code highlighting
- ✅ **Authentic Design**: Faithful to the original Tomorrow Night Bright aesthetic

## Recommended Settings (All Platforms)

- **Font**: SF Mono, Menlo, Fira Code, or Source Code Pro
- **Font Size**: 12-14pt for optimal readability
- **Cursor Style**: Block or underline
- **Opacity**: 100% (theme designed for solid background)
- **Anti-aliasing**: Enabled for smooth text rendering

## Color Verification

All colors have been verified against the official Tomorrow Night Bright vim theme:

```vim
let s:foreground = "eaeaea"  ← Our foreground
let s:background = "000000"  ← Our background  
let s:selection = "424242"   ← Our selection
let s:comment = "969896"     ← Our lightBlack
let s:red = "d54e53"        ← Our red
let s:orange = "e78c45"     ← (Used for constants in vim)
let s:yellow = "e7c547"     ← Our yellow
let s:green = "b9ca4a"      ← Our green
let s:aqua = "70c0b1"       ← Our cyan
let s:blue = "7aa6da"       ← Our blue
let s:purple = "c397d8"     ← Our magenta
```

## Recommended Settings

- **Font**: SF Mono, Menlo, or Fira Code
- **Font Size**: 12-14pt for optimal readability
- **Cursor Style**: Block or underline
- **Opacity**: 100% (theme designed for solid background)

## Troubleshooting

### Common Issues

**Theme not appearing in terminal:**
- Ensure the theme file is in the correct location
- Check file permissions (should be readable)
- Restart the application after installation

**Colors look different:**
- Verify your terminal supports 256 colors or true color
- Check if other color profiles are interfering
- Ensure background is set to pure black (#000000)

**Blink.sh specific:**
- Theme must be valid JavaScript (check syntax)
- File should export default object
- Colors should be hex strings with # prefix

**Vim/Neovim specific:**
- Ensure `set termguicolors` is enabled for true color support
- Check that the color scheme file is in the colors directory
- Verify your terminal supports the required color depth

## Screenshots & Preview

The theme provides:
- **Pure black background** perfect for OLED screens and dark environments
- **Bright, saturated colors** that maintain excellent contrast
- **Consistent appearance** across different platforms and applications
- **Professional aesthetic** suitable for both coding and general terminal use

## Version History

- **v1.0**: Initial Blink.sh port with official colors
- **v1.1**: Added multi-platform support and documentation
- **Current**: Complete installation guide for all major platforms

## Contributing

To add support for additional platforms:
1. Use the official color values listed in this README
2. Follow the platform's theme/color scheme format
3. Test thoroughly across different scenarios
4. Submit with installation instructions

## Support & Resources

- **Original Theme**: [Tomorrow Theme GitHub](https://github.com/chriskempson/tomorrow-theme)
- **Color Reference**: Use the hex values in the Color Palette section
- **Issues**: Check platform-specific troubleshooting sections
- **Additional Platforms**: Many more platforms available in the original Tomorrow Theme repository

## Credits & License

- **Original Theme**: [Tomorrow Theme](https://github.com/chriskempson/tomorrow-theme) by Chris Kempson
- **Color Source**: Official Tomorrow-Night-Bright.vim theme
- **Multi-Platform Port**: Comprehensive installation guide
- **License**: Follows original Tomorrow Theme licensing

## Related Tomorrow Themes

This is part of the Tomorrow color scheme family:
- **Tomorrow** (light theme)
- **Tomorrow Night** (standard dark)
- **Tomorrow Night Blue** (blue accent)
- **Tomorrow Night Eighties** (retro feel)
- **Tomorrow Night Bright** (this theme - high contrast)

---

*Authentic Tomorrow Night Bright theme with installation support for Blink.sh, macOS Terminal, Vim/Neovim, VS Code, and iTerm2. Maintains 100% fidelity to Chris Kempson's original design.*