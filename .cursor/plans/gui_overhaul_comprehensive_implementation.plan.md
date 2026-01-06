# GUI Overhaul - Comprehensive Implementation

## Overview
Transform Typster into a modern, polished Typst editor with professional SaladUI styling matching shadcn/ui's mira design system, with advanced features and desktop-first UX.

---

## Design System

### Theme Configuration (Mira Style)
- **Base**: Radix UI
- **Style**: Mira (clean, minimal, subtle shadows)
- **Base Color**: Gray (neutral grays)
- **Theme**: Indigo (primary accents)
- **Menu Accent**: Subtle
- **Font**: Inter
- **Radius**: Default (0.5rem)

### Design Tokens
```css
--primary: #4f46e5;              /* Indigo-600 */
--primary-foreground: #ffffff;
--secondary: #f4f4f5;             /* Gray-100 */
--accent: #f4f4f5;
--background: #ffffff;
--foreground: #09090b;            /* Gray-950 */
--muted: #f4f4f5;
--muted-foreground: #737373;      /* Gray-500 */
--border: #e4e4e7;                /* Gray-200 */
--radius: 0.5rem;
```

---

## Phase 1: Foundation & Editor Alignment

### 1.1 Fix Editor Alignment Issues

**Problem**: Editor container lacks proper height/width constraints and layout structure causing misalignment.

**Files**:
- `lib/typster_web/live/editor_live/index.html.heex`
- `assets/css/app.css`

**Solution**:
- Fix editor container layout to use proper flexbox structure
- Ensure all three panes (sidebar, editor, preview) have equal height
- Add proper `min-h-0` and `overflow-hidden` to prevent layout shift
- Remove negative margins and fix z-index stacking

**Editor Template Structure**:
```heex
<div class="flex flex-1 overflow-hidden h-[calc(100vh-4rem)]">
  <!-- Sidebar -->
  <!-- Editor Pane -->
  <!-- Preview Pane -->
</div>
```

---

## Phase 2: Component Library (SaladUI) Implementation

### 2.1 Core Components

Create reusable SaladUI components matching shadcn/ui's mira style:

**Files to Create**:
- `lib/typster_web/components/ui/button.ex`
- `lib/typster_web/components/ui/card.ex`
- `lib/typster_web/components/ui/input.ex`
- `lib/typster_web/components/ui/dialog.ex`
- `lib/typster_web/components/ui/dropdown_menu.ex`
- `lib/typster_web/components/ui/tooltip.ex`
- `lib/typster_web/components/ui/badge.ex`
- `lib/typster_web/components/ui/separator.ex`
- `lib/typster_web/components/ui/scroll_area.ex`
- `lib/typster_web/components/ui/skeleton.ex`
- `lib/typster_web/components/ui/toast.ex`
- `lib/typster_web/components/ui/breadcrumb.ex`

**Component Design Pattern**:
```elixir
defmodule TypsterWeb.Components.UI.Button do
  use Phoenix.Component

  attr :variant, :string, default: "default", values: ["default", "ghost", "outline", "link", "destructive"]
  attr :size, :string, default: "default", values: ["default", "sm", "lg", "icon"]
  attr :rest, :global
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button class={button_classes(assigns)} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp button_classes(assigns) do
    base = "inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 focus-visible:ring-offset-2 disabled:opacity-50 disabled:pointer-events-none"

    variants = %{
      "default" => "bg-indigo-600 text-white hover:bg-indigo-700",
      "ghost" => "hover:bg-gray-100 hover:text-gray-900",
      "outline" => "border border-gray-200 bg-transparent hover:bg-gray-100",
      "link" => "text-indigo-600 underline-offset-4 hover:underline",
      "destructive" => "bg-red-600 text-white hover:bg-red-700"
    }

    sizes = %{
      "default" => "h-10 px-4 py-2",
      "sm" => "h-9 rounded-md px-3",
      "lg" => "h-11 rounded-md px-8",
      "icon" => "h-10 w-10"
    }

    [
      base,
      variants[@variant],
      sizes[@size]
    ]
  end
end
```

### 2.2 Update Existing Pages

