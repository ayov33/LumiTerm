# Changelog

## v1.9.0 (2026-04-15)

- Terminal theme selection: Default, Tokyo Night, Catppuccin Mocha
- Settings > Appearance: theme preview cards with radio button selection
- Theme applies to all tabs in real-time, panel background tint adapts
- New `ThemeRadioButton` custom control
- Theme preference persisted to UserDefaults

## v1.8.0 (2026-04-15)

- Ad-hoc code signing in package.sh (reduces macOS Gatekeeper warnings)
- Aurora WKWebView: unload content when expanded, reload on collapse (saves memory/CPU)
- Inline `collapsedVisibleRect()` dead forwarding method
- 37 unit tests: FrameCalculation (19) + OutputMonitor (18)
- Fix codesign symlink issue (remove before signing, restore after)

## v1.7.0 (2026-04-15)

- Animation: replace 8ms DispatchSource timer with NSAnimationContext (vsync-aligned, GPU-composited)
- ScreenEdgeMonitor: reduce poll timer 200ms to 1s (fallback only, events are primary)
- Remove dead `fitTerminal()` method
- Universal binary: package.sh builds arm64 + x86_64 for Intel Mac support
- Resource bundle moved to Contents/Resources with top-level symlink for SPM compatibility
- README: update requirements for universal binary

## v1.6.0 (2026-04-15)

- About page version reads from `Bundle.main.infoDictionary` (was hardcoded v1.4.0)
- Hotkey toggle now controls both `Cmd+Shift+A` and double-tap Right Option
- PTY `execve` memory safety fix (`strdup` for stable C pointer lifetime)
- Extract 6 custom UI control classes to `CustomControls.swift` (Settings 600 to 300 lines)
- Add `AppIcon.icns` (L-shaped gradient logo for Finder/Dock)
- `Info.plist`: add `CFBundleIconFile`
- Fix `fitAll` bug: `t.fit` to `t.fitAddon` (was silently no-op)
- Fix `.gitignore`: replace blanket `*.html` with specific demo file exclusions
- Fix StatusBarView hardcoded color to use Theme token
- Remove dead `container.alphaValue = 1.0` line
- Add Dependencies section to README (xterm.js, addon-fit)
- Notification names: hardcoded strings to `Notification.Name` constants
- Theme tokens: add `bgPanelSolid`, `bgSettings`; eliminate hardcoded colors
- `package.sh`: read version from Info.plist via PlistBuddy

## v1.5.0 (2026-04-15)

- **P0 fix**: Shell infinite restart loop — 3-retry backoff + red error message
- **P0 fix**: PTY `forkpty` failure — report error to user instead of silent fail
- **P0 fix**: DispatchIO `done` flag — stop scheduling reads after channel closes
- Global Hotkey toggle now actually enables/disables double-tap Option
- About page GitHub link is clickable (`ayov33/LumiTerm`)
- `MAX_TABS` increased from 3 to 5
- `Cmd+1~5` keyboard shortcuts to switch tabs
- Fix expand animation: semi-transparent overlay + instant terminal swap (no black flash)
- Add `.app` packaging script (`scripts/package.sh`)
- Add `Info.plist` with `LSUIElement=true`
- Add `README.md` (EN/CN bilingual) with screenshots
- Add MIT `LICENSE`
- First GitHub Release with downloadable `.app`

## v1.4.0 (2026-04-15)

- Integrate L-shaped gradient logo: menu bar icon (template image), Settings About, tab bar SVG
- Fix panel opacity: single-layer architecture (HTML body only, native layer clear)
- Fix double-tap Right Option hotkey: deduplicate global+local monitor events
- Fix Settings slider vertical alignment (knob + track centered)
- Tighten Settings card spacing (16px to 8px)
- Clean up unused `[weak self]` captures

## v1.3.0

- Settings window redesign with custom controls (Switch, Dropdown, Slider, Stepper, DockButtons)
- All UI controls hand-drawn with Core Graphics (no Interface Builder)
- Settings tabs: General, Appearance, Notifications, About

## v1.2.0

- Native experience improvements
- Hover expand/collapse polish
- Drag and edge snapping refinements

## v1.1.0

- Code cleanup and rename to LumiTerm
- Codebase organization

## v1.0.0

- Initial feature-complete release
- Swift + AppKit floating terminal with WKWebView + xterm.js
- Hover to expand/collapse
- Edge docking (top/bottom/left/right)
- Collapsed status bar with aurora/pixel pet animations
- Custom bubble notifications on command completion
- Global hotkey (`Cmd+Shift+A`) and double-tap Right Option
- Menu bar icon + Quit menu
- Settings window (launch at login, hotkey, dock position, appearance, notifications)
