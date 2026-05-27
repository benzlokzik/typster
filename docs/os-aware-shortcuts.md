# OS-aware keyboard shortcut hints

How Typster shows keyboard-shortcut hints that match the user's operating
system — ⌘ on Apple platforms, **Ctrl** everywhere else.

## Convention

The common keyboard modifier is the **Meta / ⌘ (Command)** key on macOS (and
related Apple platforms) and the **Control** key on Windows and Linux. UI that
advertises a shortcut should reflect the platform so the hint matches the key
the user actually presses. This is the de-facto standard across editors
(VS Code), and productivity apps (GitHub, Linear, Notion).

## Detection

Platform is detected once in `assets/js/app.js`, before the LiveSocket
connects, and recorded as a class on `<html>`:

```js
const platformHint =
  navigator.userAgentData?.platform || navigator.platform || navigator.userAgent || ""
document.documentElement.classList.toggle("is-mac", /mac/i.test(platformHint))
```

We prefer the modern UA-Client-Hints API (`navigator.userAgentData.platform`,
Chromium-only and experimental), fall back to the deprecated
`navigator.platform`, then the UA string. Together these three give a reliable
enough answer for a cosmetic hint; the actual key handler is platform-agnostic
and listens for `event.metaKey || event.ctrlKey`.

## Rendering

Hints render both variants and let CSS pick one based on `html.is-mac`
(see `assets/css/_typster_ui.css`):

- `.ts-mac` — shown on Apple platforms (default before JS runs).
- `.ts-other` — shown everywhere else.

The command-palette button (`editor_live/index.html.heex`) uses the lucide
`command` icon on macOS and `square-terminal` elsewhere. The ⌘ icon already
conveys the modifier, so the Mac key cap is just `K` (no duplicated ⌘); the
non-Mac variant spells out `Ctrl K` beside the terminal icon.

## Sources

- [Command or Control — Austin Poor](https://austinpoor.com/blog/command-or-control)
- [Capturing Keyboard Event Modifiers Across Operating Systems in JavaScript — Ben Nadel](https://www.bennadel.com/blog/4090-capturing-keyboard-event-modifiers-across-operating-systems-in-javascript.htm)
