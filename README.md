# Brand Toolbox 🎨

A native macOS companion dock and Dynamic Island overlay for instant brand color hex copying and logo drag-and-drop.

Inspired by [Octane0411/open-vibe-island](https://github.com/Octane0411/open-vibe-island).

---

## ✨ Features

- **Left Screen Dock Mode ("Second Dock")**:
  - Floats on the far left edge of the screen as a sleek dark glass dock.
  - Automatically appears whenever you hover your cursor on the far left edge of the screen.
  - Smooth spring slide-out and auto-collapse on mouse leave with grace delay.
  - **Pin Button**: Pin the dock open while actively designing in Figma, Illustrator, Photoshop, Canva, or coding in VS Code.
- **Dynamic Island / Notch Mode**:
  - Sits in the MacBook display notch (or as a compact floating Dynamic Island pill on external displays).
  - In closed state, displays the active brand icon, name, and live color palette preview dots.
  - On hover or click, expands smoothly into a 2-column card view (Colors on left, Logos on right).
- **Seamless Mode Switching**:
  - Switch between **Left Dock** and **Dynamic Island / Notch** mode at any moment with a single click.
- **Brand Grouping & Switching**:
  - Group colors and logos by brand (preloaded with presets: **Apple**, **Open Island**, **Stripe**, **Figma**, **Linear**).
  - Quick brand switcher bar to switch brands in one click.
  - Create custom brands with custom symbols, names, taglines, and accent colors.
- **1-Click Color Hex Copying**:
  - Click any color swatch to instantly copy `#HEX` to your clipboard with haptic feedback and a visual "COPIED!" animation badge.
  - Right-click for multiple formats: `#HEX`, plain `HEX`, `rgb(...)`, SwiftUI `Color(hex: ...)`, and CSS variables (`--brand-...`).
  - Add custom colors with native macOS color picker and live contrast calculations.
- **Logo Drag & Drop**:
  - **Drag Out**: Click and drag any logo card directly into Finder, Desktop, Figma, Photoshop, Illustrator, or Slack.
  - **Drop In**: Drag any image file (PNG, SVG, JPG, PDF) straight into the app to import it into your brand.
  - Click logo to copy image directly to the clipboard.
- **Menu Bar Accessory & Shortcuts**:
  - Lives in your macOS menu bar with quick brand switcher, display mode toggle, and preferences.
  - Global toggle shortcut: `Cmd + Shift + B`.

---

## 🚀 Building & Running

### Build via Command Line
```bash
xcodebuild -scheme brand-toolbox -destination 'platform=macOS' build
```

### Launch App
```bash
open ./Build/Products/Debug/brand-toolbox.app
```

Or open `brand-toolbox.xcodeproj` directly in Xcode and click **Run** (`Cmd + R`).