**Files**:
- `lib/typster_web/controllers/page_html/home.html.heex`
- `lib/typster_web/live/project_live/index.html.heex`
- `lib/typster_web/live/project_live/show.html.heex`
- `lib/typster_web/live/editor_live/index.html.heex`

---

## Phase 3: Advanced Editor Features

### 3.1 Panel Resizing System

**Files**:
- `lib/typster_web/live/editor_live/index.html.heex` - Add resize handles
- `assets/js/panel_resizer.js` - New file
- `assets/css/app.css` - Add resize handle styling

### 3.2 Keyboard Shortcuts

**Files**:
- `lib/typster_web/components/ui/command_palette.ex` - Command palette component
- `lib/typster_web/live/editor_live/index.ex` - Add keyboard event handlers
- `assets/js/keyboard_shortcuts.js` - New file

**Shortcuts**:
- `Cmd/Ctrl + S` - Save document
- `Cmd/Ctrl + Shift + P` - Command palette
- `Cmd/Ctrl + B` - Toggle sidebar
- `Cmd/Ctrl + E` - Toggle editor/preview
- `Cmd/Ctrl + /` - Toggle search
- `Cmd/Ctrl + N` - New file
- `Cmd/Ctrl + W` - Close current file
- `Cmd/Ctrl + 1-9` - Switch to file n

### 3.3 Search & Replace

**Files**:
- `assets/js/search.js` - Search functionality
- `lib/typster_web/live/editor_live/index.html.heex` - Search UI

---

## Phase 4: Visual Polish & UX

### 4.1 Enhanced Typography

```css
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');

body {
  font-family: 'Inter', system-ui, -apple-system, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
```

### 4.2 Smooth Animations

```css
.transition-all-smooth {
  transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
}

.hover-lift {
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.hover-lift:hover {
  transform: translateY(-2px);
  box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.1);
}

.focus-ring {
  outline: none;
}

.focus-ring:focus-visible {
  outline: none;
  box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.3);
}
```

### 4.3 Loading States & Skeletons

### 4.4 File Tree Enhancements

### 4.5 Preview Panel Enhancements

### 4.6 Toast Notifications

---

## Phase 5: Editor Improvements

### 5.1 Enhanced CodeMirror Styling

```javascript
const miraLightTheme = EditorView.theme({
  "&": {
    backgroundColor: "#ffffff",
    color: "#09090b",
    fontFamily: "'JetBrains Mono', 'Fira Code', monospace"
  },
  ".cm-gutters": {
    backgroundColor: "#f4f4f5",
    color: "#a1a1aa",
    border: "none"
  },
  ".cm-activeLine": {
    backgroundColor: "#fafafa"
  },
  ".cm-selectionBackground": {
    backgroundColor: "rgba(79, 70, 229, 0.2)"
  }
})
```

### 5.2 Minimap

### 5.3 Bracket Matching

---

## Phase 6: Navigation & Routing

### 6.1 Breadcrumbs

### 6.2 Improved Navbar

---

## Phase 7: Accessibility

### 7.1 Focus Management

### 7.2 Color Contrast

---

## Phase 8: Performance

### 8.1 CodeMirror Optimization

### 8.2 Asset Optimization

---

## Implementation Order

1. **Fix editor alignment** (immediate)
2. **Create SaladUI components** (button, card, input, skeleton, badge, separator)
3. **Update home page** with modern design
4. **Update projects pages** with modern design
5. **Update editor template** with SaladUI components
6. **Enhance CodeMirror styling** with mira theme
7. **Add smooth animations** and transitions
8. **Add tooltips** throughout UI
9. **Implement panel resizing**
10. **Add keyboard shortcuts**
11. **Implement search and replace**
12. **Add loading skeletons** and toast notifications
13. **Run precommit** and fix issues

---

## Success Criteria

✅ Editor perfectly aligned with no layout shifts
✅ All pages use consistent SaladUI styling matching mira design
✅ Panel resizing works smoothly with saved state
✅ Keyboard shortcuts for all major operations
✅ Search and replace functional
✅ Desktop-first UX with responsive fallback
✅ Dark mode fully supported across all components
✅ Accessibility passes WCAG AA standards
✅ Performance >90 on Lighthouse
✅ Zero console errors in production
